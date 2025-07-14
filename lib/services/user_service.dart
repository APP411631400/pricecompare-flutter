// ✅ services/user_service.dart - 使用者登入狀態管理（後端登入 + 模擬註冊共存）
import 'dart:convert';                              // 用來處理 JSON 格式
import 'package:http/http.dart' as http;            // 用來呼叫後端 API
import 'package:shared_preferences/shared_preferences.dart'; // 用於本地儲存登入資訊

class UserService {
  // ✅ 共用 Key 名稱（避免寫死錯誤）
  static const _tokenKey = 'auth_token';              // 模擬登入 token，可改為後端 JWT
  static const _userEmailKey = 'user_email';          // 儲存登入成功的 Email
  static const _userNameKey = 'user_name';            // 儲存登入者名稱
  static const _userIdKey = 'user_id';                // 儲存登入者 UserID

  // ✅ 保留原本模擬註冊帳號的 Key
  static const _mockEmailKey = 'mock_email';          // 模擬註冊帳號 Email
  static const _mockPasswordKey = 'mock_password';    // 模擬註冊帳號 密碼

  // ✅ 後端 API 網址（本機模擬器請用 10.0.2.2）
  static const String apiBaseUrl = 'https://acdb-api.onrender.com';

  /// ✅ 儲存模擬註冊的帳號資料（供註冊頁使用）
  static Future<void> saveMockAccount(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mockEmailKey, email);
    await prefs.setString(_mockPasswordKey, password);
  }

  /// ✅ 驗證帳號密碼：改為串接後端 /login API 驗證
  static Future<bool> validateCredentials(String email, String password) async {
    try {
      final url = Uri.parse('$apiBaseUrl/login'); // 後端登入 API 路徑
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'}, // 傳送 JSON 格式資料
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body); // 解 JSON 結果

      // ✅ 後端回傳成功就儲存登入資訊
      if (response.statusCode == 200 && data['status'] == 'success') {
        await login(
          userName: data['userName'],
          email: email,
          userId: data['userId'],
        );
        return true;
      } else {
        return false; // ❌ 帳密錯誤或後端回傳 fail
      }
    } catch (e) {
      print('登入失敗: $e');
      return false; // ❌ 無法連接或其他錯誤
    }
  }

  /// ✅ 後端登入專用：需儲存完整 userId、userName、email
  static Future<void> login({
    required String userName,
    required String email,
    required int userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, 'mock_token');     // 🔒 模擬 token，可改 JWT
    await prefs.setString(_userEmailKey, email);        // 儲存登入 email
    await prefs.setString(_userNameKey, userName);      // 儲存使用者名稱
    await prefs.setInt(_userIdKey, userId);             // 儲存 UserID
  }

  /// ✅ 模擬登入（給註冊頁使用）：只儲存 email 和 mock token
  /// 📌 不需 userName 或 userId，避免註冊頁爆錯
  static Future<void> mockLogin(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, 'mock_token');     // 模擬登入狀態
    await prefs.setString(_userEmailKey, email);        // 儲存 Email
  }

  /// ✅ 登出功能：清除所有登入資料
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);        // 清除 token
    await prefs.remove(_userEmailKey);    // 清除 email
    await prefs.remove(_userNameKey);     // 清除名稱
    await prefs.remove(_userIdKey);       // 清除 UserID
  }

  /// ✅ 檢查是否已登入（以是否有 token 為準）
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_tokenKey);
  }

  /// ✅ 取得目前登入使用者的 Email（用於顯示、上傳等）
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  /// ✅ 取得目前登入使用者的名稱（可用於首頁歡迎詞）
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  /// ✅ 取得目前登入使用者的 ID（後端比對上傳者、收藏等用途）
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  /// ✅ 取得目前使用者的 ID，未登入則回傳 'guest'（方便比對紀錄用）
  static Future<String> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_userIdKey);
    return userId?.toString() ?? 'guest'; // 若沒登入，回傳 guest
  }
}







