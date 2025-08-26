// user_page.dart — 會員中心（可辨識 Google 登入）
// 依賴：google_sign_in / shared_preferences（間接 via UserService）
// 頁面：ProfileEditPage / FavoritesPage / ScanHistoryPage / SavedCardsPage / PriceReportsPage / LoginPage / HomePage

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart'; // 🟡 新增：Google Sign-In

import 'scan_history_page.dart';
import 'favorites_page.dart';
import 'saved_cards_page.dart';
import 'price_reports_page.dart';
import 'profile_edit_page.dart';
import 'login_page.dart';
import 'home_page.dart';

import '../services/user_service.dart';
import '../services/local_account_store.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});
  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  // ===== 使用者基本狀態 =====
  String? _email;
  bool _loading = true;
  String _authProvider = 'local'; // 'google' | 'local'

  // ===== Google Sign-In 物件（只取 email）=====
  final GoogleSignIn _gsi = GoogleSignIn(scopes: const ['email']);

  // 五大項中的 4 個會有數量徽章（個人資料不用）
  int _historyCount = 0;
  int _favCount = 0;
  int _cardCount = 0;
  int _reportCount = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// 初始化：
  /// 1) 檢查本地是否登入（你原本的假登入/一般登入）
  /// 2) 嘗試 Google 靜默登入（若曾授權過，不會跳出 Google 視窗）
  /// 3) 兩者擇一成功即視為登入；優先以 Google 身份覆蓋 email 與 provider
  Future<void> _bootstrap() async {
    // 先看你原本的 UserService 狀態（local）
    bool localLoggedIn = await UserService.isLoggedIn();

    // 嘗試讀本地 email（暫存；若後面 Google 成功會覆蓋）
    String? email = await UserService.getUserEmail();

    // 檢查 Google 當前使用者（app 重新啟動時 currentUser 可能為 null，需要 signInSilently）
    bool googleLoggedIn = false;
    try {
      if (_gsi.currentUser != null) {
        googleLoggedIn = true;
        email = _gsi.currentUser!.email;
      } else {
        // 若沒有 currentUser，嘗試靜默登入（成功就拿到帳號）
        final acc = await _gsi.signInSilently();
        if (acc != null) {
          googleLoggedIn = true;
          email = acc.email;
        }
      }
    } catch (_) {
      // 靜默登入失敗不影響本地流程
    }

    // 若兩者都未登入，導回 LoginPage
    if (!localLoggedIn && !googleLoggedIn) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
      return;
    }

    // 有登入→決定 provider 與 email（Google 優先）
    _email = email ?? '';
    _authProvider = googleLoggedIn ? 'google' : 'local';

    // 載入徽章數量
    await _loadCounts();

    if (!mounted) return;
    setState(() => _loading = false);
  }

  /// 抓取各清單數量（本機版：直接取 List 長度）
  Future<void> _loadCounts() async {
    //final history = await LocalAccountStore.getHistory();
    //final favs    = await LocalAccountStore.getFavorites();
    final cards   = await LocalAccountStore.getSavedCards();
    final reports = await LocalAccountStore.getPriceReports();

    setState(() {
      //_historyCount = history.length;
      //_favCount     = favs.length;
      _cardCount    = cards.length;
      _reportCount  = reports.length;
    });
  }

  /// 進子頁→返回後刷新徽章
  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = (_authProvider == 'google') ? '已登入（Google）' : '已登入';

    return Scaffold(
      appBar: AppBar(title: const Text('會員中心')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 個人資料卡（點擊可編輯個資）
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(radius: 26, child: Icon(Icons.person, size: 28)),
                    title: Text(_email ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    subtitle: Text(subtitle), // 🟡 這裡會顯示 Google/Local
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _go(const ProfileEditPage()),
                  ),
                ),
                const SizedBox(height: 16),

                // 我的功能
                _entry(
                  icon: Icons.favorite,
                  title: '我的收藏',
                  badge: _favCount,
                  onTap: () => _go(const FavoritesPage()),
                ),
                _entry(
                  icon: Icons.history,
                  title: '瀏覽歷史',
                  badge: _historyCount,
                  onTap: () => _go(const ScanHistoryPage()),
                ),
                _entry(
                  icon: Icons.credit_card,
                  title: '已儲存的信用卡',
                  badge: _cardCount,
                  onTap: () => _go(const SavedCardsPage()),
                ),
                _entry(
                  icon: Icons.local_offer,
                  title: '我的價格回報紀錄',
                  badge: _reportCount,
                  onTap: () => _go(const PriceReportsPage()),
                ),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // 登出（會同時處理 Google 與本地旗標）
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('登出 / 清除資料', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      // 🟡 先嘗試 Google 登出（若未登入會被忽略）
                      try {
                        await _gsi.disconnect(); // 解除授權（可選，但建議做）
                      } catch (_) {}
                      try {
                        await _gsi.signOut();
                      } catch (_) {}

                      // 🟡 呼叫你原本的登出（清除本地 logged_in 等）
                      await UserService.logout();

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已成功登出')));
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => HomePage()),
                        (route) => false,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  /// 單一入口（含徽章）
  Widget _entry({
    required IconData icon,
    required String title,
    int? badge,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((badge ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${badge ?? 0}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}





