import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/material.dart';

import '../app.dart';
import '../models/entities.dart';
import '../services/firestore_repository.dart';

class Auth extends StatefulWidget {
  const Auth({super.key, required this.app});
  final AppState app;
  @override
  State<Auth> createState() => _AuthState();
}

class _AuthState extends State<Auth> {
  final email = TextEditingController();
  final name = TextEditingController();
  final password = TextEditingController();
  final auth = FirebaseAuth.instance;
  final profiles = FirestoreRepository();
  bool signup = false;
  bool busy = false;
  String error = '';

  bool get strongPassword => RegExp(
    r'(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}',
  ).hasMatch(password.text);

  Future<void> submit() async {
    final accountEmail = email.text.trim().toLowerCase();
    if (!accountEmail.contains('@')) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }
    if (signup && name.text.trim().length < 3) {
      setState(() => error = 'Username needs at least 3 characters.');
      return;
    }
    if (signup && !strongPassword) {
      setState(
        () => error =
            'Password needs 8+ chars, uppercase, lowercase, digit, and symbol.',
      );
      return;
    }
    if (signup) {
      try {
        if (await profiles.usernameTaken(name.text.trim())) {
          setState(() => error = 'That username is already in use.');
          return;
        }
      } catch (_) {
        setState(() => error = 'Could not check that username. Check your connection and try again.');
        return;
      }
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      if (signup) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: accountEmail,
          password: password.text,
        );
        await credential.user!.updateDisplayName(name.text.trim());
        try {
          await profiles.createProfile(
            username: name.text.trim(),
            about: '',
            avatar: '',
          );
        } on StateError {
          // A simultaneous registration took the username after the pre-check.
          // Remove the just-created Auth account so the user can choose another.
          await credential.user!.delete();
          rethrow;
        }
        await credential.user!.sendEmailVerification();
        widget.app.data.users.add(User(accountEmail, name.text.trim(), '', id: credential.user!.uid));
      } else {
        final credential = await auth.signInWithEmailAndPassword(
          email: accountEmail,
          password: password.text,
        );
        if (!widget.app.data.users.any((user) => user.email == accountEmail)) {
          final remote = await profiles.profile(credential.user!.uid);
          widget.app.data.users.add(remote ?? User(accountEmail,
              credential.user?.displayName ?? accountEmail.split('@').first, '', id: credential.user!.uid));
        }
        final localUser = widget.app.data.users.firstWhere(
          (user) => user.email == accountEmail,
        );
        localUser.id = credential.user!.uid;
        await profiles.upsertProfile(
          username: localUser.name,
          about: localUser.about,
          avatar: localUser.avatar,
        );
      }
      await widget.app.completeAuthentication(
        accountEmail,
        notice: signup
            ? 'Verification link sent. Open it, then refresh verification from Profile.'
            : null,
      );
    } on FirebaseAuthException catch (exception) {
      if (mounted) setState(() => error = friendlyError(exception));
    } on StateError catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } on FirebaseException catch (exception) {
      if (mounted) {
        setState(
          () => error = exception.message ?? 'Account setup failed. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not complete sign-in. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void resetPassword() {
    final resetEmail = TextEditingController(text: email.text.trim());
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: resetEmail,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await auth.sendPasswordResetEmail(
                  email: resetEmail.text.trim(),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Firebase password-reset email sent.'),
                    ),
                  );
                }
              } on FirebaseAuthException catch (exception) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(friendlyError(exception))),
                  );
                }
              }
            },
            child: const Text('Send link'),
          ),
        ],
      ),
    );
  }

  String friendlyError(FirebaseAuthException exception) =>
      switch (exception.code) {
        'email-already-in-use' => 'That email is already in use.',
        'weak-password' => 'Choose a stronger password.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'Incorrect email or password.',
        'network-request-failed' =>
          'Network error. Check your connection and try again.',
        _ => exception.message ?? 'Authentication failed. Please try again.',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.forum_rounded, size: 62, color: brand),
              Text(
                'nimble',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                signup ? 'Create your private space' : 'Welcome back',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              if (signup) ...[
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: password,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (signup)
                Text(
                  strongPassword
                      ? 'Strong password ✓'
                      : '8+ chars, upper/lowercase, number & symbol',
                  style: TextStyle(
                    fontSize: 12,
                    color: strongPassword ? Colors.green : Colors.red,
                  ),
                ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(error, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(
                  busy
                      ? 'Please wait…'
                      : signup
                      ? 'Create account'
                      : 'Sign in',
                ),
              ),
              if (!signup)
                TextButton(
                  onPressed: resetPassword,
                  child: const Text('Forgot password?'),
                ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        signup = !signup;
                        error = '';
                      }),
                child: Text(
                  signup
                      ? 'Already have an account? Sign in'
                      : 'New here? Create account',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
