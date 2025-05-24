import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// ✅ ScanRecord：代表一筆掃碼或拍照的商品記錄資料
class ScanRecord {
  int? id;
  String barcode;               // 商品條碼（若為拍照可為空）
  String name;                  // 商品名稱（AI 辨識或條碼比對結果）
  DateTime timestamp;          // 拍照或掃碼的時間（由後端回傳更準確）
  double? latitude;            // 使用者拍照當下的緯度（可為 null）
  double? longitude;           // 使用者拍照當下的經度（可為 null）
  double? price;               // 使用者輸入的價格（可為 null）
  String? store;               // 使用者輸入的店名（可為 null）
  String? imagePath;           // 圖片檔案的本機路徑（可為 null）

  /// ✅ 建構函式
  ScanRecord({
    this.id,
    required this.barcode,
    required this.name,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.price,
    this.store,
    this.imagePath,
  });

  /// ✅ 將資料轉為 JSON 格式（儲存至 SharedPreferences 或送給後端）
  Map<String, dynamic> toJson() => {
        'id': id,
        'barcode': barcode,
        'name': name,
        'timestamp': timestamp.toIso8601String(),  // ✅ 用標準 ISO 格式儲存時間
        'latitude': latitude,
        'longitude': longitude,
        'price': price,
        'store': store,
        'imagePath': imagePath,
      };

  /// ✅ 從 JSON 建立一筆 ScanRecord（例如從 SharedPreferences 載入）
  static ScanRecord fromJson(Map<String, dynamic> json) => ScanRecord(
        id: json['id'],
        barcode: json['barcode'] ?? '',
        name: json['name'] ?? '',
        timestamp: DateTime.parse(json['timestamp']),
        latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
        longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
        price: json['price'] != null ? (json['price'] as num).toDouble() : null,
        store: json['store'],
        imagePath: json['imagePath'],
      );
}

/// ✅ 儲存於記憶體的掃描紀錄清單（供 UI 顯示與操作）
List<ScanRecord> scanHistory = [];

/// ✅ 儲存 scanHistory 清單到 SharedPreferences（轉 JSON 字串陣列）
Future<void> saveScanHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = scanHistory.map((r) => json.encode(r.toJson())).toList();
  await prefs.setStringList('scan_history', jsonList);
}

/// ✅ 從 SharedPreferences 載入掃描紀錄（轉回 List<ScanRecord>）
Future<void> loadScanHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = prefs.getStringList('scan_history') ?? [];
  scanHistory = jsonList.map((j) => ScanRecord.fromJson(json.decode(j))).toList();
}

/// ✅ 刪除指定 index 的紀錄並更新 SharedPreferences
Future<void> deleteScanRecord(int index) async {
  scanHistory.removeAt(index);
  await saveScanHistory();
}





