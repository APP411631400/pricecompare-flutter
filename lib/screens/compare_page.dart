// 匯入頁面需要的元件
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/favorite_service.dart';
import '../services/product_service.dart' as ps;
import 'ai_page.dart'; // ✅ 加入 AI 分析頁面

/// 比價頁面：顯示實體店與各大電商比價結果，並推薦最佳信用卡
class ComparePage extends StatefulWidget {
  final String? barcode;
  final String? keyword;
  final String? fromStore;
  final double? fromPrice;

  const ComparePage({Key? key, this.barcode, this.keyword, this.fromStore, this.fromPrice}) : super(key: key);

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  ps.Product? product;
  bool isFavorite = false;

  // 狀態旗標：載入商品、載入價格與推薦
  bool _loadingProduct = true;
  bool _loadingPrices = true;

  String? _aiCardRecommendation;
  Map<String, double> crawledPrices = {};
  // final List<String> _platforms = ['momo', 'pchome', '博客來', '屈臣氏', '康是美'];
  final List<String> _platforms = ['燦坤', 'PChome', 'momo', '全國電子'];


  @override
  void initState() {
    super.initState();
    _initProduct();
  }

  Future<void> _initProduct() async {
    try {
      if (widget.keyword != null && widget.keyword!.isNotEmpty) {
        final candidates = await ps.ProductService.fuzzyMatchTopN(widget.keyword!, 3);
        product = candidates.isEmpty
            ? null
            : candidates.length == 1
                ? candidates.first
                : await _showProductSelectionDialog(candidates);
      } else if (widget.barcode != null && widget.barcode!.isNotEmpty) {
        final list = await ps.ProductService.search(widget.barcode!);
        product = list.isNotEmpty ? list.first : null;
      }
      if (product != null) {
        isFavorite = await FavoriteService.isFavorited(product!.name);
      }
    } catch (e) {
      product = null;
    }
    setState(() => _loadingProduct = false);
    _fetchPricesAndRecommend();
  }

/*
  Future<void> _fetchPricesAndRecommend() async {
    try {
      if (product == null) return;
      final crawlUri = Uri.parse('https://acdb-api.onrender.com/product_detail?id=${product!.id}');
      final crawlRes = await http.get(crawlUri);
      if (crawlRes.statusCode == 200) {
        final data = jsonDecode(crawlRes.body);
        crawledPrices = {for (var p in _platforms) p: _parsePrice(data[p])};
      }
      final List<double> allPrices = crawledPrices.values.where((v) => v > 0).toList();
      if (widget.fromPrice != null) {
        allPrices.add(widget.fromPrice!);
      }
      final double? minPrice = allPrices.isNotEmpty ? allPrices.reduce((a, b) => a < b ? a : b) : null;

      if (minPrice != null) {
        final resp = await http.post(
          Uri.parse('https://acdb-api.onrender.com/recommend_card'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'store': product!.name, 'amount': minPrice}),
        );
        if (resp.statusCode == 200) {
          _aiCardRecommendation = jsonDecode(resp.body)['result'];
        } else {
          _aiCardRecommendation = '伺服器錯誤：${resp.statusCode}';
        }
      }
    } catch (e) {
      _aiCardRecommendation = '推薦失敗：$e';
    } finally {
      setState(() => _loadingPrices = false);
    }
  }

  */

  Future<void> _fetchPricesAndRecommend() async {
    try {
      if (product == null) return;

      // ✅ 新的資料 API：用模糊搜尋找對應商品資料（使用你的 Flask API）
      final crawlUri = Uri.parse(
          'https://acdb-api.onrender.com/appliances/products/search?query=${Uri.encodeComponent(product!.name)}');
      final crawlRes = await http.get(crawlUri);

      if (crawlRes.statusCode == 200) {
        final List<dynamic> resultList = jsonDecode(crawlRes.body);
        if (resultList.isNotEmpty) {
          final data = resultList.first;

          // ✅ 將價格資料轉成 crawledPrices Map，方便後面顯示卡片
          crawledPrices = {
            '燦坤': _parsePrice(data['燦坤_價格']),
            'PChome': _parsePrice(data['PChome_價格']),
            'momo': _parsePrice(data['momo_價格']),
            '全國電子': _parsePrice(data['全國電子_價格']),
          };

          // ✅ 圖片連結與商店連結也一併處理（賦值給 product 以便 ListTile 顯示）
          product!.images['燦坤'] = data['燦坤_圖片'] ?? '';
          product!.images['PChome'] = data['PChome_圖片'] ?? '';
          product!.images['momo'] = data['momo_圖片'] ?? '';
          product!.images['全國電子'] = data['全國電子_圖片'] ?? '';

          product!.links['燦坤'] = data['燦坤_連結'] ?? '';
          product!.links['PChome'] = data['PChome_連結'] ?? '';
          product!.links['momo'] = data['momo_連結'] ?? '';
          product!.links['全國電子'] = data['全國電子_連結'] ?? '';
        }
      }

      // ✅ 取得所有有效價格（不為 0）
      final List<double> allPrices =
          crawledPrices.values.where((v) => v > 0).toList();
      if (widget.fromPrice != null) {
        allPrices.add(widget.fromPrice!);
      }

      // ✅ 計算最低價，用於後續標示與推薦信用卡使用
      final double? minPrice =
          allPrices.isNotEmpty ? allPrices.reduce((a, b) => a < b ? a : b) : null;

      if (minPrice != null) {
        // ✅ 呼叫推薦信用卡 API（此段邏輯不變）
        final resp = await http.post(
          Uri.parse('https://acdb-api.onrender.com/recommend_card'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'store': product!.name, 'amount': minPrice}),
        );
        if (resp.statusCode == 200) {
          _aiCardRecommendation = jsonDecode(resp.body)['result'];
        } else {
          _aiCardRecommendation = '伺服器錯誤：${resp.statusCode}';
        }
      }
    } catch (e) {
      _aiCardRecommendation = '推薦失敗：$e';
    } finally {
      setState(() => _loadingPrices = false);
    }
  }


  double _parsePrice(dynamic value) {
    if (value is String) {
      final numStr = value.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(numStr) ?? 0;
    }
    return 0;
  }

  Future<ps.Product?> _showProductSelectionDialog(List<ps.Product> products) async {
    return showDialog<ps.Product>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('選擇商品'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: products.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) {
              final p = products[i];
              return ListTile(
                leading: const Icon(Icons.shopping_cart),
                title: Text(p.name),
                onTap: () => Navigator.pop(context, p),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消'))],
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (product == null) return;
    setState(() => isFavorite = !isFavorite);
    if (isFavorite) {
      await FavoriteService.addToFavorites(product!);
    } else {
      await FavoriteService.removeFromFavorites(product!.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProduct) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('比價結果')),
        body: const Center(child: Text('查無此商品')),
      );
    }

    final List<double> allPrices = crawledPrices.values.where((v) => v > 0).toList();
    if (widget.fromPrice != null) {
      allPrices.add(widget.fromPrice!);
    }
    final double? minPrice = allPrices.isNotEmpty ? allPrices.reduce((a, b) => a < b ? a : b) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('比價結果'),
        actions: [
          IconButton(
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.pink : Colors.grey),
            onPressed: _toggleFavorite,
            tooltip: isFavorite ? '移除收藏' : '加入收藏',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ⬇️ 商品區塊 + AI 分析按鈕
          Center(child: Column(children: [
            const Icon(Icons.shopping_cart, size: 80),
            const SizedBox(height: 8),
            Text(product!.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                // ✅ 點擊跳轉到 AI 分析頁
                Navigator.push(context, MaterialPageRoute(builder: (_) => AIPredictPage()));
              },
              icon: const Icon(Icons.smart_toy),
              label: const Text("AI 分析商品"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ])),

          const SizedBox(height: 24),
          const Text('📊 比價清單', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 12),

          // ⬇️ 實體店價格卡片
          if (widget.fromStore != null && widget.fromPrice != null)
            Card(
              color: Colors.yellow[100],
              child: ListTile(
                leading: const Icon(Icons.store),
                title: Row(children: [
                  Text(widget.fromStore!),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (minPrice != null && widget.fromPrice == minPrice) ? Colors.redAccent : Colors.teal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text((minPrice != null && widget.fromPrice == minPrice) ? '🔥 最低' : '現場價格',
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                  )
                ]),
                subtitle: Text('價格：\$${widget.fromPrice!.toStringAsFixed(0)}'),
              ),
            ),

          // ⬇️ 電商價格卡片清單
          Column(
            children: _platforms.map((platform) {
              final price = crawledPrices[platform] ?? 0;
              final url = product!.links[platform] ?? '';
              final img = product!.images[platform] ?? '';
              final isLowest = !_loadingPrices && minPrice != null && price == minPrice;
              return Card(
                child: ListTile(
                  leading: img.isNotEmpty
                      ? Image.network(img, width: 50, height: 50, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))
                      : const Icon(Icons.image_not_supported),
                  title: Row(children: [
                    Text(platform),
                    if (isLowest)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                        child: const Text('🔥 最低', style: TextStyle(color: Colors.white, fontSize: 12)),
                      )
                  ]),
                  subtitle: _loadingPrices
                      ? const Text('讀取中…')
                      : (price > 0 ? Text('價格：\$${price.toStringAsFixed(0)}') : const Text('無價格資料')),
                  trailing: (url.isNotEmpty && price > 0)
                      ? IconButton(
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () async {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ 無法開啟連結')));
                            }
                          },
                        )
                      : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          const Text('💳 建議信用卡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_loadingPrices ? '信用卡推薦讀取中…' : (_aiCardRecommendation ?? '無推薦資訊')),
            ),
          ),

          const SizedBox(height: 24),
          const Text('📐 商品規格比較（預留）', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            color: Colors.grey[200],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('這裡將來可放商品規格比較資訊，例如：重量、成分、規格、容量…等'),
            ),
          ),

          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

















/// ✅ 最長共同子字串演算法（Longest Common Substring，用於模糊比對）
// String _longestCommonSubstring(String s1, String s2) {
  //final m = List.generate(s1.length + 1, (_) => List.filled(s2.length + 1, 0));
  //int maxLen = 0, endIndex = 0;

  //for (int i = 1; i <= s1.length; i++) {
    //for (int j = 1; j <= s2.length; j++) {
      //if (s1[i - 1] == s2[j - 1]) {
        //m[i][j] = m[i - 1][j - 1] + 1;
        //if (m[i][j] > maxLen) {
         // maxLen = m[i][j];
          //endIndex = i;
       // }
     // }
    //}
 // }
 // return s1.substring(endIndex - maxLen, endIndex);
//}

/// ✅ 模糊比對規則：只要連續 3 字元以上相同就算相似
// bool _fuzzyMatch(String a, String b) {
  //return _longestCommonSubstring(a, b).length >= 3;
//}



















