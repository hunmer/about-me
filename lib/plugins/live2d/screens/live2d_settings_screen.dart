import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/tts/models/tts_service_config.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'package:aboutme/plugins/tts/widgets/tts_settings_dialog.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'live2d_archive_form_screen.dart';

/// 文字展示速度的滑杆区间（毫秒/字）
const double _minTypingMs = 20;
const double _maxTypingMs = 200;

/// Live2D 全局设置：语音播报、文字速度、全局悬浮宠物与转发行为。
///
/// 存档选择与模型预览已从这里移除：存档在 Live2D 主界面中选择、
/// 模型在果冻小屋主界面预览；存档内容编辑（名称/模型/Agent/封面）
/// 仍在 [Live2DArchiveFormScreen]。
class Live2DSettingsScreen extends StatefulWidget {
  const Live2DSettingsScreen({super.key, this.initialArchiveId});

  /// 进入设置界面时定位到的存档 id，默认使用当前选中存档
  final String? initialArchiveId;

  @override
  State<Live2DSettingsScreen> createState() => _Live2DSettingsScreenState();
}

class _Live2DSettingsScreenState extends State<Live2DSettingsScreen> {
  final plugin = Live2DPlugin.instance;
  Live2DArchive? archive;
  late double _typingIntervalMs =
      (plugin.settings['typingIntervalMs'] as int? ??
              Live2DPlugin.defaultTypingIntervalMs)
          .toDouble();

  /// 语音设置统一存档绑定的 Agent 上
  AIAgent? _boundAgent;
  bool _autoReadEnabled = false;
  String? _selectedTTSServiceId;
  TTSServiceConfig? _selectedTTSService;

  /// 全局悬浮宠物大小/透明度滑条的本地拖动值（松手才落库）
  double? _petSizeDrag;
  double? _petOpacityDrag;

  @override
  void initState() {
    super.initState();
    archive =
        plugin.archives
            .where((a) => a.id == widget.initialArchiveId)
            .firstOrNull ??
        plugin.selected ??
        (plugin.archives.isNotEmpty ? plugin.archives.first : null);
    _loadBoundAgent();
  }

  /// 加载当前存档绑定的 Agent 语音设置；未绑定时语音区不可用
  Future<void> _loadBoundAgent() async {
    _boundAgent = null;
    _autoReadEnabled = false;
    _selectedTTSServiceId = null;
    final agentId = archive?.agentId;
    if (agentId != null) {
      try {
        _boundAgent = await AgentController().getAgent(agentId);
      } catch (error) {
        debugPrint('加载存档绑定 Agent 失败: $error');
      }
    }
    if (_boundAgent != null) {
      _autoReadEnabled = _boundAgent!.ttsEnabled;
      _selectedTTSServiceId = _boundAgent!.ttsServiceId;
    }
    if (mounted) setState(() {});
    await _loadSelectedTTSService();
  }

  Future<void> _loadSelectedTTSService() async {
    try {
      final manager = TTSPlugin.instance.managerService;
      final service = _selectedTTSServiceId == null
          ? await manager.getDefaultService()
          : await manager.getServiceById(_selectedTTSServiceId!);
      if (mounted) setState(() => _selectedTTSService = service);
    } catch (error) {
      debugPrint('加载 Live2D 播报语音失败: $error');
    }
  }

  Future<void> _setAutoReadEnabled(bool enabled) async {
    final agent = _boundAgent;
    if (agent == null) {
      ToastService.instance.showToast('live2d_bindAgentFirst'.tr);
      return;
    }
    setState(() => _autoReadEnabled = enabled);
    await AgentController().updateAgent(agent.copyWith(ttsEnabled: enabled));
  }

  Future<void> _openTTSSettings() async {
    final agent = _boundAgent;
    if (agent == null) {
      ToastService.instance.showToast('live2d_bindAgentFirst'.tr);
      return;
    }
    final result = await showTTSSettingsDialog(
      context,
      agent: agent,
      initialEnabled: _autoReadEnabled,
      initialServiceId: _selectedTTSServiceId,
    );
    if (!mounted || result == null) return;
    setState(() {
      _autoReadEnabled = result.enabled;
      _selectedTTSServiceId = result.serviceId;
    });
    await AgentController().updateAgent(
      agent.copyWith(
        ttsEnabled: result.enabled,
        ttsServiceId: result.serviceId,
        clearTtsServiceId: result.serviceId == null,
      ),
    );
    await _loadSelectedTTSService();
  }

  String get _selectedVoiceLabel {
    final service = _selectedTTSService;
    if (service == null) {
      return _selectedTTSServiceId == null
          ? 'live2d_defaultVoice'.tr
          : 'live2d_voiceUnavailable'.tr;
    }
    final voice = service.voice ?? service.voiceId;
    return voice == null || voice.isEmpty
        ? service.name
        : '${service.name} · $voice';
  }

  Future<void> _editCurrentArchive() async {
    final id = archive?.id;
    if (id == null) return;
    VoidCallback? saveArchive;
    VoidCallback? deleteArchive;
    await SmoothBottomSheet.showForm(
      context: context,
      title: 'live2d_editArchiveTitle'.tr,
      child: Live2DArchiveFormScreen(
        archiveId: id,
        embedInSheet: true,
        onReady: (save) => saveArchive = save,
        onDeleteReady: (delete) => deleteArchive = delete,
      ),
      onSave: () => saveArchive?.call(),
      onDelete: () => deleteArchive?.call(),
    );
    if (mounted) {
      setState(() => archive = plugin.selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (builderContext) {
          final theme = DSThemeBridge.resolve(builderContext);
          return SuperCupertinoNavigationWrapper(
            title: Text('live2d_settingsTitle'.tr),
            enableLargeTitle: false,
            actions: [
              // actions 经 Overlay 渲染，DS 组件需自带 DSThemeBridge
              if (archive != null)
                DSThemeBridge(
                  child: Builder(
                    builder: (actionContext) {
                      final actionTheme = DSThemeBridge.resolve(actionContext);
                      return DSIconButton(
                        icon: DsIconKind.edit,
                        size: 38,
                        color: actionTheme.surfaceAlt,
                        iconColor: actionTheme.textSub,
                        tooltip: 'live2d_editArchiveTitle'.tr,
                        onPressed: _editCurrentArchive,
                      );
                    },
                  ),
                ),
            ],
            body: _buildBody(builderContext, theme),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppThemeData theme) {
    final current = archive;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.lg,
        theme.spacing.sm,
        theme.spacing.lg,
        MediaQuery.paddingOf(context).bottom + theme.spacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildVoiceSection(theme),
          _buildDisplaySection(theme, current),
          _buildGlobalPetSection(theme),
          _buildBehaviorCard(theme),
        ],
      ),
    );
  }

  /// 当前存档提示：名称 + 模型，避免设置项不知道作用于哪个存档
  Widget _buildArchiveSummary(AppThemeData theme, Live2DArchive current) {
    return WiredDraw(
      child: DSCard(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.md,
        ),
        child: Row(
          children: [
            DsIcon(DsIconKind.bot, size: 22, color: theme.primary),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    current.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                  Text(
                    current.displayModelLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 语音播报 ----------------

  Widget _buildVoiceSection(AppThemeData theme) {
    return _Section(
      theme: theme,
      title: 'live2d_voiceSection'.tr,
      icon: DsIconKind.volumeUp,
      children: [
        _SettingRow(
          theme: theme,
          title: 'live2d_autoReadTitle'.tr,
          subtitle: 'live2d_autoReadSubtitle'.tr,
          trailing: DSSwitch(
            value: _autoReadEnabled,
            onChanged: _setAutoReadEnabled,
          ),
        ),
        if (_autoReadEnabled)
          WiredDraw(
            child: _SettingRow(
              theme: theme,
              title: 'live2d_voiceTitle'.tr,
              subtitle: _selectedVoiceLabel,
              onTap: _openTTSSettings,
              trailing: DsIcon(
                DsIconKind.chevronRight,
                size: 16,
                color: theme.textSub,
              ),
            ),
          ),
      ],
    );
  }

  // ---------------- 显示 ----------------

  Widget _buildDisplaySection(AppThemeData theme, Live2DArchive? current) {
    return _Section(
      theme: theme,
      title: 'live2d_displaySection'.tr,
      icon: DsIconKind.speed,
      children: [
        if (current != null && current.isVideo)
          _SettingRow(
            theme: theme,
            title: 'live2d_videoRandomWalkTitle'.tr,
            subtitle: 'live2d_videoRandomWalkSubtitle'.trParams({
              'name': current.name,
            }),
            trailing: DSSwitch(
              value: current.randomWalkEnabled,
              onChanged: (value) {
                plugin.setArchiveRandomWalkEnabled(current, value);
                setState(() {});
              },
            ),
          ),
        _SliderRow(
          theme: theme,
          title: 'live2d_typingSpeed'.trParams({
            'ms': _typingIntervalMs.round().toString(),
          }),
          value:
              ((_typingIntervalMs - _minTypingMs) /
                      (_maxTypingMs - _minTypingMs))
                  .clamp(0.0, 1.0),
          onChanged: (value) => setState(
            () => _typingIntervalMs =
                _minTypingMs + value * (_maxTypingMs - _minTypingMs),
          ),
          onChangeEnd: (value) {
            final ms = (_minTypingMs + value * (_maxTypingMs - _minTypingMs))
                .round();
            plugin.updateSettings({'typingIntervalMs': ms});
            setState(() => _typingIntervalMs = ms.toDouble());
          },
        ),
      ],
    );
  }

  // ---------------- 全局悬浮宠物 ----------------

  Widget _buildGlobalPetSection(AppThemeData theme) {
    final size = (_petSizeDrag ?? plugin.globalPetSize)
        .clamp(Live2DPlugin.minGlobalPetSize, Live2DPlugin.maxGlobalPetSize)
        .toDouble();
    final opacity = (_petOpacityDrag ?? plugin.globalPetOpacity)
        .clamp(0.2, 1.0)
        .toDouble();
    return _Section(
      theme: theme,
      title: 'live2d_globalPetSection'.tr,
      icon: DsIconKind.sparkle,
      children: [
        _SettingRow(
          theme: theme,
          title: 'live2d_globalPetTitle'.tr,
          subtitle: 'live2d_globalPetSubtitle'.tr,
          trailing: DSSwitch(
            value: plugin.globalPetEnabled,
            onChanged: (value) {
              plugin.setGlobalPetEnabled(value);
              setState(() {});
            },
          ),
        ),
        if (plugin.globalPetEnabled)
          WiredDraw(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plugin.archives.isNotEmpty) ...[
                  SizedBox(height: theme.spacing.sm),
                  Text(
                    'live2d_globalPetChoose'.tr,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  Wrap(
                    spacing: theme.spacing.sm,
                    runSpacing: theme.spacing.sm,
                    children: [
                      DSChip(
                        label: 'live2d_globalPetFollowSelected'.tr,
                        selected: plugin.globalPetArchiveId == null,
                        onSelected: (_) {
                          plugin.setGlobalPetArchiveId(null);
                          setState(() {});
                        },
                      ),
                      for (final item in plugin.archives)
                        DSChip(
                          label: item.name,
                          selected: plugin.globalPetArchiveId == item.id,
                          onSelected: (_) {
                            plugin.setGlobalPetArchiveId(item.id);
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ],
                _SliderRow(
                  theme: theme,
                  title: 'live2d_globalPetSize'.trParams({
                    'px': size.round().toString(),
                  }),
                  value:
                      ((size - Live2DPlugin.minGlobalPetSize) /
                              (Live2DPlugin.maxGlobalPetSize -
                                  Live2DPlugin.minGlobalPetSize))
                          .clamp(0.0, 1.0),
                  onChanged: (value) => setState(
                    () => _petSizeDrag =
                        Live2DPlugin.minGlobalPetSize +
                        value *
                            (Live2DPlugin.maxGlobalPetSize -
                                Live2DPlugin.minGlobalPetSize),
                  ),
                  onChangeEnd: (value) {
                    plugin.setGlobalPetSize(
                      Live2DPlugin.minGlobalPetSize +
                          value *
                              (Live2DPlugin.maxGlobalPetSize -
                                  Live2DPlugin.minGlobalPetSize),
                    );
                    setState(() => _petSizeDrag = null);
                  },
                ),
                _SliderRow(
                  theme: theme,
                  title: 'live2d_globalPetOpacity'.trParams({
                    'value': opacity.toStringAsFixed(1),
                  }),
                  value: ((opacity - 0.2) / 0.8).clamp(0.0, 1.0),
                  onChanged: (value) =>
                      setState(() => _petOpacityDrag = 0.2 + value * 0.8),
                  onChangeEnd: (value) {
                    plugin.setGlobalPetOpacity(0.2 + value * 0.8);
                    setState(() => _petOpacityDrag = null);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------------- 行为 ----------------

  Widget _buildBehaviorCard(AppThemeData theme) {
    return WiredDraw(
      child: DSCard(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.xs,
        ),
        child: _SettingRow(
          theme: theme,
          title: 'live2d_forwardAiReplyTitle'.tr,
          subtitle: 'live2d_forwardAiReplySubtitle'.tr,
          icon: DsIconKind.reply,
          trailing: DSSwitch(
            value: plugin.forwardAiReplyEnabled,
            onChanged: (value) {
              plugin.setForwardAiReplyEnabled(value);
              setState(() {});
            },
          ),
        ),
      ),
    );
  }
}

/// 设置分组：墨线小标题 + 纸底手绘卡片
class _Section extends StatelessWidget {
  const _Section({
    required this.theme,
    required this.title,
    required this.children,
    this.icon,
  });

  final AppThemeData theme;
  final String title;
  final DsIconKind? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: theme.spacing.xs,
              bottom: theme.spacing.sm,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  DsIcon(icon!, size: 16, color: theme.textSub),
                  SizedBox(width: theme.spacing.xs),
                ],
                Text(
                  title,
                  style: DsTypography.heading.copyWith(color: theme.text),
                ),
              ],
            ),
          ),
          DSCard(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置行：图标 + 标题/副标题 + 尾部控件，整行可点
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.theme,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
  });

  final AppThemeData theme;
  final String title;
  final String? subtitle;
  final DsIconKind? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            DsIcon(icon!, size: 20, color: theme.primary),
            SizedBox(width: theme.spacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: DsTypography.body.copyWith(color: theme.text),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: theme.spacing.xs / 2),
                  Text(
                    subtitle!,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: theme.spacing.sm),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

/// 滑杆行：标题（含当前值）+ 手绘滑杆
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.theme,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final AppThemeData theme;
  final String title;

  /// 归一化到 0~1（[DSSlider] 约定）
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DsTypography.body.copyWith(color: theme.text)),
          DSSlider(
            value: value,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}
