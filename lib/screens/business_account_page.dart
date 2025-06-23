import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'business_login_page.dart';
import 'home_page.dart'; // 匯入首頁

class BusinessAccountPage extends StatefulWidget {
  const BusinessAccountPage({Key? key}) : super(key: key);

  @override
  State<BusinessAccountPage> createState() => _BusinessAccountPageState();
}

class _BusinessAccountPageState extends State<BusinessAccountPage> {
  String businessEmail = '';
  String storeName = '';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isBusinessLoggedIn') ?? false;

    if (!isLoggedIn) {
      // 如果沒登入，跳回登入頁
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BusinessLoginPage()),
      );
    } else {
      // 如果有登入 → 載入商家資料
      setState(() {
        businessEmail = prefs.getString('businessEmail') ?? '';
        storeName = prefs.getString('storeName') ?? '';
      });
    }
  }

  Future<void> _handleLogout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isBusinessLoggedIn');
    await prefs.remove('businessEmail');
    await prefs.remove('storeName');

    if (!mounted) return;

    // 登出後 → 回首頁
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商家帳號中心'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '登出',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '商家名稱：$storeName',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Email：$businessEmail',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: 導向商品上架頁（未來擴充）
              },
              icon: const Icon(Icons.add_box),
              label: const Text('我要上架商品'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: 導向商家商品管理頁（可擴充）
              },
              icon: const Icon(Icons.list_alt),
              label: const Text('我的商品清單'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




