import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/scripts_center/models/script_info.dart';

/// 脚本卡片组件（两列网格紧凑样式，手绘纸墨风）
///
/// 参考 node_card：纸底墨线卡 + 右下硬偏移墨影，
/// 脚本图标放大贴右上角作背景水印（置于内容层之下，
/// 溢出圆角部分被裁剪）；禁用脚本整体降透明度
class ScriptCard extends StatelessWidget {
  final ScriptInfo script;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onRun;

  const ScriptCard({
    super.key,
    required this.script,
    this.onTap,
    this.onLongPress,
    this.onRun,
  });

  /// 右上角水印图标边长
  static const double _watermarkSize = 88;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final enabled = script.enabled;
    final seed = script.id.hashCode & 0x7fffffff;
    // 启用：主色墨线；禁用：次级墨色
    final inkColor = enabled ? theme.primary : theme.textSub;
    final radius = BorderRadius.circular(14);

    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            // 右下硬偏移墨影（零模糊实底影）
            Positioned.fill(
              left: 3,
              top: 3,
              child: DecoratedBox(
                decoration: dsSketchDecoration(
                  theme: theme,
                  fillColor: theme.ink,
                  stroke: theme.ink,
                  strokeWidth: 1.2,
                  radius: radius,
                  seed: seed + 13,
                ),
              ),
            ),
            // 卡体：纸底 + 墨线框（内容层）
            DecoratedBox(
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: enabled ? theme.surface : theme.surfaceAlt,
                stroke: inkColor,
                radius: radius,
                strokeWidth: 1.8,
                seed: seed,
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  children: [
                    // 右上角图标水印：放大贴角，处于内容层之下，溢出被裁剪
                    Positioned(
                      right: -10,
                      top: -10,
                      child: DsIcon(
                        _getIconKind(script.icon),
                        size: _watermarkSize,
                        color: inkColor.withValues(alpha: 0.12),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 状态指示器 + 脚本名称
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: enabled
                                      ? theme.success
                                      : theme.textSub,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  script.name,
                                  style: DsTypography.heading.copyWith(
                                    color: enabled
                                        ? theme.text
                                        : theme.textSub,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // 版本与作者
                          Text(
                            'v${script.version} · ${script.author}',
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // 描述
                          if (script.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              script.description,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          const Spacer(),

                          // 底部行：类型徽章 + 运行按钮
                          Row(
                            children: [
                              _TypeBadge(script: script, seed: seed + 5),
                              const Spacer(),
                              if (enabled && onRun != null)
                                _RunButton(seed: seed + 7, onTap: onRun!),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 根据图标名称获取手绘图标种类
  DsIconKind _getIconKind(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'code':
        return DsIconKind.code;
      case 'backup':
        return DsIconKind.cloud;
      case 'analytics':
        return DsIconKind.chart;
      case 'settings':
        return DsIconKind.gear;
      case 'sync':
        return DsIconKind.refresh;
      case 'schedule':
        return DsIconKind.clock;
      case 'notification':
        return DsIconKind.bell;
      case 'data':
        return DsIconKind.layers;
      case 'auto':
        return DsIconKind.replay;
      default:
        return DsIconKind.code;
    }
  }
}

/// 类型徽章：淡色 wash + 同色墨圈（module 主色 / standalone 警示色）
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.script, required this.seed});

  final ScriptInfo script;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final color = script.isModule ? theme.primary : theme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: color.withValues(alpha: 0.15),
        stroke: color.withValues(alpha: 0.7),
        strokeWidth: 1.2,
        radius: BorderRadius.circular(4),
        seed: seed,
      ),
      child: Text(
        script.type.toUpperCase(),
        style: DsTypography.label.copyWith(color: color),
      ),
    );
  }
}

/// 运行小方钮：墨线圆角方 + 播放图标
class _RunButton extends StatelessWidget {
  const _RunButton({required this.seed, required this.onTap});

  final int seed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.success.withValues(alpha: 0.14),
          radius: BorderRadius.circular(10),
          strokeWidth: 1.4,
          seed: seed,
        ),
        child: DsIcon(DsIconKind.play, size: 18, color: theme.success),
      ),
    );
  }
}
