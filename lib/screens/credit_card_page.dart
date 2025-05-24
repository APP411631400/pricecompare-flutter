// lib/screens/credit_card_page.dart
import 'package:flutter/material.dart';

class CreditCardPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('信用卡優惠')),
      body: Center(child: Text('信用卡資料（預留串接後端或 API）')),
    );
  }
}