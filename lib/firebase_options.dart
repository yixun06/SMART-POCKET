
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD6NUVS_ShG7ICNfWssWi1-wnMKYTMn4xA',
    appId: '1:992557937003:web:499e8d6905f1b8c0095c2e',
    messagingSenderId: '992557937003',
    projectId: 'smart-pocket-a58e0',
    authDomain: 'smart-pocket-a58e0.firebaseapp.com',
    storageBucket: 'smart-pocket-a58e0.firebasestorage.app',
    measurementId: 'G-5JJ8CN8VCB',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDFXEeASt9DkgwTjrEsg-Vyqp2KheqR9Tw',
    appId: '1:992557937003:android:51abecbd2a98a2c4095c2e',
    messagingSenderId: '992557937003',
    projectId: 'smart-pocket-a58e0',
    storageBucket: 'smart-pocket-a58e0.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD6NUVS_ShG7ICNfWssWi1-wnMKYTMn4xA',
    appId: '1:992557937003:web:0e448a84b1943de0095c2e',
    messagingSenderId: '992557937003',
    projectId: 'smart-pocket-a58e0',
    authDomain: 'smart-pocket-a58e0.firebaseapp.com',
    storageBucket: 'smart-pocket-a58e0.firebasestorage.app',
    measurementId: 'G-H6X7C8TSNJ',
  );
}
