import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapStore {
  final String name;
  final double price;
  final LatLng location;

  MapStore({
    required this.name,
    required this.price,
    required this.location,
  });
}

// ✅ 假資料：之後可由後端取得，請勿寫死太多資料
final List<MapStore> mapStores = [
  MapStore(name: '博客來（中山區）', price: 450, location: LatLng(25.0480, 121.5315)),
  MapStore(name: '金石堂（忠孝店）', price: 470, location: LatLng(25.0415, 121.5340)),
  MapStore(name: '誠品書店（信義店）', price: 490, location: LatLng(25.0345, 121.5640)),
];

