// 📄 lib/screens/scan_history_page.dart
// 單檔版：內嵌 HistoryItem 與 _HistoryRepo，無需新增檔案

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/product_service.dart' as ps; // ← 取得商品資料用
import 'compare_page.dart';

/// ----- 資料模型 -----
class HistoryItem {
  final String productId;      // 你的唯一鍵（條碼或產品 id）
  final String productName;    // 顯示名稱
  final int viewCount;         // 檢視次數
  final DateTime lastViewedAt; // 最近時間
  final Map<String, dynamic>? extra;

  HistoryItem({
    required this.productId,
    required this.productName,
    required this.viewCount,
    required this.lastViewedAt,
    this.extra,
  });

  factory HistoryItem.fromMap(Map<String, dynamic> m) {
    return HistoryItem(
      productId: m['productId'] as String,
      productName: (m['productName'] as String?) ?? '',
      viewCount: (m['viewCount'] is int) ? m['viewCount'] as int : 1,
      lastViewedAt: (m['lastViewedAt'] is Timestamp)
          ? (m['lastViewedAt'] as Timestamp).toDate()
          : (DateTime.tryParse(m['lastViewedAt']?.toString() ?? '') ?? DateTime.now()),
      extra: (m['extra'] as Map?)?.cast<String, dynamic>(),
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'viewCount': viewCount,
        'lastViewedAt': lastViewedAt.toIso8601String(),
        if (extra != null) 'extra': extra,
      };
}

/// ----- 輕量資料層（內嵌，不另外建檔）-----
class HistoryRepo {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static User? get _user => FirebaseAuth.instance.currentUser;

  static CollectionReference<Map<String, dynamic>> _col() =>
      _db.collection('users').doc(_user!.uid).collection('history');

  static const _guestKey = 'guest_history_v1';

  /// 新增/累加瀏覽紀錄
  static Future<void> addView({
    required String productId,
    required String productName,
    Map<String, dynamic>? extra,
  }) async {
    if (_user == null) {
      final prefs = await SharedPreferences.getInstance();
      final list = await _guestList();
      final idx = list.indexWhere((e) => e['productId'] == productId);
      if (idx >= 0) {
        final cur = list[idx] as Map<String, dynamic>;
        cur['viewCount'] = (cur['viewCount'] ?? 1) + 1;
        cur['lastViewedAt'] = DateTime.now().toIso8601String();
        if (extra != null) cur['extra'] = extra;
      } else {
        list.insert(0, {
          'productId': productId,
          'productName': productName,
          'viewCount': 1,
          'lastViewedAt': DateTime.now().toIso8601String(),
          if (extra != null) 'extra': extra,
        });
      }
      await prefs.setString(_guestKey, jsonEncode(list));
      return;
    }

    final doc = _col().doc(productId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(doc);
      if (snap.exists) {
        final v = snap.data()!;
        tx.update(doc, {
          'viewCount': (v['viewCount'] ?? 1) + 1,
          'lastViewedAt': FieldValue.serverTimestamp(),
          if (extra != null) 'extra': extra,
          'productName': productName,
        });
      } else {
        tx.set(doc, {
          'productId': productId,
          'productName': productName,
          'viewCount': 1,
          'lastViewedAt': FieldValue.serverTimestamp(),
          if (extra != null) 'extra': extra,
        });
      }
    });
  }

  /// 讀取列表
  static Future<List<HistoryItem>> list({bool desc = true, int limit = 500}) async {
    if (_user == null) {
      final list = await _guestList();
      list.sort((a, b) => (desc ? -1 : 1) *
          (DateTime.parse((a as Map)['lastViewedAt']).compareTo(DateTime.parse((b as Map)['lastViewedAt']))));
      if (list.length > limit) list.length = limit;
      return list.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return HistoryItem(
          productId: m['productId'] as String,
          productName: (m['productName'] as String?) ?? '',
          viewCount: (m['viewCount'] ?? 1) as int,
          lastViewedAt: DateTime.parse(m['lastViewedAt'] as String),
          extra: (m['extra'] as Map?)?.cast<String, dynamic>(),
        );
      }).toList();
    }

    final qs = await _col()
        .orderBy('lastViewedAt', descending: desc)
        .limit(limit)
        .get();

    return qs.docs.map((d) {
      final m = d.data();
      m['productId'] = d.id;
      return HistoryItem.fromMap(m);
    }).toList();
  }

  /// 刪除單筆
  static Future<void> remove(String productId) async {
    if (_user == null) {
      final prefs = await SharedPreferences.getInstance();
      final list = await _guestList();
      list.removeWhere((e) => (e as Map)['productId'] == productId);
      await prefs.setString(_guestKey, jsonEncode(list));
      return;
    }
    await _col().doc(productId).delete();
  }

  /// 清空
  static Future<void> clearAll() async {
    if (_user == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestKey);
      return;
    }
    final qs = await _col().limit(500).get();
    final batch = _db.batch();
    for (final d in qs.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  /// guest list helper
  static Future<List<dynamic>> _guestList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guestKey);
    return raw != null ? jsonDecode(raw) as List : <dynamic>[];
  }
}

/// ----- UI -----
class ScanHistoryPage extends StatefulWidget {
  const ScanHistoryPage({super.key});
  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  bool _desc = true;
  bool _loading = true;
  List<HistoryItem> _items = [];

  // 產品快取，避免重複查詢
  final Map<String, Future<ps.Product?>> _productCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await HistoryRepo.list(desc: _desc, limit: 500);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _remove(HistoryItem it) async {
    await HistoryRepo.remove(it.productId);
    await _load();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空瀏覽歷史？'),
        content: const Text('此操作會刪除此帳號下的全部瀏覽歷史資料。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) {
      await HistoryRepo.clearAll();
      await _load();
    }
  }

  // 依據 productId / productName 取產品（快取一次）
  Future<ps.Product?> _getProduct(HistoryItem it) {
    return _productCache.putIfAbsent(it.productId, () async {
      // 優先用 productId 搜（條碼/你的唯一鍵）
      final byId = await ps.ProductService.search(it.productId);
      if (byId.isNotEmpty) return byId.first;

      // 退回用名稱模糊匹配
      final byName = await ps.ProductService.fuzzyMatchTopN(it.productName, 1);
      return byName.isNotEmpty ? byName.first : null;
    });
  }

  // 產生價格區間字串（跟你首頁一致）
  String _priceRangeText(ps.Product p) {
    final values = p.prices.values
        .whereType<double>()
        .where((v) => v > 0)
        .toList()
      ..sort();

    String fmt(num v) {
      final s = v.toStringAsFixed(0);
      return s.replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',');
    }

    if (values.isEmpty) return '—';
    if (values.first == values.last) return '\$${fmt(values.first)}';
    return '\$${fmt(values.first)} - \$${fmt(values.last)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('瀏覽歷史'),
        actions: [
          IconButton(
            icon: Icon(_desc ? Icons.arrow_downward : Icons.arrow_upward),
            tooltip: _desc ? '由舊到新' : '由新到舊',
            onPressed: () async {
              setState(() => _desc = !_desc);
              await _load();
            },
          ),
          IconButton(icon: const Icon(Icons.delete_sweep), onPressed: _clearAll),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('尚無瀏覽歷史'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      return Dismissible(
                        key: ValueKey(it.productId),
                        direction: DismissDirection.startToEnd,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _remove(it),
                        child: FutureBuilder<ps.Product?>(
                          future: _getProduct(it),
                          builder: (_, snapshot) {
                            final product = snapshot.data;

                            // 卡片樣式（對齊首頁搜尋結果）
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ComparePage(
                                        // 你比價頁用 barcode 查，這裡就傳 productId
                                        keyword: it.productId,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 左：圖片
                                      Container(
                                        width: 86,
                                        height: 86,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF4F5F7),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: (product != null)
                                            ? () {
                                                // 嘗試從最低價平台抓圖片
                                                final entries = product.prices.entries
                                                    .where((e) => e.value > 0)
                                                    .toList()
                                                  ..sort((a, b) => a.value.compareTo(b.value));
                                                final lowestKey = entries.isNotEmpty ? entries.first.key : null;
                                                final imgUrl = lowestKey != null ? (product.images[lowestKey] ?? '') : '';
                                                if (imgUrl.isNotEmpty) {
                                                  return Image.network(imgUrl, fit: BoxFit.cover);
                                                }
                                                return const Center(child: Icon(Icons.image_not_supported));
                                              }()
                                            : (snapshot.connectionState == ConnectionState.waiting
                                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                                : const Center(child: Icon(Icons.image_not_supported))),
                                      ),

                                      const SizedBox(width: 12),

                                      // 中：商品名稱 + 次數/時間
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product?.name ?? it.productName,
                                              softWrap: true,
                                              maxLines: 3,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                height: 1.25,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '次數：${it.viewCount} ・ 最近：${it.lastViewedAt.toLocal().toString().substring(0, 19)}',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // 右：價格區間
                                      SizedBox(
                                        width: 128,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text('價格', style: TextStyle(color: Colors.black54)),
                                            const SizedBox(height: 4),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                product != null
                                                    ? _priceRangeText(product)
                                                    : (snapshot.connectionState == ConnectionState.waiting ? '載入中…' : '—'),
                                                maxLines: 1,
                                                softWrap: false,
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}








