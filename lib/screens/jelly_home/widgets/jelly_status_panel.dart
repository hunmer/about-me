import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/screens/jelly_home/companion_controller.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/widgets/picker/avatar_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'jelly_configurable_image.dart';
import 'jelly_status_panel_settings.dart';

/// 状态项种类（图标与取值见 [_StatusItem] / [_value]）
enum JellyStatusItemType { mood, energy, affection, companionDays }

/// 顶部状态面板：手绘组件构建（纸底 + 排线 + 墨线框），长按更换头像
class JellyStatusPanel extends StatefulWidget {
  const JellyStatusPanel({super.key, required this.controller});

  final CompanionController controller;

  @override
  State<JellyStatusPanel> createState() => _JellyStatusPanelState();
}

class _JellyStatusPanelState extends State<JellyStatusPanel> {
  static const _level = 17;
  static const _experience = 568;
  static const _experienceMax = 1250;

  final _settings = JellyStatusPanelSettings.instance;

  @override
  void initState() {
    super.initState();
    _settings.load();
    eventManager.subscribe(
      Live2DPlugin.archiveSelectedEvent,
      _onArchiveSelected,
    );
  }

  @override
  void dispose() {
    eventManager.unsubscribe(
      Live2DPlugin.archiveSelectedEvent,
      _onArchiveSelected,
    );
    super.dispose();
  }

  /// 选中档案变化后重建，头像同步为新档案的封面
  void _onArchiveSelected(EventArgs args) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 900,
          maxHeight: JellyStatusPanelSettings.maxDisplayHeight,
        ),
        child: AnimatedBuilder(
          animation: _settings,
          builder: (context, _) => AspectRatio(
            aspectRatio: JellyStatusPanelSettings.panelAspectRatio,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPress: () => _editAvatar(theme),
              child: DsSketchPanel(
                theme: theme,
                radius: theme.radii.xxl,
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.xl,
                  vertical: theme.spacing.sm,
                ),
                child: AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, _) => Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _buildContent(theme),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AppThemeData theme) {
    final types = JellyStatusItemType.values;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AvatarFrame(theme: theme, child: _buildAvatar()),
        SizedBox(width: theme.spacing.lg),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _settings.userName,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(width: theme.spacing.md),
                Text(
                  'Lv.$_level',
                  style: DsTypography.heading.copyWith(
                    color: theme.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 220,
                  height: 18,
                  child: _SketchProgressBar(
                    theme: theme,
                    value: _experience / _experienceMax,
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Text(
                  '$_experience/$_experienceMax',
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < types.length; i++) ...[
                  if (i > 0) SizedBox(width: theme.spacing.lg),
                  _StatusItem(
                    theme: theme,
                    type: types[i],
                    value: _value(types[i]),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// 头像优先取选中 Live2D 档案的封面，无封面时回退用户头像
  Widget _buildAvatar() {
    final cover = Live2DPlugin.instance.selected?.coverPath;
    if (cover != null && cover.isNotEmpty) {
      return JellyConfigurableImage(path: cover, fit: BoxFit.cover);
    }
    final avatarPath = _settings.avatarPath;
    if (avatarPath == null) {
      return Image.asset(
        'assets/images/default_avatar.jpg',
        fit: BoxFit.cover,
      );
    }
    return AdaptiveImage(imagePath: avatarPath, fit: BoxFit.cover);
  }

  /// 长按更换用户头像（档案封面优先级更高，见 [_buildAvatar]）
  Future<void> _editAvatar(AppThemeData theme) {
    return showDSDialog(
      context: context,
      builder: (dialogContext) => DSDialog(
        title: 'screens_configureTopPanel'.tr,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarPicker(
              size: 54,
              username: _settings.userName,
              currentAvatarPath: _settings.avatarPath,
              defaultAvatarAsset: 'assets/images/default_avatar.jpg',
              saveDirectory: 'avatars',
              onAvatarChanged: _settings.saveAvatar,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'screens_topPanelAvatarHint'.tr,
                style: DsTypography.body.copyWith(color: theme.textSub),
              ),
            ),
          ],
        ),
        confirmText: 'app_save'.tr,
        cancelText: 'app_cancel'.tr,
      ),
    );
  }

  String _value(JellyStatusItemType type) => switch (type) {
    JellyStatusItemType.mood => '${widget.controller.mood}',
    JellyStatusItemType.energy => '${widget.controller.energy}',
    JellyStatusItemType.affection => '${widget.controller.affection}',
    JellyStatusItemType.companionDays =>
      '${widget.controller.totalCompanionDays}天',
  };
}

/// 头像 + 手绘墨线圆环边框
class _AvatarFrame extends StatelessWidget {
  const _AvatarFrame({required this.theme, required this.child});

  static const double size = 92;

  final AppThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(child: child),
          IgnorePointer(
            child: DecoratedBox(
              decoration: dsSketchDecoration(theme: theme, circle: true),
            ),
          ),
        ],
      ),
    );
  }
}

/// 手绘经验条：墨线胶囊轨道 + 实底填充
class _SketchProgressBar extends StatelessWidget {
  const _SketchProgressBar({required this.theme, required this.value});

  final AppThemeData theme;
  final double value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: dsSketchDecoration(
        theme: theme,
        radius: theme.radii.pill,
        fillColor: theme.hatch,
        strokeWidth: 1.6,
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: ClipRRect(
          borderRadius: theme.radii.pill,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: theme.primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// 单个状态项：手绘图标 + 数值
class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.theme,
    required this.type,
    required this.value,
  });

  final AppThemeData theme;
  final JellyStatusItemType type;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DsIcon(_icon(type), size: 18, color: theme.primaryText),
        const SizedBox(width: 4),
        Text(value, style: DsTypography.heading.copyWith(color: theme.text)),
      ],
    );
  }

  DsIconKind _icon(JellyStatusItemType type) => switch (type) {
    JellyStatusItemType.mood => DsIconKind.mood,
    JellyStatusItemType.energy => DsIconKind.fire,
    JellyStatusItemType.affection => DsIconKind.heart,
    JellyStatusItemType.companionDays => DsIconKind.calendarCheck,
  };
}
