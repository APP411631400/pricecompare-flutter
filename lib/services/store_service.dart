import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // ✅ 圖片壓縮套件
import 'package:http/http.dart' as http;
import '../data/scan_history.dart'; // ✅ 自訂的掃描紀錄資料模型


class StoreService {
  /// ✅ 上傳一筆掃描紀錄至後端 Flask API
  Future<void> addScanRecordToDatabase(ScanRecord record) async {
    try {
      // ✅ 壓縮圖片後轉換成 base64 字串（若有圖片）
      String? imageBase64;
      if (record.imagePath != null) {
        final file = File(record.imagePath!);
        final compressed = await _compressImage(file);
        final bytes = await compressed.readAsBytes();
        imageBase64 = base64Encode(bytes);
      }


      // ✅ 組成要送出的 JSON 資料（包含 captureTime）
      final data = {
        "name": record.name,
        "price": record.price,
        "latitude": record.latitude,
        "longitude": record.longitude,
        "store": record.store ?? "APP回報",
        "barcode": record.barcode,
        "userId": "guest",
        "imageBase64": imageBase64,
        "captureTime": record.timestamp.toIso8601String(),
      };


      final url = Uri.parse("https://acdb-api.onrender.com/upload");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );


      // ✅ 後端成功回傳時儲存 id 與時間
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
      if (result["timestamp"] != null && result["id"] != null) {
      // ✅ 直接更新原物件（這個才會在畫面上傳遞下去）
        record.id = result["id"];
        record.timestamp = DateTime.parse(result["timestamp"]);

    // ✅ 強制用 timestamp 移除舊的（避免重複）
      scanHistory.removeWhere((r) =>
      r.timestamp.toIso8601String().substring(0, 19) ==
      record.timestamp.toIso8601String().substring(0, 19));

    // ✅ 重新加入更新後的 record（有 id）
      scanHistory.add(record);

      await saveScanHistory();
    }
  }



      print("📤 上傳狀態：${response.statusCode}");
      print("📤 上傳結果：${response.body}");
    } catch (e) {
      print('❌ 上傳紀錄失敗：$e');
    }
  }


  /// ✅ 刪除一筆紀錄（根據唯一 id）
  Future<void> deleteScanRecordFromDatabase(ScanRecord record) async {
    try {
      if (record.id == null) {
        print("⚠️ 無法刪除：record.id 為 null");
        return;
      }


      final url = Uri.parse("https://acdb-api.onrender.com/delete");


      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "id": record.id,
        }),
      );


      print("🗑️ 刪除狀態：${response.statusCode}");
      print("🗑️ 刪除結果：${response.body}");
    } catch (e) {
      print('❌ 刪除紀錄失敗：$e');
    }
  }


  /// ✅ 從後端讀取所有回報資料（不包含圖片）
  Future<List<ScanRecord>> loadScanRecordsFromDatabase() async {
    final List<ScanRecord> records = [];


    try {
      final url = Uri.parse("https://acdb-api.onrender.com/records");
      final response = await http.get(url);


      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        for (final row in jsonData) {
          final gps = row['座標'] ?? "0,0";
          final parts = gps.split(',');


          records.add(ScanRecord(
            id: row['id'],
            name: row['商品名稱'] ?? '',
            barcode: row['條碼'] ?? '',
            price: (row['價格'] ?? 0).toDouble(),
            timestamp: DateTime.tryParse(row['時間']) ?? DateTime.now(),
            latitude: double.tryParse(parts[0]) ?? 0,
            longitude: double.tryParse(parts[1]) ?? 0,
            store: row['來源'] ?? "API",
            imagePath: null, // 圖片尚未還原
          ));
        }
      } else {
        print("⚠️ 載入失敗：${response.statusCode}");
      }
    } catch (e) {
      print("❌ 載入資料錯誤：$e");
    }


    return records;
  }


  /// ✅ 圖片壓縮（節省上傳大小）
  Future<File> _compressImage(File file) async {
    final dir = await Directory.systemTemp.createTemp();
    final targetPath = '${dir.path}/compressed.jpg';


    final xfile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 60,
      format: CompressFormat.jpeg,
    );


    return xfile != null ? File(xfile.path) : file;
  }
}



















