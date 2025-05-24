import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart';
import '../data/fake_data.dart'; // 讓它可以使用 Product/PriceInfo 類別

/// ✅ 從 Excel 檔案中載入資料並轉換為 Product 清單
Future<List<Product>> loadProductsFromExcel() async {
  // 讀取 Excel 二進位內容
  ByteData data = await rootBundle.load("assets/product_data.xlsx");
  var bytes = data.buffer.asUint8List();
  var excel = Excel.decodeBytes(bytes);

  List<Product> products = [];

  for (var sheet in excel.tables.keys) {
    var rows = excel.tables[sheet]!.rows;

    // 跳過第一列（欄位名稱），從第2列開始讀
    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];

      try {
        // ✅ 正確抓取資料欄位
        String barcode = row[0]?.value.toString() ?? ''; // 商品編號
        String name = row[3]?.value.toString() ?? '';    // 商品名稱
        double? price = double.tryParse(row[10]?.value.toString() ?? '0'); // 特價欄位

        if (name.isEmpty || price == null || price == 0) continue;

        products.add(
          Product(
            barcode: barcode,
            name: name,
            prices: [PriceInfo(storeName: "Watsons", price: price)],
          ),
        );
      } catch (_) {
        continue; // 跳過格式錯誤的行
      }
    }

    break; // 只處理第一個工作表
  }

  return products;
}

