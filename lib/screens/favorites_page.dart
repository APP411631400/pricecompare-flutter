import 'package:flutter/material.dart';
import '../services/favorite_service.dart';
import '../services/product_service.dart' as ps;
import 'compare_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<ps.Product> favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  /// ✅ 載入收藏商品（直接從 FavoriteService 取得所有 Product）
  Future<void> _loadFavorites() async {
    final result = await FavoriteService.getFavorites(); // 已是完整 ps.Product 清單
    setState(() {
      favorites = result;
    });
  }

  /// ✅ 移除收藏
  Future<void> _removeFavorite(String name) async {
    await FavoriteService.removeFromFavorites(name);
    await _loadFavorites();
  }

  /// ✅ 計算最低價與來源平台
  MapEntry<String, double>? _findLowestPrice(ps.Product product) {
    final validPrices = product.prices.entries.where((e) => e.value > 0).toList();
    if (validPrices.isEmpty) return null;
    validPrices.sort((a, b) => a.value.compareTo(b.value));
    return validPrices.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: RefreshIndicator(
        onRefresh: _loadFavorites,
        child: favorites.isEmpty
            ? const Center(child: Text('尚未收藏任何商品'))
            : ListView.builder(
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final product = favorites[index];
                  final lowest = _findLowestPrice(product);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.favorite, color: Colors.red), // 沒圖片就用心 icon
                      title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: lowest != null
                          ? Text('最低價：\$${lowest.value.toStringAsFixed(0)}（${lowest.key}）')
                          : const Text('無價格資料'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.grey),
                        onPressed: () => _removeFavorite(product.name),
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComparePage(barcode: product.name),
                          ),
                        );
                        _loadFavorites(); // 回來後重新刷新收藏
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}



