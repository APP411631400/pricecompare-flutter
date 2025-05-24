// ✅ barcode_scan_page.dart - 條碼掃描頁面
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // 📷 相機條碼掃描套件
import 'compare_page.dart'; // 📄 掃描完後導向比價頁面
import '../data/scan_history.dart'; // 📦 掃描紀錄資料來源

class BarcodeScanPage extends StatefulWidget {
  @override
  State<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<BarcodeScanPage> {
  // ✅ 控制相機掃描功能
  final MobileScannerController scannerController = MobileScannerController();

  // ✅ 用來儲存是否已經掃到條碼（避免重複觸發）
  String? scannedCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('掃描條碼')),
      body: Column(
        children: [
          // ✅ 條碼掃描區（上方占 4/5 空間）
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: scannerController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final code = barcode.rawValue;

                  if (code != null && scannedCode == null) {
                    // ✅ 第一次掃描到條碼才執行
                    setState(() {
                      scannedCode = code;
                    });

                    // ✅ 新增掃描紀錄，只存條碼與時間，其餘留空
                    scanHistory.add(
                      ScanRecord(
                        barcode: code,
                        name: '', // 掃碼無名稱，留空
                        timestamp: DateTime.now(),
                        latitude: null,
                        longitude: null,
                        price: null,
                        store: null,
                        imagePath: null,
                      ),
                    );

                    // ✅ 停止掃描（避免重複進入）
                    scannerController.stop();

                    // ✅ 跳轉比價頁面（傳入掃描到的條碼）
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ComparePage(barcode: code),
                      ),
                    );

                    break; // ✅ 掃到就跳出 loop
                  }
                }
              },
            ),
          ),

          // ✅ 下方顯示掃描狀態提示（占 1/5 空間）
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                scannedCode == null ? '掃描中...' : '掃描完成，準備跳轉...',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          )
        ],
      ),
    );
  }
}




