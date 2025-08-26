// ✅ login_page.dart - 登入頁面（支援：後端帳號 + 模擬註冊 + Google 登入）
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';     // ← 新增：Google + Firebase
import '../services/user_service.dart';    // 你原本的帳密驗證
import 'home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  /// ✅ 原本帳密登入（維持）
  Future<void> _login() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() { _errorMessage = '請輸入帳號與密碼'; _isLoading = false; });
      return;
    }

    try {
      final isValid = await UserService.validateCredentials(email, password);
      if (!mounted) return;
      if (isValid) {
        Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => HomePage()), (_) => false);
      } else {
        setState(() { _errorMessage = '帳號或密碼錯誤'; });
      }
    } catch (e) {
      setState(() { _errorMessage = '登入過程發生錯誤，請稍後再試'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  /// ✅ 新增：Google 登入（最簡流程）
  Future<void> _googleLogin() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final cred = await AuthService.signInWithGoogle(); // 跳 Google 選擇器
      // 可用 cred.user 取 displayName / email / uid
      debugPrint('Google 登入成功：${cred.user?.displayName} (${cred.user?.uid})');
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context, MaterialPageRoute(builder: (_) => HomePage()), (_) => false);
    } catch (e) {
      setState(() { _errorMessage = 'Google 登入失敗：$e'; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('會員登入')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🔐 Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email', prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 16),

              // 🔐 密碼
              TextField(
                controller: _passwordController, obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密碼', prefixIcon: Icon(Icons.lock)),
              ),

              const SizedBox(height: 12),

              // 錯誤訊息
              if (_errorMessage != null)
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),

              const SizedBox(height: 16),

              // 🔘 帳密登入
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: busy ? null : _login,
                  child: busy
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('以帳號密碼登入'),
                ),
              ),

              const SizedBox(height: 12),

              // 分隔線
              Row(children: const [
                Expanded(child: Divider()), SizedBox(width: 8),
                Text('或'), SizedBox(width: 8),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 12),

              // 🟦 Google 登入按鈕
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Image.asset('assets/google_logo.png', width: 20, height: 20,
                    errorBuilder: (_, __, ___) => const Icon(Icons.login)),
                  label: const Text('使用 Google 帳號登入'),
                  onPressed: busy ? null : _googleLogin,
                ),
              ),

              const SizedBox(height: 20),

              // 🆕 註冊（保留）
              TextButton(
                onPressed: () {
                  Navigator.push(context,
                    MaterialPageRoute(builder: (_) => RegisterPage()));
                },
                child: const Text('還沒有帳號？點我註冊',
                    style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}







