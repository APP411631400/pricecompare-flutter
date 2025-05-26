import 'dart:convert';
import 'package:http/http.dart' as http;

/// ✅ 商品模型（對應新的比價商品資料表結構）
class Product {
  final String name;                 // 商品名稱
  final int id;                      // 商品 ID
  final Map<String, double> prices; // 各平台價格對照表，例如 {"momo": 159, "博客來": 149}
  final Map<String, String> links;  // 各平台商品連結對照表，例如 {"momo": "...", "博客來": "..."}

  Product({
    required this.name,
    required this.id,
    required this.prices,
    required this.links,
  });

  /// ✅ 從 JSON 建立 Product 實體
  factory Product.fromJson(Map<String, dynamic> json) {
    final Map<String, double> prices = {};
    final Map<String, String> links = {};

    // ✅ 支援的比價平台（需與後端欄位一致）
    final List<String> platforms = ['momo', 'pchome', '博客來', '屈臣氏', '康是美'];

    for (final platform in platforms) {
      final priceKey = '${platform}_價格';
      final urlKey = '${platform}_網址';
      prices[platform] = _parsePrice(json[priceKey]);
      links[platform] = json[urlKey] ?? '';
    }

    return Product(
      name: json['商品名稱'] ?? '',
      id: int.tryParse(json['商品ID'].toString()) ?? 0,
      prices: prices,
      links: links,
    );
  }

  /// ✅ 將價格欄位轉為 double，去除字串雜訊（例如 NT$, $）
  static double _parsePrice(dynamic value) {
    if (value == null) return 0;
    final cleaned = value.toString().replaceAll(RegExp(r'[^\d.]'), '').trim();
    return double.tryParse(cleaned) ?? 0;
  }
}

/// ✅ 商品查詢服務：提供查詢比價商品資料的 API 操作
class ProductService {
  /// ✅ 後端 API 伺服器 base URL（請換成你部署的網址）
  static const String baseUrl = 'https://acdb-api.onrender.com';

  /// 📦 取得所有比價商品（完整商品清單）
  static Future<List<Product>> fetchAll() async {
    final response = await http.get(Uri.parse('$baseUrl/products'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((item) => Product.fromJson(item)).toList();
    } else {
      throw Exception('❌ 無法取得商品資料');
    }
  }

  /// 🔍 模糊搜尋比價商品（關鍵字查詢）
  static Future<List<Product>> search(String keyword) async {
    final response = await http.get(Uri.parse('$baseUrl/products/search?query=$keyword'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((item) => Product.fromJson(item)).toList();
    } else {
      throw Exception('❌ 搜尋失敗');
    }
  }

  /// 📷 拍照辨識後模糊比對比價商品（傳回 Top-N 筆結果）
  /// ✅ 結合 token 分詞比對 + 中文 2-gram 比對，回傳 Top N 相似度最高的商品
  static Future<List<Product>> fuzzyMatchTopN(String keyword, [int topN = 3]) async {
    final all = await fetchAll();

    final raw = keyword.toLowerCase(); // 使用者輸入的關鍵字
    final rawTokens = _tokenize(raw);  // 中英分詞 token
    final chineseText = keyword.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '');
    final chineseTokens = _tokenize(chineseText);   // 中文分詞
    final chineseGrams = _twoGram(chineseText);     // 中文 2-gram 拆字

    // ✅ 每個商品計算一個相似度分數
    final scoredList = all.map((product) {
      final name = product.name.toLowerCase();
      final productTokens = _tokenize(name);
      final productZh = product.name.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '');
      final productGrams = _twoGram(productZh);

      // ✅ 比對三種相似度
      final rawMatch = rawTokens.where(productTokens.contains).length;      // 中英 token 比對
      final zhMatch = chineseTokens.where(productTokens.contains).length;   // 中文 token 比對
      final gramMatch = chineseGrams.where(productGrams.contains).length;   // 中文 2-gram 比對

      // ✅ 綜合分數加權計算（中文 2-gram 權重最高）
      final score = rawMatch + zhMatch * 2 + gramMatch * 3;

      return MapEntry(product, score);
    }).toList();

    // ✅ 根據分數排序，取前 N 筆（只保留分數 ≥ 2 的結果）
    scoredList.sort((a, b) => b.value.compareTo(a.value));
    return scoredList.where((e) => e.value >= 2).take(topN).map((e) => e.key).toList();
  }

  /// 🧩 將輸入字串切為 token（英數字 + 中文詞）
  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\u4e00-\u9fa5a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// 🈶 中文 2-gram：將中文字串分成連續兩字組（如：舒潔 → [舒潔]）
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









