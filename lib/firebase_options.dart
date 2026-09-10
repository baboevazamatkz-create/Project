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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// The web app registered in the Firebase console. Only apiKey and appId
  /// differ from the Android entry; authDomain is web-only and is what the
  /// auth SDK talks to from the browser.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBs4NJF-MXoO8gw-rHwsxktcEx015Cb_IE',
    appId: '1:561343492723:web:5164cb680762d8cff8f006',
    messagingSenderId: '561343492723',
    projectId: 'money-78d6d',
    authDomain: 'money-78d6d.firebaseapp.com',
    storageBucket: 'money-78d6d.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDiAzkZhMMjJYotgIMdwxuwgR7JytWKyfo',
    appId: '1:561343492723:android:6a61599390b40089f8f006',
    messagingSenderId: '561343492723',
    projectId: 'money-78d6d',
    storageBucket: 'money-78d6d.firebasestorage.app',
  );
}
