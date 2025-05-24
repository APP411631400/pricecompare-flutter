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

    // ✅ 1. 請求圖片（從後端 /image/<id>）
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

    // ✅ 2. 顯示 AlertDialog，包含圖片、價格與時間
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
            Text('時間：${record.timestamp.toLocal()}'),
          ],
        ),
        actions: [
          // ✅ 刪除紀錄
          TextButton(
            onPressed: () async {
              await StoreService().deleteScanRecordFromDatabase(record);
              scanHistory.removeWhere((r) => r.id == record.id);
              await saveScanHistory();
              Navigator.pop(context);
              await _loadAndMarkStores();
            },
            child: const Text('刪除紀錄', style: TextStyle(color: Colors.red)),
          ),
          // ✅ 前往比價頁
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
          // ✅ 關閉對話框
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
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


















