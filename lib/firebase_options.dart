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
          'DefaultFirebaseOptions have not been configured for iOS.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBnV7YGL-0n2JlcYBBh7BWSjAybFNFqLxw',
    appId: '1:966942783222:web:4144557de24cfbd1bcded7',
    messagingSenderId: '966942783222',
    projectId: 'snapmap-2fde2',
    authDomain: 'snapmap-2fde2.firebaseapp.com',
    storageBucket: 'snapmap-2fde2.firebasestorage.app',
    measurementId: 'G-46S1GBHMF3',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCsgT5x7UgPkMPcKHRoKn4nzsiXSxLAaOU',
    appId: '1:966942783222:android:5eacc7030249e810bcded7',
    messagingSenderId: '966942783222',
    projectId: 'snapmap-2fde2',
    storageBucket: 'snapmap-2fde2.firebasestorage.app',
  );
}
