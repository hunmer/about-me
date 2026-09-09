import 'dart:convert';
import 'dart:math';

import 'package:aboutme/core/storage/http_storage.dart';
import 'package:aboutme/core/storage/storage_backend_config.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/storage/storage_migration_service.dart';
import 'package:flutter/material.dart';

class StorageBackendSettingsDialog extends StatefulWidget {
  const StorageBackendSettingsDialog({super.key});

  @override
  State<StorageBackendSettingsDialog> createState() => _StorageBackendSettingsDialogState();
}

class _StorageBackendSettingsDialogState extends State<StorageBackendSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _credentialController = TextEditingController();
  final _keyController = TextEditingController();
  final _userIdController = TextEditingController();
  final _store = LocalStorageBackendConfigStore();
  StorageBackendType _type = StorageBackendType.local;
  StorageBackendType _originalType = StorageBackendType.local;
  StorageAuthType _authType = StorageAuthType.jwt;
  bool _loading = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await _store.load();
    if (!mounted) return;
    setState(() {
      _type = config.type;
      _originalType = config.type;
      _authType = config.authType;
      _serverController.text = config.serverUrl;
      _credentialController.text = config.credential;
      _keyController.text = config.encryptionKey;
      _userIdController.text = config.userId;
      _loading = false;
    });
  }

  StorageBackendConfig _config() => StorageBackendConfig(
    type: _type,
    serverUrl: _serverController.text,
    authType: _authType,
    credential: _credentialController.text,
    encryptionKey: _keyController.text,
    userId: _userIdController.text,
  );

  Future<void> _test() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _status = null; });
    try {
      await HttpStorage.fromConfig(_config()).testConnection();
      if (mounted) {
        setState(() => _status = '连接成功');
      }
    } catch (error) {
      if (mounted) setState(() => _status = '连接失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_type == StorageBackendType.http &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_type != _originalType) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('切换数据存储后端'),
          content: const Text('切换不会迁移或删除现有数据。请先完成数据导出，并确认当前没有未完成的写入。保存后需要重新启动应用。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('继续')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _loading = true);
    try {
      await _store.save(_config());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() { _loading = false; _status = '保存失败：$error'; });
    }
  }

  Future<void> _migrate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _status = '正在迁移…'; });
    try {
      final destination = HttpStorage.fromConfig(_config());
      await destination.testConnection();
      final result = await const StorageMigrationService().migrate(
        source: StorageManager.localBackend,
        destination: destination,
        onProgress: (completed, total) {
          if (mounted) setState(() => _status = '正在迁移 $completed/$total');
        },
      );
      if (mounted) {
        setState(() => _status = '迁移完成：${result.migrated} 个文件，跳过 ${result.skipped} 个');
      }
    } catch (error) {
      if (mounted) setState(() => _status = '迁移失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _generateKey() {
    final random = Random.secure();
    _keyController.text = base64Encode(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  @override
  void dispose() {
    _serverController.dispose();
    _credentialController.dispose();
    _keyController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('数据存储后端'),
      content: SizedBox(
        width: 480,
        child: _loading && _serverController.text.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SegmentedButton<StorageBackendType>(
                        segments: const [
                          ButtonSegment(value: StorageBackendType.local, icon: Icon(Icons.folder), label: Text('本地文件')),
                          ButtonSegment(value: StorageBackendType.http, icon: Icon(Icons.cloud), label: Text('HTTP 服务器')),
                        ],
                        selected: {_type},
                        onSelectionChanged: _loading ? null : (value) => setState(() => _type = value.first),
                      ),
                      if (_type == StorageBackendType.http) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _serverController,
                          decoration: const InputDecoration(labelText: '服务器地址', hintText: 'https://example.com'),
                          validator: (value) => value == null || value.trim().isEmpty ? '请输入服务器地址' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<StorageAuthType>(
                          initialValue: _authType,
                          decoration: const InputDecoration(labelText: '认证方式'),
                          items: const [
                            DropdownMenuItem(value: StorageAuthType.jwt, child: Text('JWT Token')),
                            DropdownMenuItem(value: StorageAuthType.apiKey, child: Text('API Key')),
                          ],
                          onChanged: (value) => setState(() => _authType = value!),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _credentialController,
                          obscureText: true,
                          decoration: InputDecoration(labelText: _authType == StorageAuthType.jwt ? 'Token' : 'API Key'),
                          validator: (value) => value == null || value.trim().isEmpty ? '请输入认证凭据' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _keyController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: '端到端加密密钥',
                            suffixIcon: IconButton(
                              tooltip: '生成加密密钥',
                              icon: const Icon(Icons.refresh),
                              onPressed: _generateKey,
                            ),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? '请输入加密密钥' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _userIdController,
                          decoration: const InputDecoration(labelText: '用户标识（可选）'),
                        ),
                      ],
                      if (_status != null) ...[
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerLeft, child: Text(_status!)),
                      ],
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.pop(context), child: const Text('取消')),
        if (_type == StorageBackendType.http)
          OutlinedButton.icon(onPressed: _loading ? null : _test, icon: const Icon(Icons.wifi_tethering), label: const Text('测试连接')),
        if (_type == StorageBackendType.http)
          OutlinedButton.icon(onPressed: _loading ? null : _migrate, icon: const Icon(Icons.upload), label: const Text('迁移本地数据')),
        FilledButton.icon(onPressed: _loading ? null : _save, icon: const Icon(Icons.save), label: const Text('保存')),
      ],
    );
  }
}
