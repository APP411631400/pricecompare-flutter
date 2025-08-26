import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCBRFiBu35SBRdcvwOntWhTVsMk01zCNVU',
    appId: '1:1015685231522:android:036c482a27f8ed2d96f8fb',
    messagingSenderId: '1015685231522',
    projectId: 'mydebuglogintest',
    storageBucket: 'mydebuglogintest.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform {
    // 若你只做 Android，可以直接這樣返回：
    return android;
  }
}

