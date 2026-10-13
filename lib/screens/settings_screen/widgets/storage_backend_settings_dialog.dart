import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/storage/http_storage.dart';
import 'package:aboutme/core/storage/storage_backend_config.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/storage/storage_migration_service.dart';
import 'package:aboutme/core/storage/storage_websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';
class StorageBackendSettingsDialog extends StatefulWidget {
  const StorageBackendSettingsDialog({super.key});

  @override
  State<StorageBackendSettingsDialog> createState() =>
      _StorageBackendSettingsDialogState();
}

class _StorageBackendSettingsDialogState
    extends State<StorageBackendSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _credentialController = TextEditingController();
  final _userIdController = TextEditingController();
  final _store = LocalStorageBackendConfigStore();
  StorageBackendType _type = StorageBackendType.local;
  StorageBackendType _originalType = StorageBackendType.local;
  StorageAuthType _authType = StorageAuthType.apiKey;
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
      _userIdController.text = config.userId;
      _loading = false;
    });
  }

  StorageBackendConfig _config() => StorageBackendConfig(
    type: _type,
    serverUrl: _serverController.text,
    authType: _authType,
    credential: _credentialController.text,
    userId: _userIdController.text,
  );

  Future<void> _test() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _status = null;
    });
    try {
      await HttpStorage.fromConfig(_config()).testConnection();
      await StorageWebSocketService.instance.connect(_config());
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
        builder:
            (context) => AlertDialog(
              title: Text('settings_screen_switchStorageBackend'.tr),
              content: Text('settings_screen_switchStorageBackendDesc'.tr,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('app_cancel'.tr),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('app_stillContinue'.tr),
                ),
              ],
            ),
      );
      if (confirmed != true) return;
    }
    setState(() => _loading = true);
    try {
      await _store.save(_config());
      if (_type == StorageBackendType.http) {
        await StorageWebSocketService.instance.connect(_config());
      } else {
        await StorageWebSocketService.instance.dispose();
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = '保存失败：$error';
        });
      }
    }
  }

  Future<void> _migrate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _status = '正在迁移…';
    });
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
        setState(
          () => _status = '迁移完成：${result.migrated} 个文件，跳过 ${result.skipped} 个',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _status = '迁移失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyField(
    TextEditingController controller,
    String label,
  ) async {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    Toast.success('已复制$label');
  }

  @override
  void dispose() {
    _serverController.dispose();
    _credentialController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('settings_screen_storageBackend'.tr),
      content: SizedBox(
        width: 480,
        child:
            _loading && _serverController.text.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<StorageBackendType>(
                          segments: const [
                            ButtonSegment(
                              value: StorageBackendType.local,
                              icon: Icon(Icons.folder),
                              label: Text('本地文件'),
                            ),
                            ButtonSegment(
                              value: StorageBackendType.http,
                              icon: Icon(Icons.cloud),
                              label: Text('HTTP 服务器'),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged:
                              _loading
                                  ? null
                                  : (value) =>
                                      setState(() => _type = value.first),
                        ),
                        if (_type == StorageBackendType.http) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _serverController,
                            decoration: const InputDecoration(
                              labelText: '服务器地址',
                              hintText: 'https://example.com',
                            ),
                            validator:
                                (value) =>
                                    value == null || value.trim().isEmpty
                                        ? '请输入服务器地址'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          const InputDecorator(
                            decoration: InputDecoration(labelText: '认证方式'),
                            child: Text('API Key'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _credentialController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'API Key',
                              suffixIcon: IconButton(
                                tooltip: '复制 API Key',
                                icon: const Icon(Icons.copy),
                                onPressed:
                                    () => _copyField(
                                      _credentialController,
                                      'API Key',
                                    ),
                              ),
                            ),
                            validator:
                                (value) =>
                                    value == null || value.trim().isEmpty
                                        ? '请输入认证凭据'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _userIdController,
                            decoration: const InputDecoration(
                              labelText: '用户标识（可选）',
                            ),
                          ),
                        ],
                        if (_status != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(_status!),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text('app_cancel'.tr),
        ),
        if (_type == StorageBackendType.http)
          OutlinedButton.icon(
            onPressed: _loading ? null : _test,
            icon: const Icon(Icons.wifi_tethering),
            label: Text('settings_screen_testConnection'.tr),
          ),
        if (_type == StorageBackendType.http)
          OutlinedButton.icon(
            onPressed: _loading ? null : _migrate,
            icon: const Icon(Icons.upload),
            label: Text('settings_screen_migrateLocalData'.tr),
          ),
        FilledButton.icon(
          onPressed: _loading ? null : _save,
          icon: const Icon(Icons.save),
          label: Text('app_save'.tr),
        ),
      ],
    );
  }
}
