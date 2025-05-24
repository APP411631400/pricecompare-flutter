// ✅ services/favorite_service.dart - 收藏功能管理器（支援來自後端的商品資料）

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/product_service.dart' as ps; // ✅ 匯入後端商品模型，避免與假資料衝突

/// 收藏功能服務類別：管理本地儲存的收藏商品資料
class FavoriteService {
  static const _key = 'favorite_products'; // SharedPreferences 儲存鍵名

  /// ✅ 加入收藏：將商品加入本地收藏清單
  static Future<void> addToFavorites(ps.Product product) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _getRawList(); // 取得目前收藏清單（原始 JSON 陣列）

    // 以商品名稱作為唯一 key，避免重複加入
    if (!list.any((item) => item['name'] == product.name)) {
      list.add({
        'name': product.name,
        'category': product.category,
        'store': product.store,
        'originalPrice': product.originalPrice,
        'salePrice': product.salePrice,
        'imageUrl': product.imageUrl,
        'link': product.link,
      });
      await prefs.setString(_key, jsonEncode(list)); // 儲存更新後清單
    }
  }

  /// ✅ 移除收藏：從收藏清單中移除指定名稱的商品
  static Future<void> removeFromFavorites(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _getRawList();
    list.removeWhere((item) => item['name'] == name); // 移除符合條件的商品
    await prefs.setString(_key, jsonEncode(list));
  }

  /// ✅ 檢查是否已收藏某商品（以名稱判斷）
  static Future<bool> isFavorited(String name) async {
    final list = await _getRawList();
    return list.any((item) => item['name'] == name);
  }

  /// ✅ 取得所有收藏的商品資料（轉換為 ps.Product）
  static Future<List<ps.Product>> getFavorites() async {
    final list = await _getRawList();
    return list.map<ps.Product>((item) {
      return ps.Product(
        name: item['name'],
        category: item['category'],
        store: item['store'],
        originalPrice: (item['originalPrice'] ?? 0).toDouble(),
        salePrice: (item['salePrice'] ?? 0).toDouble(),
        imageUrl: item['imageUrl'] ?? '',
        link: item['link'] ?? '',
      );
    }).toList();
  }

  /// ✅ 擷取所有收藏的商品名稱清單（作為識別 key）
  static Future<List<String>> getFavoriteNames() async {
    final favorites = await getFavorites();
    return favorites.map((p) => p.name).toList();
  }

  /// 🔧 取得原始 JSON 清單（SharedPreferences 讀取）
  static Future<List<dynamic>> _getRawList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return raw != null ? jsonDecode(raw) : []; // 若無資料則回傳空陣列
  }
}


