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
  _SlotPoseTween({required _SlotPose end})
    : super(begin: _SlotPose.rest, end: end);

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

  /// Q 弹关键帧（对应 clawbert 的 jellyBounce keyframes）
  static final _jellySequence = TweenSequence<_SlotPose>([
    TweenSequenceItem(
      tween: Tween(
        begin: _SlotPose.rest,
        end: const _SlotPose(1.14, 0.88, 2),
      ),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: const _SlotPose(1.14, 0.88, 2),
        end: const _SlotPose(0.92, 1.12, -10),
      ),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: const _SlotPose(0.92, 1.12, -10),
        end: const _SlotPose(1.05, 0.96, -2),
      ),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: const _SlotPose(1.05, 0.96, -2),
        end: _SlotPose.rest,
      ),
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
          tween: _SlotPoseTween(end: base),
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

/// 单层货架：背板 + 左右出檐的搁板横木，物品（槽位）底对齐站立
///
/// [children] 通常是一组 [CollectionShelfSlot]；不满一排时槽位均分整行宽度
/// （与 clawbert 每层 4 格的网格一致）。
class CollectionShelf extends StatelessWidget {
  const CollectionShelf({
    super.key,
    required this.theme,
    this.children = const [],
    this.slotHeight = 96,
    this.backboardColor,
    this.boardColor,
    this.seed = 1,
  });

  final AppThemeData theme;

  /// 槽位列表
  final List<Widget> children;

  /// 槽位高度（不含搁板横木）
  final double slotHeight;

  /// 背板底色（默认主题次级背景）
  final Color? backboardColor;

  /// 搁板横木底色（默认主色调淡）
  final Color? boardColor;

  /// 墨迹 seed（多层货架传不同值让墨线有变化）
  final int seed;

  @override
  Widget build(BuildContext context) {
    final back = backboardColor ?? theme.surfaceAlt;
    final board = boardColor ?? theme.primary.withValues(alpha: 0.55);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 背板：物品站立其上
        Container(
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: back,
            radius: BorderRadius.circular(14),
            seed: seed,
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: SizedBox(
            height: slotHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: children[i]),
                ],
              ],
            ),
          ),
        ),
        // 搁板横木：左右出檐，紧贴背板下沿
        Container(
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: -6),
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: board,
            radius: BorderRadius.circular(6),
            seed: seed + 1,
          ),
        ),
      ],
    );
  }
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
