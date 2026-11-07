# Nimble Mobile Messenger

## Project overview

Nimble is a Flutter messenger with Firebase Authentication, encrypted persistence, account validation, editable profiles, private contact lookup, direct chats, media attachments, audio recording/playback, archive, mute and message management. The app stores its local data as one AES-256-GCM encrypted snapshot and encrypts profile and message content before it is written to Firestore.

## Setup and installation

1. Install Flutter 3.29+ and run `flutter doctor`.
2. In Firebase Console, open **Authentication → Sign-in method** and enable **Email/Password**.
3. Run `flutter pub get`.
4. Connect an Android device or start an emulator, then run `flutter run`.

Build an Android release APK with:

```bash
flutter build apk --release
```

The generated installable file is `build/app/outputs/flutter-apk/app-release.apk`.

## Usage guide

1. Create an account using a unique email, username and a strong password.
2. Open the Firebase verification link received at the registered email address, then return to the app and use **Refresh verification** in Profile.
3. Create a second account on the same installation to test search and invitations.
4. Search in **People** using an exact username or email, then choose **Chat** to open a protected direct chat.
5. Open a chat to send text, use **+** for an image/video (550 KB maximum because it is encrypted inside a Firestore document), or use the microphone to record/stop/send a voice message. Tap a voice message to play it.
6. Long-press one of your messages to edit or delete it. Use the chat toolbar to archive/unarchive or mute/unmute.
7. In **Profile**, tap the avatar to select a JPEG/PNG picture (5 MB maximum) and edit your username/About Me section.

## Reviewer installation options

- **Android device:** transfer and install `app-release.apk` (enable installation from this source if Android asks).
- **NoxPlayer / BlueStacks:** drag `app-release.apk` into the emulator, then open Nimble.
- **Browser emulator:** upload the APK to Appetize or another Android browser emulator and open its generated session.

## Reviewer-mode limitations

Firebase Authentication provides public verification and password-reset email links. Firestore provides synchronized encrypted profile/message records, exact blind-index contact lookup, delivery/read receipts, and message edit/delete. FCM/APNs push notifications, synchronized real-time typing, large-media storage/compression, and a managed per-chat secure key service remain future production integrations.
