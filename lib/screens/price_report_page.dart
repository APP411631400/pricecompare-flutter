// 📄 lib/screens/price_report_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import '../data/scan_history.dart';

class PriceReportPage extends StatefulWidget {
  @override
  _PriceReportPageState createState() => _PriceReportPageState();
}

class _PriceReportPageState extends State<PriceReportPage> {
  String? keyword;
  File? imageFile;
  final _storeController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null) {
      keyword = args['keyword'] as String;
      imageFile = args['imageFile'] as File;
    }
  }

  Future<File> _compressImage(File file) async {
    final dir = await Directory.systemTemp.createTemp();
    final targetPath = '${dir.path}/compressed.jpg';
    final xfile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 85,
    );
    return xfile != null ? File(xfile.path) : file;
  }

  Future<void> _saveRecord() async {
    final store = _storeController.text.trim();
    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText);

    if (store.isEmpty || price == null || price <= 0 || keyword == null || imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入有效價格與店名')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final position = await Geolocator.getCurrentPosition();
      final compressed = await _compressImage(imageFile!);
      final imageBytes = await compressed.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final captureTime = DateTime.now();

      // ✅ 傳送至後端 API
      final response = await http.post(
        Uri.parse('https://acdb-api.onrender.com/upload'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': keyword,
          'price': price,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'store': store,
          'barcode': '',
          'userId': 'guest',
          'imageBase64': base64Image,
          'captureTime': captureTime.toIso8601String(), // ✅ 傳送拍照時間
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        // ✅ 儲存 API 回傳的完整資料
        final updatedRecord = ScanRecord(
          id: result['id'],
          name: keyword!,
          price: price,
          latitude: position.latitude,
          longitude: position.longitude,
          barcode: '',
          store: store,
          imagePath: compressed.path,
          timestamp: DateTime.parse(result['timestamp']),
        );
        
        print("✅ 後端回傳的 id：${result['id']}");
        print("✅ updatedRecord.id：${updatedRecord.id}");

        // ✅ 嘗試找出之前本地已加入但沒 id 的舊紀錄（比對時間只比到秒）
        final index = scanHistory.indexWhere((r) =>
          r.timestamp.toIso8601String().substring(0, 19) ==
          updatedRecord.timestamp.toIso8601String().substring(0, 19));

        if (index != -1) {
          scanHistory[index] = updatedRecord; // ✅ 替換掉舊的
        } else {
          scanHistory.add(updatedRecord); // ✅ 如果找不到就直接加入
        }

          await saveScanHistory(); // ✅ 儲存更新後的清單
          
        print("✅ 最終 scanHistory 最後一筆 id：${scanHistory.last.id}");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 已成功回報價格')),
        );
        Navigator.pop(context);
      } else {
        print('❌ API 回應錯誤：${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 上傳失敗：${response.body}')),
        );
      }
    } catch (e) {
      print('❌ 儲存發生錯誤：$e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ 儲存失敗，請稍後再試')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('價格回報')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageFile != null) ...[
                const Text('商品圖片：'),
                const SizedBox(height: 8),
                Image.file(imageFile!, height: 200),
                const SizedBox(height: 16),
              ],
              if (keyword != null) ...[
                Text('商品名稱：$keyword',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '輸入價格 (NT\$)'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _storeController,
                decoration: const InputDecoration(labelText: '輸入店名'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveRecord,
                  icon: const Icon(Icons.save),
                  label: const Text('儲存價格回報'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}





