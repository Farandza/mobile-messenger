import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import 'chats_screen.dart';
import 'people_screen.dart';
import 'profile_screen.dart';

class Home extends StatefulWidget {
  const Home({super.key, required this.app});
  final AppState app;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int index = 0;
  @override
  Widget build(BuildContext c) {
    final pages = [
      Chats(app: widget.app, refresh: () => setState(() {})),
      People(app: widget.app, refresh: () => setState(() {})),
      Profile(app: widget.app, refresh: () => setState(() {})),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(['Chats', 'People', 'Profile'][index]),
        actions: [
          if (index == 2)
            IconButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                widget.app.data.active = null;
                await widget.app.save();
                setState(() {});
              },
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (x) => setState(() => index = x),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'People',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
