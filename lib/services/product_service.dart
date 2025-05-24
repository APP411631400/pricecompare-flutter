import 'dart:convert';
import 'package:http/http.dart' as http;


/// ✅ 商品模型（對應後端資料欄位）
class Product {
  final String name;           // 商品名稱
  final String category;       // 商品分類
  final String store;          // 店家名稱
  final double originalPrice;  // 原價
  final double salePrice;      // 特價
  final String imageUrl;       // 圖片連結
  final String link;           // 商品頁面連結

  Product({
    required this.name,
    required this.category,
    required this.store,
    required this.originalPrice,
    required this.salePrice,
    required this.imageUrl,
    required this.link,
  });

  /// ✅ 建構函數：從 JSON 轉為 Product 物件
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['商品名稱'],
      category: json['分類'],
      store: json['店家名稱'],
      originalPrice: _parsePrice(json['原價']),
      salePrice: _parsePrice(json['特價']),
      imageUrl: json['圖片網址'] ?? '',
      link: json['連結'] ?? '',
    );
  }

  /// ✅ 處理價格字串為 double（自動去除 $, NT$, 空白等符號）
  static double _parsePrice(dynamic value) {
    if (value == null) return 0;
    final cleaned = value
        .toString()
        .replaceAll(RegExp(r'[^\d.]'), '') // 只保留數字與小數點
        .trim();
    return double.tryParse(cleaned) ?? 0;
  }
}

/// ✅ 商品查詢服務（透過 API 與後端溝通）
class ProductService {
  static const String baseUrl = 'https://acdb-api.onrender.com'; // ✅ API 伺服器網址

  /// 📦 取得所有商品資料（完整清單）
  static Future<List<Product>> fetchAll() async {
    final response = await http.get(Uri.parse('$baseUrl/products'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((item) => Product.fromJson(item)).toList();
    } else {
      throw Exception('❌ 無法取得商品資料');
    }
  }

  /// 🔍 商品搜尋（根據關鍵字模糊查詢，多筆結果）
  static Future<List<Product>> search(String keyword) async {
    final response = await http.get(Uri.parse('$baseUrl/products/search?query=$keyword'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((item) => Product.fromJson(item)).toList();
    } else {
      throw Exception('❌ 搜尋失敗');
    }
  }

  /// 📷 拍照後模糊比對商品（回傳 Top-N 筆最佳比對結果）
/// 結合 token 比對 + 中文 2-gram 分數
static Future<List<Product>> fuzzyMatchTopN(String keyword, [int topN = 3]) async {
  final all = await fetchAll();

  // ✅ 建立使用者輸入的 token 與 2-gram 中文詞片段
  final raw = keyword.toLowerCase();
  final rawTokens = _tokenize(raw);
  final chineseText = keyword.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '');
  final chineseTokens = _tokenize(chineseText);
  final chineseGrams = _twoGram(chineseText);

  // 🧮 建立每筆商品的分數並排序
  final scoredList = all.map((product) {
    final name = product.name.toLowerCase();
    final category = product.category.toLowerCase();
    final store = product.store.toLowerCase();

    final combined = '$name $category $store';
    final productTokens = _tokenize(combined);
    final productZh = product.name.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '');
    final productGrams = _twoGram(productZh);

    // ✅ Token 比對
    final rawMatch = rawTokens.where(productTokens.contains).length;
    final zhMatch = chineseTokens.where(productTokens.contains).length;

    // ✅ 中文 2-gram 比對
    final gramMatch = chineseGrams.where(productGrams.contains).length;

    // ✅ 綜合分數（中文權重最高）
    final score = rawMatch + zhMatch * 2 + gramMatch * 3;

    return MapEntry(product, score);
  }).toList();

  // ✅ 排序後取前 N 筆（分數需 ≥ 2 才合理）
  scoredList.sort((a, b) => b.value.compareTo(a.value));
  return scoredList.where((e) => e.value >= 2).take(topN).map((e) => e.key).toList();
}




  /// 🧩 將字串切成關鍵詞 tokens（中英數）
  /// 🧩 將中英文混合字串切成 token 清單
/// 🧩 將文字切成中英數 tokens（移除標點與符號）
static List<String> _tokenize(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\u4e00-\u9fa5a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
}

/// 🈶 中文 2-gram 拆字比對（例：可麗 → [可麗]、麗舒 → [麗舒]）
static List<String> _twoGram(String text) {
  final result = <String>[];
  for (int i = 0; i < text.length - 1; i++) {
    result.add(text.substring(i, i + 2));
  }
  return result;
}





  /// 📏 最長共同子字串（Longest Common Substring，用於模糊補分）
//static String _longestCommonSubstring(String s1, String s2) {
  //final m = List.generate(s1.length + 1, (_) => List.filled(s2.length + 1, 0));
  //int maxLen = 0;
  //int endIndex = 0;

  //for (int i = 1; i <= s1.length; i++) {
    //for (int j = 1; j <= s2.length; j++) {
      //if (s1[i - 1] == s2[j - 1]) {
        //m[i][j] = m[i - 1][j - 1] + 1;
        //if (m[i][j] > maxLen) {
          //maxLen = m[i][j];
          //endIndex = i;
       // }
     // }
   // }
 // }

 // return s1.substring(endIndex - maxLen, endIndex);
//}

}









