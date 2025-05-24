// 📄 lib/screens/scan_history_page.dart
import 'dart:io'; // ✅ 處理本地圖片刪除
import 'package:flutter/material.dart';
import '../data/scan_history.dart';       // 📦 掃描與拍照紀錄資料來源
import '../services/store_service.dart';   // ✅ 呼叫 Flask API 刪除資料功能
import 'compare_page.dart';                // 📄 商品比價頁面

/// 📄 ScanHistoryPage：共用的紀錄清單頁面（掃碼或拍照）
/// ✅ 功能說明：
/// 1. 顯示所有使用者的掃碼或拍照紀錄（共用 ScanRecord 結構）
/// 2. 支援排序切換（由新到舊 / 由舊到新）
/// 3. 支援左滑刪除功能（會同步刪除：本地圖片、SharedPreferences、資料庫紀錄）
/// 4. 點擊紀錄會根據「條碼 or 關鍵字」跳轉至 ComparePage 進行商品比價
class ScanHistoryPage extends StatefulWidget {
  const ScanHistoryPage({super.key});

  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  bool sortDesc = true; // ✅ 預設排序：由新到舊

  @override
  Widget build(BuildContext context) {
    // ✅ 排序掃描紀錄清單（避免影響原始 scanHistory）
    final sorted = List<ScanRecord>.from(scanHistory);
    sorted.sort((a, b) =>
        sortDesc ? b.timestamp.compareTo(a.timestamp) : a.timestamp.compareTo(b.timestamp));

    return Scaffold(
      appBar: AppBar(
        title: const Text('掃描 / 拍照紀錄'),
        actions: [
          // 🔄 排序切換按鈕（由新到舊 / 由舊到新）
          IconButton(
            icon: Icon(sortDesc ? Icons.arrow_downward : Icons.arrow_upward),
            tooltip: '切換排序順序',
            onPressed: () => setState(() => sortDesc = !sortDesc),
          ),
        ],
      ),

      body: sorted.isEmpty
          // 📭 無資料提示
          ? const Center(child: Text('尚無任何掃描或拍照紀錄'))

          // ✅ 顯示掃描紀錄清單（支援刪除與點擊跳轉）
          : ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final record = sorted[index];

                return Dismissible(
                  // ✅ 用主鍵 id 當唯一 key，若為 null 則 fallback 用時間
                  key: ValueKey(record.id ?? record.timestamp.toIso8601String()),
                  direction: DismissDirection.startToEnd, // ✅ 左滑刪除

                  // ✅ 左滑時的紅色背景提示
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),

                  /// ✅ 執行刪除：圖片 + SharedPreferences + 後端 API
                  onDismissed: (_) async {
                    // ✅ 改成用時間（到秒）來找對應的原始紀錄
                  final recordToDelete = record;

                    // ✅ 刪除圖片檔案（若有）
                    if (record.imagePath != null) {
                      final file = File(record.imagePath!);
                      if (await file.exists()) await file.delete();
                    }

                    // ✅ 從本地記憶體移除該紀錄
                    scanHistory.removeWhere((r) =>
                      r.timestamp.toIso8601String().substring(0, 19) ==
                      recordToDelete.timestamp.toIso8601String().substring(0, 19));
                    // ✅ 從後端刪除該紀錄（Flask API）
                    await StoreService().deleteScanRecordFromDatabase(recordToDelete);

                    // ✅ 儲存更新後的本地紀錄
                    await saveScanHistory();

                    // ✅ 更新畫面狀態
                    setState(() {});
                  },

                  // ✅ 每筆紀錄的顯示卡片
                  child: ListTile(
                    leading: const Icon(Icons.qr_code_scanner), // ✅ 左側圖示

                    // ✅ 顯示條碼或拍照文字
                    title: Text(
                      record.barcode.isNotEmpty
                          ? '條碼：${record.barcode}'
                          : '📸 拍照識別結果',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    // ✅ 顯示時間、價格、位置資訊
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('時間：${record.timestamp.toLocal().toString().substring(0, 19)}'),
                        Text('🆔 ID：${record.id}'),
                        if (record.price != null)
                          Text('價格：\$${record.price!.toStringAsFixed(0)}'),
                        if (record.latitude != null && record.longitude != null)
                          Text(
                              '位置：(${record.latitude!.toStringAsFixed(4)}, ${record.longitude!.toStringAsFixed(4)})'),
                      ],
                    ),

                    // ✅ 點擊紀錄：跳轉比價頁 ComparePage（帶入條碼或關鍵字）
                    onTap: () {
                      if (record.barcode.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComparePage(barcode: record.barcode),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComparePage(keyword: record.name),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}






