import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  /// 使用 Google 登入並讓 Firebase 取得使用者
  static Future<UserCredential> signInWithGoogle() async {
    // 叫出 Google 帳號選擇器（可能會被使用者取消，回傳 null）
    final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
    if (gUser == null) {
      throw Exception('使用者取消登入');
    }

    // 取得 Google OAuth token
    final GoogleSignInAuthentication gAuth = await gUser.authentication;

    // 轉成 Firebase 認證憑證
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    // 交給 Firebase 產生/取得使用者
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  static Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }

  static User? get currentUser => FirebaseAuth.instance.currentUser;
}
