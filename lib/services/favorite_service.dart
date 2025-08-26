// lib/services/favorite_service.dart
// Firestore 版收藏服務（未登入自動退回本機 SharedPreferences）

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';   // ✅ 修正
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ⚠️ 你這支檔案就在 services/ 資料夾裡，所以路徑不用 ../services
import 'product_service.dart' as ps;

class FavoriteService {
  // ---------- Firestore 共用 ----------
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static User? get _user => FirebaseAuth.instance.currentUser;

  // ✅ 指名泛型 <Map<String, dynamic>>，避免推斷成 dynamic
  static CollectionReference<Map<String, dynamic>> _col() =>
      _db
          .collection('users')
          .doc(_user!.uid)
          .collection('favorites');

  // ---------- Public API（與你原本方法簽名一致） ----------

  /// 加入收藏
  static Future<void> addToFavorites(ps.Product product) async {
    if (_user == null) {
      await _localAdd(product); // 未登入 → 本機
      return;
    }

    await _col().doc(product.name).set({
      'name': product.name,
      'id': product.id,
      'prices': product.prices,  // Map<String, double>
      'links': product.links,    // Map<String, String>
      'images': product.images,  // Map<String, String>
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 移除收藏（以名稱為 docId）
  static Future<void> removeFromFavorites(String name) async {
    if (_user == null) {
      await _localRemove(name);
      return;
    }
    await _col().doc(name).delete();
  }

  /// 是否已收藏
  static Future<bool> isFavorited(String name) async {
    if (_user == null) return _localIsFavorited(name);
    final doc = await _col().doc(name).get();
    return doc.exists;
  }

  /// 取得所有收藏（回傳 ps.Product 清單）
  static Future<List<ps.Product>> getFavorites() async {
    if (_user == null) return _localGetFavorites();

    final qs = await _col().orderBy('createdAt', descending: true).get();
    return qs.docs.map((d) {
      final data = d.data();
      return ps.Product(
        name: (data['name'] ?? '') as String,
        id: (data['id'] ?? 0) as int,
        prices: Map<String, double>.from(data['prices'] ?? const {}),
        links: Map<String, String>.from(data['links'] ?? const {}),
        images: Map<String, String>.from(data['images'] ?? const {}),
      );
    }).toList();
  }

  /// 收藏名稱清單
  static Future<List<String>> getFavoriteNames() async {
    final list = await getFavorites();
    return list.map((p) => p.name).toList();
  }

  // ---------- 未登入時的本機 fallback ----------
  static const _localKey = 'favorite_products';

  static Future<void> _localAdd(ps.Product p) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _localRawList();
    if (!list.any((e) => e['name'] == p.name)) {
      list.add({
        'name': p.name,
        'id': p.id,
        'prices': p.prices,
        'links': p.links,
        'images': p.images,
      });
      await prefs.setString(_localKey, jsonEncode(list));
    }
  }

  static Future<void> _localRemove(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _localRawList();
    list.removeWhere((e) => e['name'] == name);
    await prefs.setString(_localKey, jsonEncode(list));
  }

  static Future<bool> _localIsFavorited(String name) async {
    final list = await _localRawList();
    return list.any((e) => e['name'] == name);
  }

  static Future<List<ps.Product>> _localGetFavorites() async {
    final list = await _localRawList();
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

  static Future<List<dynamic>> _localRawList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    return raw != null ? jsonDecode(raw) : <dynamic>[];
  }
}





