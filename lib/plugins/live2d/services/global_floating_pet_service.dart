import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/event/ai_auto_reply_event_args.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_speech_bubble.dart';

/// 全局悬浮宠物服务：把 Live2D 伙伴挂到应用根 Overlay，
/// 在所有页面最上层展示（应用内悬浮，非系统级悬浮窗）。
///
/// - [refresh] 依据插件设置挂载/摘除根 OverlayEntry；
/// - 订阅 [AiAutoReplyEventArgs] 广播，转发开关开启且宠物确实可展示
///   （stage 已附着 + 模型可解析）时，同步标记 handled 拦截默认 Toast，
///   改为宠物气泡展示；否则不拦截，交由发射方默认展示。
class GlobalFloatingPetService {
  GlobalFloatingPetService._();

  static final GlobalFloatingPetService instance = GlobalFloatingPetService._();

  OverlayEntry? _entry;
  bool _subscribed = false;
  bool _stageAttached = false;
  int _mountRetries = 0;
  static const int _maxMountRetries = 120;

  /// 待展示的转发回复；宿主组件监听此值渲染气泡
  final ValueNotifier<String?> pendingReply = ValueNotifier<String?>(null);

  bool get isMounted => _entry != null;

  /// 插件初始化时调用：订阅事件 + 按设置挂载
  void ensureInitialized() {
    if (!_subscribed) {
      _subscribed = true;
      EventManager.instance.subscribe(
        AiAutoReplyEventArgs.event,
        _onAiAutoReply,
      );
      // 存档增删/选中变化后重算挂载状态（跟随选中存档的悬浮宠物）
      EventManager.instance.subscribe(
        Live2DPlugin.archiveSelectedEvent,
        (_) => refresh(),
      );
    }
    refresh();
  }

  /// 悬浮宠物此刻是否真的能承接气泡展示：
  /// entry 已插入、stage 已附着（气泡监听就位）、模型可解析
  bool get _canDisplay {
    if (_entry == null || !_stageAttached) return false;
    final plugin = Live2DPlugin.instance;
    final archive = plugin.globalPetArchive;
    if (archive == null) return false;
    return modelDefinitionForArchive(
          archive,
          importedModels: plugin.importedModels,
        ) !=
        null;
  }

  void _onAiAutoReply(EventArgs args) {
    if (args is! AiAutoReplyEventArgs || args.handled) return;
    final plugin = Live2DPlugin.instance;
    if (!plugin.globalPetEnabled || !plugin.forwardAiReplyEnabled) return;
    // 仅在宠物确实可展示时拦截默认展示，否则交回默认 Toast
    if (!_canDisplay) return;
    args.handled = true;
    pendingReply.value = Live2DPlugin.cleanReply(args.text);
  }

  /// 设置变化后重算挂载状态；导航器未就绪时按帧重试
  void refresh() {
    final plugin = Live2DPlugin.instance;
    if (plugin.globalPetEnabled && plugin.globalPetArchive != null) {
      _mountWithRetry();
    } else {
      _unmount();
    }
  }

  void _mountWithRetry() {
    if (_entry != null) {
      // 已挂载：设置（尺寸/透明度/档案）变化后重建宿主
      _entry!.markNeedsBuild();
      return;
    }
    // navigatorKey.currentContext 是 Navigator 自身的 context，
    // Overlay.maybeOf 只找祖先拿不到其内部 Overlay；
    // 这里直接取根 NavigatorState 自带的 overlay
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null || !overlay.mounted) {
      if (_mountRetries >= _maxMountRetries) {
        debugPrint('[Live2D][GlobalPet] Overlay 未就绪，放弃挂载重试');
        return;
      }
      _mountRetries++;
      WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
      return;
    }
    _mountRetries = 0;
    _stageAttached = false;
    final entry = OverlayEntry(
      builder: (_) => const _GlobalFloatingPetStage(),
    );
    overlay.insert(entry);
    _entry = entry;
  }

  void _unmount() {
    _mountRetries = 0;
    _stageAttached = false;
    _entry?.remove();
    _entry = null;
    pendingReply.value = null;
  }
}

/// 全屏透明的悬浮宠物宿主：右下角展示宠物与转发回复气泡
class _GlobalFloatingPetStage extends StatefulWidget {
  const _GlobalFloatingPetStage();

  @override
  State<_GlobalFloatingPetStage> createState() =>
      _GlobalFloatingPetStageState();
}

class _GlobalFloatingPetStageState extends State<_GlobalFloatingPetStage> {
  String? _bubbleText;
  Timer? _bubbleTimer;
  Timer? _bubbleSafetyTimer;

  @override
  void initState() {
    super.initState();
    GlobalFloatingPetService.instance.pendingReply.addListener(_onPendingReply);
    // 标记 stage 已附着，事件侧才允许拦截 handled
    GlobalFloatingPetService.instance._stageAttached = true;
  }

  @override
  void dispose() {
    GlobalFloatingPetService.instance._stageAttached = false;
    _bubbleTimer?.cancel();
    _bubbleSafetyTimer?.cancel();
    GlobalFloatingPetService.instance.pendingReply
        .removeListener(_onPendingReply);
    super.dispose();
  }

  void _onPendingReply() {
    final text = GlobalFloatingPetService.instance.pendingReply.value;
    if (text == null || text.isEmpty) return;
    // 立即消费，避免相同文本的连续回复不触发监听
    GlobalFloatingPetService.instance.pendingReply.value = null;
    if (!mounted) return;
    // 先取消旧气泡的收起/兜底定时器，避免提前收起新气泡
    _bubbleTimer?.cancel();
    _bubbleSafetyTimer?.cancel();
    setState(() => _bubbleText = text);
    // 兜底：打字回调异常时也按时收起
    _bubbleSafetyTimer = Timer(const Duration(seconds: 90), _hideBubble);
  }

  void _hideBubble() {
    _bubbleTimer?.cancel();
    _bubbleSafetyTimer?.cancel();
    if (!mounted) return;
    setState(() => _bubbleText = null);
  }

  /// 与小屋舞台一致：打字结束后按文本长度展示 6-30 秒再收起
  void _onBubbleTyped() {
    if (_bubbleText == null) return;
    final length = _bubbleText!.runes.length;
    final seconds = (6 + (length ~/ 80) * 4).clamp(6, 30);
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(Duration(seconds: seconds), _hideBubble);
  }

  /// 用户与气泡交互：暂停收起，稍后重新计时
  void _onBubbleInteract() {
    if (_bubbleText == null) return;
    _bubbleTimer?.cancel();
    _bubbleSafetyTimer?.cancel();
    _bubbleSafetyTimer = Timer(const Duration(seconds: 2), _onBubbleTyped);
  }

  @override
  Widget build(BuildContext context) {
    final plugin = Live2DPlugin.instance;
    final archive = plugin.globalPetArchive;
    final model = archive == null
        ? null
        : modelDefinitionForArchive(
            archive,
            importedModels: plugin.importedModels,
          );
    if (archive == null || model == null) return const SizedBox.shrink();

    final bottomPadding = 24.0 + MediaQuery.paddingOf(context).bottom;
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(right: 16, bottom: bottomPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 屏幕过小（小屏手机/分屏）时压缩气泡与宠物，避免溢出
            final availWidth = constraints.maxWidth;
            final availHeight = constraints.maxHeight;
            const bubbleGap = 8.0;
            const bubbleBaseWidth = 260.0;
            const bubbleBaseHeight = 140.0;
            final bubbleWidth = math
                .min(bubbleBaseWidth, math.max(0.0, availWidth))
                .toDouble();
            final bubbleHeight = math
                .min(bubbleBaseHeight, math.max(0.0, availHeight * 0.35))
                .toDouble();
            final bubbleVisible = _bubbleText != null && bubbleHeight > 40;
            final petBudget = availHeight -
                (bubbleVisible ? bubbleHeight + bubbleGap : 0.0);
            final petSize = plugin.globalPetSize
                .clamp(
                  0.0,
                  math.max(0.0, math.min(petBudget, availWidth)),
                )
                .toDouble();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (bubbleVisible) ...[
                  SizedBox(
                    width: bubbleWidth,
                    height: bubbleHeight,
                    child: AppTheme(
                      data: AppTheme.of(context),
                      child: JellySpeechBubble(
                        key: ValueKey('global-pet-bubble-$_bubbleText'),
                        text: _bubbleText!,
                        modelName: model.label,
                        bubbleAsset: plugin.bubbleAsset,
                        customRegions: BubbleTextRegions.fromSettings(
                          plugin.bubbleAsset,
                          plugin.bubbleRegions,
                        ),
                        typingInterval: plugin.bubbleTypingInterval,
                        onTypingComplete: _onBubbleTyped,
                        onUserInteract: _onBubbleInteract,
                        onTap: _hideBubble,
                      ),
                    ),
                  ),
                  const SizedBox(height: bubbleGap),
                ],
                // 宠物本体：透明度只作用于本体，气泡保持全不透明可读
                Opacity(
                  opacity: plugin.globalPetOpacity,
                  child: SizedBox(
                    width: petSize,
                    height: petSize,
                    child: JellyLive2D(
                      key: ValueKey(
                        'global-pet-${archive.id}-${model.modelDir}-${model.modelFile}',
                      ),
                      initialModel: model,
                      fitContainer: true,
                      typingInterval: plugin.bubbleTypingInterval,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
