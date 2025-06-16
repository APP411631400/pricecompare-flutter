// ✅ login_page.dart - 登入頁面（支援後端帳號 + 模擬註冊帳號登入）
import 'package:flutter/material.dart';
import 'home_page.dart';               // 登入成功後跳轉至主畫面
import '../services/user_service.dart'; // 使用者登入邏輯處理
import 'register_page.dart';          // 可跳轉至註冊頁


class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}


class _LoginPageState extends State<LoginPage> {
  // 📌 控制使用者輸入 Email 與密碼
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();


  bool _isLoading = false;   // 📌 控制登入按鈕轉圈圈狀態
  String? _errorMessage;     // 📌 顯示錯誤訊息（如帳密錯誤）


  /// ✅ 登入流程（支援模擬帳號 + 資料庫帳號）
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });


    final email = _emailController.text.trim();
    final password = _passwordController.text;


    // ✅ 基本輸入欄位檢查
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = '請輸入帳號與密碼';
        _isLoading = false;
      });
      return;
    }


    try {
      // ✅ 呼叫 UserService 驗證帳號（可能是模擬或後端）
      final isValid = await UserService.validateCredentials(email, password);


      if (isValid) {
        // ✅ 登入成功 → 跳轉首頁並移除返回堆疊
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
          (route) => false,
        );
      } else {
        // ❌ 登入失敗（帳密錯）
        setState(() {
          _errorMessage = '帳號或密碼錯誤';
        });
      }
    } catch (e) {
      // ❌ 發生錯誤（例如 API 錯誤或無網路）
      setState(() {
        _errorMessage = '登入過程發生錯誤，請稍後再試';
      });
    } finally {
      setState(() {
        _isLoading = false; // 停止載入動畫
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('會員登入')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔐 Email 輸入欄位
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),


            // 🔐 密碼輸入欄位
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '密碼',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),


            // ❗ 錯誤提示區塊（如果帳密錯誤或 API 失敗）
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),


            // 🔘 登入按鈕（點擊觸發登入流程）
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('登入'),
            ),


            const SizedBox(height: 20),


            // 🆕 尚未註冊的提示 + 註冊頁連結按鈕
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RegisterPage()),
                );
              },
              child: const Text(
                '還沒有帳號？點我註冊',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}






