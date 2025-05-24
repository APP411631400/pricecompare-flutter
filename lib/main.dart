// ✅ lib/main.dart - App 入口點（含價格回報頁面路由設定）
import 'package:flutter/material.dart';

// 📦 首頁頁面（功能入口）
import 'screens/home_page.dart';

// 📦 價格回報頁面（新增的）
import 'screens/price_report_page.dart';

// 📦 使用者登入檢查邏輯（模擬用）
import 'services/user_service.dart';

// 📦 掃描紀錄資料結構與預載方法（假資料）
import 'data/scan_history.dart';

void main() async {
  // ✅ 初始化 Flutter 執行環境，必要 for async/await 與插件初始化
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 預先載入掃描紀錄（通常會從本地檔案或資料庫讀取）
  await loadScanHistory();

  // ✅ 檢查使用者是否已登入（預設為 true，但可做登入判斷跳轉）
  final loggedIn = await UserService.isLoggedIn();

  // ✅ 啟動應用程式，並傳入是否登入的布林值給 MyApp
  runApp(MyApp(isLoggedIn: loggedIn));
}

/// ✅ 整體應用程式設定
class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 🏷️ App 顯示名稱
      title: '智慧購物助手',

      // 🎨 設定整體主題色調
      theme: ThemeData(primarySwatch: Colors.teal),

      // 🐞 關閉右上角 DEBUG 標籤
      debugShowCheckedModeBanner: false,

      // 🏠 指定首頁（預設進入 HomePage，有各種功能入口按鈕）
      home: HomePage(),

      // 🧭 命名路由設定（這裡加入 /price_report）
      routes: {
        '/price_report': (context) => PriceReportPage(), // ✅ 價格回報頁面
      },
    );
  }
}





