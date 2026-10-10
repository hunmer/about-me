import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/widgets/adaptive_switch.dart';
import 'package:aboutme/plugins/scripts_center/models/script_info.dart';

/// 脚本卡片组件（两列网格紧凑样式）
///
/// 参考 DSListItemCard：卡片内部为脚本色调亮的浅色底 + 原色描边，
/// 脚本图标放大后贴在卡片右下角作为背景水印，置于内容层之下，
/// 超出圆角的部分被裁剪
class ScriptCard extends StatelessWidget {
  final ScriptInfo script;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onRun;

  const ScriptCard({
    super.key,
    required this.script,
    this.onTap,
    this.onLongPress,
    this.onToggle,
    this.onRun,
  });

  /// 右下角水印图标边长
  static const double _watermarkSize = 88;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = script.enabled;
    final baseColor = enabled ? Colors.deepPurple : Colors.grey;
    final cardColor = Color.lerp(baseColor, Colors.white, 0.85);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: baseColor, width: 1.8),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          children: [
            // 右下角图标水印：放大贴角，处于内容层之下，溢出被裁剪
            Positioned(
              right: -10,
              bottom: -10,
              child: Opacity(
                opacity: 0.12,
                child: Icon(
                  _getIconData(script.icon),
                  size: _watermarkSize,
                  color: baseColor,
                ),
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
                          color: enabled ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          script.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: enabled
                                ? theme.textTheme.bodyLarge?.color
                                : Colors.grey,
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
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // 描述
                  if (script.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      script.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: enabled ? theme.hintColor : Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const Spacer(),

                  // 底部行：类型徽章 + 运行按钮 + 启用开关
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (script.isModule
                                  ? Colors.blue
                                  : Colors.orange)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          script.type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: script.isModule
                                ? Colors.blue
                                : Colors.orange,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (enabled && onRun != null)
                        IconButton(
                          onPressed: onRun,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(
                            Icons.play_arrow_rounded,
                            size: 22,
                            color: Colors.green,
                          ),
                          tooltip: 'scripts_center_run'.tr,
                        ),
                      AdaptiveSwitch(
                        value: enabled,
                        onChanged: onToggle,
                        activeThumbColor: Colors.deepPurple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 根据图标名称获取IconData
  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'code':
        return Icons.code;
      case 'backup':
        return Icons.backup;
      case 'analytics':
        return Icons.analytics;
      case 'settings':
        return Icons.settings;
      case 'sync':
        return Icons.sync;
      case 'schedule':
        return Icons.schedule;
      case 'notification':
        return Icons.notifications;
      case 'data':
        return Icons.storage;
      case 'auto':
        return Icons.autorenew;
      default:
        return Icons.code;
    }
  }
}
