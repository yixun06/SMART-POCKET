# Smart Pocket

Smart Pocket is a Flutter-based personal finance app for tracking accounts,
transactions, budgets, recurring plans, shortcuts, analytics, and local export
workflows. It uses Firebase Authentication and Cloud Firestore for user data.

## Features

- Email and Google sign-in
- Account, transaction, category, and budget management
- Recurring transaction planning
- Shortcut-based quick transaction entry
- Analytics and PDF export support
- Light and dark themes

## Tech Stack

- Flutter and Dart
- Provider for state management
- Firebase Core, Firebase Auth, and Cloud Firestore
- GoRouter for navigation

## Local Setup

1. Install Flutter and run `flutter pub get`.
2. Create or connect a Firebase project.
3. Copy `android/app/google-services.json.example` to
   `android/app/google-services.json` and fill it with your Firebase Android
   app configuration.
4. Confirm `lib/firebase_options.dart` matches your Firebase project. Regenerate
   it with FlutterFire CLI if you use a different Firebase project.
5. Run `flutter run`.

## APK

The latest Android release APK is included at:

```text
releases/smart-pocket-release.apk
```

## Checks

```powershell
dart analyze lib
```
