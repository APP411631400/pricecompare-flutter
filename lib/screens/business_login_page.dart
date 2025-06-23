import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'business_account_page.dart';

class BusinessLoginPage extends StatefulWidget {
  const BusinessLoginPage({Key? key}) : super(key: key);

  @override
  State<BusinessLoginPage> createState() => _BusinessLoginPageState();
}

class _BusinessLoginPageState extends State<BusinessLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoggingIn = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商家登入'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密碼'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoggingIn ? null : _handleLogin,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('登入'),
            ),
            const SizedBox(height: 12),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ 處理登入按鈕
  Future<void> _handleLogin() async {
    setState(() {
      _isLoggingIn = true;
      _errorMessage = '';
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    try {
      // ✅ 呼叫後端 API
      var url = Uri.parse('https://acdb-api.onrender.com/api/business/login');  // 改成你的 API 位址
      var response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        // 登入成功
        var jsonResponse = jsonDecode(response.body);
        String storeName = jsonResponse['storeName'] ?? '';

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isBusinessLoggedIn', true);
        await prefs.setString('businessEmail', email);
        await prefs.setString('storeName', storeName);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BusinessAccountPage()),
        );
      } else {
        var errorResponse = jsonDecode(response.body);
        setState(() {
          _errorMessage = errorResponse['error'] ?? '登入失敗';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '伺服器錯誤：$e';
      });
    }

    setState(() {
      _isLoggingIn = false;
    });
  }
}
