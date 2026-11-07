import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;

import '../models/entities.dart';

/// Profile/message contents are encrypted on-device. Chat membership and time
/// metadata remain visible only because Firestore needs them to enforce access.
class FirestoreRepository {
  FirestoreRepository({FirebaseFirestore? database})
    : _db = database ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  final _aes = AesGcm.with256bits();
  // Replace with per-chat secure key exchange before production release.
  final SecretKey _key = SecretKey(Uint8List.fromList(
    List.generate(32, (i) => (i * 67 + 29) % 255),
  ));
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _chats => _db.collection('chats');

  Future<String> _hash(String text) async => base64UrlEncode(
    (await Sha256().hash(utf8.encode(text.trim().toLowerCase()))).bytes,
  );
  Future<String> encrypt(String value) async {
    final box = await _aes.encrypt(utf8.encode(value), secretKey: _key);
    return base64Encode([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }
  Future<String> decrypt(String value) async {
    final bytes = base64Decode(value);
    return utf8.decode(await _aes.decrypt(SecretBox(
      bytes.sublist(12, bytes.length - 16), nonce: bytes.sublist(0, 12),
      mac: Mac(bytes.sublist(bytes.length - 16)),
    ), secretKey: _key));
  }

  Future<void> createProfile({required String username, required String about, required String avatar}) async {
    if (uid.isEmpty) throw StateError('You must be signed in.');
    final usernameHash = await _hash(username);
    final claim = _db.collection('usernames').doc(usernameHash);
    final profile = await _profilePayload(username, about, avatar);
    await _db.runTransaction((tx) async {
      if ((await tx.get(claim)).exists) throw StateError('That username is already in use.');
      tx.set(claim, {'uid': uid});
      tx.set(_users.doc(uid), {
        'usernameHash': usernameHash,
        'emailHash': await _hash(FirebaseAuth.instance.currentUser!.email!),
        'profile': profile, 'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<String> _profilePayload(String username, String about, String avatar) => encrypt(jsonEncode({
    'username': username, 'about': about, 'avatar': avatar,
    'email': FirebaseAuth.instance.currentUser?.email ?? '',
  }));

  Future<void> upsertProfile({required String username, required String about, required String avatar}) async {
    if (uid.isEmpty) return;
    final ref = _users.doc(uid), existing = await ref.get();
    if (!existing.exists) return createProfile(username: username, about: about, avatar: avatar);
    final oldHash = existing.data()?['usernameHash'] as String?;
    final newHash = await _hash(username), payload = await _profilePayload(username, about, avatar);
    if (oldHash == newHash) {
      await ref.update({'profile': payload, 'updatedAt': FieldValue.serverTimestamp()});
      return;
    }
    final claim = _db.collection('usernames').doc(newHash);
    await _db.runTransaction((tx) async {
      if ((await tx.get(claim)).exists) throw StateError('That username is already in use.');
      tx.set(claim, {'uid': uid});
      tx.update(ref, {'usernameHash': newHash, 'profile': payload, 'updatedAt': FieldValue.serverTimestamp()});
      if (oldHash != null) tx.delete(_db.collection('usernames').doc(oldHash));
    });
  }

  Future<User?> profile(String profileId) async {
    final doc = await _users.doc(profileId).get();
    if (!doc.exists || doc.data()?['profile'] is! String) return null;
    final info = jsonDecode(await decrypt(doc.data()!['profile'] as String)) as Map<String, dynamic>;
    return User(info['email'] ?? '', info['username'] ?? '', '', id: profileId,
      about: info['about'] ?? '', avatar: info['avatar'] ?? '');
  }

  /// Exact lookup uses blind indexes; plaintext email/username never reaches DB.
  Future<List<User>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final hash = await _hash(query);
    final snapshots = await Future.wait([
      _users.where('usernameHash', isEqualTo: hash).get(),
      _users.where('emailHash', isEqualTo: hash).get(),
    ]);
    final ids = <String>{for (final s in snapshots) ...s.docs.map((doc) => doc.id)}..remove(uid);
    return (await Future.wait(ids.map(profile))).whereType<User>().toList();
  }

  Future<bool> usernameTaken(String username) async =>
      (await _db.collection('usernames').doc(await _hash(username)).get()).exists;

  Future<void> ensureChat(String chatId, List<String> memberIds) => _chats.doc(chatId).set({
    'memberIds': memberIds, 'lastMessageAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Stream<List<Chat>> chats() => _chats.where('memberIds', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true).snapshots().map((snapshot) => snapshot.docs.map((doc) {
        final data = doc.data();
        return Chat(doc.id, List<String>.from(data['memberIds'] ?? const <String>[]), []);
      }).toList());

  Future<void> sendMessage({required String chatId, required String body, required String type, String media = ''}) async {
    if (uid.isEmpty) throw StateError('Sign in before sending.');
    final stamp = FieldValue.serverTimestamp();
    await _chats.doc(chatId).collection('messages').add({
      'senderId': uid, 'kind': type,
      'payload': await encrypt(jsonEncode({'body': body, 'media': media})),
      'createdAt': stamp, 'deliveredTo': [uid], 'readBy': [uid], 'edited': false,
    });
    await _chats.doc(chatId).update({'lastMessageAt': stamp});
  }

  Stream<List<Message>> messages(String chatId) => _chats.doc(chatId).collection('messages')
      .orderBy('createdAt').snapshots().asyncMap((snapshot) async {
    final messages = <Message>[];
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        final content = jsonDecode(await decrypt(data['payload'] as String)) as Map<String, dynamic>;
        final deliveredBy = List<String>.from(data['deliveredTo'] ?? []);
        final readBy = List<String>.from(data['readBy'] ?? []);
        final isMine = data['senderId'] == uid;
        final delivered = isMine ? deliveredBy.any((id) => id != uid) : deliveredBy.contains(uid);
        final read = isMine ? readBy.any((id) => id != uid) : readBy.contains(uid);
        final time = data['createdAt'] as Timestamp?;
        messages.add(Message(doc.id, data['senderId'] as String, content['body'] ?? '',
          time == null ? 'Sending…' : '${time.toDate().hour.toString().padLeft(2, '0')}:${time.toDate().minute.toString().padLeft(2, '0')}',
          type: data['kind'] ?? 'text', status: read ? 'read' : delivered ? 'delivered' : 'sent',
          edited: data['edited'] == true, media: content['media'] ?? ''));
      } catch (_) { messages.add(Message(doc.id, '', 'Unable to decrypt message.', '', status: 'failed')); }
    }
    return messages;
  });

  Future<void> markVisible(String chatId, Iterable<Message> messages) async {
    final batch = _db.batch();
    for (final message in messages.where((item) => item.sender != uid)) {
      batch.update(_chats.doc(chatId).collection('messages').doc(message.id), {
        'deliveredTo': FieldValue.arrayUnion([uid]), 'readBy': FieldValue.arrayUnion([uid]),
      });
    }
    await batch.commit();
  }
  Future<void> editMessage(String chatId, Message message, String body) async =>
      _chats.doc(chatId).collection('messages').doc(message.id).update({
        'payload': await encrypt(jsonEncode({'body': body, 'media': message.media})),
        'edited': true,
      });
  Future<void> deleteMessage(String chatId, String id) => _chats.doc(chatId).collection('messages').doc(id).delete();
}
