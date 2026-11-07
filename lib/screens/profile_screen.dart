import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/material.dart';

import '../app.dart';
import '../models/entities.dart';
import '../services/firestore_repository.dart';
import '../widgets/avatar.dart';

class Profile extends StatefulWidget {
  const Profile({super.key, required this.app, required this.refresh});
  final AppState app;
  final VoidCallback refresh;
  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final profiles = FirestoreRepository();
  Future<void> refreshVerification(User user) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      await firebaseUser?.reload();
      final verified =
          FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      user.verified = verified;
      await widget.app.save();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              verified
                  ? 'Email verified successfully.'
                  : 'Your email is not verified yet. Open the Firebase email link first.',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not refresh verification.'),
          ),
        );
      }
    }
  }

  Future<void> choose(User u) async {
    final f = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (f == null) return;
    final p = f.files.single;
    if (p.size > 500 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture must be 500 KB or less so it can be encrypted and synced.'),
          ),
        );
      }
      return;
    }
    final bytes = p.bytes ?? (p.path == null ? null : await File(p.path!).readAsBytes());
    if (bytes == null) return;
    u.avatar = 'base64:${base64Encode(bytes)}';
    await widget.app.save();
    try {
      await profiles.upsertProfile(
        username: u.name,
        about: u.about,
        avatar: u.avatar,
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Picture was saved locally but could not sync. Retry when online.')),
        );
      }
    }
  }

  void edit(User u) {
    final n = TextEditingController(text: u.name),
        a = TextEditingController(text: u.about);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(c).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: n,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: a,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'About me'),
            ),
            FilledButton(
              onPressed: () async {
                if (widget.app.data.users.any(
                  (x) =>
                      x != u &&
                      x.name.toLowerCase() == n.text.trim().toLowerCase(),
                )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Username already in use.')),
                  );
                  return;
                }
                u.name = n.text.trim();
                u.about = a.text.trim();
                try {
                  await profiles.upsertProfile(
                    username: n.text.trim(),
                    about: a.text.trim(),
                    avatar: u.avatar,
                  );
                  u.name = n.text.trim();
                  u.about = a.text.trim();
                  await widget.app.save();
                  if (c.mounted) Navigator.pop(c);
                  if (mounted) setState(() {});
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
                    );
                  }
                }
              },
              child: const Text('Save profile'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final u = widget.app.data.me;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: GestureDetector(
            onTap: () => choose(u),
            child: Avatar(u, size: 96),
          ),
        ),
        if (!u.verified)
          TextButton.icon(
            onPressed: () => refreshVerification(u),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh verification'),
          ),
        TextButton.icon(
          onPressed: () => choose(u),
          icon: const Icon(Icons.photo),
          label: const Text('Change picture (JPEG/PNG, encrypted sync, max 500 KB)'),
        ),
        Text(
          u.name,
          textAlign: TextAlign.center,
          style: Theme.of(c).textTheme.headlineSmall,
        ),
        Text(u.email, textAlign: TextAlign.center),
        Center(
          child: Chip(
            label: Text(u.verified ? 'Email verified' : 'Verification pending'),
            avatar: Icon(
              u.verified ? Icons.verified : Icons.pending,
              color: brand,
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit profile'),
            subtitle: Text(
              u.about.isEmpty ? 'Add an About me section' : u.about,
            ),
            onTap: () => edit(u),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.lock),
            title: Text('Encryption'),
            subtitle: Text('Local data uses AES-256-GCM encryption'),
          ),
        ),
      ],
    );
  }
}
