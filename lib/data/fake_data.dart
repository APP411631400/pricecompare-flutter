// lib/data/fake_data.dart

class Product {
  final String barcode;
  final String name;
  final List<PriceInfo> prices;

  Product({
    required this.barcode,
    required this.name,
    required this.prices,
  });
}


class PriceInfo {
  final String storeName;
  final double price;

  PriceInfo({required this.storeName, required this.price});
}

// 假資料
final List<Product> fakeProducts = [
  Product(
    barcode: "9789865774431",
    name: "人際關係與溝通",
    prices: [
      PriceInfo(storeName: "博客來", price: 450),
      PriceInfo(storeName: "金石堂", price: 470),
      PriceInfo(storeName: "誠品書店", price: 490),
    ],
  ),
  Product(
    barcode: "4902430753320",
    name: "Oral-B 電動牙刷",
    prices: [
      PriceInfo(storeName: "momo", price: 1290),
      PriceInfo(storeName: "PChome", price: 1250),
      PriceInfo(storeName: "蝦皮商城", price: 1220),
    ],
  ),
  Product(
    barcode: "123456",
    name: "倍潔雅衛生紙",
    prices: [
      PriceInfo(storeName: "便利店", price: 39),
      PriceInfo(storeName: "貴到哭商城", price: 120),
      PriceInfo(storeName: "蝦皮商城", price: 12),
    ],
  ),
  
];
