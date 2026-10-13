import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'button.dart';
import 'icons.dart';

/// 轻量手绘页面顶栏：返回圆钮 + 居中标题 + 尾部动作
///
/// 用于不需要 [SuperCupertinoNavigationWrapper] 完整能力（大标题/搜索/过滤栏）
/// 的简单子页面（表单、详情页）。标题恒居中：尾部无动作时保留与返回钮等宽的占位。
///
/// 需要 AppTheme 祖先（页面外层包 DSThemeBridge）。
class DSLightHeader extends StatelessWidget {
  const DSLightHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onBack,
  });

  /// 标题文本（居中，超出省略）
  final String title;

  /// 尾部动作（通常为 38px 圆形 DSIconButton）；null 时占位保持标题居中
  final Widget? trailing;

  /// 返回回调，默认 [Navigator.maybePop]
  final VoidCallback? onBack;

  /// 与圆钮直径一致，用于标题对称
  static const double _buttonSize = 38;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          DSIconButton(
            icon: DsIconKind.chevronLeft,
            size: _buttonSize,
            color: theme.surface,
            iconColor: theme.text,
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
          ),
          SizedBox(
            width: _buttonSize,
            child: Center(child: trailing),
          ),
        ],
      ),
    );
  }
}
