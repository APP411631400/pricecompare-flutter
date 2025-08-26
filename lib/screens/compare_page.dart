// 匯入頁面需要的元件
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/favorite_service.dart';
import '../services/product_service.dart' as ps;
import 'ai_page.dart';

import 'scan_history_page.dart' show HistoryRepo;

class ComparePage extends StatefulWidget {
  final String? barcode;
  final String? keyword;
  final String? fromStore;
  final double? fromPrice;

  const ComparePage({
    Key? key,
    this.barcode,
    this.keyword,
    this.fromStore,
    this.fromPrice,
  }) : super(key: key);

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

        if (product != null) {
            final historyKey = product!.name.trim(); // 不用條碼，一律用名稱
            await HistoryRepo.addView(
              productId: historyKey,
              productName: product!.name,
              extra: {
                'from': 'compare',
                'query': widget.keyword ?? widget.barcode ?? '',
                if (widget.fromStore != null) 'fromStore': widget.fromStore,
                if (widget.fromPrice != null) 'fromPrice': widget.fromPrice,
              },
            );
          }
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

      // ✅ 以你的 API 抓比價資料
      final crawlUri = Uri.parse(
        'https://acdb-api.onrender.com/appliances/products/search?query=${Uri.encodeComponent(product!.name)}',
      );
      final crawlRes = await http.get(crawlUri);

      if (crawlRes.statusCode == 200) {
        final List<dynamic> resultList = jsonDecode(crawlRes.body);
        if (resultList.isNotEmpty) {
          final data = resultList.first;

          crawledPrices = {
            '燦坤': _parsePrice(data['燦坤_價格']),
            'PChome': _parsePrice(data['PChome_價格']),
            'momo': _parsePrice(data['momo_價格']),
            '全國電子': _parsePrice(data['全國電子_價格']),
          };

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

      // 計算最低價
      final List<double> allPrices = crawledPrices.values.where((v) => v > 0).toList();
      if (widget.fromPrice != null) allPrices.add(widget.fromPrice!);
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
        ],
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

  // ─────────────────────────────────────────────────────────────────────────
  // UI（僅改樣式與排版，不動你原本邏輯）
  // ─────────────────────────────────────────────────────────────────────────
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

    final theme = Theme.of(context);
    final List<double> allPrices = crawledPrices.values.where((v) => v > 0).toList();
    if (widget.fromPrice != null) allPrices.add(widget.fromPrice!);
    final double? minPrice = allPrices.isNotEmpty ? allPrices.reduce((a, b) => a < b ? a : b) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('比價結果'),
        actions: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.pink : Colors.grey,
            ),
            onPressed: _toggleFavorite,
            tooltip: isFavorite ? '移除收藏' : '加入收藏',
          )
        ],
      ),
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, c) {
          final isWide = c.maxWidth >= 880; // 寬螢幕雙欄
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 頂部：商品標題 + AI 提示膠囊
                Center(
                  child: Column(
                    children: [
                      Text(
                        product!.name,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _aiHeaderCapsule(context),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 中段：左 清單 / 右 地圖（or 占位）
                isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 左側：清單卡們
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle('比價清單'),
                                const SizedBox(height: 12),
                                if (widget.fromStore != null && widget.fromPrice != null)
                                  _pricePill(
                                    label: widget.fromStore!,
                                    price: widget.fromPrice!,
                                    highlight: minPrice != null && widget.fromPrice == minPrice,
                                    icon: Icons.store,
                                    onTap: null,
                                  ),
                                ..._platforms.map((platform) {
                                  final price = crawledPrices[platform] ?? 0;
                                  final url = product!.links[platform] ?? '';
                                  final img = product!.images[platform] ?? '';
                                  final isLowest = !_loadingPrices && minPrice != null && price == minPrice;
                                  return _platformPill(
                                    platform: platform,
                                    imageUrl: img,
                                    price: price,
                                    isLowest: isLowest,
                                    loading: _loadingPrices,
                                    onTap: (url.isNotEmpty && price > 0)
                                        ? () async {
                                            final uri = Uri.parse(url);
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('❌ 無法開啟連結')),
                                              );
                                            }
                                          }
                                        : null,
                                  );
                                }),
                                const SizedBox(height: 20),
                                _sectionTitle('建議信用卡'),
                                const SizedBox(height: 8),
                                _creditCardCapsule(_loadingPrices, _aiCardRecommendation),
                              ],
                            ),
                          ),

                          const SizedBox(width: 18),

                          // 右側：地圖 / 占位圖
                          Expanded(
                            child: _mapCardPlaceholder(),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('比價清單'),
                          const SizedBox(height: 12),
                          if (widget.fromStore != null && widget.fromPrice != null)
                            _pricePill(
                              label: widget.fromStore!,
                              price: widget.fromPrice!,
                              highlight: minPrice != null && widget.fromPrice == minPrice,
                              icon: Icons.store,
                              onTap: null,
                            ),
                          ..._platforms.map((platform) {
                            final price = crawledPrices[platform] ?? 0;
                            final url = product!.links[platform] ?? '';
                            final img = product!.images[platform] ?? '';
                            final isLowest = !_loadingPrices && minPrice != null && price == minPrice;
                            return _platformPill(
                              platform: platform,
                              imageUrl: img,
                              price: price,
                              isLowest: isLowest,
                              loading: _loadingPrices,
                              onTap: (url.isNotEmpty && price > 0)
                                  ? () async {
                                      final uri = Uri.parse(url);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('❌ 無法開啟連結')),
                                        );
                                      }
                                    }
                                  : null,
                            );
                          }),
                          const SizedBox(height: 20),
                          _sectionTitle('建議信用卡'),
                          const SizedBox(height: 8),
                          _creditCardCapsule(_loadingPrices, _aiCardRecommendation),
                          const SizedBox(height: 16),
                          _mapCardPlaceholder(),
                        ],
                      ),

                const SizedBox(height: 28),

                // 歷史價格（占位）
                _sectionTitle('歷史價格'),
                const SizedBox(height: 10),
                _historyCardPlaceholder(minPrice: minPrice),

                const SizedBox(height: 28),

                // 規格表占位
                _sectionTitle('詳細規格'),
                const SizedBox(height: 8),
                _specTablePlaceholder(),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // ────────────────────────── UI 小元件 ──────────────────────────

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  // 上方「AI 提示 + 分析按鈕」膠囊
  Widget _aiHeaderCapsule(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 820),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE3E4E6),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text('AI 依使用者偏好描述規格', style: TextStyle(color: Colors.black87)),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AIPredictPage()));
            },
            icon: const Icon(Icons.smart_toy),
            label: const Text('AI 分析'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff8dd8f2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // 實體店/一般價格膠囊
  Widget _pricePill({
    required String label,
    required double price,
    required bool highlight,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22000000)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.black54),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          if (highlight)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
              child: const Text('🔥 最低', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          Text('\$${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (onTap != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: onTap,
              tooltip: '前往賣場',
            ),
        ],
      ),
    );
  }

  // 電商膠囊（含圖片）
  Widget _platformPill({
    required String platform,
    required String imageUrl,
    required double price,
    required bool isLowest,
    required bool loading,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22000000)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 28),
                  )
                : const Icon(Icons.image_not_supported, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(platform, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                if (isLowest)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                    child: const Text('🔥 最低', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
              ],
            ),
          ),
          if (loading)
            const Text('讀取中…')
          else
            Text(
              price > 0 ? '\$${price.toStringAsFixed(0)}' : '無價格資料',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          if (onTap != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: onTap,
              tooltip: '前往賣場',
            ),
        ],
      ),
    );
  }

  // 信用卡推薦膠囊
  Widget _creditCardCapsule(bool loading, String? text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F6FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: Text(
        loading ? '信用卡推薦讀取中…' : (text ?? '無推薦資訊'),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  // 右側地圖占位卡
  Widget _mapCardPlaceholder() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x22000000)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 這裡放靜態占位圖（或將來接地圖）
            Container(color: const Color(0xFFEFF4F7)),
            const Center(
              child: Icon(Icons.map, size: 80, color: Colors.black26),
            ),
          ],
        ),
      ),
    );
  }

  // 歷史價格占位卡（含最低/最高字樣）
  Widget _historyCardPlaceholder({double? minPrice}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x22000000)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 折線圖占位
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('（未接圖表）歷史價格折線圖占位')),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _priceStat(label: '歷史最低', value: minPrice != null ? ' \$ ${minPrice.toStringAsFixed(0)}' : '—', color: Colors.green),
              const SizedBox(width: 20),
              _priceStat(label: '歷史最高', value: ' \$ 5090', color: Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _priceStat({required String label, required String value, required Color color}) {
    return Row(
      children: [
        Text(label),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  // 規格表占位卡
  Widget _specTablePlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: const Text('這裡將來可放商品規格比較資訊，例如：重量、成分、規格、容量…等'),
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



















