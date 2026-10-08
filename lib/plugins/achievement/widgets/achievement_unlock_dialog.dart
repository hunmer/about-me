import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/plugins/achievement/models/achievement_definition.dart';
import 'package:aboutme/plugins/achievement/widgets/achievement_badge.dart';

/// 成就达成全局弹窗（队列式）
///
/// 监听方把 [AchievementLevelUpEventArgs] 投入 [enqueue]，
/// 弹窗在全局 [navigatorKey] 上依次展示。
class AchievementUnlockDialog {
  AchievementUnlockDialog._();

  static final List<AchievementLevelUpEventArgs> _queue = [];
  static bool _showing = false;

  /// 弹窗自动关闭时长
  static const Duration _autoDismiss = Duration(seconds: 4);

  static void enqueue(AchievementLevelUpEventArgs args) {
    _queue.add(args);
    _showNext();
  }

  static Future<void> _showNext() async {
    if (_showing || _queue.isEmpty) return;
    final context = navigatorKey.currentContext;
    if (context == null) {
      // 界面尚未就绪，稍后重试
      await Future.delayed(const Duration(milliseconds: 500));
      if (navigatorKey.currentContext == null) {
        _queue.clear();
        return;
      }
    }

    _showing = true;
    final args = _queue.removeAt(0);
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _showing = false;
      return;
    }

    final timer = Timer(_autoDismiss, () {
      if (navigator.canPop()) {
        navigator.pop();
      }
    });

    await showDialog(
      context: navigator.context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      useRootNavigator: true,
      builder: (dialogContext) => _UnlockDialogBody(args: args),
    ).whenComplete(timer.cancel);

    _showing = false;
    if (_queue.isNotEmpty) {
      _showNext();
    }
  }
}

class _UnlockDialogBody extends StatelessWidget {
  const _UnlockDialogBody({required this.args});

  final AchievementLevelUpEventArgs args;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ScaleInAnimation(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AchievementLevels.borderColor(args.level).withAlpha(120),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AchievementLevels.borderColor(args.level).withAlpha(90),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              Text(
                'achievement_unlocked'.tr,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AchievementLevels.borderColor(args.level),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              // 徽章
              AchievementBadge(
                iconAsset: args.iconAsset,
                level: args.level,
                size: 104,
              ),
              const SizedBox(height: 16),
              // 名称 + 等级
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  children: [
                    TextSpan(text: args.name),
                    const TextSpan(text: '  '),
                    TextSpan(
                      text: AchievementLevels.levelLabel(args.level),
                      style: TextStyle(
                        color: AchievementLevels.borderColor(args.level),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // 本等级具体完成的事项
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  args.condition,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(200),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 获得日期
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 14, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Text(
                    '${'achievement_unlocked_at'.tr} ${_fmt(args.unlockedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 积分奖励
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(120),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '+${args.points} ${'achievement_points'.tr}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'achievement_tapToClose'.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor.withAlpha(150),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// 弹窗入场缩放动画
class ScaleInAnimation extends StatefulWidget {
  const ScaleInAnimation({super.key, required this.child});

  final Widget child;

  @override
  State<ScaleInAnimation> createState() => _ScaleInAnimationState();
}

class _ScaleInAnimationState extends State<ScaleInAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        ),
        child: widget.child,
      ),
    );
  }
}
