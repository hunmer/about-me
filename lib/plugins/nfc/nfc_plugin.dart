import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'nfc_controller.dart';
import 'card_handlers/read_card_handler.dart';
import 'card_handlers/custom_write_card_handler.dart';
import 'card_handlers/checkin_card_handler.dart';
import 'card_handlers/goods_usage_card_handler.dart';
import 'card_handlers/habit_timer_card_handler.dart';
import 'card_handlers/tracker_progress_card_handler.dart';

/// NFC控制器插件主视图
class NfcMainView extends StatefulWidget {
  const NfcMainView({super.key});

  @override
  State<NfcMainView> createState() => _NfcMainViewState();
}

class _NfcMainViewState extends State<NfcMainView> {
  late final NfcController _controller;
  late final ReadCardHandler _readCardHandler;
  late final CustomWriteCardHandler _writeCardHandler;
  late final CheckinCardHandler _checkinCardHandler;
  late final GoodsUsageCardHandler _goodsUsageCardHandler;
  late final HabitTimerCardHandler _habitTimerCardHandler;
  late final TrackerProgressCardHandler _trackerProgressCardHandler;

  bool _isReading = false;
  bool _isWriting = false;

  @override
  void initState() {
    super.initState();
    _controller = NfcController();
    _readCardHandler = ReadCardHandler(onRead: _readNfc);
    _writeCardHandler = CustomWriteCardHandler(onWrite: _writeNfcRecords);
    _checkinCardHandler = CheckinCardHandler();
    _goodsUsageCardHandler = GoodsUsageCardHandler();
    _habitTimerCardHandler = HabitTimerCardHandler();
    _trackerProgressCardHandler = TrackerProgressCardHandler();
    _checkNfcStatus();
  }

  Future<void> _checkNfcStatus() async {
    await _controller.checkNfcStatus();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _readNfc() async {
    setState(() {
      _isReading = true;
    });

    // 先显示等待对话框
    if (!mounted) return;

    bool isCancelled = false;

    showDSDialog(
      context: context,
      barrierDismissible: false,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: _NfcWaitingDialog(
          message: 'nfc_pleaseBringPhoneNearNFC'.tr,
          detail: 'nfc_readingData'.tr,
          cancelText: 'nfc_cancel'.tr,
          onCancel: () {
            isCancelled = true;
            Navigator.of(dialogContext).pop();
            setState(() {
              _isReading = false;
            });
          },
        ),
      ),
    );

    try {
      final result = await _controller.readNfc();

      // 如果用户已取消,则不处理结果
      if (isCancelled) return;

      // 关闭等待对话框
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      setState(() {
        _isReading = false;
      });

      if (result.success) {
        final readData = result.data ?? '';
        if (readData.isNotEmpty) {
          _controller.showSuccess('nfc_readSuccess'.tr);
          _showNfcDataDialog(readData);
        } else {
          _controller.showError('nfc_noDataDetected'.tr);
        }
      } else {
        _controller.showError(result.error ?? 'nfc_readFailed'.tr);
      }
    } catch (e) {
      // 如果用户已取消,则不处理错误
      if (isCancelled) return;

      // 关闭等待对话框
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() {
        _isReading = false;
      });
      _controller.showError('nfc_readError'.trParams({'error': e.toString()}));
    }
  }

  /// 写入多条 NFC 记录
  Future<void> _writeNfcRecords(List<Map<String, String>> records) async {
    setState(() {
      _isWriting = true;
    });

    // 显示等待对话框
    if (!mounted) return;

    showDSDialog(
      context: context,
      barrierDismissible: false,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => PopScope(
        canPop: false,
        child: _NfcWaitingDialog(
          message: 'nfc_pleaseBringPhoneNearNFC'.tr,
          detail: 'nfc_writingRecords'
              .trParams({'count': records.length.toString()}),
        ),
      ),
    );

    try {
      final result = await _controller.writeNfcRecords(records);

      // 关闭等待对话框
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      setState(() {
        _isWriting = false;
      });

      if (result.success) {
        _controller.showSuccess('nfc_writeSuccess'.tr);
      } else {
        _controller.showError(result.error ?? 'nfc_writeFailed'.tr);
      }
    } catch (e) {
      // 关闭等待对话框
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() {
        _isWriting = false;
      });
      _controller.showError('nfc_writeError'.trParams({'error': e.toString()}));
    }
  }

  void _showNfcDataDialog(String data) {
    final theme = DSThemeBridge.resolve(context);

    showDSDialog(
      context: context,
      theme: theme,
      builder: (dialogContext) => DSDialog(
        title: 'nfc_nfcData'.tr,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'nfc_readDataLabel'.tr,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
            SizedBox(height: theme.spacing.sm),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(theme.spacing.md),
              decoration: BoxDecoration(
                color: theme.surfaceAlt,
                borderRadius: theme.radii.md,
              ),
              child: SelectableText(
                data,
                style: DsTypography.body.copyWith(color: theme.text),
              ),
            ),
          ],
        ),
        cancelText: 'nfc_close'.tr,
        confirmText: 'nfc_copyData'.tr,
        onConfirm: () {
          Navigator.of(dialogContext).pop();
          Clipboard.setData(ClipboardData(text: data));
          Toast.success('nfc_copiedToClipboard'.tr);
        },
      ),
    );
  }

  /// 处理 NFC 状态图标点击
  void _handleNfcStatusTap() {
    if (!_controller.isNfcSupported) {
      // 设备不支持 NFC
      Toast.error('nfc_deviceNotSupported'.tr);
      return;
    }

    if (!_controller.isNfcEnabled) {
      // NFC 未启用，打开设置
      Toast.info('nfc_nfcDisabled'.tr);
      _controller.openNfcSettings();
    } else {
      // NFC 已启用
      Toast.success('nfc_nfcEnabledToast'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final isNfcReady = _controller.isNfcSupported && _controller.isNfcEnabled;

    return SuperCupertinoNavigationWrapper(
      title: Text('nfc_nfcController'.tr),
      largeTitle: 'nfc_nfcController'.tr,
      enableLargeTitle: false,
      actions: [
        // NFC 状态按钮
        DSIconButton(
          icon: DsIconKind.nfc,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: isNfcReady ? theme.primary : theme.danger,
          tooltip: _controller.isNfcSupported
              ? (_controller.isNfcEnabled
                    ? 'nfc_statusEnabled'.tr
                    : 'nfc_statusDisabled'.tr)
              : 'nfc_deviceNotSupported'.tr,
          onPressed: _handleNfcStatusTap,
        ),
        DSIconButton(
          icon: DsIconKind.refresh,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          tooltip: 'nfc_refreshStatus'.tr,
          onPressed: _checkNfcStatus,
        ),
      ],
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // NFC操作卡片 - 一行两个
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _readCardHandler.buildCard(
                    context,
                    _controller.isNfcEnabled,
                    _isReading,
                  ),
                  const SizedBox(width: 16),
                  _writeCardHandler.buildCard(
                    context,
                    _controller.isNfcEnabled,
                    _isWriting,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 写入签到卡片
              _checkinCardHandler.buildCard(
                context,
                _controller.isNfcEnabled,
                false,
              ),
              const SizedBox(height: 16),
              // 写入物品使用记录卡片
              _goodsUsageCardHandler.buildCard(
                context,
                _controller.isNfcEnabled,
                false,
              ),
              const SizedBox(height: 16),
              // 写入习惯计时卡片
              _habitTimerCardHandler.buildCard(
                context,
                _controller.isNfcEnabled,
                false,
              ),
              const SizedBox(height: 16),
              // 写入目标追踪进度卡片
              _trackerProgressCardHandler.buildCard(
                context,
                _controller.isNfcEnabled,
                false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// NFC 等待对话框：果冻面板 + 加载动画 + 可选取消按钮
class _NfcWaitingDialog extends StatelessWidget {
  const _NfcWaitingDialog({
    required this.message,
    this.detail,
    this.cancelText,
    this.onCancel,
  });

  final String message;

  /// 副标题（当前操作说明）
  final String? detail;

  final String? cancelText;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return JellyBox(
      radius: theme.radii.xxl,
      padding: EdgeInsets.all(theme.spacing.xl),
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DSLoadingDots(size: 14),
          SizedBox(height: theme.spacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: DsTypography.body.copyWith(color: theme.text),
          ),
          if (detail != null) ...[
            SizedBox(height: theme.spacing.sm),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
          if (cancelText != null && onCancel != null) ...[
            SizedBox(height: theme.spacing.xl),
            DSButton(
              label: cancelText!,
              variant: DSButtonVariant.outline,
              onPressed: onCancel,
            ),
          ],
        ],
      ),
    );
  }
}

class NfcPlugin extends PluginBase {
  static NfcPlugin? _instance;

  static NfcPlugin get instance {
    if (_instance == null) {
      _instance = PluginManager.instance.getPlugin('nfc') as NfcPlugin?;
      if (_instance == null) {
        throw StateError('NfcPlugin has not been initialized');
      }
    }
    return _instance!;
  }

  @override
  String get id => 'nfc';

  @override
  IconData get icon => Icons.nfc;

  @override
  Color get color => Colors.orange;

  @override
  Future<void> initialize() async {
    await loadSettings({});
  }

  @override
  Future<void> registerToApp(
    PluginManager pluginManager,
    ConfigManager configManager,
  ) async {
    // 插件已在 initialize() 中完成初始化
    // 这里可以添加额外的应用级注册逻辑
  }

  @override
  Widget buildMainView(BuildContext context) {
    return const NfcMainView();
  }

  @override
  Widget? buildCardView(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              'nfc_pluginName'.tr,
              style: DsTypography.heading.copyWith(color: theme.text),
            ),
            const SizedBox(height: 4),
            Text(
              'nfc_pluginDescription'.tr,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
        ),
      ),
    );
  }

  @override
  String? getPluginName(context) {
    return 'nfc_pluginName'.tr;
  }
}
