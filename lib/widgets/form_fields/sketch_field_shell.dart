import 'package:flutter/material.dart';

import 'package:aboutme/design_system/design_system.dart';

/// 手绘描线风格的表单字段外壳（对齐 [DSInput] 的墨线框样式）
///
/// label 上置（textSub 小字）+ `dsSketchDecoration` 墨线圆角框，
/// 内层输入框需自备 `border: InputBorder.none`。
/// 仅在存在 AppTheme 祖先（DSThemeBridge 包裹）时使用；
/// 无 DS 主题的旧调用点由字段自行回退 Material 样式。
class SketchFieldShell extends StatelessWidget {
  const SketchFieldShell({
    super.key,
    required this.theme,
    this.label,
    this.child,
  });

  final AppThemeData theme;
  final String? label;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: dsSketchDecoration(
            theme: theme,
            radius: theme.radii.lg,
            fillColor: theme.surface,
            stroke: theme.textSub.withValues(alpha: 0.45),
            strokeWidth: 1.6,
          ),
          child: child,
        ),
      ],
    );
  }
}
