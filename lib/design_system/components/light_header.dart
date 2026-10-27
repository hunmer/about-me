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
    this.titleWidget,
    this.trailing,
    this.trailingWidth = _buttonSize,
    this.onBack,
    this.showBack = true,
  });

  /// 标题文本（居中，超出省略）
  final String title;

  /// 自定义标题区（如 TabBar）；非空时优先于 [title] 文本，
  /// 占满中间区域，对齐方式由内容自身决定
  final Widget? titleWidget;

  /// 尾部动作（通常为 38px 圆形 DSIconButton）；null 时占位保持标题居中
  final Widget? trailing;

  /// 尾部动作区宽度；放置多个按钮时调大
  final double trailingWidth;

  /// 返回回调，默认 [Navigator.maybePop]
  final VoidCallback? onBack;

  /// 是否显示返回钮；作为 tab 内嵌的页面传 false
  /// （左侧补等宽占位保持标题居中）
  final bool showBack;

  /// 与圆钮直径一致，用于标题对称
  static const double _buttonSize = 38;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // 尾部动作区超过默认圆钮宽度时，左侧补差保持标题居中
          if (showBack)
            DSIconButton(
              icon: DsIconKind.chevronLeft,
              size: _buttonSize,
              color: theme.surface,
              iconColor: theme.text,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: _buttonSize),
          Expanded(
            child:
                titleWidget ??
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
          ),
          SizedBox(
            width: trailingWidth,
            child: Center(child: trailing),
          ),
        ],
      ),
    );
  }
}
