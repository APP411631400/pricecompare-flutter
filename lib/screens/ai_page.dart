// ✅ ai_page.dart - AI 智慧推薦頁面
import 'package:flutter/material.dart';
// import '../data/fake_data.dart';
import 'compare_page.dart';

class AIPredictPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI 智慧推薦')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'AI 推薦區塊（預留模型/後端）',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // 🔜 TODO: 未來這裡會根據 AI 推薦結果的條碼跳轉
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ComparePage(barcode: '12345678'), // 先放假的 barcode
                  ),
                );
              },
              child: Text('查看推薦結果'),
            ),
          ],
        ),
      ),
    );
  }
}