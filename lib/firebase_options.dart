// GENERATED FILE — Replace with your actual Firebase configuration.
// Run: flutterfire configure
// See SETUP.md for step-by-step instructions.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web platform is not configured.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
            'Unsupported platform: $defaultTargetPlatform');
    }
  }

  // ── Replace these values with your Firebase project values ──────────────

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBW0R-BsJhcrT31GbjdoY-6MHlBcriJ90Q',
    appId: '1:556675629389:android:7d3d47a6f66ddbdd64b704',
    messagingSenderId: '556675629389',
    projectId: 'scholaro-88942',
    storageBucket: 'scholaro-88942.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyALELHmnnGVbAzyAXF-fFFLaKCBRGkZfYo',
    appId: '1:556675629389:web:a741c83af77a160764b704',
    messagingSenderId: '556675629389',
    projectId: 'scholaro-88942',
    authDomain: 'scholaro-88942.firebaseapp.com',
    storageBucket: 'scholaro-88942.firebasestorage.app',
    measurementId: 'G-R1JTYY24HH',
  );

}