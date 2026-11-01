import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../video/video_pet_manifest.dart';
import '../video/video_pet_player_state.dart';

/// 视频宠物区域命中盒：在 Flutter hit-test 阶段把拖拽命中限定在
/// manifest.regions 中 enabled=true 的归一化矩形内。
///
/// - 复用 [videoPetContainPoint]（contain letterbox 感知）做视图→归一化坐标
///   转换，再用 [VideoPetManifest.hitTest] 判定区域，与播放器内部
///   点按命中链路完全同源（含缩放/竖视频，比例换算与展示尺寸无关）。
/// - 区域不命中时 [hitTest] 直接返回 false：指针事件根本不会到达子树的
///   Listener/GestureDetector，自然穿透到下层页面（非手势阶段过滤）。
/// - manifest 为 null（Live2D 模型或视频清单未解析）：整盒命中，保持
///   既有拖拽行为。
/// - manifest.regions 为空（未配置任何区域）：整盒命中（可用性兜底）。
/// - 配置了区域但全部 enabled=false：处处穿透（用户显式禁用拖拽）。
/// - 拖拽一旦在区域内开始，后续 move/up 由手势竞技场路由，
///   手指漂出区域不影响本次拖拽（标准行为）。
class VideoPetRegionHitBox extends SingleChildRenderObjectWidget {
  const VideoPetRegionHitBox({super.key, required this.manifest, super.child});

  /// 视频桌宠清单；null = 不做区域过滤（整盒命中）
  final VideoPetManifest? manifest;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderVideoPetRegionHitBox(manifest: manifest);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderVideoPetRegionHitBox renderObject,
  ) {
    renderObject.manifest = manifest;
  }
}

class _RenderVideoPetRegionHitBox extends RenderProxyBox {
  _RenderVideoPetRegionHitBox({required VideoPetManifest? manifest})
    : _manifest = manifest;

  VideoPetManifest? _manifest;

  set manifest(VideoPetManifest? value) {
    if (identical(value, _manifest)) return;
    _manifest = value;
    // 命中区域变化不影响布局/绘制，无需 markNeedsLayout
  }

  /// 区域命中判定：返回 true 才允许命中子树（拖拽手势所在）。
  bool _hitsRegion(Offset position) {
    final manifest = _manifest;
    if (manifest == null || manifest.regions.isEmpty) {
      return true;
    }
    final point = videoPetContainPoint(
      x: position.dx,
      y: position.dy,
      width: size.width,
      height: size.height,
      canvasWidth: manifest.canvasWidth,
      canvasHeight: manifest.canvasHeight,
    );
    // letterbox 区（画布外）或未命中任何 enabled 区域 → 穿透
    return point != null && manifest.hitTest(point.x, point.y) != null;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.isEmpty) return false;
    if (!_hitsRegion(position)) return false;
    return super.hitTest(result, position: position);
  }
}
