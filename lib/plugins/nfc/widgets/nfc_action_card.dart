import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:get/get.dart';

/// NFC 操作卡片（DS 果冻风）
///
/// [compact] 为竖排紧凑布局（配合外层 `Row + Expanded` 使用），
/// 否则为横排整行布局，可通过 [onPreview] 显示数据预览按钮
class NfcActionCard extends StatelessWidget {
  const NfcActionCard({
    super.key,
    required this.name,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.isEnabled,
    required this.isWorking,
    this.workingLabel,
    this.onTap,
    this.onPreview,
    this.compact = false,
  });

  final String name;
  final String description;
  final IconData icon;

  /// 卡片强调色（图标/角标）
  final Color accentColor;
  final bool isEnabled;

  /// 读取/写入进行中
  final bool isWorking;

  /// 进行中替代 [name] 的文案（如"写入中..."）
  final String? workingLabel;
  final VoidCallback? onTap;

  /// 数据预览回调（仅横排布局显示按钮）
  final VoidCallback? onPreview;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final iconTint = isEnabled ? accentColor : theme.textSub;

    final iconChip = Container(
      width: compact ? 64.0 : 56.0,
      height: compact ? 64.0 : 56.0,
      decoration: BoxDecoration(
        color: isEnabled ? accentColor.withValues(alpha: 0.15) : theme.disabled,
        shape: compact ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: compact ? null : BorderRadius.circular(14),
      ),
      child: Center(
        child: isWorking
            ? const DSLoadingDots(size: 9)
            : Icon(icon, size: compact ? 32.0 : 28.0, color: iconTint),
      ),
    );

    final title = Text(
      isWorking ? (workingLabel ?? name) : name,
      textAlign: compact ? TextAlign.center : TextAlign.start,
      style: DsTypography.heading.copyWith(color: theme.text),
    );

    final subtitle = Text(
      description,
      textAlign: compact ? TextAlign.center : TextAlign.start,
      style: DsTypography.caption.copyWith(color: theme.textSub),
    );

    return DSCard(
      onTap: isEnabled && !isWorking ? onTap : null,
      child: compact
          ? Column(
              children: [
                iconChip,
                SizedBox(height: theme.spacing.md),
                title,
                SizedBox(height: theme.spacing.sm),
                subtitle,
              ],
            )
          : Row(
              children: [
                iconChip,
                SizedBox(width: theme.spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      SizedBox(height: theme.spacing.xs),
                      subtitle,
                    ],
                  ),
                ),
                if (onPreview != null) ...[
                  DSIconButton(
                    icon: DsIconKind.info,
                    size: 32,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    tooltip: 'nfc_previewData'.tr,
                    onPressed: isWorking ? null : onPreview,
                  ),
                  SizedBox(width: theme.spacing.sm),
                ],
                DsIcon(
                  DsIconKind.chevronRight,
                  size: 20,
                  color: isEnabled ? accentColor : theme.textSub,
                ),
              ],
            ),
    );
  }
}
