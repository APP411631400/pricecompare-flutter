import 'dart:convert';
// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http; // ✅ 載入 http 套件
import '../data/map_data.dart';
import '../utils/cost_calculator.dart';
import '../data/scan_history.dart';
import '../services/store_service.dart';
import 'compare_page.dart';

class MapComparePage extends StatefulWidget {
  const MapComparePage({super.key});

  @override
  State<MapComparePage> createState() => _MapComparePageState();
}

class _MapComparePageState extends State<MapComparePage> {
  GoogleMapController? mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  bool useFakeData = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation().then((_) => _loadAndMarkStores());
  }

  // ✅ 取得使用者當前 GPS 位置
  Future<void> _fetchLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
    final pos = await Geolocator.getCurrentPosition();
    setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
  }

  // ✅ 根據是否為假資料切換資料來源並標記到地圖上
  Future<void> _loadAndMarkStores() async {
    List<Marker> markers = [];

    // ✅ 標記使用者當前位置
    if (_currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: _currentPosition!,
        infoWindow: const InfoWindow(title: '你的位置'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    // ✅ 處理假資料（mapStores）
    if (useFakeData) {
      for (var store in mapStores) {
        double dist = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              store.location.latitude,
              store.location.longitude,
            ) / 1000;

        double total = CostCalculator.calculateTotalCost(
          distanceInKm: dist,
          basePrice: store.price,
        );

        markers.add(Marker(
          markerId: MarkerId(store.name),
          position: store.location,
          infoWindow: InfoWindow(
            title: store.name,
            snippet: '(原價 \$${store.price})\n總價: \$${total.toStringAsFixed(2)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ));
      }
    } else {
      // ✅ 載入資料庫的掃描紀錄資料
      final records = await StoreService().loadScanRecordsFromDatabase();
      for (var record in records) {
        if (record.latitude != null && record.longitude != null) {
          markers.add(Marker(
            markerId: MarkerId('record_${record.id}'),
            position: LatLng(record.latitude!, record.longitude!),
            infoWindow: InfoWindow(
              title: record.name,
              snippet: '價格：\$${record.price?.toStringAsFixed(0) ?? '未知'}\n點擊查看 / 刪除',
              onTap: () => _showRecordDialog(record), // ✅ 點擊顯示對話框
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ));
        }
      }
    }

    setState(() => _markers = markers.toSet());
  }

  // ✅ 顯示標記紀錄對話框（動態從後端載入圖片）
  void _showRecordDialog(ScanRecord record) async {
  String? imageBase64;

  // ✅ 取得圖片
  try {
    final url = Uri.parse("https://acdb-api.onrender.com/image/${record.id}");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      imageBase64 = result['imageBase64'];
    }
  } catch (e) {
    print("❌ 圖片載入失敗：$e");
  }

  // ✅ 顯示主對話框
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(record.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageBase64 != null)
            Image.memory(base64Decode(imageBase64), height: 150, fit: BoxFit.cover)
          else
            const Text("（無圖片）"),
          const SizedBox(height: 10),
          Text('價格：\$${record.price?.toStringAsFixed(0) ?? '未知'}'),
          Text('店家：${record.store}'),
          Text('時間：${record.timestamp.toLocal()}'),
        ],
      ),
      actions: [
        // ✅ 編輯按鈕：打開編輯 Dialog
        TextButton(
          onPressed: () {
            Navigator.pop(context); // 關閉主對話框
            _showEditDialog(record); // ➤ 顯示編輯畫面
          },
          child: const Text('編輯', style: TextStyle(color: Colors.blue)),
        ),
        // ✅ 查看比價
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ComparePage(
                  barcode: record.barcode.isNotEmpty ? record.barcode : null,
                  keyword: record.name.isNotEmpty ? record.name : null,
                ),
              ),
            );
          },
          child: const Text('查看比價'),
        ),
        // ✅ 刪除紀錄
        TextButton(
          onPressed: () async {
            await StoreService().deleteScanRecordFromDatabase(record);
            scanHistory.removeWhere((r) => r.id == record.id);
            await saveScanHistory();
            Navigator.pop(context);
            await _loadAndMarkStores();
          },
          child: const Text('刪除', style: TextStyle(color: Colors.red)),
        ),
        // ✅ 關閉
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('關閉'),
        ),
      ],
    ),
  );
}

void _showEditDialog(ScanRecord record) {
  final nameCtrl = TextEditingController(text: record.name);
  final storeCtrl = TextEditingController(text: record.store);
  final priceCtrl = TextEditingController(text: record.price?.toString() ?? '');

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('編輯回報資料'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '商品名稱')),
          TextField(controller: storeCtrl, decoration: const InputDecoration(labelText: '店家名稱')),
          TextField(
            controller: priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '價格'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: () async {
            final newName = nameCtrl.text.trim();
            final newStore = storeCtrl.text.trim();
            final newPrice = double.tryParse(priceCtrl.text.trim());

            if (newName.isEmpty || newStore.isEmpty || newPrice == null || newPrice <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ 請輸入有效資料')));
              return;
            }

            Navigator.pop(context); // 關閉 Dialog

            // ✅ 呼叫後端 API 更新
            final res = await http.post(
              Uri.parse("https://acdb-api.onrender.com/update"),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                "id": record.id,
                "name": newName,
                "store": newStore,
                "price": newPrice,
              }),
            );

            if (res.statusCode == 200 && jsonDecode(res.body)['status'] == 'success') {
              setState(() {
                record.name = newName;
                record.store = newStore;
                record.price = newPrice;
              });
              await _loadAndMarkStores();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 更新成功')));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ 更新失敗')));
            }
          },
          child: const Text('儲存'),
        ),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('地圖比價（${useFakeData ? "假資料" : "資料庫"}）'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: '切換資料來源',
            onPressed: () async {
              setState(() => useFakeData = !useFakeData);
              await _loadAndMarkStores();
            },
          )
        ],
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: (controller) => mapController = controller,
              initialCameraPosition: CameraPosition(target: _currentPosition!, zoom: 14),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
    );
  }
}


















