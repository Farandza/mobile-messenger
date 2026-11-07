import 'package:flutter/material.dart';

import '../app.dart';
import '../models/entities.dart';
import '../services/firestore_repository.dart';
import '../widgets/avatar.dart';
import 'conversation_screen.dart';

class Chats extends StatefulWidget {
  const Chats({super.key, required this.app, required this.refresh});
  final AppState app;
  final VoidCallback refresh;
  @override
  State<Chats> createState() => _ChatsState();
}

class _ChatsState extends State<Chats> {
  bool archived = false;
  final repo = FirestoreRepository();
  @override
  Widget build(BuildContext c) {
    final me = widget.app.data.me;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => archived = !archived),
              icon: Icon(
                archived ? Icons.unarchive_outlined : Icons.archive_outlined,
              ),
              label: Text(archived ? 'Show active' : 'Archived'),
            ),
          ),
        ),
        Expanded(child: StreamBuilder<List<Chat>>(
          stream: repo.chats(),
          builder: (_, snapshot) {
            final xs = (snapshot.data ?? const <Chat>[]).where((chat) => chat.archived == archived).toList();
            if (snapshot.hasError) return const Center(child: Text('Could not load chats. Check your connection.'));
            return xs.isEmpty
              ? Center(
                  child: Text(
                    archived
                        ? 'No archived chats'
                        : 'No chats yet. Accept an invitation from People.',
                  ),
                )
              : ListView.builder(
                  itemCount: xs.length,
                  itemBuilder: (_, i) {
                    final chat = xs[i],
                        peer = widget.app.data.users.firstWhere(
                          (u) => u.id == chat.members.firstWhere((e) => e != me.id),
                          orElse: () => User('', 'Contact', ''),
                        ),
                        last = chat.messages.isEmpty
                            ? null
                            : chat.messages.last;
                    return Card(
                      child: ListTile(
                        onTap: () => Navigator.push(
                          c,
                          MaterialPageRoute(
                            builder: (_) => Conversation(
                              app: widget.app,
                              chat: chat,
                              onDone: widget.refresh,
                            ),
                          ),
                        ),
                        leading: Avatar(peer),
                        title: Text(peer.name),
                        subtitle: Text(
                          last?.body ?? 'Encrypted conversation',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (chat.muted)
                              const Icon(Icons.notifications_off, size: 16),
                            Text(
                              last?.when ?? '',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
          },
        )),
      ],
    );
  }
}
