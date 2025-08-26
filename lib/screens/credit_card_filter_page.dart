import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../services/local_account_store.dart';
import 'saved_cards_page.dart';

/// 📌 資料模型：代表一張信用卡
class CreditCard {
  final int id;         // ✅ 信用卡的唯一識別編號
  final String name;    // ✅ 卡名，例如「Ubear卡」
  final String bank;    // ✅ 發卡銀行名稱，例如「玉山銀行」
  final String promo;   // ✅ 一般優惠資訊

  CreditCard({
    required this.id,
    required this.name,
    required this.bank,
    required this.promo,
  });

  /// ✅ 將從 API 回傳的 JSON 轉為 CreditCard 物件
  factory CreditCard.fromJson(Map<String, dynamic> json) {
    return CreditCard(
      // 🔧 修正型別錯誤：API 回傳的 id 是字串，因此需轉為 int
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['卡名'] ?? '',
      bank: json['銀行名稱'] ?? '',
      promo: json['一般優惠'] ?? '',
    );
  }
}

/// 📱 信用卡篩選頁面（主畫面）
class CreditCardFilterPage extends StatefulWidget {
  @override
  State<CreditCardFilterPage> createState() => _CreditCardFilterPageState();
}

class _CreditCardFilterPageState extends State<CreditCardFilterPage> {
  List<CreditCard> allCards = [];         // ✅ 所有從後端抓回來的卡片資料
  List<CreditCard> filteredCards = [];    // ✅ 被篩選後要顯示的卡片清單
  String selectedBank = '全部銀行';        // ✅ 下拉選單目前選擇的銀行
  List<String> bankOptions = ['全部銀行']; // ✅ 銀行下拉選單的選項

  @override
  void initState() {
    super.initState();
    _loadCreditCards();  // ✅ 初始化時自動載入資料
  }

  /// 🔽 從後端 API 載入信用卡資料
  Future<void> _loadCreditCards() async {
    const apiUrl = 'https://acdb-api.onrender.com/cards'; // ✅ 你部署在 Render 的 API 位置

    try {
      final response = await http.get(Uri.parse(apiUrl)); // 🌐 發送 GET 請求

      if (response.statusCode == 200) {
        // ✅ 成功收到資料，解析 JSON
        final List<dynamic> data = jsonDecode(response.body);
        final cards = data.map((e) => CreditCard.fromJson(e)).toList();

        // 🔍 取得所有銀行選項（用 Set 去除重複）
        final banks = cards.map((e) => e.bank).toSet().toList();

        setState(() {
          allCards = cards;
          bankOptions.addAll(banks);  // 將銀行選項加入下拉選單
          _applyFilters();            // 根據目前銀行進行篩選
        });
      } else {
        print('❌ 錯誤：伺服器回傳狀態碼 ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 無法取得信用卡資料：$e');
    }
  }

  /// 🔽 根據 selectedBank 篩選出要顯示的卡片
  void _applyFilters() {
    setState(() {
      filteredCards = allCards.where((card) {
        return selectedBank == '全部銀行' || card.bank == selectedBank;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('信用卡篩選')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔽 銀行篩選下拉選單
            Row(
              children: [
                const Text('銀行：'),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedBank,
                    isExpanded: true,
                    items: bankOptions
                        .map((bank) => DropdownMenuItem(
                              value: bank,
                              child: Text(bank),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        selectedBank = value;
                        _applyFilters(); // ✅ 當選項改變時，立即重新篩選
                      }
                    },
                  ),
                )
              ],
            ),

            const SizedBox(height: 20),

            // 🔽 顯示過濾後卡片的清單
            Expanded(
              child: ListView.builder(
                itemCount: filteredCards.length,
                itemBuilder: (context, index) {
                  final card = filteredCards[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    /*child: ListTile(
                      leading: Icon(Icons.credit_card),       // ✅ 信用卡圖示
                      title: Text(card.name),                 // ✅ 卡名
                      subtitle: Text('${card.bank}\n${card.promo}'), // ✅ 銀行 + 一般優惠
                    ),
                    */


                    child: ListTile(
                      leading: const Icon(Icons.credit_card),
                      title: Text(card.name),
                      subtitle: Text('${card.bank}\n${card.promo}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: '加入到我的信用卡',
                        onPressed: () async {
                          await LocalAccountStore.addSavedCard(
                            card.id,         // ← 你的卡片唯一ID
                            nickname: card.name,     // ← 先用卡名當暱稱
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已將「${card.name}」加入已儲存的信用卡'),
                              action: SnackBarAction(
                                label: '查看',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const SavedCardsPage()),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),




                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}




