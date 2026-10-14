import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 单个 item 的姿态:倾斜角度(度)与水平偏移(px)
@immutable
class StickyPose {
  const StickyPose(this.angleDegrees, this.offsetX);

  final double angleDegrees;
  final double offsetX;
}

/// 确定性随机 ±1 取样:字符串哈希映射,过滤/排序重排后同 key 值不变。
/// album 瀑布流照片格与手绘便签列表/网格共用此取样。
double handDrawnUnitRandom(String source) {
  final h = source.hashCode & 0x7fffffff;
  return (h % 1000 - 500) / 500;
}

/// 手绘便签风列表:按索引循环固定姿态表(参考 nth-child(4n+k) 取样),
/// item 顶部带半透明胶带贴条,鼠标悬浮时角度归零、放大并轻微上移,
/// 模拟"拿起便签"的交互。
class HandDrawnListView extends StatelessWidget {
  const HandDrawnListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.padding,
    this.poses = defaultPoses,
    this.tiltKeyOf,
    this.tapeWidth = 90,
    this.tapeHeight = 24,
    this.tapeColor,
    this.holeColor,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    this.primary,
  });

  /// 默认姿态表:四组角度/偏移按索引循环,相邻项方向交替
  static const List<StickyPose> defaultPoses = [
    StickyPose(-1.8, -4.0),
    StickyPose(1.5, 6.0),
    StickyPose(-1.2, 2.0),
    StickyPose(2.2, -5.0),
  ];

  /// 默认贴条底色(米白纸色)
  static const Color defaultTapeColor = Color(0xFFF8F3E6);

  final int itemCount;

  /// 构建 item,倾斜、胶带与悬浮动效由本组件负责
  final IndexedWidgetBuilder itemBuilder;

  /// 可选分隔符,提供时内部使用 ListView.separated
  final Widget Function(BuildContext context, int index)? separatorBuilder;

  final EdgeInsetsGeometry? padding;

  /// 姿态取样表,按 index % poses.length 循环
  final List<StickyPose> poses;

  /// 提供时改用随机倾斜模式(album 瀑布流同款哈希取样):
  /// 角度 ±[1.2°, 2.6°]、水平偏移 ±6px,由 key 确定性生成,
  /// 重排后同 key 角度不变;此时 [poses] 不生效
  final String Function(int index)? tiltKeyOf;

  /// 顶部胶带贴条尺寸
  final double tapeWidth;
  final double tapeHeight;

  /// 按索引返回贴条底色(不透明),如传入仓库/数据自身颜色;
  /// 不传时使用 [defaultTapeColor]
  final Color? Function(int index)? tapeColor;

  /// 圆孔颜色,默认深色半透明;传页面背景色可获得"真打孔"效果
  final Color? holeColor;

  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final bool? primary;

  @override
  Widget build(BuildContext context) {
    Widget wrappedItemBuilder(BuildContext context, int index) {
      final tiltKey = tiltKeyOf?.call(index);
      return HandDrawnStickyItem(
        pose: tiltKey == null ? poses[index % poses.length] : null,
        tiltKey: tiltKey,
        tapeWidth: tapeWidth,
        tapeHeight: tapeHeight,
        tapeColor: tapeColor?.call(index) ?? defaultTapeColor,
        holeColor: holeColor,
        seed: index,
        child: itemBuilder(context, index),
      );
    }

    if (separatorBuilder != null) {
      return ListView.separated(
        padding: _effectivePadding,
        itemCount: itemCount,
        itemBuilder: wrappedItemBuilder,
        separatorBuilder: separatorBuilder!,
        controller: controller,
        physics: physics,
        shrinkWrap: shrinkWrap,
        primary: primary,
      );
    }
    return ListView.builder(
      padding: _effectivePadding,
      itemCount: itemCount,
      itemBuilder: wrappedItemBuilder,
      controller: controller,
      physics: physics,
      shrinkWrap: shrinkWrap,
      primary: primary,
    );
  }

  /// 贴条上半露出卡片外,顶部自动预留出血边距,避免首条贴条被视口裁剪
  EdgeInsetsGeometry get _effectivePadding {
    final bleed = tapeHeight / 2 + 4;
    final p = padding;
    if (p == null) return EdgeInsets.only(top: bleed);
    if (p is EdgeInsets) return p.copyWith(top: p.top + bleed);
    if (p is EdgeInsetsDirectional) return p.copyWith(top: p.top + bleed);
    return p;
  }
}

/// 倾斜 + skribble 胶带贴条 + 悬浮"拿起"动效的便签 item 容器,
/// 可独立用于任意列表/网格(如 goods 瀑布流、album 照片格)。
///
/// 姿态二选一:[tiltKey] 随机哈希取样(album 瀑布流同款,
/// 角度 ±[1.2°, 2.6°]、偏移 ±6px,同 key 恒定);或 [pose] 固定姿态。
class HandDrawnStickyItem extends StatefulWidget {
  const HandDrawnStickyItem({
    super.key,
    this.pose,
    this.tiltKey,
    this.tapeWidth = 90,
    this.tapeHeight = 24,
    this.tapeColor = HandDrawnListView.defaultTapeColor,
    this.holeColor,
    this.seed,
    required this.child,
  }) : assert(
         pose != null || tiltKey != null,
         'pose 与 tiltKey 至少提供一个',
       );

  /// 固定姿态(与姿态表配合使用)
  final StickyPose? pose;

  /// 随机取样 key(建议传数据 id),提供时优先于 [pose]
  final String? tiltKey;

  final double tapeWidth;
  final double tapeHeight;

  /// 贴条底色(不透明纸胶带色)
  final Color tapeColor;

  /// 圆孔颜色,默认深色半透明;传页面背景色可获得"真打孔"效果
  final Color? holeColor;

  /// skribble 墨迹种子;不传时随机模式由 tiltKey 派生
  final int? seed;

  final Widget child;

  @override
  State<HandDrawnStickyItem> createState() => _HandDrawnStickyItemState();
}

class _HandDrawnStickyItemState extends State<HandDrawnStickyItem> {
  bool _hovering = false;

  /// 随机模式:由 key 哈希派生姿态(幅度 [1.2°, 2.6°] + 偏移)
  static StickyPose _poseFromKey(String key) {
    final u = handDrawnUnitRandom(key);
    final magnitude = 1.2 + u.abs() * 1.4;
    return StickyPose(
      u < 0 ? -magnitude : magnitude,
      handDrawnUnitRandom('$key~offset') * 6,
    );
  }

  StickyPose get _pose =>
      widget.pose ?? _poseFromKey(widget.tiltKey ?? '');

  int get _seed =>
      widget.seed ?? widget.tiltKey.hashCode & 0x7fffffff;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _hovering ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            // 顶部胶带:横跨卡片顶边,一半露出卡片外
            Positioned(
              top: -widget.tapeHeight / 2,
              left: 0,
              right: 0,
              child: Center(
                child: _buildTape(),
              ),
            ),
          ],
        ),
        builder: (context, t, child) {
          // t: 0 = 静置姿态,t: 1 = 悬浮拿起(角度归零、放大 1.04、上移 4px)
          final angle = lerpDouble(_pose.angleDegrees * math.pi / 180, 0, t)!;
          final scale = lerpDouble(1.0, 1.04, t)!;
          final dy = lerpDouble(0.0, -4.0, t)!;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translate(_pose.offsetX, dy)
              ..rotateZ(angle)
              ..scale(scale),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildTape() {
    final theme = DSThemeBridge.resolve(context);
    // 胶带自身带轻微反向角度,避免与卡片倾斜方向完全一致显得死板
    final tapeAngle = _pose.angleDegrees > 0 ? -1.5 : 2.0;
    return Transform.rotate(
      angle: tapeAngle * math.pi / 180,
      // skribble 手绘贴条:墨线描边 + 不透明纸底
      child: Container(
        width: widget.tapeWidth,
        height: widget.tapeHeight,
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: widget.tapeColor,
          radius: BorderRadius.circular(2),
          strokeWidth: 1.4,
          seed: _seed + 1,
        ),
        // 三个手绘圆孔均匀分布,模拟撕页打孔
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (_) {
            return Container(
              width: 8,
              height: 8,
              decoration: dsSketchDecoration(
                theme: theme,
                circle: true,
                fillColor:
                    widget.holeColor ??
                    Colors.black.withValues(alpha: 0.25),
                strokeWidth: 1.2,
                seed: _seed,
              ),
            );
          }),
        ),
      ),
    );
  }
}
