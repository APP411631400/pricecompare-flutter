// ✅ ai_page.dart - AI 智慧推薦頁面
import 'package:flutter/material.dart';
import '../data/fake_data.dart';
import 'compare_page.dart';

class AIPredictPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ✅ 模擬推薦的商品清單（直接拿假資料）
    // TODO: 改為從後端 API 取得推薦商品清單
    final recommended = fakeProducts;

    return Scaffold(
      appBar: AppBar(title: Text('AI 智慧推薦')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: recommended.length,
        itemBuilder: (context, index) {
          final product = recommended[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: Icon(Icons.lightbulb, color: Colors.teal),
              title: Text(product.name),
              subtitle: Text('最低價：\$${product.prices.map((p) => p.price).reduce((a, b) => a < b ? a : b)}'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ComparePage(barcode: product.barcode)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}