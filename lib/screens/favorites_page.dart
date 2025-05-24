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

  /// ✅ 重新載入收藏商品（從 FavoriteService 抓 barcode，再從 API 查詢完整資料）
  Future<void> _loadFavorites() async {
    final names = await FavoriteService.getFavoriteNames();
    final allProducts = await ps.ProductService.fetchAll();
    setState(() {
      favorites = allProducts.where((p) => names.contains(p.name)).toList();
    });
  }

  /// ✅ 移除指定收藏商品
  Future<void> _removeFavorite(String barcode) async {
    await FavoriteService.removeFromFavorites(barcode);
    await _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFavorites,
        child: favorites.isEmpty
            ? const Center(child: Text('尚未收藏任何商品'))
            : ListView.builder(
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final product = favorites[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: Image.network(
                        product.imageUrl,
                        width: 50,
                        height: 50,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                      ),
                      title: Text(product.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('分類：${product.category}'),
                          Text('店家：${product.store}'),
                          Text('原價：\$${product.originalPrice.toStringAsFixed(0)}'),
                        ],
                      ),
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
                        _loadFavorites();
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}


