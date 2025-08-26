import 'package:flutter/material.dart';
import '../data/scan_history.dart';          // 有 ScanRecord model
import '../services/store_service.dart';     // 你已經有 load / delete 的 API
import '../services/user_service.dart';      // 取得目前登入者 userId
import 'price_report_page.dart';            // 空清單時引導去回報

class PriceReportsPage extends StatefulWidget {
  const PriceReportsPage({super.key});
  @override
  State<PriceReportsPage> createState() => _PriceReportsPageState();
}

class _PriceReportsPageState extends State<PriceReportsPage> {
  bool _loading = true;
  List<ScanRecord> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // 1) 目前登入者
      final currentUserId = await UserService.getCurrentUserId(); // int? 或 String? 都可
      final myId = currentUserId;                     // 轉成字串統一比較

      // 2) 從資料庫撈全部回報
      final all = await StoreService().loadScanRecordsFromDatabase();

      // 3) 前端過濾出「我的」
      final mine = all.where((r) {
        final owner = r.userId?.toString();
        return owner != null && owner == myId;
      }).toList();

      if (!mounted) return;
      setState(() {
        _items = mine;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入失敗：$e')),
      );
    }
  }

  Future<void> _removeAt(int index) async {
    final record = _items[index];
    // 你原本就有的刪除 API：
    await StoreService().deleteScanRecordFromDatabase(record);
    setState(() => _items.removeAt(index));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已刪除')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的價格回報紀錄')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _EmptyHint(onCreate: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PriceReportPage()),
                  ).then((_) => _load());
                })
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      return Dismissible(
                        key: ValueKey(it.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('刪除這筆回報？'),
                                  content: Text('${it.name} • ${it.store} • \$${it.price}'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) => _removeAt(i),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text('${it.name}   \$${it.price}'),
                          subtitle: Text('${it.store}\n${it.timestamp}'),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyHint({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 56),
            const SizedBox(height: 12),
            const Text('目前沒有任何回報紀錄', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('去回報一筆'),
            ),
          ],
        ),
      ),
    );
  }
}

