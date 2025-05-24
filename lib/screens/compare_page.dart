// ----------------------------- ComparePage.dart（整合後端真實資料 + 修正查詢跳錯誤視窗問題 + 完整中文註解）-----------------------------
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // 📍 取得 GPS 位置
import 'package:url_launcher/url_launcher.dart'; // 🔗 開啟商品連結
import '../services/favorite_service.dart'; // ❤️ 收藏服務（本地儲存）
import '../data/scan_history.dart'; // 📝 拍照或掃碼紀錄儲存結構
import '../services/product_service.dart' as ps; // ⭐ 使用後端 Product 並避免名稱衝突

class ComparePage extends StatefulWidget {
  final String? barcode; // 📥 條碼掃描後傳入
  final String? keyword; // 📥 拍照辨識後傳入

  const ComparePage({Key? key, this.barcode, this.keyword}) : super(key: key);

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  ps.Product? product; // ✅ 查詢到的商品資料
  bool isFavorite = false; // ❤️ 收藏狀態
  bool _isLoading = true; // 🔄 加入 loading 狀態避免 build 過早顯示錯誤畫面

  @override
  void initState() {
    super.initState();
    _initProduct();
  }

  /// 🔍 根據條碼或關鍵字查詢商品（從後端 API）
  Future<void> _initProduct() async {
  try {
    if (widget.keyword != null && widget.keyword!.trim().isNotEmpty) {
      final raw = widget.keyword!;

      // ✅ 改為模糊查詢 Top 3 筆商品（可自行調整數量）
      final candidates = await ps.ProductService.fuzzyMatchTopN(raw, 3);

      if (candidates.isEmpty) {
        product = null;
      } else if (candidates.length == 1) {
        // ✅ 只有一筆時自動採用
        product = candidates.first;
      } else {
        // ✅ 多筆時讓使用者挑選
        product = await _showProductSelectionDialog(candidates);
      }
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

  setState(() {
    _isLoading = false;
  });
}


/// ✅ 顯示商品選單讓使用者選擇正確比對商品
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
                leading: Image.network(p.imageUrl, width: 50, errorBuilder: (_, __, ___) => const Icon(Icons.image)),
                title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('店家：${p.store}'),
                onTap: () => Navigator.pop(context, p), // ✅ 回傳選中的商品
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('取消'))
        ],
      );
    },
  );
}




  /// 💗 收藏狀態切換（加入或移除）
  Future<void> _toggleFavorite() async {
    if (product == null) return;
    setState(() => isFavorite = !isFavorite);
    if (isFavorite) {
      await FavoriteService.addToFavorites(product!);
    } else {
      await FavoriteService.removeFromFavorites(product!.name);
    }
  }

  /// 📩 顯示價格回報視窗（拍照限定）
  Future<void> _showReportDialog() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('回報價格'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '請輸入價格 (NT\$)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final price = double.tryParse(controller.text);
              if (price == null || price <= 0) return;

              final pos = await Geolocator.getCurrentPosition();

              scanHistory.add(
                ScanRecord(
                  barcode: widget.barcode ?? '',
                  timestamp: DateTime.now(),
                  latitude: pos.latitude,
                  longitude: pos.longitude,
                  price: price,
                  name: product!.name,
                  store: product!.store,
                  imagePath: null,
                ),
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ 已成功回報價格！')),
              );
            },
            child: const Text('送出'),
          ),
        ],
      ),
    );
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
                  Image.network(
                    product!.imageUrl,
                    width: 100,
                    height: 100,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                  ),
                  const SizedBox(height: 8),
                  Text(product!.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("分類：${product!.category}"),
                  Text("店家：${product!.store}"),
                  const SizedBox(height: 10),
                  Text("原價：\$${product!.originalPrice.toStringAsFixed(0)}",
                      style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                  Text("特價：\$${product!.salePrice.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(product!.link);
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text("前往商品頁面"),
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 📩 僅拍照模式顯示價格回報按鈕
            if (widget.keyword != null)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _showReportDialog,
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('我要回報價格'),
                ),
              ),
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



















