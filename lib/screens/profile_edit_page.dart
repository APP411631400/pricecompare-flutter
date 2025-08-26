import 'package:flutter/material.dart';
import '../services/local_account_store.dart';
import '../services/user_service.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({Key? key}) : super(key: key);

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _displayName = TextEditingController();
  final _avatarUrl   = TextEditingController();
  final _email       = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = await UserService.getUserEmail();      // 目前登入 email（只顯示）
    final prof  = await LocalAccountStore.getProfile();  // 本機個資（可編輯）

    _email.text       = email ?? '';
    _displayName.text = (prof?['displayName'] ?? '') as String;
    _avatarUrl.text   = (prof?['avatarUrl']   ?? '') as String;

    if (mounted) setState(() => _loading = false);
  }

  /// 只存暱稱、頭像（本機，分帳號）
  Future<void> _saveProfile() async {
    await LocalAccountStore.updateProfile(
      displayName: _displayName.text.trim().isEmpty ? null : _displayName.text.trim(),
      avatarUrl:   _avatarUrl.text.trim().isEmpty   ? null : _avatarUrl.text.trim(),
    );

    _toast('已儲存（暱稱 / 頭像）');
    if (mounted) Navigator.pop(context);
  }

  /// 改密碼先不做：僅提示
  Future<void> _changePassword() async {
    _toast('密碼變更暫不提供，之後再接後端。');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _displayName.dispose();
    _avatarUrl.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('編輯個人資料')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundImage:
                        _avatarUrl.text.trim().isEmpty ? null : NetworkImage(_avatarUrl.text.trim()),
                    child: _avatarUrl.text.trim().isEmpty
                        ? const Icon(Icons.person, size: 36)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _avatarUrl,
                  decoration: const InputDecoration(
                    labelText: '頭像圖片 URL（可留空）',
                    hintText: 'https://...',
                  ),
                  onChanged: (_) => setState(() {}), // 立即刷新預覽
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _displayName,
                  decoration: const InputDecoration(labelText: '暱稱'),
                ),
                const SizedBox(height: 16),

                // Email 僅顯示，禁止修改
                TextField(
                  controller: _email,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email（唯讀）',
                    helperText: '暫不支援在此變更 Email',
                  ),
                ),

                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.save),
                  label: const Text('儲存'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _changePassword,
                  icon: const Icon(Icons.lock),
                  label: const Text('變更密碼（暫不提供）'),
                ),
              ],
            ),
    );
  }
}

