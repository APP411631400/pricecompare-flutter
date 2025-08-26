// 📄 lib/screens/price_report_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/scan_history.dart';
import 'package:price_compare_app/services/user_service.dart';

import '../services/local_account_store.dart';


class PriceReportPage extends StatefulWidget {
  @override
  _PriceReportPageState createState() => _PriceReportPageState();
}

class _PriceReportPageState extends State<PriceReportPage> {
  String? keyword;
  File? imageFile;
  final _priceController = TextEditingController();
  bool _isSaving = false;

  // ✅ 新增：定位與附近店家清單
  LatLng? _currentPosition;
  List<String> _nearbyStores = [];
  String? _selectedStore;

  @override
  void initState() {
    super.initState();
    _fetchNearbyStores(); // ⬅️ 一開始就抓附近店家
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null) {
      keyword = args['keyword'] as String;
      imageFile = args['imageFile'] as File;
    }
  }

  // ✅ 壓縮圖片
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

  // ✅ 抓取目前位置與附近店家（最多 5 筆）
  Future<void> _fetchNearbyStores() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      _currentPosition = LatLng(pos.latitude, pos.longitude);

      const apiKey = 'AIzaSyD7anVSRtxnFU9XimXMfLOmrqc0mEnZxfY'; // ❗請替換成你自己的 Google Places API 金鑰
      final url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          '&rankby=distance'
          '&type=store'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'OK') {
        final stores = (data['results'] as List)
            .take(6)
            .map((e) => e['name'].toString())
            .toList();

        setState(() {
          _nearbyStores = stores;
          if (_nearbyStores.isNotEmpty) {
            _selectedStore = _nearbyStores[0];
          }
        });
      } else {
        print('❌ Google Places API 錯誤：${data['status']}');
      }
    } catch (e) {
      print('❌ 抓附近店家錯誤：$e');
    }
  }

  // ✅ 儲存價格回報
  Future<void> _saveRecord() async {
    final store = _selectedStore ?? '';
    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText);
    

    if (store.isEmpty || price == null || price <= 0 || keyword == null || imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入有效價格與選擇店家')),
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
      final userId = await UserService.getCurrentUserId();


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
          'userId': userId,
          'imageBase64': base64Image,
          'captureTime': captureTime.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

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
          userId: userId,
        );



        await LocalAccountStore.addPriceReport(
          productName: keyword!,
          storeName: store,
          price: price,
          lat: position.latitude,
          lng: position.longitude,
          photoUrl: compressed.path,
        );




        final index = scanHistory.indexWhere((r) =>
            r.timestamp.toIso8601String().substring(0, 19) ==
            updatedRecord.timestamp.toIso8601String().substring(0, 19));

        if (index != -1) {
          scanHistory[index] = updatedRecord;
        } else {
          scanHistory.add(updatedRecord);
        }

        await saveScanHistory();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 已成功回報價格')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 上傳失敗：${response.body}')),
        );
      }
    } catch (e) {
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

              // ✅ 改成下拉式選單顯示附近店家
              DropdownButtonFormField<String>(
                value: _selectedStore,
                items: _nearbyStores.map((store) {
                  return DropdownMenuItem(
                    value: store,
                    child: Text(store),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedStore = value);
                },
                decoration: const InputDecoration(labelText: '選擇附近店家'),
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







