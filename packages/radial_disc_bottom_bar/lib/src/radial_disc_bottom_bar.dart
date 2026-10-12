import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart'
    show
        DrawConfig,
        RoughBoxShape,
        RoughDrawingStyle,
        RoughPen,
        SolidFiller,
        WaveredContour,
        waverPath,
        waveredPolygons;

import 'rough_edge_decoration.dart';

import 'geometry.dart';
import 'spring.dart';
import 'style.dart';
import 'widgets.dart';

/// 上层子栏的展示策略
enum RadialSubBarBehavior {
  /// 前半部分 tab 展示子栏，切到后半部分自动收起（参考实现默认）
  auto,

  /// 所有 tab 下均展示子栏
  always,

  /// 只显示主弧形 dock
  never,
}

/// 子栏分段选项
enum RadialSubOption { left, right }

/// 上层子栏的图标动作项（沿子栏弧线均匀排布的圆钮，与 [RadialDiscBottomBar.subLabels] 互斥）
class RadialSubAction {
  const RadialSubAction({
    required this.label,
    required this.icon,
    this.onTap,
    this.selected = false,
  });

  /// 语义标签 / 无障碍描述（圆钮不渲染文字）
  final String label;

  /// 圆钮内图标；选中态圆钮换主题色实底，图标颜色仍由
  /// [RadialDiscBarStyle.activeIconColor] 经 IconTheme 下发
  final Widget icon;

  final VoidCallback? onTap;

  /// 激活态：圆钮以 activePillColor 实底高亮
  final bool selected;
}

/// 弧形圆盘导航栏的 tab 项
class RadialDiscTab {
  const RadialDiscTab({
    required this.label,
    required this.iconBuilder,
    this.badge,
  });

  /// 语义标签 / 无障碍描述（弧形 dock 不渲染文字）
  final String label;

  /// 图标构建器，[selected] 为当前选中态，便于调用方切换颜色
  final Widget Function(BuildContext context, bool selected) iconBuilder;

  /// 图标右上角徽标（如小红点）
  final Widget? badge;
}

/// 双层同心圆弧浮动底部导航栏
///
/// - 主层：弧形扇环 dock，tab 沿圆弧排布并按切线方向旋转，
///   选中药丸以弹簧物理沿弧线滑动
/// - 上层：可折叠子栏（左右圆按钮 + 中间双选项分段药丸）
/// - [floatingAction]：子栏右圆钮位置的常驻浮动操作钮（如 FAB）
///
/// 固有尺寸 380×146（仅 dock 时自动裁掉上下空区为 380×78），
/// 更窄的容器中请用 `FittedBox(fit: BoxFit.scaleDown)` 等比缩放。
class RadialDiscBottomBar extends StatelessWidget {
  const RadialDiscBottomBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    this.onTabChange,
    this.subBarBehavior = RadialSubBarBehavior.auto,
    this.subOption = RadialSubOption.left,
    this.onSubOptionChange,
    this.subBarVisible,
    this.subLabels,
    this.subActions,
    this.leadingAction,
    this.onLeadingTap,
    this.trailingAction,
    this.onTrailingTap,
    this.trailingSelected = false,
    this.floatingAction,
    this.style,
    this.frosted = false,
    this.frostSigma = 10,
    this.hapticsEnabled = true,
  }) : assert(tabs.length > 0, 'tabs 不能为空'),
       assert(
         subLabels == null || subActions == null,
         'subLabels 与 subActions 不能同时使用',
       );

  final List<RadialDiscTab> tabs;
  final int activeIndex;
  final ValueChanged<int>? onTabChange;

  final RadialSubBarBehavior subBarBehavior;
  final RadialSubOption subOption;
  final ValueChanged<RadialSubOption>? onSubOptionChange;

  /// 手动覆盖子栏显隐（null 时按 [subBarBehavior] 策略推断）。
  /// 需与常驻子栏元素搭配：显隐切换经弹簧折叠动画过渡；
  /// 元素本身随条件增删则是瞬间挂载/卸载，没有过渡
  final bool? subBarVisible;

  final (String, String)? subLabels;

  /// 上层子栏的图标动作（与 [subLabels] 互斥），沿子栏弧线均匀排布
  final List<RadialSubAction>? subActions;

  /// 子栏左侧圆按钮图标（null 则不渲染该按钮）。
  /// 无 subLabels 时圆按钮不画空胶囊，常驻浮动在子栏弧线左端
  final Widget? leadingAction;
  final VoidCallback? onLeadingTap;

  /// 子栏右侧圆按钮图标（null 则不渲染该按钮）。
  /// 无 subLabels 时圆按钮不画空胶囊，常驻浮动在子栏弧线右端
  final Widget? trailingAction;
  final VoidCallback? onTrailingTap;

  /// 右侧圆按钮激活态：与 [RadialSubAction.selected] 同款主题色实底
  final bool trailingSelected;

  /// 停靠在子栏右圆钮位置（±15.4° 上层弧线，参考设计 eye 钮）的
  /// 浮动操作钮（如 FAB），自带手势与外观，常驻不随子栏折叠；
  /// 仅 dock 模式下渲染，启用子栏时请改用子栏 [trailingAction]
  final Widget? floatingAction;

  final RadialDiscBarStyle? style;

  /// 扇环用背景模糊做磨砂玻璃效果（需父级无遮挡背景）
  final bool frosted;

  /// 磨砂玻璃模糊强度
  final double frostSigma;

  /// 点按时触发 HapticFeedback.selectionClick
  final bool hapticsEnabled;

  /// 仅 dock 时裁掉的画布上方空区高度（主扇环弧顶 y=56）
  static const double _dockCropTop = 55;

  /// 浮动内容（FAB 顶 ≈30 / 35px 圆钮顶 ≈34）模式下更小的上裁剪
  static const double _floatActionCropTop = 28;

  /// 仅 dock 时裁掉的画布下方空区高度（主扇环最低点 y≈133）
  static const double _dockCropBottom = 13;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style ??
        RadialDiscBarStyle.fromBrightness(
          MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark,
        );
    final count = tabs.length;
    final index = activeIndex.clamp(0, count - 1);
    // 子栏胶囊（含折叠动画）只在有分段选项 subLabels 或图标动作
    // subActions 时出现；仅传圆按钮时不画空胶囊，圆按钮以常驻浮动
    // 圆盘渲染在子栏弧线两端
    final subBarPossible =
        subBarBehavior != RadialSubBarBehavior.never &&
        (subLabels != null || (subActions?.isNotEmpty ?? false));
    final hasFloatingDiscs =
        !subBarPossible && (leadingAction != null || trailingAction != null);
    final wantsSubBar = subBarVisible ??
        switch (subBarBehavior) {
          RadialSubBarBehavior.never => false,
          RadialSubBarBehavior.always => subBarPossible,
          RadialSubBarBehavior.auto =>
            subBarPossible && index <= (count - 1) ~/ 2,
        };

    Widget scene = SizedBox(
      width: RadialGeometry.canvasWidth,
      height: RadialGeometry.canvasHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. 背景画布：双层扇环 + 子栏弧形滑动药丸。
          //    磨砂模式下拆成两遍绘制：阴影不裁剪，玻璃体在 ClipPath
          //    + BackdropFilter 内绘制，保证投影不被玻璃边界切断
          SpringBuilder(
            value: wantsSubBar ? 1.0 : 0.0,
            stiffness: 420,
            damping: 30,
            builder: (context, fold) => SpringBuilder(
              value: subOption == RadialSubOption.right ? 1.0 : 0.0,
              stiffness: 450,
              damping: 34,
              builder: (context, optionT) => RepaintBoundary(
                child: frosted
                    ? _buildFrostedBackground(resolvedStyle, fold, optionT)
                    : CustomPaint(
                        size: const Size(
                          RadialGeometry.canvasWidth,
                          RadialGeometry.canvasHeight,
                        ),
                        painter: _ScenePainter(
                          style: resolvedStyle,
                          fold: fold,
                          optionT: optionT,
                          hasSubLabels: subLabels != null,
                        ),
                      ),
              ),
            ),
          ),
          // 2. 上层子栏交互控件（随折叠进度淡入缩放）
          if (subBarPossible)
            SpringBuilder(
              value: wantsSubBar ? 1.0 : 0.0,
              stiffness: 420,
              damping: 30,
              builder: (context, fold) => IgnorePointer(
                ignoring: !wantsSubBar,
                child: Opacity(
                  opacity: fold.clamp(0.0, 1.0),
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..scale(0.92 + 0.08 * fold.clamp(0.0, 1.0)),
                    // Stack 全是 Positioned 子项时尺寸会塌成 0×0（绘制正常
                    // 但不可命中），显式给定画布尺寸
                    child: SizedBox(
                      width: RadialGeometry.canvasWidth,
                      height: RadialGeometry.canvasHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _roundButton(
                            angle: RadialGeometry.leadingAngle,
                            icon: leadingAction,
                            onTap: onLeadingTap,
                            style: resolvedStyle,
                          ),
                          if (subLabels != null) ...[
                            _optionButton(
                              angle: RadialGeometry.optionLeftAngle,
                              label: subLabels!.$1,
                              selected: subOption == RadialSubOption.left,
                              style: resolvedStyle,
                              onTap: () => _handleAction(
                                () => onSubOptionChange?.call(
                                  RadialSubOption.left,
                                ),
                              ),
                            ),
                            _optionButton(
                              angle: RadialGeometry.optionRightAngle,
                              label: subLabels!.$2,
                              selected: subOption == RadialSubOption.right,
                              style: resolvedStyle,
                              onTap: () => _handleAction(
                                () => onSubOptionChange?.call(
                                  RadialSubOption.right,
                                ),
                              ),
                            ),
                          ],
                          _roundButton(
                            angle: RadialGeometry.trailingAngle,
                            icon: trailingAction,
                            onTap: onTrailingTap,
                            style: resolvedStyle,
                            selected: trailingSelected,
                          ),
                          if (subActions != null)
                            for (var i = 0; i < subActions!.length; i++)
                              _roundButton(
                                angle: RadialGeometry.subActionAngle(
                                  i,
                                  subActions!.length,
                                ),
                                icon: Semantics(
                                  button: true,
                                  selected: subActions![i].selected,
                                  label: subActions![i].label,
                                  child: subActions![i].icon,
                                ),
                                onTap: subActions![i].onTap,
                                style: resolvedStyle,
                                selected: subActions![i].selected,
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // 3. 无胶囊时左右圆按钮渲染为常驻浮动圆盘（不随子栏折叠）
          if (hasFloatingDiscs) ...[
            _roundButton(
              angle: RadialGeometry.leadingAngle,
              icon: leadingAction,
              onTap: onLeadingTap,
              style: resolvedStyle,
            ),
            _roundButton(
              angle: RadialGeometry.trailingAngle,
              icon: trailingAction,
              onTap: onTrailingTap,
              style: resolvedStyle,
              selected: trailingSelected,
            ),
          ],
          // 4. 主层滑动药丸（弹簧沿弧线滑动并随切线旋转）
          SpringBuilder(            value: index.toDouble(),
            stiffness: 420,
            damping: 34,
            builder: (context, animatedIndex) {
              final angle = RadialGeometry.continuousTabAngle(
                animatedIndex,
                count,
              );
              final center = RadialGeometry.polar(
                angle,
                RadialGeometry.mainMidRadius,
              );
              return Positioned(
                left: center.dx - RadialGeometry.pillWidth / 2,
                top: center.dy - RadialGeometry.pillHeight / 2,
                child: Transform.rotate(
                  angle: angle * math.pi / 180,
                  child: Container(
                    width: RadialGeometry.pillWidth,
                    height: RadialGeometry.pillHeight,
                    // 手绘药丸：实底 + 墨线抖动描边，贴边绘制
                    // （RoughEdgeBoxDecoration：填充与描边画在真实边界）
                    decoration: RoughEdgeBoxDecoration(
                      shape: RoughBoxShape.roundedRectangle,
                      borderRadius: BorderRadius.circular(
                        RadialGeometry.pillRadius,
                      ),
                      fillStyle: RoughDrawingStyle(
                        color: resolvedStyle.activePillColor,
                      ),
                      // SolidFiller 必传：默认 NoFiller 时实底不画，
                      // 药丸只剩描边、与 dock 纸底融为一体
                      filler: SolidFiller(),
                      borderStyle: RoughDrawingStyle(
                        width: 1.8,
                        color: resolvedStyle.strokeColor,
                      ),
                      drawConfig:
                          resolvedStyle.drawConfig ?? _fallbackSketchConfig,
                      seed: 3,
                    ),
                  ),
                ),
              );
            },
          ),
          // 5. tab 按钮
          for (var i = 0; i < count; i++)
            _tabButton(context, i, resolvedStyle),
          // 6. 子栏右圆钮位置的常驻浮动操作钮（如 FAB），随切线旋转；
          //    启用子栏时由子栏 trailingAction 承担该位置，此处不渲染
          if (floatingAction != null && !subBarPossible)
            Builder(
              builder: (context) {
                final anchor = RadialGeometry.polar(
                  RadialGeometry.trailingAngle,
                  RadialGeometry.subMidRadius,
                );
                return Positioned(
                  left: anchor.dx,
                  top: anchor.dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -0.5),
                    child: Transform.rotate(
                      angle: RadialGeometry.trailingAngle * math.pi / 180,
                      child: floatingAction,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );

    // 仅显式声明"只要主弧 dock"（never）时裁掉画布上下空区；
    // auto/always 实例可能随 tab 动态出现子栏，若按当前内容裁剪，
    // 占位高度会在 tab 间跳变（body 内容经 bottomNavigationBar
    // 高度联动跟随跳动）。
    // OverflowBox 放松约束让场景保持 380×146（直接嵌套 SizedBox
    // 会被外层紧约束压扁，导致下半部分不可命中）
    if (subBarBehavior == RadialSubBarBehavior.never) {
      final hasFloating = floatingAction != null || hasFloatingDiscs;
      final cropTop = hasFloating ? _floatActionCropTop : _dockCropTop;
      scene = SizedBox(
        width: RadialGeometry.canvasWidth,
        height: RadialGeometry.canvasHeight - cropTop - _dockCropBottom,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: RadialGeometry.canvasWidth,
          maxWidth: RadialGeometry.canvasWidth,
          minHeight: RadialGeometry.canvasHeight,
          maxHeight: RadialGeometry.canvasHeight,
          child: Transform.translate(
            offset: Offset(0, -cropTop),
            child: scene,
          ),
        ),
      );
    }
    return scene;
  }

  Widget _buildFrostedBackground(
    RadialDiscBarStyle style,
    double fold,
    double optionT,
  ) {
    final size = const Size(
      RadialGeometry.canvasWidth,
      RadialGeometry.canvasHeight,
    );
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        // 阴影层：不受玻璃裁剪，保持投影完整
        CustomPaint(
          size: size,
          painter: _ScenePainter(
            style: style,
            fold: fold,
            optionT: optionT,
            hasSubLabels: subLabels != null,
            shadowsOnly: true,
          ),
        ),
        // 玻璃层：扇环内背景模糊 + 填充
        ClipPath(
          clipper: _RibbonClipper(fold: fold),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: frostSigma,
              sigmaY: frostSigma,
            ),
            child: CustomPaint(
              size: size,
              painter: _ScenePainter(
                style: style,
                fold: fold,
                optionT: optionT,
                hasSubLabels: subLabels != null,
                fillsOnly: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleAction(VoidCallback action) {
    if (hapticsEnabled) HapticFeedback.selectionClick();
    action();
  }

  Widget _tabButton(BuildContext context, int index, RadialDiscBarStyle style) {
    final count = tabs.length;
    final tab = tabs[index];
    final selected = index == activeIndex.clamp(0, count - 1);
    final angle = RadialGeometry.tabAngle(index, count);
    final center = RadialGeometry.polar(angle, RadialGeometry.mainMidRadius);

    return Positioned(
      left: center.dx - RadialGeometry.tabButtonWidth / 2,
      top: center.dy - RadialGeometry.tabButtonHeight / 2,
      child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: TapScale(
          onTap: onTabChange == null
              ? null
              : () => _handleAction(() => onTabChange!(index)),
          child: Semantics(
            button: true,
            selected: selected,
            label: tab.label,
            child: SizedBox(
              width: RadialGeometry.tabButtonWidth,
              height: RadialGeometry.tabButtonHeight,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  IconTheme.merge(
                    data: IconThemeData(
                      color: selected
                          ? style.activeIconColor
                          : style.inactiveIconColor,
                    ),
                    child: tab.iconBuilder(context, selected),
                  ),
                  if (tab.badge != null)
                    Positioned(
                      top: -1,
                      right: 2,
                      child: tab.badge!,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundButton({
    required double angle,
    required Widget? icon,
    required VoidCallback? onTap,
    required RadialDiscBarStyle style,
    bool selected = false,
  }) {
    if (icon == null) return const SizedBox.shrink();
    final center = RadialGeometry.polar(angle, RadialGeometry.subMidRadius);
    return Positioned(
      left: center.dx - RadialGeometry.roundButtonSize / 2,
      top: center.dy - RadialGeometry.roundButtonSize / 2,
      child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: TapScale(
          onTap: onTap == null ? null : () => _handleAction(onTap),
          child: Container(
            width: RadialGeometry.roundButtonSize,
            height: RadialGeometry.roundButtonSize,
            // 手绘圆钮：实底 + 墨线抖动圆，贴边绘制
            decoration: RoughEdgeBoxDecoration(
              shape: RoughBoxShape.circle,
              fillStyle: RoughDrawingStyle(
                color: selected ? style.activePillColor : style.roundButtonColor,
              ),
              // SolidFiller 必传：默认 NoFiller 时实底不画
              filler: SolidFiller(),
              borderStyle: RoughDrawingStyle(
                width: 1.6,
                color: selected
                    ? style.activePillColor
                    : style.roundButtonBorderColor,
              ),
              drawConfig: style.drawConfig ?? _fallbackSketchConfig,
              seed: 5,
            ),
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(
                  size: 16,
                  color: selected
                      ? style.activeIconColor
                      : style.roundButtonIconColor,
                ),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionButton({
    required double angle,
    required String label,
    required bool selected,
    required RadialDiscBarStyle style,
    required VoidCallback onTap,
  }) {
    final center = RadialGeometry.polar(angle, RadialGeometry.subMidRadius);
    return Positioned(
      left: center.dx - RadialGeometry.optionButtonWidth / 2,
      top: center.dy - RadialGeometry.optionButtonHeight / 2,
      child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: TapScale(
          pressedScale: 0.94,
          onTap: onTap,
          child: Semantics(
            button: true,
            selected: selected,
            child: SizedBox(
              width: RadialGeometry.optionButtonWidth,
              height: RadialGeometry.optionButtonHeight,
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? style.subActiveTextColor
                        : style.subInactiveTextColor,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 扇环玻璃裁剪：主扇环 + 随折叠进度缩放的子栏扇环
class _RibbonClipper extends CustomClipper<Path> {
  _RibbonClipper({required this.fold});

  final double fold;

  @override
  Path getClip(Size size) {
    if (fold <= 0.001) return RadialGeometry.mainRibbon;
    final progress = fold.clamp(0.0, 1.0);
    final scale = 0.92 + 0.08 * progress;
    final origin = Offset(
      RadialGeometry.centerX,
      RadialGeometry.canvasHeight,
    );
    final matrix = Matrix4.identity()
      ..translate(origin.dx, origin.dy)
      ..scale(scale)
      ..translate(-origin.dx, -origin.dy);
    return Path()
      ..addPath(RadialGeometry.mainRibbon, Offset.zero)
      ..addPath(RadialGeometry.subRibbon.transform(matrix.storage), Offset.zero);
  }

  @override
  bool shouldReclip(_RibbonClipper oldClipper) => oldClipper.fold != fold;
}

/// 包内默认手绘档（宿主未传 drawConfig 时使用，参数对齐 skribble playful）
final DrawConfig _fallbackSketchConfig = DrawConfig.build(
  roughness: 1.5,
  maxRandomnessOffset: 1.6,
  lineWobble: 0.65,
  pen: RoughPen.ink,
  seed: 7,
);

/// 背景画布：主 / 子两条扇环 + 子栏弧形滑动药丸
///
/// [shadowsOnly] / [fillsOnly] 用于磨砂模式拆分绘制：
/// 阴影层在玻璃裁剪外，玻璃体层在 ClipPath 内。
class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.style,
    required this.fold,
    required this.optionT,
    this.hasSubLabels = false,
    this.shadowsOnly = false,
    this.fillsOnly = false,
  });

  final RadialDiscBarStyle style;

  /// 子栏折叠进度 0~1（0 隐藏，1 完全展开）
  final double fold;

  /// 子栏选项位置 0（左）~1（右），驱动弧形药丸沿弧线滑动
  final double optionT;

  /// 分段选项（subLabels）模式才画弧形滑动药丸；图标动作
  /// （subActions）模式下没有选项文字，药丸只是悬在左侧的色块
  final bool hasSubLabels;

  final bool shadowsOnly;
  final bool fillsOnly;

  /// 背景画布不参与命中：CustomPainter.hitTest 默认 true 会把整个
  /// 画布矩形（含弧线外的透明角落）变成命中黑洞，挡住下层内容点击；
  /// 命中交给各按钮自身的 GestureDetector
  @override
  bool hitTest(Offset position) => false;

  @override
  void paint(Canvas canvas, Size size) {
    if (fold > 0.001) {
      final progress = fold.clamp(0.0, 1.0);
      final scale = 0.92 + 0.08 * progress;
      final origin = const Offset(
        RadialGeometry.centerX,
        RadialGeometry.canvasHeight,
      );
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.scale(scale);
      canvas.translate(-origin.dx, -origin.dy);

      if (!fillsOnly) _paintShadows(canvas, RadialGeometry.subRibbon, progress);
      if (!shadowsOnly) {
        _paintFill(canvas, RadialGeometry.subRibbon, progress);
        if (hasSubLabels) {
          final pillCenter =
              RadialGeometry.optionLeftAngle +
              (RadialGeometry.optionRightAngle - RadialGeometry.optionLeftAngle) *
                  optionT;
          final subPill = RadialGeometry.annularSector(
            pillCenter - RadialGeometry.subPillHalfWidth,
            pillCenter + RadialGeometry.subPillHalfWidth,
            RadialGeometry.subPillInnerRadius,
            RadialGeometry.subPillOuterRadius,
          );
          // 手绘药丸：waver 抖动轮廓实底 + 墨线描边（path 随 optionT
          // 连续变化，不进缓存；短弧采样代价小）
          final config = style.drawConfig ?? _fallbackSketchConfig;
          final subPillWavered = waveredPolygons(
            waverPath(subPill, config, amplitude: 1.0),
          );
          canvas.drawPath(
            subPillWavered,
            Paint()
              ..color = style.subPillColor.withValues(
                alpha: style.subPillColor.a * progress,
              ),
          );
          canvas.drawPath(
            subPillWavered,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..strokeJoin = StrokeJoin.round
              ..strokeCap = StrokeCap.round
              ..color = style.strokeColor.withValues(
                alpha: style.strokeColor.a * progress,
              ),
          );
        }
      }
      canvas.restore();
    }
    if (!fillsOnly) _paintShadows(canvas, RadialGeometry.mainRibbon, 1);
    if (!shadowsOnly) _paintFill(canvas, RadialGeometry.mainRibbon, 1);
  }

  void _paintShadows(Canvas canvas, Path path, double alpha) {
    for (final shadow in style.shadows) {
      canvas.drawPath(
        path.shift(Offset(shadow.dx, shadow.dy)),
        Paint()
          ..color = shadow.color.withValues(alpha: shadow.color.a * alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.sigma),
      );
    }
  }

  void _paintFill(Canvas canvas, Path path, double alpha) {
    // 手绘扇环：waver 抖动轮廓（填充边界与墨线都带手绘痕迹）
    final config = style.drawConfig ?? _fallbackSketchConfig;
    final wavered = waveredPolygons(_cachedContours(path, config));
    canvas.drawPath(
      wavered,
      Paint()
        ..color = style.fillColor.withValues(
          alpha: style.fillColor.a * alpha,
        ),
    );
    canvas.drawPath(
      wavered,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = style.strokeColor.withValues(
          alpha: style.strokeColor.a * alpha,
        ),
    );
  }

  /// 固定扇环 path 的 waver 轮廓缓存（ribbon 为 static final Path，
  /// DrawConfig 由 style 持有同样稳定；纯函数同输入同输出）
  static final Map<int, List<WaveredContour>> _waverCache = {};

  List<WaveredContour> _cachedContours(Path path, DrawConfig config) {
    final key = Object.hash(
      identityHashCode(path),
      identityHashCode(config),
    );
    return _waverCache.putIfAbsent(
      key,
      () => waverPath(path, config, amplitude: 1.0),
    );
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) =>
      oldDelegate.fold != fold ||
      oldDelegate.optionT != optionT ||
      oldDelegate.style != style ||
      oldDelegate.hasSubLabels != hasSubLabels ||
      oldDelegate.shadowsOnly != shadowsOnly ||
      oldDelegate.fillsOnly != fillsOnly;
}
