import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../app.dart';
import '../models/entities.dart';
import '../services/firestore_repository.dart';
import '../widgets/avatar.dart';

class Conversation extends StatefulWidget {
  const Conversation({super.key, required this.app, required this.chat, required this.onDone});
  final AppState app;
  final Chat chat;
  final VoidCallback onDone;
  @override State<Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<Conversation> {
  final input = TextEditingController(), recorder = AudioRecorder(), player = AudioPlayer();
  final repo = FirestoreRepository();
  bool recording = false, sending = false;
  String get me => repo.uid;

  @override
  void initState() {
    super.initState();
    repo.ensureChat(widget.chat.id, widget.chat.members);
  }

  Future<void> send({String? body, String type = 'text', String media = ''}) async {
    final text = (body ?? input.text).trim();
    if (text.isEmpty && media.isEmpty) return;
    setState(() => sending = true);
    try {
      await repo.sendMessage(chatId: widget.chat.id, body: text, type: type, media: media);
      input.clear();
      widget.onDone();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Message failed to send. Check your connection and try again.'),
        ));
      }
    } finally { if (mounted) setState(() => sending = false); }
  }

  Future<void> media() async {
    final pick = await FilePicker.platform.pickFiles(type: FileType.media, withData: true);
    if (pick == null) return;
    final file = pick.files.single;
    final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
    // Firestore document limit is 1 MiB. Leave room for AES-GCM/base64 overhead.
    if (bytes == null || bytes.length > 550 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Choose an image or video up to 550 KB. It is encrypted before upload.'),
        ));
      }
      return;
    }
    final ext = (file.extension ?? '').toLowerCase();
    await send(body: file.name, media: base64Encode(bytes),
      type: ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext) ? 'video' : 'image');
  }

  Future<void> voice() async {
    if (recording) {
      final path = await recorder.stop();
      setState(() => recording = false);
      if (path != null) await send(body: path, type: 'audio');
      return;
    }
    if (await recorder.hasPermission()) {
      await recorder.start(const RecordConfig(), path: 'voice-${DateTime.now().millisecondsSinceEpoch}.m4a');
      setState(() => recording = true);
    }
  }

  void menu(Message message) => showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.edit), title: const Text('Edit message'), onTap: () {
        Navigator.pop(sheet); input.text = message.body;
        showDialog<void>(context: context, builder: (dialog) => AlertDialog(
          title: const Text('Edit message'), content: TextField(controller: input), actions: [
            TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
            FilledButton(onPressed: () async { await repo.editMessage(widget.chat.id, message, input.text.trim()); input.clear(); if (dialog.mounted) Navigator.pop(dialog); }, child: const Text('Save')),
          ],
        ));
      }),
      ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Delete message'), onTap: () async {
        Navigator.pop(sheet); await repo.deleteMessage(widget.chat.id, message.id);
      }),
    ])),
  );

  @override void dispose() { input.dispose(); recorder.dispose(); player.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final peer = widget.app.data.users.firstWhere(
      (user) => user.id == widget.chat.members.firstWhere((id) => id != me),
      orElse: () => User('', 'Contact', ''),
    );
    return Scaffold(
      appBar: AppBar(title: Row(children: [Avatar(peer, size: 34), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(peer.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Text('encrypted conversation', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
      ])])),
      body: Column(children: [
        Expanded(child: StreamBuilder<List<Message>>(
          stream: repo.messages(widget.chat.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('Could not load messages. Pull back and retry.'));
            final messages = snapshot.data ?? const <Message>[];
            if (messages.isNotEmpty) repo.markVisible(widget.chat.id, messages);
            return ListView.builder(padding: const EdgeInsets.all(14), itemCount: messages.length, itemBuilder: (_, index) {
              final message = messages[index], mine = message.sender == me;
              final status = message.status == 'failed' ? '! Failed' : message.status == 'read' ? '✓✓ Read' : message.status == 'delivered' ? '✓✓ Delivered' : '✓ Sent';
              Widget content = Text(message.type == 'audio' ? '▶ Voice message' : message.type == 'video' ? '🎬 Video: ${message.body}' : message.body,
                style: TextStyle(color: mine ? Colors.white : Colors.black));
              if (message.type == 'image' && message.media.isNotEmpty) {
                content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Image.memory(base64Decode(message.media), height: 180, fit: BoxFit.cover), const SizedBox(height: 4),
                  Text(message.body, style: TextStyle(color: mine ? Colors.white : Colors.black)),
                ]);
              }
              return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: GestureDetector(
                onLongPress: mine ? () => menu(message) : null,
                onTap: message.type == 'audio' ? () => player.play(DeviceFileSource(message.body)) : null,
                child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(11), constraints: const BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(color: mine ? brand : Colors.white, borderRadius: BorderRadius.circular(15)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [content, Text('${message.when}${message.edited ? ' · edited' : ''}${mine ? ' · $status' : ''}', style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : Colors.blueGrey))]),
                ),
              ));
            });
          },
        )),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          IconButton(onPressed: media, icon: const Icon(Icons.add_circle_outline)),
          IconButton(onPressed: voice, icon: Icon(recording ? Icons.stop_circle : Icons.mic_none, color: recording ? Colors.red : null)),
          Expanded(child: TextField(controller: input, onSubmitted: (_) => send(), decoration: const InputDecoration(hintText: 'Message'))),
          IconButton(onPressed: sending ? null : send, icon: const Icon(Icons.send, color: brand)),
        ]))),
      ]),
    );
  }
}
