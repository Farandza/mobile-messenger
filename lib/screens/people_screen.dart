import 'package:flutter/material.dart';

import '../app.dart';
import '../models/entities.dart';
import '../services/firestore_repository.dart';
import '../widgets/avatar.dart';

class People extends StatefulWidget {
  const People({super.key, required this.app, required this.refresh});
  final AppState app;
  final VoidCallback refresh;
  @override State<People> createState() => _PeopleState();
}

class _PeopleState extends State<People> {
  final query = TextEditingController(), repo = FirestoreRepository();
  List<User> results = [];
  bool searching = false;

  Future<void> search() async {
    setState(() => searching = true);
    try { results = await repo.search(query.text); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search failed. Check your connection and try again.'))); }
    finally { if (mounted) setState(() => searching = false); }
  }

  Future<void> start(User user) async {
    final members = [repo.uid, user.id]..sort();
    final id = members.join('_');
    try {
      await repo.ensureChat(id, members);
      if (!widget.app.data.users.any((item) => item.id == user.id)) widget.app.data.users.add(user);
      if (!widget.app.data.chats.any((chat) => chat.id == id)) widget.app.data.chats.add(Chat(id, members, []));
      await widget.app.save();
      widget.refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Secure chat ready with ${user.name}.')));
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create chat. Please retry.'))); }
  }

  @override void dispose() { query.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    TextField(controller: query, onSubmitted: (_) => search(), decoration: InputDecoration(
      hintText: 'Enter exact username or email', prefixIcon: const Icon(Icons.search),
      suffixIcon: searching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : IconButton(onPressed: search, icon: const Icon(Icons.search)),
    )),
    const Padding(padding: EdgeInsets.only(top: 10, bottom: 6), child: Text('Search is exact to keep usernames and email addresses private.')),
    ...results.map((user) => Card(child: ListTile(
      leading: Avatar(user), title: Text(user.name), subtitle: Text(user.email),
      trailing: FilledButton(onPressed: () => start(user), child: const Text('Chat')),
    ))),
    if (!searching && query.text.isNotEmpty && results.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No matching account found.'))),
  ]);
}
