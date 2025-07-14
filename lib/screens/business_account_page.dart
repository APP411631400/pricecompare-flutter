// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'business_login_page.dart';
import 'home_page.dart';


class BusinessAccountPage extends StatefulWidget {
  const BusinessAccountPage({Key? key}) : super(key: key);

  @override
  State<BusinessAccountPage> createState() => _BusinessAccountPageState();
}

class _BusinessAccountPageState extends State<BusinessAccountPage> {
  String businessEmail = '';
  String storeName = '';
  LatLng? _currentPosition;
  GoogleMapController? _mapController; // 地圖控制器

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // 檢查登入狀態
    _getCurrentLocation(); // 嘗試取得目前位置
  }

  /// 檢查商家是否已登入，否則導回登入頁面
  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isBusinessLoggedIn') ?? false;

    if (!isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BusinessLoginPage()),
      );
    } else {
      setState(() {
        businessEmail = prefs.getString('businessEmail') ?? '';
        storeName = prefs.getString('storeName') ?? '';
      });
    }
  }

  /// 嘗試取得裝置當前 GPS 座標，若失敗則略過
  Future<void> _getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return;

  LocationPermission permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) return;

  Position position = await Geolocator.getCurrentPosition();

  // 👉 預防 setState 錯誤
  if (!mounted) return;

  setState(() {
    _currentPosition = LatLng(position.latitude, position.longitude);
  });
}


  /// 商家登出後導回首頁，清除登入資訊
  Future<void> _handleLogout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isBusinessLoggedIn');
    await prefs.remove('businessEmail');
    await prefs.remove('storeName');

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商家帳號中心'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '登出',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔶 商家資訊顯示卡片
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🧾 商家資訊', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text('商家名稱：$storeName', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      Text('Email：$businessEmail', style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 🔶 功能按鈕區塊
              const Text('🛠 功能操作', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: () {
                  // 暫時不導頁，只顯示提示訊息
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('功能尚未開放')),
                  );
                },
                icon: const Icon(Icons.add_box),
                label: const Text('我要上架商品'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: () {
                  // 暫時不導頁，只顯示提示訊息
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('功能尚未開放')),
                  );
                },
                icon: const Icon(Icons.list_alt),
                label: const Text('我的商品清單'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),

              const SizedBox(height: 32),

              // 🔶 顯示小地圖區塊
              const Text('📍 目前定位', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: _currentPosition != null
                      ? GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _currentPosition!,
                            zoom: 16,
                          ),
                          onMapCreated: (controller) => _mapController = controller,
                          markers: {
                            Marker(
                              markerId: const MarkerId('current'),
                              position: _currentPosition!,
                              infoWindow: const InfoWindow(title: '您的店面位置'),
                            ),
                          },
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_mapController != null && _currentPosition != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(target: _currentPosition!, zoom: 16),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.my_location),
                  label: const Text('移動到我的位置'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}







