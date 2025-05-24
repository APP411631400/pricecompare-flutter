// ✅ 屈臣氏門市資料模型類別
// ✅ 本類別用於統一表示一筆門市資料，方便地圖標記與資料查詢整合

class Store {
  /// 門市名稱（如：屈臣氏台北中正店）
  final String name;

  /// 門市地址（如：台北市中正區南陽街15號）
  final String address;

  /// 行政區（如：中正區）
  final String district;

  /// 電話號碼（如：(02)2311-10661）
  final String phone;

  /// 緯度（Latitude）地圖標記會用到
  final double lat;

  /// 經度（Longitude）地圖標記會用到
  final double lng;

  /// 建構子，必須傳入所有欄位
  Store({
    required this.name,
    required this.address,
    required this.district,
    required this.phone,
    required this.lat,
    required this.lng,
  });

  /// ✅ 工廠建構方法：從 Map<String, dynamic> 轉換為 Store 物件
  /// 常見用於從資料庫、API 撈出資料後做格式轉換
  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      district: map['district'] ?? '',
      phone: map['phone'] ?? '',
      lat: map['lat']?.toDouble() ?? 0.0,
      lng: map['lng']?.toDouble() ?? 0.0,
    );
  }

  /// ✅ 輸出成 Map：方便未來儲存、傳給後端 API
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'district': district,
      'phone': phone,
      'lat': lat,
      'lng': lng,
    };
  }
}