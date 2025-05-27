import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/favorite_service.dart';
import '../services/product_service.dart' as ps;

class ComparePage extends StatefulWidget {
  final String? barcode;
  final String? keyword;

  // ✅ 新增：來自地圖或拍照的實體價格資料
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initProduct();
  }

  Future<void> _initProduct() async {
    try {
      if (widget.keyword != null && widget.keyword!.trim().isNotEmpty) {
        final raw = widget.keyword!;
        final candidates = await ps.ProductService.fuzzyMatchTopN(raw, 3);
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
      print('❌ 商品查詢失敗: $e');
      product = null;
    }

    setState(() => _isLoading = false);
  }

  Future<ps.Product?> _showProductSelectionDialog(List<ps.Product> products) async {
    return await showDialog<ps.Product>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('辨識結果 - 請選擇商品'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: products.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final p = products[index];
                return ListTile(
                  leading: const Icon(Icons.shopping_cart),
                  title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, p),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消')),
          ],
        );
      },
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('比價結果')),
        body: const Center(child: Text('查無此商品，請確認條碼或辨識結果')),
      );
    }

    // ✅ 統整所有價格來源：平台價格 + 實體價格（若有）
    final allPrices = [
      ...product!.prices.entries.map((e) => e.value),
      if (widget.fromPrice != null) widget.fromPrice!,
    ];

    final double? minPrice = allPrices.isNotEmpty
        ? allPrices.where((p) => p > 0).reduce((a, b) => a < b ? a : b)
        : null;

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
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Icon(Icons.shopping_cart, size: 80),
                  const SizedBox(height: 8),
                  Text(product!.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('📊 比價清單', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // ✅ 加入實體店報價卡片（若有）
            if (widget.fromStore != null && widget.fromPrice != null)
              Card(
                color: Colors.yellow[100],
                child: ListTile(
                  leading: const Icon(Icons.store),
                  title: Row(
                    children: [
                      Text(widget.fromStore!),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (minPrice != null && widget.fromPrice == minPrice)
                              ? Colors.redAccent
                              : Colors.teal,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (minPrice != null && widget.fromPrice == minPrice)
                              ? '🔥 最低'
                              : '你現場看到的價格',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text('價格：\$${widget.fromPrice!.toStringAsFixed(0)}'),
                ),
              ),

            // ✅ 顯示平台價格列表
            Column(
              children: product!.prices.entries.map((entry) {
                final platform = entry.key;
                final price = entry.value;
                final url = product!.links[platform];
                final isLowest = (minPrice != null && price == minPrice);

                return Card(
                  child: ListTile(
                    title: Row(
                      children: [
                        Text(platform),
                        if (isLowest)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '🔥 最低',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    subtitle: price > 0
                        ? Text('價格：\$${price.toStringAsFixed(0)}')
                        : const Text('無價格資料'),
                    trailing: url != null && url.isNotEmpty && price > 0
                        ? IconButton(
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () async {
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('❌ 無法開啟連結')),
                                );
                              }
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
          ],
        ),
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



















