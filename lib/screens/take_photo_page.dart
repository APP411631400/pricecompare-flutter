// ----------------------------- TakePhotoPage.dart（最終版 + pageTitle 多結果選擇 + 電商平台清理 + 完整中文註解）-----------------------------
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'compare_page.dart'; // ✅ 導入比價頁面（使用識別商品名稱）

class TakePhotoPage extends StatefulWidget {
  @override
  _TakePhotoPageState createState() => _TakePhotoPageState();
}

class _TakePhotoPageState extends State<TakePhotoPage> {
  File? _imageFile; // ✅ 拍攝的圖片檔案
  bool _isLoading = false; // ✅ 控制載入動畫顯示狀態

  final String visionApiKey = 'AIzaSyA84zcXEHXH_ilB5T4Gks03ieRXE6izb9U'; // ❗請替換為你實際的 Vision API 金鑰

  // ✅ 使用者按下拍照後觸發
  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 100, // ✅ 保持最高畫質，避免辨識失敗
    );
    if (picked == null) return;
    setState(() {
      _imageFile = File(picked.path);
      _isLoading = true;
    });
    await _analyzeImage(_imageFile!);
    setState(() => _isLoading = false);
  }

  // ✅ 進行圖片分析：呼叫 Vision API 並回傳可能結果
  Future<void> _analyzeImage(File img) async {
    final results = await _callVisionAPI(img);
    if (results.isEmpty) {
      _showResultDialog('❌ 無辨識結果');
    } else {
      _showRecognizedDialog(results);
    }
  }

  // ✅ 呼叫 Google Vision API 並從 pageTitle 抓取商品候選名稱
  Future<List<String>> _callVisionAPI(File img) async {
    final url = 'https://vision.googleapis.com/v1/images:annotate?key=$visionApiKey';
    final b64 = base64Encode(await img.readAsBytes());

    final payload = {
      'requests': [
        {
          'image': {'content': b64},
          'features': [
            {'type': 'WEB_DETECTION', 'maxResults': 10}
          ],
          'imageContext': {
            'webDetectionParams': {'includeGeoResults': true}
          }
        }
      ]
    };

    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (resp.statusCode != 200) {
        _showResultDialog('Vision API HTTP ${resp.statusCode}');
        return [];
      }

      final data = jsonDecode(resp.body)['responses'][0];
      final web = data['webDetection'];
      final Set<String> candidates = {};

      if (web != null && web['pagesWithMatchingImages'] != null) {
        for (var p in web['pagesWithMatchingImages']) {
          final rawTitle = p['pageTitle']?.toString();
          if (rawTitle != null && rawTitle.isNotEmpty) {
            final cleaned = _cleanPlatformSuffix(rawTitle);
            if (cleaned.isNotEmpty && !_isTooGeneric(cleaned)) {
              candidates.add(cleaned);
            }
          }
        }
      }

      return candidates.take(5).toList(); // ✅ 最多顯示 5 筆讓使用者選擇
    } catch (e) {
      _showResultDialog('Vision API 呼叫失敗：$e');
      return [];
    }
  }

  // ✅ 清除尾段電商平台描述，例如 momo購物網、PChome 等
  String _cleanPlatformSuffix(String text) {
    final cutWords = [
      'momo', '蝦皮', 'shopee', 'pchome', '博客來', 'costco', 'amazon',
      '購物網', '商城', 'product page', '網路商店', '價格', '比價'
    ];
    for (var word in cutWords) {
      final idx = text.toLowerCase().indexOf(word.toLowerCase());
      if (idx > 0) {
        return text.substring(0, idx).trim();
      }
    }
    return text.trim();
  }

  // ✅ 排除過於模糊的關鍵詞（避免回傳「drink」、「bottle」等沒意義的名詞）
  bool _isTooGeneric(String text) {
    final generic = ['bottle', 'drink', 'label', 'plastic', 'product'];
    return generic.contains(text.toLowerCase());
  }

  // ✅ 顯示候選辨識結果清單（可選一個）
  void _showRecognizedDialog(List<String> keywords) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('辨識結果'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_imageFile != null) ...[
              const Text('商品照片：'),
              const SizedBox(height: 8),
              Image.file(_imageFile!, height: 150),
              const SizedBox(height: 12),
            ],
            const Text('您要找的是：'),
            const SizedBox(height: 6),
            ...keywords.map((k) => ListTile(
              title: Text(k),
              trailing: const Icon(Icons.arrow_forward_ios, size: 18),
              onTap: () => _showActionDialog(k),
            ))
          ],
        ),
      ),
    );
  }

  // ✅ 使用者選擇其中一筆結果後進一步操作：比價 or 回報
  void _showActionDialog(String keyword) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('辨識結果'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_imageFile != null) ...[
              const Text('商品照片：'),
              const SizedBox(height: 8),
              Image.file(_imageFile!, height: 150),
              const SizedBox(height: 12),
            ],
            Text('系統辨識為：「$keyword」', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('請選擇接下來的動作：'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ComparePage(keyword: keyword)));
            },
            child: const Text('查看比價'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_imageFile != null) {
                Navigator.pushNamed(context, '/price_report', arguments: {
                  'keyword': keyword,
                  'imageFile': _imageFile,
                });
              } else {
                _showResultDialog("⚠️ 無法取得照片檔案，請重新拍攝！");
              }
            },
            child: const Text('價格回報'),
          ),
        ],
      ),
    );
  }

  // ✅ 錯誤通用提示框
  void _showResultDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('辨識結果'),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('確定'))],
      ),
    );
  }

  // ✅ 主畫面 UI 架構
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('拍照商品辨識')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _takePhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text('拍照辨識商品'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (_imageFile != null) ...[
              const Text('圖片預覽：'),
              const SizedBox(height: 8),
              Image.file(_imageFile!, height: 300),
            ],
          ],
        ),
      ),
    );
  }
}































