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
import '../services/user_service.dart'; // 依照你的路徑調整

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

          // ✅ 額外標記「Google 地圖附近店家」
      if (_currentPosition != null) {
        try {
          const String apiKey = 'AIzaSyD7anVSRtxnFU9XimXMfLOmrqc0mEnZxfY'; // ❗換成你自己的 API 金鑰
          final String url =
              'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
              '?location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
              '&rankby=distance'
              '&type=store'
              '&key=$apiKey';

          final response = await http.get(Uri.parse(url));
          final data = jsonDecode(response.body);

          if (response.statusCode == 200 && data['status'] == 'OK') {
            for (var place in data['results'].take(6)) {
              final name = place['name'];
              final lat = place['geometry']['location']['lat'];
              final lng = place['geometry']['location']['lng'];

              markers.add(Marker(
                markerId: MarkerId('place_$name'),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(
                  title: name,
                  snippet: 'Google 附近店家',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
              ));
            }
          } else {
            print('❌ Google Places API 錯誤：${data['status']}');
          }
        } catch (e) {
          print('❌ 取得附近店家失敗：$e');
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 20.0),
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
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      // ✅ 編輯按鈕
      TextButton(
        onPressed: () {
          Navigator.pop(context);
          _showEditDialog(record);
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
                fromStore: record.store,
                fromPrice: record.price,
              ),
            ),
          );
        },
        child: const Text('查看比價'),
      ),

      FutureBuilder<String?>(
          future: UserService.getCurrentUserId(), // ✅ 取得目前登入者的真正 ID
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();

            final currentUserId = snapshot.data ?? 'guest'; // ⚠️ 改為你實際用的 guest id
            final recordUserId = record.userId ?? '';

            final isOwner = currentUserId == recordUserId;

            if (!isOwner) return const SizedBox.shrink();

            return TextButton(
              onPressed: () async {
                await StoreService().deleteScanRecordFromDatabase(record);
                scanHistory.removeWhere((r) => r.id == record.id);
                await saveScanHistory();
                Navigator.pop(context);
                await _loadAndMarkStores();
              },
              child: const Text('刪除', style: TextStyle(color: Colors.red)),
            );
          },
        ),


      // ✅ 關閉
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('關閉'),
      ),
    ],
  )
],





    ),
  );
}

// 🔁 新版：附近店家選單 + 保留原有店名邏輯
void _showEditDialog(ScanRecord record) async {
  final nameCtrl = TextEditingController(text: record.name);
  final priceCtrl = TextEditingController(text: record.price?.toString() ?? '');

  String selectedStore = record.store ?? ''; // 👉 初始為原本的店家

  // ✅ 呼叫 Google Places API 抓附近店家（取最多 5 間）
  List<String> nearbyStores = [];
  if (_currentPosition != null) {
    try {
      const String apiKey = 'AIzaSyD7anVSRtxnFU9XimXMfLOmrqc0mEnZxfY'; // ❗請換成你自己的金鑰
      final String url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          '&rankby=distance'
          '&type=store'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'OK') {
        // ✅ 只保留前 5 筆最近的店家名稱
        nearbyStores = (data['results'] as List)
            .take(6)
            .map((e) => e['name'].toString())
            .toList();
      } else {
        print('❌ Places API 錯誤：${data['status']}');
      }
    } catch (e) {
      print('❌ 載入附近店家失敗：$e');
    }
  }

  // ✅ 若原始店家不在清單中，也要補上，避免失去原值
  if (!nearbyStores.contains(selectedStore)) {
    nearbyStores.insert(0, selectedStore); // 放在最上面
  }

  // ✅ 顯示 Dialog（已整合下拉式店家選單）
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('編輯回報資料'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ 商品名稱輸入框
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: '商品名稱'),
          ),

          // ✅ 附近店家選單（Dropdown）
          DropdownButtonFormField<String>(
            value: selectedStore,
            items: nearbyStores.map((storeName) {
              return DropdownMenuItem(
                value: storeName,
                child: Text(storeName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) selectedStore = value;
            },
            decoration: const InputDecoration(labelText: '店家名稱（附近）'),
          ),

          // ✅ 價格輸入框
          TextField(
            controller: priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '價格'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () async {
            final newName = nameCtrl.text.trim();
            final newPrice = double.tryParse(priceCtrl.text.trim());

            // ✅ 加強驗證商品名稱（至少兩字、只含中英文與數字）
            final nameValid = newName.length >= 2 &&
                RegExp(r'^[\u4e00-\u9fa5a-zA-Z0-9\s]+$').hasMatch(newName);

            // ✅ 驗證價格合理範圍（10~99999）
            final priceValid = newPrice != null && newPrice > 10 && newPrice < 99999;

            // ✅ 驗證店家是否選擇
            final storeValid = selectedStore.isNotEmpty;

            if (!nameValid) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ 商品名稱請輸入正確（至少兩字，僅限中英文與數字）')),
              );
              return;
            }

            if (!priceValid) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ 價格請輸入合理數值（10～99999）')),
              );
              return;
            }

            if (!storeValid) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ 請選擇店家')),
              );
              return;
            }

            Navigator.pop(context); // 關閉 Dialog

            // ✅ 呼叫後端更新資料
            final res = await http.post(
              Uri.parse("https://acdb-api.onrender.com/update"),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                "id": record.id,
                "name": newName,
                "store": selectedStore,
                "price": newPrice,
              }),
            );

            // ✅ 成功處理後更新畫面
            if (res.statusCode == 200 && jsonDecode(res.body)['status'] == 'success') {
              setState(() {
                record.name = newName;
                record.store = selectedStore;
                record.price = newPrice;
              });
              await _loadAndMarkStores();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ 更新成功')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ 更新失敗')),
              );
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


















