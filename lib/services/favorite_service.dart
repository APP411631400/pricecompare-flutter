// ✅ services/favorite_service.dart - 收藏功能管理器（支援新的比價商品結構）

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/product_service.dart' as ps;

/// 收藏功能服務類別：管理本地儲存的收藏商品資料
class FavoriteService {
  static const _key = 'favorite_products'; // SharedPreferences 儲存鍵名

  /// ✅ 加入收藏：將商品加入本地收藏清單
  static Future<void> addToFavorites(ps.Product product) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _getRawList();

    // 以商品名稱為唯一 key（避免重複加入）
    if (!list.any((item) => item['name'] == product.name)) {
      // 儲存時將 map 結構壓平為 json-friendly 格式
      list.add({
        'name': product.name,
        'id': product.id,
        'prices': product.prices,
        'links': product.links,
      });
      await prefs.setString(_key, jsonEncode(list));
    }
  }

  /// ✅ 移除收藏：根據商品名稱移除
  static Future<void> removeFromFavorites(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _getRawList();
    list.removeWhere((item) => item['name'] == name);
    await prefs.setString(_key, jsonEncode(list));
  }

  /// ✅ 判斷某商品是否已被收藏（以名稱判斷）
  static Future<bool> isFavorited(String name) async {
    final list = await _getRawList();
    return list.any((item) => item['name'] == name);
  }

  /// ✅ 取得所有收藏的商品資料（轉回 ps.Product 類別）
  static Future<List<ps.Product>> getFavorites() async {
    final list = await _getRawList();
    return list.map<ps.Product>((item) {
      return ps.Product(
        name: item['name'] ?? '',
        id: item['id'] ?? 0,
        prices: Map<String, double>.from(item['prices'] ?? {}),
        links: Map<String, String>.from(item['links'] ?? {}),
        images: Map<String, String>.from(item['images'] ?? {}),
      );
    }).toList();
  }

  /// ✅ 擷取所有已收藏的商品名稱（可用於 UI 判斷）
  static Future<List<String>> getFavoriteNames() async {
    final favorites = await getFavorites();
    return favorites.map((p) => p.name).toList();
  }

  /// 🔧 取得原始 JSON 清單
  static Future<List<dynamic>> _getRawList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return raw != null ? jsonDecode(raw) : [];
  }
}



