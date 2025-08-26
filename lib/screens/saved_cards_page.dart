import 'package:flutter/material.dart';
import '../services/local_account_store.dart';

class SavedCardsPage extends StatefulWidget {
  const SavedCardsPage({super.key});
  @override
  State<SavedCardsPage> createState() => _SavedCardsPageState();
}

class _SavedCardsPageState extends State<SavedCardsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await LocalAccountStore.getSavedCards();
    setState(() {
      _items = data;
      _loading = false;
    });
  }

  Future<void> _removeAt(int index) async {
    //final userCardId = _items[index]['userCardId'] as int;
    //await LocalAccountStore.removeSavedCard(userCardId);
    final id = _items[index]['id'] as int; // ← 用本地自增的 id
    await LocalAccountStore.removeSavedCard(id);
    setState(() => _items.removeAt(index));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已移除')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('已儲存的信用卡')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('尚未加入任何信用卡'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      return Dismissible(
                        key: ValueKey(it['userCardId']),
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
                                  title: const Text('移除這張卡？'),
                                  content: Text((it['nickname'] ?? '信用卡').toString()),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('移除')),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) => _removeAt(i),
                        child: ListTile(
                          leading: const Icon(Icons.credit_card),
                          title: Text(it['nickname'] ?? '信用卡'),
                          subtitle: Text('CardID: ${it['cardId']} • 加入於 ${it['addedAt']}'),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
