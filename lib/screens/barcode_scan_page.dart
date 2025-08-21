// ✅ barcode_scan_page.dart - 改成掃碼後查詢商品名稱再跳轉
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'compare_page.dart';
import '../data/scan_history.dart';

class BarcodeScanPage extends StatefulWidget {
  @override
  State<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<BarcodeScanPage> {
  final MobileScannerController scannerController = MobileScannerController();
  String? scannedCode;
  bool isLoading = false;

  /// ✅ 根據條碼查詢商品名稱（使用 EANData API）
  Future<String?> fetchProductName(String barcode) async {
    final url =
        'https://eandata.com/feed/?v=3&keycode=C42EED7D6885C949&mode=json&find=$barcode&user=your_account';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final product = data['product'];
        final name = product?['attributes']?['product'];
        if (name != null && name.toString().trim().isNotEmpty) {
          return name.toString();
        }
      }
    } catch (e) {
      print('❌ 查詢商品名稱失敗: $e');
    }
    return null; // 沒找到或錯誤
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('掃描條碼')),
      body: Column(
        children: [
          // ✅ 條碼掃描區
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: scannerController,
              onDetect: (capture) async {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final code = barcode.rawValue;

                  if (code != null && scannedCode == null && !isLoading) {
                    setState(() {
                      scannedCode = code;
                      isLoading = true;
                    });

                    scannerController.stop();

                    // ✅ 查詢商品名稱
                    final name = await fetchProductName(code);

                    // ✅ 顯示對話框再跳轉
                    if (context.mounted) {
                      await showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('商品資訊'),
                          content: Text(name != null
                              ? '商品名稱：$name'
                              : '查無商品名稱，將繼續比價'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('確定'),
                            ),
                          ],
                        ),
                      );
                    }

                    // ✅ 加入掃描紀錄
                    scanHistory.add(
                      ScanRecord(
                        barcode: code,
                        name: name ?? '',
                        timestamp: DateTime.now(),
                        latitude: null,
                        longitude: null,
                        price: null,
                        store: null,
                        imagePath: null,
                      ),
                    );

                    // ✅ 導向比價頁面
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ComparePage(
                            barcode: code,
                            keyword: name,
                          ),
                        ),
                      );
                    }

                    break;
                  }
                }
              },
            ),
          ),

          // ✅ 掃描提示
          Expanded(
            flex: 1,
            child: Center(
              child: isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      scannedCode == null ? '掃描中...' : '取得資訊中...',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}





