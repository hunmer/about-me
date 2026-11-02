import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';

/// 精灵图（视频桌宠）气泡静态布局计算。
///
/// 用户需求：精灵图模式的气泡不需要自定义位置——固定在视频上方
/// 居中显示，宽度与视频实际显示矩形同宽，高度随内容自然伸缩
/// （不是撑成视频同高）。
///
/// 这里是纯函数/纯布局对象（无 StatefulWidget 依赖），镜像
/// [JellyVideoPetStage] 的舞台数学（缩放、水平活动边界、默认
/// 落点），让静态覆盖层（气泡）在没有舞台实例的情况下也能算出
/// 宠物的真实显示矩形；便于单元测试直接覆盖。

/// 启用区域的联合水平包围盒（归一化 0..1）。
///
/// 与舞台水平活动边界的口径一致：人物一边顶到容器边缘即视为
/// 到达边界；无启用区域返回 null（按整画布计算）。
({double left, double right})? jellyVideoPetBodySpan(
  List<VideoPetRegion> regions,
) {
  double? left;
  double? right;
  for (final region in regions) {
    if (!region.enabled) continue;
    left = left == null ? region.x : math.min(left, region.x);
    final regionRight = region.x + region.width;
    right = right == null ? regionRight : math.max(right, regionRight);
  }
  if (left == null || right == null) return null;
  return (left: left, right: right);
}

/// 精灵图宠物在 Home 舞台中的默认显示矩形（逻辑像素，舞台坐标）。
///
/// 镜像 [JellyVideoPetStage] 的布局：
/// - 缩放：`scale = min(1, 容器宽/宠物宽, 可用高/宠物高)`；
/// - 水平活动边界：有区域联合包围盒（[bodySpan]）按包围盒贴边、
///   满宽画布按中心锚点 ±宽/2、其余整画布留在容器内；
/// - 默认落点：水平取活动边界中心（舞台无记忆坐标时的初始值），
///   垂直贴活动区底部（Home 的 initialBottomGap = 0）。
///
/// 宠物会被拖拽/走动而离开默认位置，因此气泡优先跟随舞台上报的
/// 当前显示矩形（JellyVideoPetStage.geometry）；本函数仅在舞台
/// 尚未完成首次布局（上报为 null）时作为兜底锚点。
Rect jellyVideoPetDefaultRect({
  required double layoutWidth,
  required double layoutHeight,
  required double topInset,
  required double bottomInset,
  required double petWidth,
  required double canvasAspectRatio,
  ({double left, double right})? bodySpan,
}) {
  final petHeight = petWidth * canvasAspectRatio;
  final availableHeight = math.max(0.0, layoutHeight - topInset - bottomInset);
  final scale = math.min(
    1.0,
    math.min(
      petWidth > 0 ? layoutWidth / petWidth : 1.0,
      petHeight > 0 ? availableHeight / petHeight : 1.0,
    ),
  );
  final width = petWidth * scale;
  final height = petHeight * scale;
  final fullWidth = width > 0 && (width - layoutWidth).abs() < 0.01;
  final double minX;
  final double maxX;
  final span = bodySpan;
  if (span != null) {
    minX = -span.left * width;
    maxX = math.max(minX, layoutWidth - span.right * width);
  } else if (fullWidth) {
    minX = -width / 2;
    maxX = layoutWidth - width / 2;
  } else {
    minX = 0.0;
    maxX = math.max(0.0, layoutWidth - width);
  }
  final left = (minX + maxX) / 2;
  final top = topInset + math.max(0.0, availableHeight - height);
  return Rect.fromLTWH(left, top, width, height);
}

/// 精灵图气泡的锚定盒（舞台坐标）：视频上方居中、与视频同宽、
/// 高度为视频上方的可用空间（气泡在盒内底部对齐、随内容自然
/// 伸缩，见 [JellyVideoBubbleAboveDelegate]）。
///
/// 视频比容器宽时按容器边距收窄（不出屏）；左右都夹在边距内。
Rect jellyVideoBubbleBoxAboveVideo({
  required double containerWidth,
  required double containerTop,
  required Rect videoRect,
  double gap = 8.0,
  double margin = 12.0,
}) {
  final width = math.min(
    videoRect.width,
    math.max(0.0, containerWidth - margin * 2),
  );
  final left = (videoRect.center.dx - width / 2)
      .clamp(margin, math.max(margin, containerWidth - margin - width))
      .toDouble();
  final top = containerTop;
  final height = math.max(0.0, videoRect.top - gap - containerTop);
  return Rect.fromLTWH(left, top, width, height);
}

/// 精灵图（浮动桌宠）气泡宽度：与视频实际显示宽一致。
///
/// 用户明确要求去掉 160/260 的人为截断——只有屏幕安全宽度
/// （可用包围盒宽度）才允许收窄；视频宽非法（≤0）时返回 0。
double jellyVideoBubbleWidthFor({
  required double videoWidth,
  required double maxWidth,
}) {
  if (videoWidth <= 0) return 0;
  return math.min(videoWidth, math.max(0.0, maxWidth));
}

/// 精灵图气泡布局代理：在锚定盒内水平居中、底部对齐。
///
/// 盒底 = 视频顶 - gap，因此气泡底边固定贴在视频上方；子级高度
/// 由内容自然决定（最多撑满盒高），不会被拉伸成视频同高。
class JellyVideoBubbleAboveDelegate extends SingleChildLayoutDelegate {
  const JellyVideoBubbleAboveDelegate();

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: constraints.maxWidth,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return Offset(
      (size.width - childSize.width) / 2,
      size.height - childSize.height,
    );
  }

  @override
  bool shouldRelayout(covariant JellyVideoBubbleAboveDelegate oldDelegate) {
    return false;
  }
}
