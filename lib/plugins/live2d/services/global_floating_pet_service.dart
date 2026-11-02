import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'
    show PanGestureRecognizer, PointerDeviceKind;
import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/event/ai_auto_reply_event_args.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/plugins/live2d/widgets/global_pet_view.dart';
import 'package:aboutme/plugins/live2d/widgets/video_pet_region_hit_box.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d_models.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d_video.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_speech_bubble.dart';

/// 全局悬浮宠物服务：把 Live2D 伙伴挂到应用根 Overlay，
/// 在所有页面最上层展示（应用内悬浮，非系统级悬浮窗）。
///
/// - [refresh] 依据插件设置挂载/摘除根 OverlayEntry；
/// - 订阅 [AiAutoReplyEventArgs] 广播，转发开关开启且宠物确实可展示
///   （stage 已附着 + 模型可解析 + 不在首页路由）时，同步标记 handled
///   拦截默认 Toast，改为宠物气泡展示；否则不拦截，交由发射方默认展示；
/// - 监听 [RouteHistoryManager.topRouteName]，首页（/jelly_home 及其
///   子页签路由、旧首页 / 与 home）隐藏宠物且不拦截 AI 事件，离开恢复。
class GlobalFloatingPetService {
  GlobalFloatingPetService._();

  static final GlobalFloatingPetService instance = GlobalFloatingPetService._();

  /// 调试日志开关（代码或调试器翻转；命中/拖拽/路由/事件决策全链路输出）
  static bool debugLogging = true;

  static void _log(String message) {
    if (debugLogging) {
      debugPrint('[Live2D][GlobalPet] $message');
    }
  }

  OverlayEntry? _entry;
  bool _subscribed = false;
  bool _stageAttached = false;
  bool _onHomeRoute = false;
  int _mountRetries = 0;
  static const int _maxMountRetries = 120;

  /// 待展示的转发回复；宿主组件监听此值渲染气泡
  final ValueNotifier<String?> pendingReply = ValueNotifier<String?>(null);

  bool get isMounted => _entry != null;

  /// 首页路由名：/jelly_home 与 /jelly_home/1..4 子页签、旧首页 / 与 home
  ///
  /// null = 栈空（启动初期）或匿名业务页——按"所有页面展示"的需求保持
  /// 可见（路由栈在首帧 Navigator 构建时即播种，悬浮宠物挂载晚于首帧，
  /// 不会在启动时闪现；pet 默认关闭，onboarding 不受影响）。
  static bool _isHomeRoute(String? name) {
    if (name == null) return false;
    return name == '/jelly_home' ||
        name.startsWith('/jelly_home/') ||
        name == '/' ||
        name == 'home';
  }

  /// 当前是否应渲染悬浮宠物（首页隐藏）
  bool get shouldRender => !_onHomeRoute;

  /// 插件初始化时调用：订阅事件 + 路由 + 按设置挂载
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
      // 真实路由跟踪：进首页隐藏（不拦截事件），离开恢复
      RouteHistoryManager.instance.topRouteName.addListener(_onRouteChanged);
      _onRouteChanged();
    }
    refresh();
  }

  /// 悬浮宠物此刻是否真的能承接气泡展示：
  /// entry 已插入、stage 已附着（气泡监听就位）、不在首页、模型可解析
  bool get _canDisplay {
    if (_entry == null || !_stageAttached || _onHomeRoute) return false;
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
    if (!_canDisplay) {
      _log('ai_auto_reply 不拦截：canDisplay=false（未挂载/首页隐藏/模型缺失）');
      return;
    }
    args.handled = true;
    _log('ai_auto_reply 已拦截 ${args.text.length} 字');
    pendingReply.value = Live2DPlugin.cleanReply(args.text);
  }

  /// 路由变化：进首页隐藏并清气泡，离开恢复
  void _onRouteChanged() {
    final name = RouteHistoryManager.instance.currentTopRouteName;
    final onHome = _isHomeRoute(name);
    if (onHome == _onHomeRoute) return;
    _onHomeRoute = onHome;
    _log('路由="$name" 首页=$onHome → ${onHome ? "隐藏" : "恢复"}');
    if (onHome) pendingReply.value = null;
    _entry?.markNeedsBuild();
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
        _log('Overlay 未就绪，放弃挂载重试');
        return;
      }
      _mountRetries++;
      WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
      return;
    }
    _mountRetries = 0;
    _stageAttached = false;
    final entry = OverlayEntry(builder: (_) => _GlobalFloatingPetStage());
    overlay.insert(entry);
    _entry = entry;
    _log('已挂载根 Overlay（首页隐藏中=$_onHomeRoute）');
  }

  void _unmount() {
    if (_entry == null) return;
    _log('摘除挂载');
    _mountRetries = 0;
    _stageAttached = false;
    _entry?.remove();
    _entry = null;
    pendingReply.value = null;
  }
}

/// 全屏透明的悬浮宠物宿主：可拖拽宠物 + 转发回复气泡
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

  /// 宠物左上角位置（逻辑像素）。仅内存保留：跨路由不丢，
  /// 不做持久化；窗口/安全区变化时在 build 中夹回屏幕边界。
  Offset? _petPosition;

  /// 本次拖拽的稳定起点：按下时的全局指针位置 + 当时宠物位置。
  /// 每帧直接用 globalPosition 相对起点换算，避免 build 闭包里的
  /// 旧坐标在同帧多事件时丢 delta / 跳变 / 吸边。
  Offset? _dragStartGlobal;
  Offset? _dragOrigin;

  /// 视频桌宠清单解析结果（loadDefault 兜底路径用）+ 所属模型。
  /// 存档切换时按模型实例比对，避免旧清单串档；模型自带清单
  /// （model.videoManifest）不经过这里，build 直接可用。
  VideoPetManifest? _resolvedVideoManifest;
  Live2DModelDefinition? _resolvedManifestFor;

  /// 区域随机台词抽取器（每次点击独立随机）
  final math.Random _tapMessageRandom = math.Random();

  static const double _bubbleGap = 8.0;

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
    GlobalFloatingPetService.instance.pendingReply.removeListener(
      _onPendingReply,
    );
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
    GlobalFloatingPetService._log('气泡展示 ${text.length} 字');
    // 兜底：打字回调异常时也按时收起
    _bubbleSafetyTimer = Timer(const Duration(seconds: 90), _hideBubble);
  }

  void _hideBubble() {
    _bubbleTimer?.cancel();
    _bubbleSafetyTimer?.cancel();
    if (!mounted) return;
    setState(() => _bubbleText = null);
    GlobalFloatingPetService._log('气泡收起');
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

  /// 点击区域随机台词气泡：按命中清单（与拖拽命中过滤同一份
  /// [VideoPetManifest]）查出区域 [VideoPetRegion.effectiveMessages]
  /// 随机取一条展示；未命中区域/无台词保持静默，区域点击动画
  /// 由播放器自理，互不影响。
  void _showRegionTapBubble(
    VideoPetManifest? manifest,
    String? regionId,
    String? regionName,
  ) {
    final messages = manifest
        ?.regionFor(regionId, regionName)
        ?.effectiveMessages;
    if (messages == null || messages.isEmpty) return;
    var text = messages[_tapMessageRandom.nextInt(messages.length)];
    // 池内多于一条时避免与当前气泡重复（同 Home 侧随机语义）
    if (messages.length > 1 && text == _bubbleText) {
      final others = messages.where((m) => m != text).toList();
      if (others.isNotEmpty) text = others.first;
    }
    if (!mounted) return;
    // 与转发回复气泡同一条生命周期：先清旧定时器，展示后由
    // 打字完成回调 _onBubbleTyped 按文本长度计时收起
    _bubbleTimer?.cancel();
    _bubbleSafetyTimer?.cancel();
    setState(() => _bubbleText = text);
    GlobalFloatingPetService._log(
      '区域台词气泡 region=${regionId ?? regionName} ${text.length} 字',
    );
    // 兜底：打字回调异常时也按时收起
    _bubbleSafetyTimer = Timer(const Duration(seconds: 90), _hideBubble);
  }

  /// 所有 enabled 区域的归一化并集外接矩形投影到展示盒坐标。
  ///
  /// 无清单 / 无区域 / 无启用区域 → 整画布（0,0,1,1），即整盒贴边
  /// （Live2D 与未配置区域视频的原行为，全禁用视频本就无处可拖）。
  /// petBox 与画布等比（boxSizeFor 保证），归一化直接线性映射，
  /// 缩放（fitScale）与横竖视频天然正确。
  static Rect _projectUnionBox(VideoPetManifest? manifest, Size petBox) {
    final regions = manifest?.regions;
    if (regions == null || regions.isEmpty) {
      return Offset.zero & petBox;
    }
    double left = 1.0, top = 1.0, right = 0.0, bottom = 0.0;
    for (final region in regions) {
      if (!region.enabled) continue;
      left = math.min(left, region.x);
      top = math.min(top, region.y);
      right = math.max(right, region.x + region.width);
      bottom = math.max(bottom, region.y + region.height);
    }
    if (right < left || bottom < top) return Offset.zero & petBox;
    return Rect.fromLTRB(
      left * petBox.width,
      top * petBox.height,
      right * petBox.width,
      bottom * petBox.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 首页（果冻小屋及其子页签）隐藏：不渲染也不参与命中
    if (!GlobalFloatingPetService.instance.shouldRender) {
      return const SizedBox.shrink();
    }
    final plugin = Live2DPlugin.instance;
    final archive = plugin.globalPetArchive;
    final model = archive == null
        ? null
        : modelDefinitionForArchive(
            archive,
            importedModels: plugin.importedModels,
          );
    if (archive == null || model == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;
        final safe = MediaQuery.paddingOf(context);
        // 键盘弹起时把宠物压回可视区（viewInsets.bottom）
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        // 可活动边界：安全区内收 8px，避免宠物贴死刘海/手势条/键盘
        final bounds = Rect.fromLTRB(
          safe.left + 8,
          safe.top + 8,
          math.max(safe.left + 8, screenW - safe.right - 8),
          math.max(
            safe.top + 8,
            screenH - math.max(safe.bottom + 8, keyboard + 8),
          ),
        );
        if (bounds.width <= 0 || bounds.height <= 0) {
          return const SizedBox.shrink();
        }
        // 小屏（分屏/窗口缩小）时按屏幕预算压缩宠物尺寸。
        // size 语义：Live2D=宠物高度，视频=宠物宽度（见 GlobalPetView），
        // 先按原始 size 出盒，再用统一 fitScale 同比缩放，
        // 保证宽高两个维度都不超可活动边界（竖版视频高>宽时同样受限）
        final rawBox = GlobalPetView.boxSizeFor(model, plugin.globalPetSize);
        final fitScale = math.min(
          1.0,
          math.min(
            bounds.width / math.max(1.0, rawBox.width),
            bounds.height / math.max(1.0, rawBox.height),
          ),
        );
        final petSize = plugin.globalPetSize * fitScale;
        // 紧贴宠物内容的展示盒：无舞台空白，盒即命中范围
        final petBox = GlobalPetView.boxSizeFor(model, petSize);
        // 视频桌宠的命中过滤清单：优先模型自带，兜底异步解析结果
        // （按模型实例比对防存档切换串档）；Live2D 为 null → 整盒命中
        final videoManifest = model.isVideo
            ? (model.videoManifest ??
                  (identical(_resolvedManifestFor, model)
                      ? _resolvedVideoManifest
                      : null))
            : null;
        // 交互区域并集（归一化画布坐标）投影到当前展示盒：
        // petBox 与画布等比（boxSizeFor），归一化直接线性映射。
        // 拖拽贴边以并集为准——交互区域贴住屏幕四边，非交互画布
        // 允许局部出屏（Positioned 取负值，屏幕外由 Stack 裁剪不可见）；
        // Live2D / 未配置区域的视频并集=整盒 → 与原整盒贴边完全一致
        final unionBox = _projectUnionBox(videoManifest, petBox);
        // 首次挂载默认停在右下角（并集右下角对齐边界右下角）
        _petPosition ??= Offset(
          math.max(bounds.left - unionBox.left, bounds.right - unionBox.right),
          math.max(bounds.top - unionBox.top, bounds.bottom - unionBox.bottom),
        );
        // petBox 允许位置范围：并集始终落在可活动边界内
        final minLeft = bounds.left - unionBox.left;
        final maxLeft = bounds.right - unionBox.right;
        final minTop = bounds.top - unionBox.top;
        final maxTop = bounds.bottom - unionBox.bottom;
        // 展示位置：窗口/安全区变化时把宠物夹回边界内（不改内存位置）
        final petLeft = _petPosition!.dx.clamp(minLeft, maxLeft).toDouble();
        final petTop = _petPosition!.dy.clamp(minTop, maxTop).toDouble();

        // 气泡尺寸与位置：跟随宠物且保持在屏幕内。
        // 精灵图（视频）与视频显示宽精确同宽（仅屏幕安全宽度收窄，
        // 不做 160/260 人为截断，见 jellyVideoBubbleWidthFor）；
        // Live2D 维持 260 上限。
        final bubbleWidth = model.isVideo
            ? jellyVideoBubbleWidthFor(
                videoWidth: petBox.width,
                maxWidth: bounds.width,
              )
            : math.min(260.0, bounds.width);
        final bubbleHeight = math
            .min(140.0, math.max(0.0, bounds.height * 0.35))
            .toDouble();
        final bubbleVisible = _bubbleText != null && bubbleHeight > 40;
        double bubbleTop = petTop;
        double bubbleLeft = petLeft;
        if (bubbleVisible) {
          final roomAbove = petTop - bounds.top;
          final roomBelow = bounds.bottom - petTop - petBox.height;
          final showBelow =
              roomAbove < bubbleHeight + _bubbleGap && roomBelow > roomAbove;
          bubbleTop = showBelow
              ? math.min(
                  petTop + petBox.height + _bubbleGap,
                  bounds.bottom - bubbleHeight,
                )
              : math.max(bounds.top, petTop - bubbleHeight - _bubbleGap);
          bubbleLeft = (petLeft + petBox.width / 2 - bubbleWidth / 2)
              .clamp(
                bounds.left,
                math.max(bounds.left, bounds.right - bubbleWidth),
              )
              .toDouble();
        }

        // 全屏透明 Stack：自身不命中，只有宠物盒与气泡参与手势，
        // 不遮挡 App 其他区域的交互
        return Stack(
          fit: StackFit.expand,
          children: [
            if (bubbleVisible)
              Positioned(
                left: bubbleLeft,
                top: bubbleTop,
                width: bubbleWidth,
                height: bubbleHeight,
                child: AppTheme(
                  data: AppTheme.of(context),
                  child: JellySpeechBubble(
                    key: ValueKey('global-pet-bubble-$_bubbleText'),
                    text: _bubbleText!,
                    modelName: model.label,
                    typingInterval: plugin.bubbleTypingInterval,
                    onTypingComplete: _onBubbleTyped,
                    onUserInteract: _onBubbleInteract,
                    onTap: _hideBubble,
                  ),
                ),
              ),
            // 宠物命中盒=展示盒（紧贴内容，无舞台空白）：外层拖拽。
            // 视频桌宠在 hit-test 阶段进一步限定在 manifest.regions 的
            // enabled 归一化矩形内，区域外/letterbox 直接穿透到下层页面；
            // Live2D（manifest=null）与未配置区域的视频保持整盒命中。
            // opaque 确保拖拽不被下层页面滚动抢走；盒外区域穿透到 App。
            // Listener 记录 Flutter 是否收到指针（平台视图吃事件时无此日志）
            Positioned(
              left: petLeft,
              top: petTop,
              width: petBox.width,
              height: petBox.height,
              child: VideoPetRegionHitBox(
                manifest: videoManifest,
                child: Listener(
                  onPointerDown: (event) => GlobalFloatingPetService._log(
                    'pointer down local=${event.localPosition} '
                    'global=${event.position} kind=${event.kind}',
                  ),
                  child: RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // 鼠标点击的微抖动（1-2px）若走默认 pan 判定（鼠标
                    // slop 仅 1px）会抢先竞技场、吃掉播放器的 tap，导致
                    // 区域点击动画失效；改用自定识别器把鼠标接受阈值
                    // 提高到 8px，让 tap 存活，拖拽行为不变。
                    gestures: {
                      _GlobalPetPanGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            _GlobalPetPanGestureRecognizer
                          >(
                            () => _GlobalPetPanGestureRecognizer(
                              debugOwner: this,
                            ),
                            (recognizer) {
                              recognizer.onStart = (details) {
                                _dragStartGlobal = details.globalPosition;
                                _dragOrigin = Offset(petLeft, petTop);
                                GlobalFloatingPetService._log(
                                  'drag start origin=$_dragOrigin '
                                  'global=$_dragStartGlobal',
                                );
                              };
                              recognizer.onUpdate = (details) {
                                final start = _dragStartGlobal;
                                final origin = _dragOrigin;
                                if (start == null || origin == null) return;
                                // 稳定起点 + 全局坐标换算：同帧多事件也不丢
                                // delta；夹在并集贴边范围内（非交互画布可
                                // 局部出屏）
                                final next =
                                    origin + (details.globalPosition - start);
                                setState(() {
                                  _petPosition = Offset(
                                    next.dx.clamp(minLeft, maxLeft).toDouble(),
                                    next.dy.clamp(minTop, maxTop).toDouble(),
                                  );
                                });
                              };
                              recognizer.onEnd = (details) {
                                GlobalFloatingPetService._log(
                                  'drag end pos=$_petPosition '
                                  'v=${details.velocity.pixelsPerSecond}',
                                );
                                _dragStartGlobal = null;
                                _dragOrigin = null;
                              };
                              recognizer.onCancel = () {
                                GlobalFloatingPetService._log(
                                  'drag cancel pos=$_petPosition',
                                );
                                _dragStartGlobal = null;
                                _dragOrigin = null;
                              };
                            },
                          ),
                    },
                    // 独立全局宠物组件：无背景/无随机游走/无内部手势，
                    // macOS 原生吃事件已在组件内通过 setInteractive 关闭
                    child: GlobalPetView(
                      key: ValueKey(
                        'global-pet-${archive.id}-${model.modelDir}-${model.modelFile}',
                      ),
                      model: model,
                      size: petSize,
                      opacity: plugin.globalPetOpacity,
                      debugLogging: GlobalFloatingPetService.debugLogging,
                      // 视频恢复内部点按（区域 click/manifest.click 兜底），
                      // 内部不注册 pan，拖拽仍由本层 GestureDetector 处理；
                      // tap 与 pan 手势竞技场互斥，拖动不会误触点击
                      videoInteractive: model.isVideo,
                      // 异步解析的视频清单（loadDefault 兜底路径）回报，
                      // 驱动区域命中过滤；切档由 ValueKey 重建重新解析
                      onManifestResolved: (manifest) {
                        if (!mounted) return;
                        setState(() {
                          _resolvedVideoManifest = manifest;
                          _resolvedManifestFor = model;
                        });
                      },
                      // 点击区域随机台词（视频）：用与拖拽命中过滤同一份
                      // 清单随机取一条气泡；未命中/无台词静默，动画照常
                      onTap: (regionId, regionName) => _showRegionTapBubble(
                        videoManifest,
                        regionId,
                        regionName,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 悬浮宠物拖拽识别器：仅对鼠标（precise 指针）提高接受阈值。
///
/// Flutter 默认鼠标 pan slop 仅 1px（kPrecisePointerHitSlop），点击时的
/// 微抖动会让本层 pan 在手势竞技场抢先胜出、拒绝播放器的 tap，区域点击
/// 动画因此失效；要求移动 ≥8px 才接受 pan，tap 得以存活，触摸维持
/// 默认 18px 判定，拖拽手感不受影响。
class _GlobalPetPanGestureRecognizer extends PanGestureRecognizer {
  _GlobalPetPanGestureRecognizer({super.debugOwner});

  /// 鼠标指针的 pan 接受阈值（像素）
  static const double _preciseAcceptSlop = 8.0;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    if (pointerDeviceKind == PointerDeviceKind.mouse) {
      return globalDistanceMoved.abs() > _preciseAcceptSlop;
    }
    return super.hasSufficientGlobalDistanceToAccept(
      pointerDeviceKind,
      deviceTouchSlop,
    );
  }
}
