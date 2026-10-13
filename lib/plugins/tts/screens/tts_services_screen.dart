import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/tts/models/tts_service_config.dart';
import 'package:aboutme/plugins/tts/models/tts_service_type.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'package:aboutme/plugins/tts/widgets/service_editor_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// TTS服务列表界面
class TTSServicesScreen extends StatefulWidget {
  const TTSServicesScreen({super.key});

  @override
  State<TTSServicesScreen> createState() => _TTSServicesScreenState();
}

class _TTSServicesScreenState extends State<TTSServicesScreen> {
  late TTSPlugin _plugin;
  List<TTSServiceConfig> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _plugin = TTSPlugin.instance;
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      final services = await _plugin.managerService.getAllServices();
      setState(() {
        _services = services;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Toast.error('${'tts_loadServicesFailed'.tr}: $e');
      }
    }
  }

  Future<void> _deleteService(TTSServiceConfig service) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) => DSDialog(
            title: 'tts_deleteService'.tr,
            message: 'tts_confirmDelete'.tr,
            cancelText: 'tts_cancel'.tr,
            confirmText: 'tts_deleteService'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await _plugin.managerService.deleteService(service.id);
        _loadServices();
        if (mounted) {
          Toast.success('tts_serviceDeleted'.tr);
        }
      } catch (e) {
        if (mounted) {
          Toast.error('${'tts_deleteFailed'.tr}: $e');
        }
      }
    }
  }

  Future<void> _testService(TTSServiceConfig service) async {
    try {
      await _plugin.speak(
        'tts_voiceTestText'.tr,
        serviceId: service.id,
        onError: (error) {
          if (mounted) {
            Toast.error('${'tts_testFailedPrefix'.tr}: $error');
          }
        },
      );

      if (mounted) {
        Toast.success('tts_testSuccess'.tr);
      }
    } catch (e) {
      if (mounted) {
        Toast.error('${'tts_testFailedPrefix'.tr}: $e');
      }
    }
  }

  Future<void> _toggleService(TTSServiceConfig service) async {
    try {
      final updated = service.copyWith(isEnabled: !service.isEnabled);
      await _plugin.managerService.saveService(updated);
      _loadServices();
    } catch (e) {
      if (mounted) {
        Toast.error('${'tts_updateFailed'.tr}: $e');
      }
    }
  }

  Future<void> _setDefaultService(TTSServiceConfig service) async {
    try {
      // 取消其他服务的默认状态
      for (var s in _services) {
        if (s.id != service.id && s.isDefault) {
          await _plugin.managerService.saveService(
            s.copyWith(isDefault: false),
          );
        }
      }

      await _plugin.managerService.saveService(
        service.copyWith(isDefault: true),
      );
      _loadServices();

      if (mounted) {
        Toast.success('tts_setAsDefaultService'.tr);
      }
    } catch (e) {
      if (mounted) {
        Toast.error('${'tts_setDefaultFailed'.tr}: $e');
      }
    }
  }

  /// 创建新服务（smooth_sheets 底部弹层）
  Future<void> _createService() async {
    final result = await ServiceEditorSheet.show(context);

    if (result != null) {
      try {
        await _plugin.managerService.saveService(result);
        _loadServices();

        if (mounted) {
          Toast.success('tts_serviceAdded'.tr);
        }
      } catch (e) {
        if (mounted) {
          Toast.error('${'tts_addFailed'.tr}: $e');
        }
      }
    }
  }

  /// 编辑服务（smooth_sheets 底部弹层）
  Future<void> _editService(TTSServiceConfig service) async {
    final result = await ServiceEditorSheet.show(context, service: service);

    if (result != null) {
      try {
        await _plugin.managerService.saveService(result);
        _loadServices();

        if (mounted) {
          Toast.success('tts_serviceUpdated'.tr);
        }
      } catch (e) {
        if (mounted) {
          Toast.error('${'tts_updateFailed'.tr}: $e');
        }
      }
    }
  }

  /// 服务操作菜单（底部 sheet）
  ///
  /// [themedContext] 需位于 DSThemeBridge 内，供 showDSBottomSheet 捕获主题
  Future<void> _showServiceActions(
    BuildContext themedContext,
    TTSServiceConfig service,
  ) {
    return showDSBottomSheet(
      context: themedContext,
      title: 'tts_serviceActions'.tr,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DSSheetAction(
            icon: DsIconKind.edit,
            label: 'tts_editService'.tr,
            onTap: () {
              Navigator.pop(sheetContext);
              _editService(service);
            },
          ),
          DSSheetAction(
            icon: DsIconKind.play,
            label: 'tts_test'.tr,
            onTap: () {
              Navigator.pop(sheetContext);
              _testService(service);
            },
          ),
          DSSheetAction(
            icon: service.isEnabled ? DsIconKind.pause : DsIconKind.play,
            label: service.isEnabled
                ? 'tts_disableThisService'.tr
                : 'tts_enableThisService'.tr,
            onTap: () {
              Navigator.pop(sheetContext);
              _toggleService(service);
            },
          ),
          if (!service.isDefault)
            DSSheetAction(
              icon: DsIconKind.star,
              label: 'tts_setAsDefault'.tr,
              onTap: () {
                Navigator.pop(sheetContext);
                _setDefaultService(service);
              },
            ),
          DSSheetAction(
            icon: DsIconKind.trash,
            label: 'tts_deleteService'.tr,
            destructive: true,
            onTap: () {
              Navigator.pop(sheetContext);
              _deleteService(service);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: Text('tts_servicesList'.tr),
      largeTitle: 'tts_servicesList'.tr,
      enableLargeTitle: false,
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.refresh,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'tts_refresh'.tr,
                onPressed: _loadServices,
              );
            },
          ),
        ),
      ],
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return DSThemeBridge(
        child: Center(
          child: DSLoadingDots(
            size: 14,
            label: 'tts_loading'.tr,
          ),
        ),
      );
    }

    if (_services.isEmpty) {
      return DSThemeBridge(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
            child: DSEmptyState(
              emoji: '🎙️',
              title: 'tts_noServicesAvailable'.tr,
              message: 'tts_noServicesHint'.tr,
              actionLabel: 'tts_addService'.tr,
              onAction: _createService,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            // 底部给 FAB 留空间
            bottom: MediaQuery.paddingOf(context).bottom + 96,
          ),
          itemCount: _services.length,
          itemBuilder: (context, index) {
            final service = _services[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              // 新列表项挂载即播墨线描画入场
              child: WiredDraw(child: _buildServiceCard(service)),
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: DSThemeBridge(
            // DSFab 内部取 AppTheme，需包桥
            child: DSFab(onPressed: _createService),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(TTSServiceConfig service) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final accent = service.isEnabled ? theme.primary : theme.disabled;

          return DSListItemCard(
            title: service.name,
            subtitle:
                '${_typeLabel(service.type)} · '
                '${service.isEnabled ? 'tts_enabled'.tr : 'tts_disabled'.tr}',
            icon: _typeIcon(service.type),
            iconColor: accent,
            onTap: () => _editService(service),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (service.isDefault) ...[
                  DSBadge(label: 'tts_defaultService'.tr, fontSize: 10),
                  SizedBox(width: theme.spacing.sm),
                ],
                DSIconButton(
                  icon: DsIconKind.more,
                  size: 36,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  onPressed: () => _showServiceActions(context, service),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _typeLabel(TTSServiceType type) {
    switch (type) {
      case TTSServiceType.system:
        return 'tts_systemTts'.tr;
      case TTSServiceType.http:
        return 'tts_httpService'.tr;
      case TTSServiceType.minimax:
        return 'tts_minimaxService'.tr;
    }
  }

  DsIconKind _typeIcon(TTSServiceType type) {
    switch (type) {
      case TTSServiceType.system:
        return DsIconKind.mic;
      case TTSServiceType.http:
        return DsIconKind.cloud;
      case TTSServiceType.minimax:
        return DsIconKind.bot;
    }
  }
}
