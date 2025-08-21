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
import 'package:price_compare_app/services/distance_service.dart';
import '../services/directions_service.dart';

//import 'package:price_compare_app/services/distance_service.dart' show TransportMode; // 你原本的枚舉
import 'package:url_launcher/url_launcher_string.dart';

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
  Set<Polyline> polylines = {};

  double? _routeKm;
  TransportMode _selectedMode = TransportMode.driving;


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
          // 1. 取得目前位置
          final double latCenter = _currentPosition!.latitude;
          final double lngCenter = _currentPosition!.longitude;

          // 2. 組成 Overpass QL 查詢 (around:1000 = 半徑 1 公里)
          final String overpassQuery = '''
            [out:json][timeout:25];
            node["shop"](around:1000,$latCenter,$lngCenter);
            out body;
          ''';

          // 3. 發 GET 請求到 Overpass interpreter
          final uri = Uri.parse(
            'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(overpassQuery)}'
          );
          final response = await http.get(uri);

          // 4. 解析並轉成 Marker
          if (response.statusCode == 200) {
            final jsonString = utf8.decode(response.bodyBytes);
            final data       = jsonDecode(jsonString);
            for (var elem in (data['elements'] as List).take(6)) {
              final name = elem['tags']?['name'] ?? 'Unknown';
              final lat  = elem['lat']  as double;
              final lng  = elem['lon']  as double;

              markers.add(Marker(
                markerId: MarkerId('osm_$name'),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(
                  title: name,
                  snippet: 'OSM 附近店家',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueViolet
                ),
              ));
            }
          } else {
            print('❌ Overpass API 錯誤：HTTP ${response.statusCode}');
          }
        } catch (e) {
          print('❌ 取得 OSM 店家失敗：$e');
        }
      }

      setState(() => _markers = markers.toSet());

    
  }
  
  
  // 顯示路線
  Future<void> togglePolylineForRecord(ScanRecord record) async {
  if (_currentPosition == null ||
      record.latitude == null ||
      record.longitude == null) return;

  final id = PolylineId('route_to_record_${record.id}');

  // 1) 已有 → 只刪線 + 清空公里數  【新增 ↓】
  final exists = polylines.any((p) => p.polylineId == id);
  if (exists) {
    setState(() {
      polylines.removeWhere((p) => p.polylineId == id);
      _routeKm = null;                      // ← 只新增這行
    });
    return;
  }

  // 2) 沒有 → 照舊呼叫 API 畫線
  final target = LatLng(record.latitude!, record.longitude!);
  try {
    final points = await DirectionsService.getRoutePolyline(
      origin: _currentPosition!,
      destination: target,
    );
    if (points.isNotEmpty) {
      setState(() {
        polylines.add(Polyline(
          polylineId: id,
          color: Colors.green,
          width: 4,
          points: points,
        ));
      });

      // ✅ 成功畫線後，再「額外」取距離（公里）並存起來  【新增 ↓】
      try {
        final kmMap = await DistanceService.getDistances(
          origin: _currentPosition!,
          destinations: [target],
          mode: _selectedMode,              // 若沒有這個變數，用 TransportMode.driving
        );
        final km = kmMap[target];
        if (km != null) {
          setState(() => _routeKm = km);    // ← 只新增這行
        }
      } catch (_) {
        // 取距離失敗不影響畫線；忽略即可
      }
      // 【新增 ↑】
    }
  } catch (e) {
    print('❌ 無法取得路線：$e');
  }
}



  // TransportMode -> Google Maps travelmode
  String _gmMode(TransportMode m) {
    return {
      TransportMode.walking: 'walking',
      TransportMode.cycling: 'bicycling',
      TransportMode.driving: 'driving',
    }[m]!;
  }
  /// 直接開啟 Google Maps 並進入導航
  Future<void> _openInGoogleMaps({
    LatLng? origin,                 // 傳 null = 讓 Google 用「你目前位置」
    required LatLng destination,
    required TransportMode mode,
  }) async {
    final url = (origin == null)
        ? 'https://www.google.com/maps/dir/?api=1'
          '&destination=${destination.latitude},${destination.longitude}'
          '&travelmode=${_gmMode(mode)}'
          '&dir_action=navigate'
        : 'https://www.google.com/maps/dir/?api=1'
          '&origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&travelmode=${_gmMode(mode)}'
          '&dir_action=navigate';

    await launchUrlString(url, mode: LaunchMode.externalApplication);
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
  // ✅ 顯示主對話框
  showDialog(
  context: context,
  builder: (_) {
    final userPos = _currentPosition;

    // ─── 新增：定義對話框內可變的交通模式狀態 ─────────────────────
    TransportMode _selectedMode = TransportMode.driving;

    return StatefulBuilder(
      builder: (context, setState) {
        return FutureBuilder<Map<LatLng, double>>(
          future: (userPos != null && record.latitude != null && record.longitude != null)
              ? DistanceService.getDistances(
                  origin: LatLng(userPos.latitude, userPos.longitude),
                  destinations: [LatLng(record.latitude!, record.longitude!)],
                  mode: _selectedMode, // ─── 修改：帶入選好的模式
                )
              : Future.value({}),
          builder: (context, snapshot) {
            double? distanceInKm;
            double? totalCost;

            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              final distances = snapshot.data!;
              distanceInKm = distances[LatLng(record.latitude!, record.longitude!)];
              if (distanceInKm != null && record.price != null) {
                totalCost = CostCalculator.calculateTotalCost(
                  distanceInKm: distanceInKm,
                  basePrice: record.price!,
                  mode: _selectedMode,                // ─── 修改：也帶入模式
                  includeParking: _selectedMode == TransportMode.driving,
                );
              }
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              title: Text(record.name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── 其餘原有顯示不動 ───────────────────────────
                  if (imageBase64 != null)
                    Image.memory(base64Decode(imageBase64), height: 150, fit: BoxFit.cover)
                  else
                    const Text("（無圖片）"),
                  const SizedBox(height: 10),
                  Text('價格：\$${record.price?.toStringAsFixed(0) ?? '未知'}'),
                  Text('店家：${record.store}'),
                  Text('時間：${record.timestamp.toLocal()}'),

                  const SizedBox(height: 10),

                  // ─── 新增：交通模式下拉選單 ───────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('模式：'),
                      const SizedBox(width: 8),
                      DropdownButton<TransportMode>(
                        value: _selectedMode,
                        items: TransportMode.values.map((m) {
                          return DropdownMenuItem(
                            value: m,
                            child: Text({
                              TransportMode.driving: '開車',
                              TransportMode.walking: '走路',
                              TransportMode.cycling: '騎車',
                            }[m]!),
                          );
                        }).toList(),
                        //onChanged: (m) => setState(() => _selectedMode = m!),
                        onChanged: (m) async {
                          if (m == null) return;
                          setState(() => _selectedMode = m);

                          // TransportMode -> RouteMode（內聯 mapping）
                          final routeMode = (m == TransportMode.driving)
                              ? RouteMode.driving
                              : (m == TransportMode.walking)
                                  ? RouteMode.walking
                                  : RouteMode.cycling;

                          DirectionsService.setDefaultMode(routeMode);

                          // 若這筆已有線，切模式後自動刷新（仍走你原本的 toggle 邏輯）
                          final id = PolylineId('route_to_record_${record.id}');
                          final exists = polylines.any((p) => p.polylineId == id);
                          if (exists) {
                            setState(() => polylines.removeWhere((p) => p.polylineId == id));
                            await togglePolylineForRecord(record); // 用新模式再畫回來
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 直接導航按鈕
                  TextButton(
                    onPressed: () {
                      final dest = LatLng(record.latitude!, record.longitude!);
                      _openInGoogleMaps(
                        origin: _currentPosition,
                        destination: dest,
                        mode: _selectedMode,
                      );
                    },
                    child: const Text('直接導航 🚀'),
                  ),

                  // ─── 原有的等待及顯示成本邏輯 ─────────────────────
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const CircularProgressIndicator(),
                  if (totalCost != null)
                    Text('🚗 含移動總成本：\$${totalCost.toStringAsFixed(2)}'),
                  if (_routeKm != null)
                    Text('📏 距離：${_routeKm!.toStringAsFixed(2)} 公里'),
                ],
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // ─── 下面所有按鈕完全原樣，不動 ────────────────
                    TextButton(
                     onPressed: () {
                        Navigator.pop(context);
                        togglePolylineForRecord(record);
                      },
                      child: Builder(builder: (_) {
                        final id = PolylineId('route_to_record_${record.id}');
                        final exists = polylines.any((p) => p.polylineId == id);
                        return Text(
                          exists ? '刪除路線' : '顯示路線',
                          style: TextStyle(color: exists ? Colors.red : Colors.green),
                        );
                      }),
                    ),


                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditDialog(record);
                      },
                      child: const Text('編輯', style: TextStyle(color: Colors.blue)),
                    ),
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
                      future: UserService.getCurrentUserId(),
                      builder: (context, snap2) {
                        if (!snap2.hasData) return const SizedBox.shrink();
                        final isOwner = (snap2.data ?? '') == (record.userId ?? '');
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
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('關閉'),
                    ),
                  ],
                )
              ],
            );
          },
        );
      },
    );
  },
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
      // 1. 取得目前經緯度
      final lat = _currentPosition!.latitude;
      final lng = _currentPosition!.longitude;

      // 2. 組成 Overpass QL：半徑 1km 的 shop 節點
      final overpassQuery = '''
        [out:json][timeout:25];
        node["shop"](around:1000,$lat,$lng);
        out body;
      ''';

      // 3. 發 GET 請求
      final uri = Uri.parse(
        'https://overpass-api.de/api/interpreter?data='
        '${Uri.encodeComponent(overpassQuery)}'
      );
      final response = await http.get(uri);

      // 4. 解析並取前 6 筆 name:zh / name
      if (response.statusCode == 200) {
        // 避免亂碼，用 bodyBytes + utf8.decode
        final jsonString = utf8.decode(response.bodyBytes);
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>;

        nearbyStores = elements
          .map((e) {
            final tags = e['tags'] as Map<String, dynamic>? ?? {};
            // 先取中文名，fallback 到 name
            return (tags['name:zh'] ?? tags['name'] ?? '').toString();
          })
          .where((name) => name.isNotEmpty) // 過濾掉空字串
          .take(6)
          .toList();
      } else {
        print('❌ Overpass API 錯誤：HTTP ${response.statusCode}');
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
              polylines: polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
    );
  }
}



















