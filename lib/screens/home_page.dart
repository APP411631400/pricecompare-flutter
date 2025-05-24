// ✅ home_page.dart（整合分類與店家篩選 + 完整註解 + 保留原有邏輯）

import 'package:flutter/material.dart';
import 'barcode_scan_page.dart';
import 'scan_history_page.dart';
import 'map_compare_page.dart';
import 'recommend_page.dart';
import 'credit_card_page.dart';
import 'compare_page.dart';
import 'ai_page.dart';
import 'user_page.dart';
import 'take_photo_page.dart';

import '../services/product_service.dart' as ps; // ✅ 用 as ps 匯入，避免與其他 Product 衝突
import '../services/user_service.dart'; // ✅ 匯入使用者服務（取得登入者名稱）

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController _searchController = TextEditingController();
  List<ps.Product> searchResults = []; // ✅ 搜尋後的商品結果（尚未過濾）

  // ✅ 使用者名稱（登入後顯示）
  String? _userName;

  // ✅ 選單篩選狀態與選項
  String? selectedCategory;
  String? selectedStore;
  List<String> categoryOptions = [];
  List<String> storeOptions = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadUserName();
  }

  /// ✅ 從 SharedPreferences 取得登入使用者名稱（UserService）
  void _loadUserName() async {
    final name = await UserService.getUserName();
    setState(() {
      _userName = name ?? '使用者';
    });
  }

  /// ✅ 關鍵字搜尋（從後端 API），同時整理分類與店家選單
  Future<void> _search(String query) async {
    final results = await ps.ProductService.search(query);
    final categories = results.map((p) => p.category).toSet().toList();
    final stores = results.map((p) => p.store).toSet().toList();

    setState(() {
      searchResults = results;
      categoryOptions = categories;
      storeOptions = stores;
      selectedCategory = null;
      selectedStore = null;
    });

    if (results.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('找不到商品'),
          content: Text('請確認輸入是否正確，或稍後再試'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('確定')),
          ],
        ),
      );
    }
  }

  /// ✅ 清除搜尋條件與結果
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      searchResults.clear();
      selectedCategory = null;
      selectedStore = null;
    });
  }

  /// ✅ 根據目前的分類與店家選擇篩選商品列表
  List<ps.Product> get _filteredResults {
    return searchResults.where((p) {
      final matchCategory = selectedCategory == null || p.category == selectedCategory;
      final matchStore = selectedStore == null || p.store == selectedStore;
      return matchCategory && matchStore;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('智慧購物助手'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ✅ 歡迎詞
            if (_userName != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '👋 歡迎回來，$_userName！',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 12),

            // ✅ 搜尋欄位
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '輸入條碼或商品名稱搜尋',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: Icon(Icons.clear), onPressed: _clearSearch)
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: _search,
            ),
            const SizedBox(height: 20),

            // ✅ 有搜尋結果時才顯示下拉選單與結果列表
            if (searchResults.isNotEmpty)
              Expanded(
                child: Column(
                  children: [
                    // ✅ 搜尋條件區 + 清除按鈕
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("搜尋結果：${_searchController.text}", style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _clearSearch,
                          icon: Icon(Icons.clear),
                          label: Text("清除搜尋"),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ✅ 分類與店家選單
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            hint: Text("分類"),
                            isExpanded: true,
                            items: [null, ...categoryOptions].map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(c ?? "全部分類"),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => selectedCategory = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButton<String>(
                            value: selectedStore,
                            hint: Text("店家"),
                            isExpanded: true,
                            items: [null, ...storeOptions].map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(s ?? "全部店家"),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => selectedStore = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ✅ 商品列表（依照篩選後結果）
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredResults.length,
                        itemBuilder: (context, index) {
                          final product = _filteredResults[index];
                          return Card(
                            elevation: 2,
                            child: ListTile(
                              leading: Image.network(
                                product.imageUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported),
                              ),
                              title: Text(product.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("分類：${product.category}"),
                                  Text("店家：${product.store}"),
                                  Text("原價：\$${product.originalPrice.toStringAsFixed(0)}"),
                                ],
                              ),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ComparePage(barcode: product.name), // 🔁 未來接入 barcode
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            else
              // ✅ 主功能入口
              Expanded(
                child: ListView(
                  children: [
                    _sectionTitle('比價功能'),
                    _functionRow([
                      _functionCard(Icons.qr_code_scanner, '掃碼比價', BarcodeScanPage(), Colors.blueAccent),
                      _functionCard(Icons.map, '地圖比價', MapComparePage(), Colors.green),
                      _functionCard(Icons.history, '掃描紀錄', ScanHistoryPage(), Colors.orange),
                      _functionCard(Icons.camera_alt, '拍照識別', TakePhotoPage(), Colors.brown),
                    ]),
                    const SizedBox(height: 16),
                    _sectionTitle('推薦與優惠'),
                    _functionRow([
                      _functionCard(Icons.recommend, '推薦商品', RecommendPage(), Colors.purple),
                      _functionCard(Icons.auto_awesome, 'AI 智慧推薦', AIPredictPage(), Colors.teal),
                      _functionCard(Icons.credit_card, '信用卡優惠', CreditCardPage(), Colors.redAccent),
                    ]),
                    const SizedBox(height: 16),
                    _sectionTitle('帳戶管理'),
                    _functionRow([
                      _functionCard(Icons.person, '會員中心', UserPage(), Colors.indigo),
                    ]),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  Widget _functionRow(List<Widget> cards) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: cards,
      );

  Widget _functionCard(IconData icon, String label, Widget page, Color color) => Expanded(
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          child: Container(
            height: 100,
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              border: Border.all(color: color.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 36, color: color),
                const SizedBox(height: 8),
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
}
















