import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'LVL LOOL Firebase is currently configured for Android only.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'LVL LOOL Firebase is currently configured for Android only.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCAVxsqrde3eVBQhBBj-zx05UEZbPbCEdQ',
    appId: '1:351650195477:android:ef05ef635311151e6d461c',
    messagingSenderId: '351650195477',
    projectId: 'lvl-lool',
    storageBucket: 'lvl-lool.firebasestorage.app',
  );
}
