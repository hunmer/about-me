import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import '../theme/app_theme.dart';

/// 手绘加载动画：三颗墨点依次弹跳（skribble WiredLoader）
///
/// 内部委托 [WiredLoader]（dots 节奏），墨点形状与全局粗糙度
/// 档位（Ink style）一致；对外 API 保持 [size]/[color]/[label]。
class DSLoadingDots extends StatelessWidget {
  const DSLoadingDots({super.key, this.size = 12, this.color, this.label});

  /// 单颗墨点的目标直径（内部换算为 WiredLoader 的画布尺寸）
  final double size;
  final Color? color;

  /// 可选文字说明
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        WiredLoader(
          style: WiredLoaderStyle.dots,
          // 原实现三颗 12px 点 + 间距的整体宽约 48，
          // 按 4 倍换算保持调用处观感一致
          size: size * 4,
          color: color ?? theme.primary,
          semanticLabel: label,
        ),
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.textSub,
              ),
            ),
          ),
      ],
    );
  }
}
