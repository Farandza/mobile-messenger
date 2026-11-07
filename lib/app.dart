import 'package:flutter/material.dart';

import 'models/entities.dart';
import 'services/vault.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

const brand = Color(0xff246bfd);

class Nimble extends StatefulWidget {
  const Nimble({super.key});
  @override
  State<Nimble> createState() => AppState();
}

class AppState extends State<Nimble> {
  final vault = Vault();
  Data data = Data(users: [], chats: [], invites: []);
  bool ready = false;
  String? warning;
  @override
  void initState() {
    super.initState();
    vault
        .load()
        .then((d) {
          if (mounted) {
            setState(() {
              data = d ?? data;
              ready = true;
            });
          }
        })
        .catchError((_) {
          setState(() {
            ready = true;
            warning =
                'Could not restore local data. A clean session was loaded.';
          });
        });
  }

  Future<void> save() async {
    try {
      await vault.save(data);
    } catch (_) {
      if (mounted) {
        setState(
          () => warning = 'Could not save your changes. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext c) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: brand),
      scaffoldBackgroundColor: const Color(0xfff7f9fc),
    ),
    home: !ready
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : data.active == null
        ? Auth(app: this)
        : Home(app: this),
    builder: (c, w) => Column(
      children: [
        if (warning != null)
          MaterialBanner(
            content: Text(warning!),
            actions: [
              TextButton(
                onPressed: () => setState(() => warning = null),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        Expanded(child: w!),
      ],
    ),
  );
}
