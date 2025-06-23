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
import 'business_account_page.dart';


import '../services/product_service.dart' as ps;
import '../services/user_service.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController _searchController = TextEditingController();
  List<ps.Product> searchResults = [];

  String? _userName;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadUserName();
  }

  /// ✅ 從 SharedPreferences 取得使用者名稱
  void _loadUserName() async {
    final name = await UserService.getUserName();
    setState(() {
      _userName = name ?? '使用者';
    });
  }

  /// ✅ 呼叫後端搜尋 API
  Future<void> _search(String query) async {
    final results = await ps.ProductService.search(query);
    setState(() {
      searchResults = results;
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

  /// ✅ 清除搜尋欄與結果
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      searchResults.clear();
    });
  }

  /// ✅ 找出最低價與平台（如 momo: $159）
  MapEntry<String, double>? _findLowestPrice(ps.Product product) {
    final validPrices = product.prices.entries.where((e) => e.value > 0).toList();
    if (validPrices.isEmpty) return null;
    validPrices.sort((a, b) => a.value.compareTo(b.value));
    return validPrices.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('智慧購物助手'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_userName != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '👋 歡迎回來，$_userName！',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 12),

            /// ✅ 搜尋欄
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

            /// ✅ 有搜尋結果就顯示列表，否則顯示主功能
            if (searchResults.isNotEmpty)
              Expanded(
                child: Column(
                  children: [
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
                    const SizedBox(height: 10),

                    /// ✅ 顯示搜尋結果（商品名稱 + 最低價）
                    Expanded(
                      child: ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final product = searchResults[index];
                          final lowest = _findLowestPrice(product);
                          final imageUrl = lowest != null ? product.images[lowest.key] ?? '' : '';

                          return Card(
                            elevation: 2,
                            child: ListTile(
                              leading: imageUrl.isNotEmpty
                                  ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                                  : Icon(Icons.image_not_supported),
                              title: Text(product.name),
                              subtitle: lowest != null
                                  ? Text("最低價：\$${lowest.value.toStringAsFixed(0)}（${lowest.key}）")
                                  : Text("點我查看比價"),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ComparePage(barcode: product.name),
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
              /// ✅ 主功能快速入口
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
                      _functionCard(Icons.store, '商家帳號', BusinessAccountPage(), Colors.teal),
                    ]),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ✅ 標題區塊樣式
  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  /// ✅ 卡片列排版
  Widget _functionRow(List<Widget> cards) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: cards,
      );

  /// ✅ 功能卡片樣式
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

















