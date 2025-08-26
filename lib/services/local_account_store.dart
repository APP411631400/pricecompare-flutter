import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地端帳號資料儲存（不連資料庫版）
/// 每個帳號會以 email 當命名空間，資料互不干擾。
///
/// Key 命名規則：
///   u:<email>:profile
///   u:<email>:favorites
///   u:<email>:history
///   u:<email>:cards
///   u:<email>:reports
class LocalAccountStore {
  /// 取出目前登入者 email（假設 UserService 有寫入 'email'）
  static Future<String> _ns() async {
    final sp = await SharedPreferences.getInstance();
    final email = sp.getString('email') ?? 'guest@mail.com';
    return 'u:$email:';
  }

  // ===== 共用 =====
  static Future<List<Map<String, dynamic>>> _readList(String key) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> _writeList(String key, List<Map<String, dynamic>> data) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(key, jsonEncode(data));
  }

  static Future<int> _nextId(String counterKey) async {
    final sp = await SharedPreferences.getInstance();
    final curr = sp.getInt(counterKey) ?? 0;
    final next = curr + 1;
    await sp.setInt(counterKey, next);
    return next;
  }

  // ===== 個人資料 =====
  static Future<Map<String, dynamic>?> getProfile() async {
    final prefix = await _ns();
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('${prefix}profile');
    return raw != null ? Map<String, dynamic>.from(jsonDecode(raw)) : null;
  }

  static Future<void> updateProfile({String? displayName, String? phone, String? avatarUrl,}) async {
    final prefix = await _ns();
    final sp = await SharedPreferences.getInstance();
    final curr = Map<String, dynamic>.from(jsonDecode(sp.getString('${prefix}profile') ?? '{}'));

    if (displayName != null) curr['displayName'] = displayName;
    if (phone != null) curr['phone'] = phone;

    await sp.setString('${prefix}profile', jsonEncode(curr));
  }

  // ===== 收藏 =====
  /*static Future<List<Map<String, dynamic>>> getFavorites() async {
    final prefix = await _ns();
    return _readList('${prefix}favorites');
  }

  static Future<void> addFavorite(String productId, String productName) async {
    final prefix = await _ns();
    final key = '${prefix}favorites';
    final counter = '${prefix}favorites_id';
    final list = await _readList(key);

    if (list.any((e) => e['productId'] == productId)) return;

    final id = await _nextId(counter);
    list.insert(0, {
      'id': id,
      'productId': productId,
      'productName': productName,
      'addedAt': DateTime.now().toIso8601String(),
    });
    await _writeList(key, list);
  }

  static Future<void> removeFavorite(int id) async {
    final prefix = await _ns();
    final key = '${prefix}favorites';
    final list = await _readList(key);
    list.removeWhere((e) => e['id'] == id);
    await _writeList(key, list);
  }
*/
  // ===== 瀏覽歷史 =====
  /*static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefix = await _ns();
    return _readList('${prefix}history');
  }

  static Future<void> addHistory(String action, {String? productId}) async {
    final prefix = await _ns();
    final key = '${prefix}history';
    final counter = '${prefix}history_id';
    final list = await _readList(key);

    final id = await _nextId(counter);
    list.insert(0, {
      'id': id,
      'action': action,
      'productId': productId,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _writeList(key, list);
  }

  static Future<void> clearHistory() async {
    final prefix = await _ns();
    await _writeList('${prefix}history', []);
  }
*/
  // ===== 已儲存信用卡 =====
  static Future<List<Map<String, dynamic>>> getSavedCards() async {
    final prefix = await _ns();
    return _readList('${prefix}cards');
  }

  static Future<void> addSavedCard(int cardId, {String? nickname}) async {
    final prefix = await _ns();
    final key = '${prefix}cards';
    final counter = '${prefix}cards_id';
    final list = await _readList(key);

    if (list.any((e) => e['cardId'] == cardId)) return;

    final id = await _nextId(counter);
    list.insert(0, {
      'id': id,
      'cardId': cardId,
      'nickname': nickname,
      'addedAt': DateTime.now().toIso8601String(),
    });
    await _writeList(key, list);
  }

  static Future<void> removeSavedCard(int id) async {
    final prefix = await _ns();
    final key = '${prefix}cards';
    final list = await _readList(key);
    list.removeWhere((e) => e['id'] == id);
    await _writeList(key, list);
  }

  // ===== 價格回報紀錄 =====
  static Future<List<Map<String, dynamic>>> getPriceReports() async {
    final prefix = await _ns();
    return _readList('${prefix}reports');
  }

  static Future<void> addPriceReport({
    required String productName,
    required String storeName,
    required double price,
    double? lat,
    double? lng,
    String? photoUrl,
  }) async {
    final prefix = await _ns();
    final key = '${prefix}reports';
    final counter = '${prefix}reports_id';
    final list = await _readList(key);

    final id = await _nextId(counter);
    list.insert(0, {
      'id': id,
      'productName': productName,
      'storeName': storeName,
      'price': price,
      'latitude': lat,
      'longitude': lng,
      'photoUrl': photoUrl,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _writeList(key, list);
  }

  static Future<void> deletePriceReport(int id) async {
    final prefix = await _ns();
    final key = '${prefix}reports';
    final list = await _readList(key);
    list.removeWhere((e) => e['id'] == id);
    await _writeList(key, list);
  }
}
