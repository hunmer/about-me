/// 手绘收集册组件（clawbert 收集册风格 → 手绘纸墨规范）
///
/// 提供三个可复用件：
/// - [CollectionShelfSlot]：货架槽位——悬浮拿起、按压回缩、点击 Q 弹（jelly）
/// - [CollectionShelf]：单层货架——背板 + 出檐搁板横木，物品底对齐站立
/// - [showCollectionStageDialog]：物品舞台详情弹窗——舞台展台 + 名称/描述 + 主操作
///
/// 颜色一律取自主题（无硬编码），墨线走 skribble rough 引擎，
/// 与全局墨线档位（Gentle/Playful/Expressive）自动一致。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 货架槽位：包裹物品造型，提供 clawbert 式交互
///
/// - 悬浮：拿起（放大 1.09 + 上移 3px）
/// - 按压：回缩 0.94
/// - 点击：Q 弹挤压动画（缩放交替 + 跳起），动画起播后延迟触发 [onTap]
///   （复刻 clawbert 的 jellyBounce → 180ms 后开详情的节奏）
class CollectionShelfSlot extends StatefulWidget {
  const CollectionShelfSlot({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  @override
  State<CollectionShelfSlot> createState() => _CollectionShelfSlotState();
}

/// 槽位姿态：非均匀缩放 + 纵向位移（transformOrigin 在底部中心）
@immutable
class _SlotPose {
  const _SlotPose(this.sx, this.sy, this.dy);

  final double sx;
  final double sy;
  final double dy;

  static const _SlotPose rest = _SlotPose(1, 1, 0);

  static _SlotPose lerp(_SlotPose a, _SlotPose b, double t) => _SlotPose(
    a.sx + (b.sx - a.sx) * t,
    a.sy + (b.sy - a.sy) * t,
    a.dy + (b.dy - a.dy) * t,
  );
}

class _SlotPoseTween extends Tween<_SlotPose> {
  _SlotPoseTween(_SlotPose begin, _SlotPose end) : super(begin: begin, end: end);

  @override
  _SlotPose lerp(double t) =>
      _SlotPose.lerp(begin ?? _SlotPose.rest, end ?? _SlotPose.rest, t);
}

class _CollectionShelfSlotState extends State<CollectionShelfSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _jelly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  late final Animation<double> _jellyCurved = CurvedAnimation(
    parent: _jelly,
    curve: Curves.easeInOut,
  );

  /// Q 弹关键帧（对应 clawbert 的 jellyBounce keyframes；
  /// 必须用覆写了 lerp 的 _SlotPoseTween，基类 Tween 无法插值自定义类型）
  static final _jellySequence = TweenSequence<_SlotPose>([
    TweenSequenceItem(
      tween: _SlotPoseTween(_SlotPose.rest, const _SlotPose(1.14, 0.88, 2)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: _SlotPoseTween(
        const _SlotPose(1.14, 0.88, 2),
        const _SlotPose(0.92, 1.12, -10),
      ),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: _SlotPoseTween(
        const _SlotPose(0.92, 1.12, -10),
        const _SlotPose(1.05, 0.96, -2),
      ),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: _SlotPoseTween(const _SlotPose(1.05, 0.96, -2), _SlotPose.rest),
      weight: 25,
    ),
  ]);

  @override
  void dispose() {
    _jelly.dispose();
    super.dispose();
  }

  void _handleTap() {
    _jelly.forward(from: 0);
    if (widget.onTap != null) {
      // Q 弹起播后再开详情，避免弹窗立刻盖住动画
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted) widget.onTap?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: (widget.onTap == null && widget.onLongPress == null)
          ? null
          : _handleTap,
      onLongPress: widget.onLongPress,
      semanticLabel: widget.semanticLabel,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        final hovered = states.contains(WidgetState.hovered);
        final base = pressed
            ? const _SlotPose(0.94, 0.94, 0)
            : hovered
            ? const _SlotPose(1.09, 1.09, -3)
            : _SlotPose.rest;

        return TweenAnimationBuilder<_SlotPose>(
          tween: _SlotPoseTween(_SlotPose.rest, base),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          builder: (context, basePose, _) {
            return AnimatedBuilder(
              animation: _jelly,
              builder: (context, _) {
                final jelly = _jelly.isDismissed
                    ? _SlotPose.rest
                    : _jellySequence.evaluate(_jellyCurved);
                return Transform.translate(
                  offset: Offset(0, basePose.dy + jelly.dy),
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.diagonal3Values(
                      basePose.sx * jelly.sx,
                      basePose.sy * jelly.sy,
                      1,
                    ),
                    child: widget.child,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// 连体多层展示柜（clawbert 柜台结构）
///
/// 还原参考稿的多面透视柜台：每层 = 背板 + 左右透视侧板 + 前宽后窄的
/// 木质台面，多层零间距相连成整柜（侧板纵贯、台面即层隔板），
/// 物品（槽位）立于各层台面上。墨线走 skribble rough 引擎，
/// 颜色全取主题：
/// - 背板：主题淡彩（hatch）
/// - 侧板：纸面（surface）
/// - 台面：主色调淡
class CollectionShelfCase extends StatelessWidget {
  const CollectionShelfCase({
    super.key,
    required this.theme,
    required this.rows,
    this.slotHeight = 92,
    this.slotsPerRow = 4,
    this.referenceRowCount,
    this.backboardColor,
    this.wallColor,
    this.counterColor,
    this.seed = 1,
  });

  final AppThemeData theme;

  /// 每层的槽位列表（通常每层 4 个 [CollectionShelfSlot]）
  final List<List<Widget>> rows;

  /// 每层净高（不含木质台面）；高度约束有限时会被拉伸撑满（见 [build]）
  final double slotHeight;

  /// 层高基准层数：高度均分按此数计算而非实际 [rows] 数，
  /// 搜索/过滤后行数变少时层高保持与全量视图一致，不拉伸成巨层
  final int? referenceRowCount;

  /// 每层固定格数（末排不足时空格占位，物品仍占 1/N 格宽）
  final int slotsPerRow;

  /// 背板底色（默认主题淡彩）
  final Color? backboardColor;

  /// 左右侧板底色（默认纸面）
  final Color? wallColor;

  /// 木质台面底色（默认主色调淡）
  final Color? counterColor;

  /// 墨迹 seed
  final int seed;

  /// 侧板内缩宽度（透视深度）
  static const double wallInset = 16;

  /// 木质台面前缘高度
  static const double counterHeight = 14;

  /// 撑满可用高度时每层净高的下限（行数过多时不再压缩，交由外层滚动）
  static const double minSlotHeight = 64;

  /// 解析层高：可用高度按 [referenceRowCount] 层均分（有下限），
  /// 高度无界（滚动内）用 [base] 固定层高
  static double resolveSlotHeight(
    double maxHeight,
    int referenceRowCount, [
    double base = 92,
  ]) {
    if (!maxHeight.isFinite || referenceRowCount <= 0) return base;
    return math.max(
      minSlotHeight,
      (maxHeight - referenceRowCount * counterHeight) / referenceRowCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // 高度约束有限（如页面 body 内）→ 层高按基准层数均分（默认实际层数）；
      // 搜索/过滤结果传全量层数作基准，行数少时层高不拉伸
      final slotH = resolveSlotHeight(
        constraints.maxHeight,
        referenceRowCount ?? rows.length,
        slotHeight,
      );
      final rowH = slotH + counterHeight;

      return SizedBox(
        height: rows.length * rowH,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ShelfCasePainter(
                  theme: theme,
                  rowCount: rows.length,
                  slotHeight: slotH,
                  backboardColor: backboardColor,
                  wallColor: wallColor,
                  counterColor: counterColor,
                  seed: seed,
                ),
              ),
            ),
            // 各层槽位：物品站立在台面上（底部略压台面）；
            // 不足固定格数的末排用空格占位，保持每格 1/N 宽
            for (var i = 0; i < rows.length; i++)
              Positioned(
                left: wallInset + 8,
                right: wallInset + 8,
                top: i * rowH + 6,
                height: rowH - 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var j = 0; j < slotsPerRow; j++) ...[
                      if (j > 0) const SizedBox(width: 8),
                      Expanded(
                        child: j < rows[i].length
                            ? rows[i][j]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// 展示柜绘制：按层画 背板 → 木质台面（梯形）→ 左右侧板（透视四边形）→ 外框
class _ShelfCasePainter extends CustomPainter {
  _ShelfCasePainter({
    required this.theme,
    required this.rowCount,
    required this.slotHeight,
    this.backboardColor,
    this.wallColor,
    this.counterColor,
    required this.seed,
  });

  final AppThemeData theme;
  final int rowCount;
  final double slotHeight;
  final Color? backboardColor;
  final Color? wallColor;
  final Color? counterColor;
  final int seed;

  Size? _size;
  late final List<RoughDrawing> _drawings;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || rowCount == 0) return;
    if (_size != size) {
      _drawings = _prepare(size);
      _size = size;
    }
    for (final d in _drawings) {
      d.paint(canvas, progress: 1, pressure: 0);
    }
  }

  List<RoughDrawing> _prepare(Size size) {
    final back = backboardColor ?? theme.hatch;
    final wall = wallColor ?? theme.paper;
    final counter = counterColor ?? theme.primary.withValues(alpha: 0.55);
    final ink = theme.ink;

    // 与全局墨线档位一致的绘制配置（reset 保证 rebuild 墨迹稳定）
    final dc = theme.wired.drawConfig;
    final generator = Generator(dc, SolidFiller());

    Paint borderPaint() => Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.8
      ..color = ink;
    Paint fillPaint(Color color) => borderPaint()..color = color;

    // 生成一个手绘多边形（带实底填充）
    RoughDrawing polygon(List<PointD> points, Color fill) {
      dc.randomizer.reset();
      return RoughDrawing(
        generator.polygon(points),
        borderPaint(),
        fillPaint(fill),
      );
    }

    // 生成一条闭合手绘描边（无填充）
    RoughDrawing outline(List<PointD> points) {
      dc.randomizer.reset();
      return RoughDrawing(
        generator.linearPath(points),
        borderPaint(),
        fillPaint(ink),
      );
    }

    final w = size.width;
    final wi = CollectionShelfCase.wallInset;
    final ch = CollectionShelfCase.counterHeight;
    final rowH = slotHeight + ch;
    final drawings = <RoughDrawing>[];

    for (var i = 0; i < rowCount; i++) {
      final top = i * rowH;
      final counterTop = top + slotHeight;
      final bottom = top + rowH;

      // 背板（整层高，延伸到台面底）
      drawings.add(
        polygon(
          [
            PointD(wi, top),
            PointD(w - wi, top),
            PointD(w - wi, bottom),
            PointD(wi, bottom),
          ],
          back,
        ),
      );
      // 木质台面：前宽后窄的梯形
      drawings.add(
        polygon(
          [
            PointD(wi, counterTop),
            PointD(w - wi, counterTop),
            PointD(w, bottom),
            PointD(0, bottom),
          ],
          counter,
        ),
      );
      // 左右侧板：透视四边形
      drawings.add(
        polygon(
          [
            PointD(0, top),
            PointD(wi, top),
            PointD(wi, counterTop),
            PointD(0, bottom),
          ],
          wall,
        ),
      );
      drawings.add(
        polygon(
          [
            PointD(w, top),
            PointD(w - wi, top),
            PointD(w - wi, counterTop),
            PointD(w, bottom),
          ],
          wall,
        ),
      );
      // 本层外框（层间分隔线即台面前缘）
      drawings.add(
        outline([
          PointD(0, top),
          PointD(w, top),
          PointD(w, bottom),
          PointD(0, bottom),
        ]),
      );
    }
    return drawings;
  }

  @override
  bool shouldRepaint(_ShelfCasePainter oldDelegate) =>
      oldDelegate.rowCount != rowCount ||
      oldDelegate.slotHeight != slotHeight ||
      oldDelegate.seed != seed ||
      oldDelegate.backboardColor != backboardColor ||
      oldDelegate.wallColor != wallColor ||
      oldDelegate.counterColor != counterColor ||
      !identical(oldDelegate.theme, theme);
}

/// 舞台详情弹窗的次级操作（小图标行）
class CollectionStageAction {
  const CollectionStageAction({
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final DsIconKind icon;
  final VoidCallback? onTap;
  final bool destructive;
}

/// 物品舞台详情弹窗（clawbert 详情卡 → 手绘规范）
///
/// 结构：状态徽章 → 舞台展台（淡彩底 + 底部木板）→ 名称 → 描述 →
/// 主操作按钮（如「使用」）→ 次级图标操作行。
/// 弹窗走 [showDSDialog]：缩放淡入 + 墨线描画入场 + 遮罩点击关闭。
Future<T?> showCollectionStageDialog<T>({
  required BuildContext context,
  required String title,
  required Widget art,
  String? chipLabel,
  Color? chipColor,
  String? description,
  String? actionLabel,
  VoidCallback? onAction,
  List<CollectionStageAction> secondaryActions = const [],
}) {
  return showDSDialog<T>(
    context: context,
    theme: DSThemeBridge.resolve(context),
    builder: (_) => DSThemeBridge(
      child: Builder(
        builder: (context) => CollectionStageDialog(
          title: title,
          art: art,
          chipLabel: chipLabel,
          chipColor: chipColor,
          description: description,
          actionLabel: actionLabel,
          onAction: onAction,
          secondaryActions: secondaryActions,
        ),
      ),
    ),
  );
}

class CollectionStageDialog extends StatelessWidget {
  const CollectionStageDialog({
    super.key,
    required this.title,
    required this.art,
    this.chipLabel,
    this.chipColor,
    this.description,
    this.actionLabel,
    this.onAction,
    this.secondaryActions = const [],
  });

  final String title;
  final Widget art;
  final String? chipLabel;
  final Color? chipColor;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<CollectionStageAction> secondaryActions;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final progress = WiredDrawTransition.progressOf(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: DsSketchPanel(
        theme: theme,
        radius: theme.radii.xxl,
        padding: EdgeInsets.all(theme.spacing.lg),
        progress: progress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 状态徽章
            if (chipLabel != null)
              Center(
                child: JellyBox(
                  color: chipColor ?? theme.surfaceAlt,
                  radius: theme.radii.circle,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  child: Text(
                    chipLabel!,
                    style: DsTypography.caption.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            SizedBox(height: theme.spacing.md),

            // 舞台展台
            _StagePanel(theme: theme, art: art),
            SizedBox(height: theme.spacing.md),

            // 名称与描述
            Text(
              title,
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
            if (description != null && description!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.sm),
                child: Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ),
            SizedBox(height: theme.spacing.lg),

            // 主操作（如「使用」）
            if (actionLabel != null)
              DSButton(
                label: actionLabel!,
                icon: DsIconKind.check,
                onPressed: () {
                  Navigator.of(context).pop();
                  onAction?.call();
                },
              ),

            // 次级操作行
            if (secondaryActions.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < secondaryActions.length; i++) ...[
                      if (i > 0) SizedBox(width: theme.spacing.md),
                      Builder(
                        builder: (context) {
                          final action = secondaryActions[i];
                          final color = action.destructive
                              ? theme.danger
                              : theme.textSub;
                          return DSIconButton(
                            icon: action.icon,
                            size: 36,
                            iconColor: color,
                            onPressed: action.onTap == null
                                ? null
                                : () {
                                    Navigator.of(context).pop();
                                    action.onTap?.call();
                                  },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 舞台展台：淡彩圆角底 + 底部出檐木板，物品立于木板上
class _StagePanel extends StatelessWidget {
  const _StagePanel({required this.theme, required this.art});

  final AppThemeData theme;
  final Widget art;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: theme.primary.withValues(alpha: 0.16),
                radius: BorderRadius.circular(16),
              ),
            ),
          ),
          // 物品站在底部木板上
          Positioned(left: 0, right: 0, bottom: 12, child: Center(child: art)),
          Positioned(
            left: -6,
            right: -6,
            bottom: 0,
            child: Container(
              height: 12,
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: theme.primary.withValues(alpha: 0.55),
                radius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
