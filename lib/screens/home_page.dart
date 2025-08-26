import 'package:flutter/material.dart';
import 'barcode_scan_page.dart';
import 'scan_history_page.dart';
import 'map_compare_page.dart';
import 'recommend_page.dart';
import 'credit_card_page.dart';
import 'compare_page.dart';
//import 'ai_page.dart';
import 'user_page.dart';
import 'take_photo_page.dart';
import 'business_account_page.dart';

import '../services/product_service.dart' as ps;
import '../services/user_service.dart';

import 'login_page.dart';      // ← 你的登入頁
import 'register_page.dart';   // ← 若沒有註冊頁可先移除

import 'package:google_sign_in/google_sign_in.dart'; // ★ 新增


class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  List<ps.Product> searchResults = [];

  String? _userName;

  bool _loggedIn = false; // ✅ 登入狀態
  final GoogleSignIn _gsi = GoogleSignIn(scopes: const ['email']); // ★ 新增：只拿 email


  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadUserName();
    _loadUser(); // 一進來就同步登入狀態
  }


  /// ✅ 從 SharedPreferences 取得使用者名稱（邏輯保留）
  void _loadUserName() async {
    final name = await UserService.getUserName();
    setState(() {
      _userName = name ?? '使用者';
    });
  }

  /// ✅ 載入使用者顯示資訊與登入狀態（保留原本 + 兼容 Google）
Future<void> _loadUser() async {
  // A) 你原本的本地邏輯（完全保留）
  final name = await UserService.getUserName();
  final isLogin = await UserService.isLoggedIn().catchError((_) => false);

  // B) 追加：偵測 Google（先看 currentUser，沒有再靜默登入）
  GoogleSignInAccount? acc = _gsi.currentUser;
  if (acc == null) {
    try {
      acc = await _gsi.signInSilently(); // 曾授權過就會直接成功
    } catch (_) {
      // 靜默失敗不影響原本登入流程
    }
  }
  final bool googleLogin = acc != null;

  // C) 決策：Google 優先當作顯示名稱；登入狀態為「本地 or Google 任何一邊成功」
  setState(() {
    _loggedIn = (isLogin == true) || googleLogin || (name != null && name.isNotEmpty);

    if (googleLogin) {
      // 用 Google 的名稱（沒有就用 email 前半段）
      _userName = acc!.displayName ?? acc.email.split('@').first;
    } else {
      // 沿用你原本的名稱邏輯
      _userName = name;
    }
  });
}


  /// ✅ 呼叫後端搜尋 API（邏輯保留）
  Future<void> _search(String query) async {
    final results = await ps.ProductService.search(query);
    setState(() {
      searchResults = results;
    });

    if (results.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('找不到商品'),
          content: const Text('請確認輸入是否正確，或稍後再試'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('確定')),
          ],
        ),
      );
    }
  }

  /// ✅ 清除搜尋欄與結果（邏輯保留）
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      searchResults.clear();
    });
  }

  /// ✅ 找出最低價與平台（邏輯保留）
  MapEntry<String, double>? _findLowestPrice(ps.Product product) {
    final validPrices = product.prices.entries.where((e) => e.value > 0).toList();
    if (validPrices.isEmpty) return null;
    validPrices.sort((a, b) => a.value.compareTo(b.value));
    return validPrices.first;
  }


  // ────────────────────── 登入/帳戶：公用方法 ──────────────────────

  /// 1) 確保已登入；未登入就導 LoginPage；成功後回傳 true
  /// 1) 確保已登入；未登入就導 LoginPage；成功後回傳 true（加入 Google 檢查）
Future<bool> _ensureLogin() async {
  // A. 先用你原本的本地判斷
  final ok = await UserService.isLoggedIn().catchError((_) => false);
  if (ok == true) return true;

  // B. 追加：Google 判斷（currentUser -> signInSilently）
  GoogleSignInAccount? acc = _gsi.currentUser;
  if (acc == null) {
    try {
      acc = await _gsi.signInSilently();
    } catch (_) {/* 忽略錯誤 */}
  }
  if (acc != null) return true; // 已是 Google 登入，不用再去 LoginPage

  // C. 真的沒登入才導到你的 LoginPage
  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => LoginPage()),
  );

  if (result == true) {
    await _loadUser(); // 回來後刷新首頁顯示
    return true;
  }
  return false;
}

  /// 2) 開啟會員中心（若未登入會先進登入）
  Future<void> _openUserCenter() async {
    if (await _ensureLogin()) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => UserPage()));
      await _loadUser(); // 例如改了暱稱，回來刷新
    }
  }

  /// 3) 右上角帳戶卡（非置中）
  void _showAccountPanel() {
    final name = _userName ?? '用戶';
    final initial = name.isNotEmpty ? name.characters.first : '用';
    final top = MediaQuery.of(context).padding.top + kToolbarHeight + 6;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'account',
      barrierColor: Colors.transparent, // 不要暗幕，像網頁 popover
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, __, ___) {
        return Stack(
          children: [
            Positioned.fill(child: GestureDetector(onTap: () => Navigator.pop(context))),
            Positioned(
              right: 12,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0x14000000)),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFFE5E7EB),
                            child: Text(initial, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: const Text('會員資料'),
                        onTap: () {
                          Navigator.pop(context);
                          _openUserCenter();
                        },
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.tune),
                        title: const Text('偏好設定'),
                        onTap: () {
                          Navigator.pop(context);
                          _openUserCenter(); // 先共用 UserPage；日後可換偏好頁
                        },
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: _logout,
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xff8dd8f2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          child: const Text('登出'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 4) 登出：關卡片、清狀態、提示
  /// 4) 登出：關卡片、清狀態、提示（追加 Google 登出）
  Future<void> _logout() async {
    Navigator.pop(context); // 關掉彈出的卡

    // ★ 新增：若有 Google 登入，一併登出（忽略錯誤）
    try { await _gsi.disconnect(); } catch (_) {}
    try { await _gsi.signOut(); } catch (_) {}

    // 仍保留你原本的登出流程（清 prefs: token/name/isLoggedIn...）
    await UserService.logout();

    setState(() {
      _loggedIn = false;
      _userName = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已登出')));
  }



  // ────────────────────── UI ──────────────────────
  


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // ───────── AppBar：白底、左上☰、右上登入/註冊 ─────────
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            tooltip: '選單',
          ),
        ),
        centerTitle: false,
        title: const SizedBox.shrink(), // 中央不放標題，改在內容區置中大標
        actions: [
          if (!_loggedIn) ...[
            // 未登入：登入 / 註冊
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: TextButton(
                onPressed: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => LoginPage()),
                  );
                  if (ok == true) await _loadUser(); // 登入成功回來 → 刷新 → 隱藏按鈕
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xff8dd8f2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('登入'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: OutlinedButton(
                onPressed: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => RegisterPage()),
                  );
                  if (ok == true) await _loadUser(); // 註冊成功一樣刷新
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.black26),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('註冊'),
              ),
            ),
          ] else ...[
            // ✅ 已登入：只顯示黑色人像，點了叫出你現有的右上角卡片
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.person, color: Colors.black87, size: 26),
                tooltip: '帳戶',
                onPressed: _showAccountPanel, // 你貼的「右上角帳戶卡」方法
              ),
            ),
          ],
        ]


      ),


      // 可放 Drawer（不影響現有功能）
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xff8dd8f2)),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text('功能選單',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),

            // 比價功能
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('比價功能', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.orange),
              title: const Text('掃描紀錄'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScanHistoryPage())),
            ),

            const Divider(height: 16),

            // 推薦與優惠
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('推薦與優惠', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
            ),
            ListTile(
              leading: const Icon(Icons.recommend, color: Colors.purple),
              title: const Text('推薦商品'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecommendPage())),
            ),
            ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.redAccent),
              title: const Text('信用卡優惠'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreditCardPage())),
            ),

            const Divider(height: 16),

            // 帳戶管理
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('帳戶管理', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.indigo),
              title: const Text('會員中心'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserPage())),
            ),
            ListTile(
              leading: const Icon(Icons.store, color: Colors.teal),
              title: const Text('商家帳號'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessAccountPage())),
            ),

            const Divider(height: 16),

            // 其他（可保留你的靜態頁）
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('關於我們'),
              onTap: () => Navigator.pop(context), // TODO: AboutPage()
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('聯絡我們'),
              onTap: () => Navigator.pop(context), // TODO: ContactPage()
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('回首頁'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),


      // ───────── 內容：大標題＋膠囊搜尋列 ─────────
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // 歡迎詞（保留）
              if (_userName != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '👋 歡迎回來，$_userName！',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),

              const SizedBox(height: 20),

              // 大標題（黑粗體、置中）
              Text(
                '智慧購物助手',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              // 搜尋膠囊（⚠️ 僅換外觀，不改你的搜尋邏輯）
              Container(
                constraints: const BoxConstraints(maxWidth: 820),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xffe3e4e6), // 淺灰
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: const [
                    BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _search, // ← 原本邏輯
                        decoration: const InputDecoration(
                          hintText: '今天想買點什麼？',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _search(_searchController.text), // ← 原本邏輯
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff8dd8f2),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('搜尋'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 下方區域：有結果就顯示清單；沒有就顯示「快速動作 + 更多功能」 ──
              if (searchResults.isNotEmpty)
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("搜尋結果：${_searchController.text}",
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.clear),
                            label: const Text("清除搜尋"),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final product = searchResults[index];
                            final lowest = _findLowestPrice(product);
                            final imageUrl = lowest != null ? product.images[lowest.key] ?? '' : '';

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ComparePage(barcode: product.name)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start, // ← 改成頂端對齊
                                    children: [
                                      // 左側圖片
                                      Container(
                                        width: 86,
                                        height: 86,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF4F5F7),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: imageUrl.isNotEmpty
                                            ? Image.network(imageUrl, fit: BoxFit.cover)
                                            : const Center(child: Icon(Icons.image_not_supported)),
                                      ),

                                      const SizedBox(width: 12),

                                      // 中間：商品名稱（多行完整顯示、不要省略號）
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.name,
                                              softWrap: true,
                                              maxLines: 3,                 // 想更完整可調成 4
                                              // 不要 overflow、不要 ellipsis
                                              style: const TextStyle(
                                                fontSize: 16,              // 維持可讀大小（不會縮到太小）
                                                height: 1.25,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              '(AI 描述規格)',
                                              style: TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // 右側價格：固定寬度，避免擠壓中間
                                      SizedBox(
                                        width: 128, // 可依需要調 120~152
                                        child: Builder(
                                          builder: (_) {
                                            final values = product.prices.values
                                                .whereType<double>()
                                                .where((v) => v > 0)
                                                //.cast<double>()
                                                .toList()
                                              ..sort();

                                            String fmt(num v) {
                                              final s = v.toStringAsFixed(0);
                                              return s.replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',');
                                            }

                                            final String priceText;
                                            if (values.isEmpty) {
                                              priceText = '—';
                                            } else if (values.first == values.last) {
                                              priceText = '\$${fmt(values.first)}'; // 單價
                                            } else {
                                              priceText = '\$${fmt(values.first)} - \$${fmt(values.last)}';
                                            }

                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                const Text('價格', style: TextStyle(color: Colors.black54)),
                                                const SizedBox(height: 4),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerRight,
                                                  child: Text(
                                                    priceText,
                                                    maxLines: 1,
                                                    softWrap: false,
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ],
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
                // ✅ 沒有搜尋結果時：快速動作膠囊 + 『更多功能』收合卡
                Expanded(
                  child: ListView(
                    children: [
                      const SizedBox(height: 6),
                      _quickActionsRow(),
                      const SizedBox(height: 20),
                      _moreFunctionsSection(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ 區塊標題（保留）
  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  /// ✅ 卡片列排版（保留）
  Widget _functionRow(List<Widget> cards) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: cards,
      );

  /// ✅ 功能卡片樣式（保留）
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

  // ───────────────────────────────────────────────
  // ✅ 快速動作：膠囊風格（與上方搜尋膠囊同語言）
  // ───────────────────────────────────────────────
  Widget _quickActionsRow() {
    Widget pill({
      required IconData icon,
      required String label,
      required Widget page,
      Color color = const Color(0xff8dd8f2), // 與搜尋按鈕同藍
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,   // 水平間距
      runSpacing: 12, // 換行後上下間距
      children: [
        pill(icon: Icons.qr_code_scanner, label: '掃碼比價', page: BarcodeScanPage()),
        pill(icon: Icons.map, label: '地圖比價', page: MapComparePage(), color: Colors.green),
        pill(icon: Icons.photo_camera, label: '拍照識別', page: TakePhotoPage(), color: Colors.brown),
      ],
    );
  }

  // ───────────────────────────────────────────────
  // ✅ 更多功能：用收合卡把你原本三個區塊包起來（不改內部邏輯）
  // ───────────────────────────────────────────────
  Widget _moreFunctionsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          title: const Text('更多功能', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('推薦與優惠、帳戶管理…'),
          childrenPadding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
          children: [
            _sectionTitle('比價功能'),
            _functionRow([
              _functionCard(Icons.history, '掃描紀錄', ScanHistoryPage(), Colors.orange),
            ]),
            const SizedBox(height: 12),

            _sectionTitle('推薦與優惠'),
            _functionRow([
              _functionCard(Icons.recommend, '推薦商品', RecommendPage(), Colors.purple),
              _functionCard(Icons.credit_card, '信用卡優惠', CreditCardPage(), Colors.redAccent),
            ]),
            const SizedBox(height: 12),

            _sectionTitle('帳戶管理'),
            _functionRow([
              _functionCard(Icons.person, '會員中心', UserPage(), Colors.indigo),
              _functionCard(Icons.store, '商家帳號', BusinessAccountPage(), Colors.teal),
            ]),
          ],
        ),
      ),
    );
  }
}



















