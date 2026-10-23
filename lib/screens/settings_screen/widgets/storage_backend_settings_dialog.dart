import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/storage/http_storage.dart';
import 'package:aboutme/core/storage/storage_backend_config.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/storage/storage_migration_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
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
  final _serverController = TextEditingController();
  final _credentialController = TextEditingController();
  final _userIdController = TextEditingController();
  final _store = LocalStorageBackendConfigStore();
  StorageBackendType _type = StorageBackendType.local;
  StorageBackendType _originalType = StorageBackendType.local;
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
      _serverController.text = config.serverUrl;
      _credentialController.text = config.credential;
      _userIdController.text = config.userId;
      _loading = false;
    });
  }

  StorageBackendConfig _config() => StorageBackendConfig(
    type: _type,
    serverUrl: _serverController.text,
    authType: StorageAuthType.apiKey,
    credential: _credentialController.text,
    userId: _userIdController.text,
  );

  /// HTTP 模式必填项校验，缺失时 toast 提示
  bool _validate() {
    if (_serverController.text.trim().isEmpty) {
      Toast.show('settings_screen_storageServerUrlRequired'.tr);
      return false;
    }
    if (_credentialController.text.trim().isEmpty) {
      Toast.show('settings_screen_storageCredentialRequired'.tr);
      return false;
    }
    return true;
  }

  Future<void> _test() async {
    if (!_validate()) return;
    setState(() {
      _loading = true;
      _status = null;
    });
    final probe = HttpStorage.fromConfig(_config());
    try {
      await probe.testConnection();
      debugPrint('[StorageBackendTest] success url=${_serverController.text}');
      if (mounted) {
        Toast.show('settings_screen_storageConnectionSuccess'.tr);
        setState(() => _status = 'settings_screen_storageConnectionSuccess'.tr);
      }
    } catch (error) {
      debugPrint('[StorageBackendTest] failed: $error');
      if (mounted) {
        Toast.show(
          'settings_screen_storageConnectionFailed'.trParams({
            'error': error.toString(),
          }),
          type: ToastType.error,
        );
        setState(
          () => _status = 'settings_screen_storageConnectionFailed'.trParams({
            'error': error.toString(),
          }),
        );
      }
    } finally {
      probe.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_loading) return;
    if (_type == StorageBackendType.http && !_validate()) {
      return;
    }
    if (_type != _originalType) {
      final confirmed = await showDSDialog<bool>(
        context: context,
        theme: DSThemeBridge.resolve(context),
        builder:
            (context) => DSDialog(
              title: 'settings_screen_switchStorageBackend'.tr,
              message: 'settings_screen_switchStorageBackendDesc'.tr,
              confirmText: 'app_stillContinue'.tr,
              cancelText: 'app_cancel'.tr,
            ),
      );
      if (confirmed != true) return;
    }
    setState(() => _loading = true);
    try {
      await _store.save(_config());
      // 当前页面提示重启生效。保存只更新 bootstrap 配置，不能提前将
      // WS 切到另一账号，而 HTTP/SDK/插件快照仍指向当前账号。
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = 'settings_screen_storageSaveFailed'.trParams({
            'error': error.toString(),
          });
        });
      }
    }
  }

  Future<void> _migrate() async {
    if (!_validate()) return;
    setState(() {
      _loading = true;
      _status = 'settings_screen_storageMigrating'.tr;
    });
    try {
      final destination = HttpStorage.fromConfig(_config());
      await destination.testConnection();
      final result = await const StorageMigrationService().migrate(
        source: StorageManager.localBackend,
        destination: destination,
        onProgress: (completed, total) {
          if (mounted) {
            setState(() {
              _status = 'settings_screen_storageMigrateProgress'.trParams({
                'completed': '$completed',
                'total': '$total',
              });
            });
          }
        },
      );
      if (mounted) {
        setState(
          () => _status = 'settings_screen_storageMigrateDone'.trParams({
            'migrated': '${result.migrated}',
            'skipped': '${result.skipped}',
          }),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = 'settings_screen_storageMigrateFailed'.trParams({
            'error': error.toString(),
          });
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyCredential() async {
    final value = _credentialController.text.trim();
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    Toast.show('settings_screen_storageCopied'.tr);
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
    final theme = DSThemeBridge.resolve(context);
    final isHttp = _type == StorageBackendType.http;

    return DSDialog(
      title: 'settings_screen_storageBackend'.tr,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DSSegmentedControl(
            options: [
              'settings_screen_storageLocalFile'.tr,
              'settings_screen_storageHttpServer'.tr,
            ],
            selected: isHttp ? 1 : 0,
            onChanged:
                _loading
                    ? null
                    : (index) => setState(
                      () => _type =
                          index == 1
                              ? StorageBackendType.http
                              : StorageBackendType.local,
                    ),
          ),
          if (isHttp) ...[
            SizedBox(height: theme.spacing.md),
            DSInput(
              controller: _serverController,
              label: 'settings_screen_storageServerUrl'.tr,
              hint: 'https://example.com',
              keyboardType: TextInputType.url,
            ),
            SizedBox(height: theme.spacing.sm),
            DSInput(
              controller: _credentialController,
              label: 'API Key',
              obscureText: true,
              suffix: DSIconButton(
                icon: DsIconKind.copy,
                size: 34,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'settings_screen_storageCopyApiKey'.tr,
                onPressed: _copyCredential,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            DSInput(
              controller: _userIdController,
              label: 'settings_screen_storageUserId'.tr,
            ),
          ],
          if (_status != null) ...[
            SizedBox(height: theme.spacing.sm),
            Text(
              _status!,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
          if (isHttp) ...[
            SizedBox(height: theme.spacing.md),
            Row(
              children: [
                Expanded(
                  child: DSButton(
                    label: 'settings_screen_testConnection'.tr,
                    icon: DsIconKind.wifi,
                    variant: DSButtonVariant.outline,
                    onPressed: _loading ? null : _test,
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: DSButton(
                    label: 'settings_screen_migrateLocalData'.tr,
                    icon: DsIconKind.upload,
                    variant: DSButtonVariant.outline,
                    onPressed: _loading ? null : _migrate,
                  ),
                ),
              ],
            ),
          ],
          if (_loading && _serverController.text.isEmpty) ...[
            SizedBox(height: theme.spacing.md),
            Center(child: DSLoadingDots(color: theme.textSub)),
          ],
        ],
      ),
      confirmText: 'app_save'.tr,
      cancelText: 'app_cancel'.tr,
      onConfirm: _save,
    );
  }
}
