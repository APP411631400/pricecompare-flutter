// ✅ user_page.dart - 會員中心頁面（優化 + 預留後端）
// ✅ 自動檢查登入狀態，未登入跳轉至登入頁；登出後返回首頁

import 'package:flutter/material.dart';
import 'scan_history_page.dart';
import 'favorites_page.dart';
import 'ai_page.dart';
import 'login_page.dart';
import 'home_page.dart'; // ✅ 登出後返回首頁
import 'credit_card_filter_page.dart'; // ✅ 新增：信用卡篩選頁面
import '../services/user_service.dart';

class UserPage extends StatefulWidget {
  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  String? userEmail; // ✅ 儲存目前登入的使用者 Email

  @override
  void initState() {
    super.initState();
    _checkLogin(); // ✅ 頁面初始化時，檢查使用者是否登入
  }

  /// ✅ 檢查登入狀態，若未登入則導回登入頁；若已登入則顯示 email
  Future<void> _checkLogin() async {
    final isLoggedIn = await UserService.isLoggedIn();
    if (!isLoggedIn) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
        );
      }
    } else {
      final email = await UserService.getUserEmail();
      setState(() {
        userEmail = email;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('會員中心')),
      body: userEmail == null
          ? Center(child: CircularProgressIndicator()) // ✅ 尚未取得 email 前顯示載入動畫
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ✅ 使用者資料卡片
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 35,
                          child: Icon(Icons.person, size: 35),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userEmail ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('已登入', style: TextStyle(color: Colors.grey[600]))
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ✅ 功能清單
                ListTile(
                  leading: Icon(Icons.history),
                  title: Text('查看掃描紀錄'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScanHistoryPage())),
                ),
                ListTile(
                  leading: Icon(Icons.favorite),
                  title: Text('我的收藏'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritesPage())),
                ),
                ListTile(
                  leading: Icon(Icons.credit_card),
                  title: Text('信用卡設定'), // ✅ 新增信用卡設定
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreditCardFilterPage())),
                ),
                ListTile(
                  leading: Icon(Icons.auto_awesome),
                  title: Text('AI 推薦設定'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AIPredictPage())),
                ),

                const Divider(height: 32),

                // ✅ 預留功能
                ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('偏好設定（預留）'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('功能尚未開放')),
                    );
                  },
                ),

                // ✅ 登出功能
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('登出 / 清除資料', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    await UserService.logout(); // ✅ 清除登入資訊
                    if (mounted) {
                      // ✅ 顯示提示訊息 + 返回首頁
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已成功登出')),
                      );
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => HomePage()),
                        (route) => false,
                      );
                    }
                  },
                )
              ],
            ),
    );
  }
}



