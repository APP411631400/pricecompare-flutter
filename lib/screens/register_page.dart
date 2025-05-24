// ✅ register_page.dart - 模擬註冊頁面（寫死儲存假帳密，可改為串接後端）
import 'package:flutter/material.dart';
import '../services/user_service.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController(); // 📌 取得 email 輸入內容
  final TextEditingController _passwordController = TextEditingController(); // 📌 取得 password 輸入內容

  bool _isLoading = false;       // 📌 控制是否顯示載入動畫
  String? _errorMessage;         // 📌 錯誤提示文字（如驗證失敗）

  /// ✅ 模擬註冊流程（預留串接後端）
  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // ✅ 模擬後端註冊成功條件：Email 非空 & 密碼長度 ≥ 6
    if (email.isNotEmpty && password.length >= 6) {
      await UserService.saveMockAccount(email, password); // ✅ 模擬儲存帳密
      await UserService.mockLogin(email); // ✅ 儲存登入狀態

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()), // ✅ 註冊成功跳轉登入頁
          (route) => false,
        );
      }
    } else {
      setState(() {
        _errorMessage = '請輸入有效 Email 並設定密碼長度至少 6 碼';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('模擬註冊')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
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
                labelText: '密碼（至少6碼）',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),

            // ❗ 錯誤提示區塊
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),

            // 🔘 註冊按鈕或轉圈圈
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('註冊'),
            ),
          ],
        ),
      ),
    );
  }
}
