import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:aboutme/core/services/hand_drawn_style_controller.dart';
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

/// 贴条样式
enum HandDrawnTapeStyle {
  /// 顶部居中胶带:skribble 墨线 + 不透明纸底 + 三个圆孔
  centerTape,

  /// 左上角文件夹标签页:墨线纸底(或传入的主题色实底)叠在卡体上沿,
  /// 可显示标题文字(源自 nodes 笔记本卡)
  folderTab,
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
    this.tapeStyle = HandDrawnTapeStyle.centerTape,
    this.tapeTitleOf,
    this.tapeLabelColorOf,
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

  /// 入场瀑布延迟:每项递增 50ms,封顶 500ms 避免长列表尾部延迟过大
  static Duration entranceDelayForIndex(int index) =>
      Duration(milliseconds: (index * 50).clamp(0, 500));

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
  /// 不传时由贴条样式决定默认色(centerTape 米白、folderTab 主题纸底)
  final Color? Function(int index)? tapeColor;

  /// 圆孔颜色,默认深色半透明;传页面背景色可获得"真打孔"效果
  final Color? holeColor;

  /// 贴条样式,默认顶部居中胶带
  final HandDrawnTapeStyle tapeStyle;

  /// 按索引返回贴条标题文字(folderTab 标签页显示)
  final String? Function(int index)? tapeTitleOf;

  /// 按索引返回贴条文字颜色(如选中态配 onPrimary)
  final Color? Function(int index)? tapeLabelColorOf;

  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final bool? primary;

  @override
  Widget build(BuildContext context) {
    // 监听全局开关：贴条关闭时顶部出血边距同步取消
    return ListenableBuilder(
      listenable: HandDrawnStyleController(),
      builder: (context, _) => _buildList(context),
    );
  }

  Widget _buildList(BuildContext context) {
    Widget wrappedItemBuilder(BuildContext context, int index) {
      final tiltKey = tiltKeyOf?.call(index);
      return HandDrawnStickyItem(
        pose: tiltKey == null ? poses[index % poses.length] : null,
        tiltKey: tiltKey,
        tapeWidth: tapeWidth,
        tapeHeight: tapeHeight,
        tapeColor: tapeColor?.call(index),
        holeColor: holeColor,
        tapeStyle: tapeStyle,
        tapeTitle: tapeTitleOf?.call(index),
        tapeLabelColor: tapeLabelColorOf?.call(index),
        seed: index,
        entranceDelay: entranceDelayForIndex(index),
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
    final bleed =
        HandDrawnStyleController().tapeEnabled ? tapeHeight / 2 + 4 : 0.0;
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
    this.tapeColor,
    this.holeColor,
    this.showTape = true,
    this.tapeStyle = HandDrawnTapeStyle.centerTape,
    this.tapeTitle,
    this.tapeLabelColor,
    this.seed,
    this.entranceDelay = Duration.zero,
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

  /// 贴条底色;不传时由样式决定(centerTape 米白、folderTab 主题纸底)
  final Color? tapeColor;

  /// 圆孔颜色,默认深色半透明;传页面背景色可获得"真打孔"效果
  final Color? holeColor;

  /// 是否绘制顶部贴条;卡片自带贴条样式时置 false 只保留倾斜与悬浮
  final bool showTape;

  /// 贴条样式
  final HandDrawnTapeStyle tapeStyle;

  /// 贴条标题文字(folderTab 标签页显示)
  final String? tapeTitle;

  /// 贴条文字颜色(如选中态配 onPrimary),默认主题文字色
  final Color? tapeLabelColor;

  /// skribble 墨迹种子;不传时随机模式由 tiltKey 派生
  final int? seed;

  /// 入场动画延迟(淡入+上滑);null 表示该项关闭入场动画,
  /// 全局开关 HandDrawnStyleController.entranceEnabled 关闭时同样不生效
  final Duration? entranceDelay;

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

  StickyPose get _pose {
    // 全局倾斜关闭:姿态归零,只保留悬浮拿起动效
    if (!HandDrawnStyleController().tiltEnabled) {
      return const StickyPose(0, 0);
    }
    return widget.pose ?? _poseFromKey(widget.tiltKey ?? '');
  }

  int get _seed =>
      widget.seed ?? widget.tiltKey.hashCode & 0x7fffffff;

  @override
  Widget build(BuildContext context) {
    // 监听全局开关:贴条/倾斜状态变化时本 item 即时重建
    return ListenableBuilder(
      listenable: HandDrawnStyleController(),
      builder: (context, _) => MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _hovering ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: _buildStack(),
          builder: (context, t, child) {
            // t: 0 = 静置姿态,t: 1 = 悬浮拿起(角度归零、放大 1.04、上移 4px)
            final angle =
                lerpDouble(_pose.angleDegrees * math.pi / 180, 0, t)!;
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
      ),
    );
  }

  /// 按贴条样式组装 卡体+贴条 的层级结构
  Widget _buildStack() {
    // 全局贴条开关关闭时视为 showTape=false
    final showTape =
        widget.showTape && HandDrawnStyleController().tapeEnabled;
    final folderTab =
        showTape && widget.tapeStyle == HandDrawnTapeStyle.folderTab;
    final content = _wrapEntrance(widget.child);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // folderTab:卡体下移,标签叠在卡体上沿形成文件夹标签效果
        folderTab
            ? Padding(
                padding: const EdgeInsets.only(top: 16),
                child: content,
              )
            : content,
        if (showTape)
          switch (widget.tapeStyle) {
            // 顶部胶带:横跨卡片顶边,一半露出卡片外
            HandDrawnTapeStyle.centerTape => Positioned(
              top: -widget.tapeHeight / 2,
              left: 0,
              right: 0,
              child: Center(child: _buildTape()),
            ),
            // 左上角标签页,叠在卡体上沿
            HandDrawnTapeStyle.folderTab => Positioned(
              left: 4,
              top: 0,
              child: _buildFolderTab(),
            ),
          },
      ],
    );
  }

  /// 入场动画(源自 timeline 卡片效果):延迟后淡入并向上滑入,
  /// 延迟随列表索引递增形成瀑布感;全局开关或 entranceDelay 关闭时直出
  Widget _wrapEntrance(Widget child) {
    final delay = widget.entranceDelay;
    if (delay == null || !HandDrawnStyleController().entranceEnabled) {
      return child;
    }
    return Animate(
      effects: [
        FadeEffect(duration: 300.ms, delay: delay),
        SlideEffect(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
          duration: 400.ms,
          delay: delay,
          curve: Curves.easeOut,
        ),
      ],
      child: child,
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
          fillColor:
              widget.tapeColor ?? HandDrawnListView.defaultTapeColor,
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

  /// 左上角文件夹标签页贴条:墨线纸底(或传入色实底)+ 标题文字
  Widget _buildFolderTab() {
    final theme = DSThemeBridge.resolve(context);
    return ConstrainedBox(
      // Positioned 无右约束,长标题需限宽避免溢出屏幕
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 32,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: widget.tapeColor ?? theme.surface,
          // 传入选中色时描边同色融为一体,默认跟墨线
          stroke: widget.tapeColor ?? theme.ink,
          strokeWidth: 1.8,
          radius: const BorderRadius.vertical(top: Radius.circular(10)),
          seed: _seed + 1,
        ),
        child: Text(
          widget.tapeTitle ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DsTypography.body.copyWith(
            color: widget.tapeLabelColor ?? theme.text,
          ),
        ),
      ),
    );
  }
}
