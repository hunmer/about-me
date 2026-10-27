import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Node, Value;
import 'package:intl/intl.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/chat_screen.dart';
import 'package:aboutme/plugins/agent_chat/services/conversation_service.dart';
import 'package:aboutme/plugins/openai/models/topic_collection.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/screens/agent_edit_screen.dart';
import 'package:aboutme/plugins/openai/services/topic_chat_service.dart';
import 'package:aboutme/widgets/newspaper_sheet.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 话题合集 tab：合集选择 + 报刊架（分类报纸）
///
/// - 每个顶层分类渲染为一张报纸卡片（见 NewspaperSheet）：
///   报头（分类标题）+ 问题/已回答统计 + 进入详情按钮
/// - 堆叠形态：点按任意报纸直达该分类详情；
///   右下角切换胶囊进入轮播（水平展开浏览，点两侧居中/中央进详情）
/// - 详情页列出分类（含子分组）下的叶子话题，
///   点按弹出该话题的会话列表
/// - 会话经 TopicChatService 创建（hideInList，不进 agent_chat 列表），
///   打开后复用 agent_chat 的 ChatScreen
class TopicCollectionScreen extends StatefulWidget {
  const TopicCollectionScreen({super.key});

  @override
  State<TopicCollectionScreen> createState() => _TopicCollectionScreenState();
}

class _TopicCollectionScreenState extends State<TopicCollectionScreen> {
  static const _springCurve = Cubic(0.22, 1, 0.36, 1);
  static const _animDuration = Duration(milliseconds: 650);

  // 报刊架舞台：堆叠（垂直错落）↔ 轮播（水平展开）
  bool _isStack = true;
  int _activeIndex = 0;
  double _dragDelta = 0;
  bool _dragging = false;

  TopicCollection? _selected;

  ConversationService? _conversationService;

  @override
  void initState() {
    super.initState();
    _bindConversationService();
    // agent_chat 若晚于本屏加载，插件就绪后重绑会话服务
    eventManager.subscribe('plugin_loaded', _onPluginLoaded);
    // 合集目录为 JSON 数据（首次自动从 assets 按 version 同步）
    TopicChatService.instance.loadCollections().then((collections) {
      if (!mounted || collections.isEmpty) return;
      _selectCollection(collections.first);
    });
  }

  void _onPluginLoaded(EventArgs args) {
    if (args is! Value<String> || args.value != 'agent_chat' || !mounted) {
      return;
    }
    _bindConversationService();
    // 合集列表加载是异步的：agent_chat 就绪前加载失败过的话重试
    if (TopicChatService.instance.collections.isEmpty) {
      TopicChatService.instance.loadCollections().then((collections) {
        if (!mounted || collections.isEmpty) return;
        _selectCollection(collections.first);
      });
      return;
    }
    setState(() {});
  }

  void _bindConversationService() {
    _conversationService?.removeListener(_onConversationsChanged);
    _conversationService =
        AgentChatPlugin.instance.conversationController?.conversationService;
    _conversationService?.addListener(_onConversationsChanged);
  }

  @override
  void dispose() {
    eventManager.unsubscribe('plugin_loaded', _onPluginLoaded);
    _conversationService?.removeListener(_onConversationsChanged);
    super.dispose();
  }

  void _onConversationsChanged() {
    if (mounted) setState(() {});
  }

  void _selectCollection(TopicCollection collection) {
    if (_selected?.id == collection.id) return;
    setState(() {
      _selected = collection;
      // 切换合集回到堆叠形态
      _isStack = true;
      _activeIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final collection = _selected;
    if (collection == null) {
      // 合集目录异步加载中（或为空）：空占位保持布局稳定
      return SuperCupertinoNavigationWrapper(
        title: Text('openai_topicsTab'.tr),
        largeTitle: 'openai_topicsTab'.tr,
        enableLargeTitle: false,
        body: const SizedBox.expand(),
      );
    }

    return SuperCupertinoNavigationWrapper(
      title: Text('openai_topicsTab'.tr),
      largeTitle: 'openai_topicsTab'.tr,
      enableLargeTitle: false,
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            // 悬浮 bottom dock 遮挡 body 底部：底部控件需按注入的 padding 避让
            final bottomInset = MediaQuery.paddingOf(context).bottom;
            return Column(
              children: [
                _buildCollectionBar(theme),
                Expanded(
                  child: Stack(
                    children: [
                      // 报刊架舞台
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragStart: _onHorizontalDragStart,
                          onHorizontalDragUpdate: _onHorizontalDragUpdate,
                          onHorizontalDragEnd: _onHorizontalDragEnd,
                          child: _buildStage(collection),
                        ),
                      ),
                      // 底部白色渐隐遮罩
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 118 + bottomInset,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 450),
                            opacity: _isStack ? 1 : 0.35,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [0, 0.48, 0.8, 1],
                                  colors: [
                                    Color(0x00FFFFFF),
                                    Color(0xB8FFFFFF),
                                    Color(0xF5FFFFFF),
                                    Color(0xFFFFFFFF),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 轮播分页短条
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 92 + bottomInset,
                        child: IgnorePointer(
                          ignoring: _isStack,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: _isStack ? 0 : 1,
                            child: AnimatedSlide(
                              duration: const Duration(milliseconds: 450),
                              curve: _springCurve,
                              offset: Offset(0, _isStack ? 0.4 : 0),
                              child: _buildPaginationDashes(collection),
                            ),
                          ),
                        ),
                      ),
                      // 右下角 堆叠/轮播 切换胶囊
                      Positioned(
                        right: 24,
                        bottom: 24 + bottomInset,
                        child: _buildViewToggle(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.bot,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'openai_topicEditAgent'.tr,
                onPressed: () => _editCollectionAgent(collection),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 合集选择条（当前仅一份合集，后续可继续追加）
  Widget _buildCollectionBar(AppThemeData theme) {
    final collections = TopicChatService.instance.collections;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.lg,
        theme.spacing.sm,
        theme.spacing.lg,
        theme.spacing.xs,
      ),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: collections.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final collection = collections[index];
            return DSChip(
              label: collection.name,
              icon: DsIconKind.category,
              selected: collection.id == _selected?.id,
              onSelected: (_) => _selectCollection(collection),
            );
          },
        ),
      ),
    );
  }

  // ========== 报刊架舞台（堆叠 ↔ 轮播） ==========

  /// 分类统计：子树内叶子话题数 = 问题数，挂有会话的叶子数 = 已回答数
  ({int total, int answered}) _topicStats(
    TopicCollection collection,
    TopicNode topic,
  ) {
    final counts = TopicChatService.instance.conversationCounts(collection);
    final leaves = topic.subtree().where((node) => !node.isGroup).toList();
    final answered = leaves.where((node) => (counts[node.id] ?? 0) > 0).length;
    return (total: leaves.length, answered: answered);
  }

  void _onCardTap(TopicCollection collection, int index) {
    if (_isStack) {
      // 堆叠中点按任意报纸：直达该分类详情（轮播浏览经右下角切换按钮进入）
      _openDetail(collection, collection.topics[index]);
    } else if (index != _activeIndex) {
      setState(() => _activeIndex = index);
    } else {
      _openDetail(collection, collection.topics[index]);
    }
  }

  void _openDetail(TopicCollection collection, TopicNode topic) {
    NavigationHelper.push(
      context,
      _TopicGroupDetailScreen(collection: collection, group: topic),
    );
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_isStack) return;
    setState(() {
      _dragging = true;
      _dragDelta = 0;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    setState(() => _dragDelta += details.delta.dx);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    final count = _selected?.topics.length ?? 0;
    final velocity = details.primaryVelocity ?? 0;
    var next = _activeIndex;
    final swipedLeft = _dragDelta < -48 || velocity < -280;
    final swipedRight = _dragDelta > 48 || velocity > 280;
    if (swipedLeft && !swipedRight && _activeIndex < count - 1) {
      next = _activeIndex + 1;
    } else if (swipedRight && !swipedLeft && _activeIndex > 0) {
      next = _activeIndex - 1;
    }
    setState(() {
      _dragging = false;
      _dragDelta = 0;
      _activeIndex = next;
    });
  }

  Widget _buildStage(TopicCollection collection) {
    final count = collection.topics.length;
    // 按 z 序排序（小的先绘制）：堆叠按序号，轮播按与当前的距离
    final order = List<int>.generate(count, (i) => i)
      ..sort((a, b) {
        final za = _isStack
            ? a
            : (a == _activeIndex
                  ? 10
                  : ((a - _activeIndex).abs() == 1 ? 5 : 1));
        final zb = _isStack
            ? b
            : (b == _activeIndex
                  ? 10
                  : ((b - _activeIndex).abs() == 1 ? 5 : 1));
        return za.compareTo(zb);
      });
    return LayoutBuilder(
      builder: (context, constraints) {
        // 底部悬浮 dock 区域：舞台中心上移、堆叠间距预留，避免报纸压到 dock
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final cx = constraints.maxWidth / 2;
        final cy = constraints.maxHeight / 2 - bottomInset / 2;
        final size = MediaQuery.sizeOf(context);
        final cardW = math.min(320.0, size.width - 48);
        const cardH = 190.0;
        // 堆叠间距：报纸数量多时压缩，整堆不超出舞台
        final spacing = math.min(
          100.0,
          (constraints.maxHeight - 60 - bottomInset - cardH) /
              math.max(1, count - 1),
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final i in order)
              // 必须带 key：切换 activeIndex 时 z 序会重排，
              // 无 key 会导致卡片按位置复用、从别的卡片的旧 transform 开始插值而跳变
              Positioned(
                key: ValueKey(i),
                left: cx - cardW / 2,
                top: cy - cardH / 2,
                child: _buildPositionedCard(collection, i, cardW, spacing),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPositionedCard(
    TopicCollection collection,
    int i,
    double cardW,
    double spacing,
  ) {
    final count = collection.topics.length;
    final topic = collection.topics[i];
    final stats = _topicStats(collection, topic);

    double x, y, rot, scale, opacity;
    if (_isStack) {
      // 堆叠：居中垂直排列，后面的报纸盖住前面的下半部（露出报头）
      x = i.isEven ? -5.0 : 5.0;
      y = (i - (count - 1) / 2) * spacing;
      rot = i.isEven ? -2.2 : 1.7;
      scale = 0.96;
      opacity = 1;
    } else {
      // 轮播：中央居前，左右相邻各露一列，其余移出并淡出
      final offset = i - _activeIndex;
      final shift = _dragDelta * 0.85;
      final spread = cardW * 0.9;
      if (offset == 0) {
        x = shift;
        y = -10;
        rot = 1.6 + _dragDelta * 0.015;
        scale = 1.04;
        opacity = 1;
      } else if (offset == -1) {
        x = -spread + shift;
        y = 18;
        rot = -4.5;
        scale = 0.94;
        opacity = 1;
      } else if (offset == 1) {
        x = spread + shift;
        y = 22;
        rot = -3.5;
        scale = 0.94;
        opacity = 1;
      } else {
        x = offset < 0 ? -600 : 600;
        y = 40;
        rot = offset < 0 ? -8 : 8;
        scale = 0.85;
        opacity = 0;
      }
    }
    final radians = rot * math.pi / 180;
    final matrix = Matrix4.identity()
      ..translate(x, y)
      ..rotateZ(radians)
      ..scale(scale);
    final duration = _dragging ? Duration.zero : _animDuration;
    return AnimatedOpacity(
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 450),
      opacity: opacity,
      child: AnimatedContainer(
        duration: duration,
        curve: _springCurve,
        transform: matrix,
        transformAlignment: Alignment.center,
        child: GestureDetector(
          onTap: () => _onCardTap(collection, i),
          child: _TopicNewspaper(
            title: topic.title,
            total: stats.total,
            answered: stats.answered,
            width: cardW,
            onOpenDetail: () => _openDetail(collection, topic),
          ),
        ),
      ),
    );
  }

  // ---------- 轮播分页短条 ----------

  Widget _buildPaginationDashes(TopicCollection collection) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < collection.topics.length; i++)
          GestureDetector(
            onTap: () => setState(() => _activeIndex = i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: _springCurve,
                width: i == _activeIndex ? 22 : 18,
                height: 3,
                decoration: BoxDecoration(
                  color: i == _activeIndex
                      ? const Color(0xFF7A7A7A)
                      : const Color(0xFFE2E2E2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------- 堆叠/轮播 切换胶囊 ----------

  Widget _buildViewToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isStack = !_isStack),
      child: Container(
        width: 92,
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F3),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: _springCurve,
              left: _isStack ? 42 : 0,
              top: 0,
              child: Container(
                width: 42,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                _viewModeIcon(Icons.view_carousel_outlined, active: !_isStack),
                _viewModeIcon(Icons.view_agenda_outlined, active: _isStack),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewModeIcon(IconData icon, {required bool active}) {
    return SizedBox(
      width: 42,
      height: 38,
      child: Icon(
        icon,
        size: 19,
        color: active ? const Color(0xFF1C1C1E) : const Color(0xFF8E8E93),
      ),
    );
  }

  // ========== 合集 agent 配置 ==========

  /// 打开 agent 编辑页：合集的 AI 是一份完整 agent 配置，
  /// 独立存储（extra storage），经 AgentEditScreen 编辑。
  /// 走 onSave 回调模式：保存由回调写独立存储，
  /// 编辑页的分享/克隆/删除入口（面向全局 agent 列表）不出现
  Future<void> _editCollectionAgent(TopicCollection collection) async {
    final agent = await TopicChatService.instance.ensureCollectionAgent(
      collection,
    );
    if (!mounted) return;
    await NavigationHelper.push(
      context,
      AgentEditScreen(
        agent: agent,
        onSave: (edited) async {
          await AgentController().saveAgentToExtraStorage(
            edited,
            TopicChatService.storageKeyFor(collection),
          );
          return edited;
        },
      ),
    );
    // 编辑保存写入了独立存储，重新注入临时表让新对话立即生效
    await TopicChatService.instance.ensureCollectionAgent(collection);
  }
}

/// 分类报纸卡片：报头（分类标题）+ 问题/已回答统计 + 进入详情按钮
/// （整卡点按由舞台层处理，这里只保留按钮的直达详情）
class _TopicNewspaper extends StatelessWidget {
  const _TopicNewspaper({
    required this.title,
    required this.total,
    required this.answered,
    required this.width,
    this.onOpenDetail,
  });

  final String title;
  final int total;
  final int answered;
  final double width;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, MMM d, yyyy').format(DateTime.now());
    // 窄卡（小屏）字号整体缩一档
    final compact = width < 300;
    return NewspaperSheet(
      width: width,
      height: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部信息行（报纸日期栏风格）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOPIC EDITION',
                style: TextStyle(
                  fontSize: 9,
                  color: Color(0xFF6B6B6B),
                  letterSpacing: 2,
                ),
              ),
              Text(
                date.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF6B6B6B),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          // 报头：分类标题
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 20 : 23,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF141413),
                fontFamilyFallback: const ['serif'],
              ),
            ),
          ),
          // 报纸双线分隔
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Column(
              children: [
                ColoredBox(
                  color: Color(0xFF262626),
                  child: SizedBox(width: double.infinity, height: 1.5),
                ),
                SizedBox(height: 1.5),
                ColoredBox(
                  color: Color(0xFF262626),
                  child: SizedBox(width: double.infinity, height: 0.7),
                ),
              ],
            ),
          ),
          // 统计、进度与按钮
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _statNumber(
                          '$total',
                          'openai_topicQuestions'.tr,
                          compact: compact,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 42,
                        color: const Color(0x33262626),
                      ),
                      Expanded(
                        child: _statNumber(
                          '$answered',
                          'openai_topicAnswered'.tr,
                          compact: compact,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // 已回答进度条（会话数变化时平滑填充）
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _buildProgressBar(),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$answered / $total',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF8A8A8A),
                          letterSpacing: 1,
                        ),
                      ),
                      _buildOpenButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statNumber(String number, String label, {bool compact = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          number,
          style: TextStyle(
            fontSize: compact ? 26 : 30,
            height: 1,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF141413),
            fontFamilyFallback: const ['serif'],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B6B6B),
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  /// 已回答进度条：底槽浅灰，已回答比例深墨填充
  Widget _buildProgressBar() {
    final factor = total > 0 ? (answered / total).clamp(0.0, 1.0) : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E2E2),
            borderRadius: BorderRadius.circular(2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: const Cubic(0.22, 1, 0.36, 1),
              width: constraints.maxWidth * factor,
              color: const Color(0xFF262626),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpenButton() {
    return GestureDetector(
      onTap: onOpenDetail,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF141413),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'openai_topicOpenDetail'.tr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.arrow_forward, size: 13, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// 分类详情页：列出分类（含子分组）下的叶子话题，点按弹出会话列表
class _TopicGroupDetailScreen extends StatefulWidget {
  const _TopicGroupDetailScreen({
    required this.collection,
    required this.group,
  });

  final TopicCollection collection;
  final TopicNode group;

  @override
  State<_TopicGroupDetailScreen> createState() =>
      _TopicGroupDetailScreenState();
}

class _TopicGroupDetailScreenState extends State<_TopicGroupDetailScreen> {
  ConversationService? _conversationService;

  List<TopicNode> get _leaves =>
      widget.group.subtree().where((node) => !node.isGroup).toList();

  @override
  void initState() {
    super.initState();
    _bindConversationService();
    eventManager.subscribe('plugin_loaded', _onPluginLoaded);
  }

  void _onPluginLoaded(EventArgs args) {
    if (args is! Value<String> || args.value != 'agent_chat' || !mounted) {
      return;
    }
    _bindConversationService();
    setState(() {});
  }

  void _bindConversationService() {
    _conversationService?.removeListener(_onConversationsChanged);
    _conversationService =
        AgentChatPlugin.instance.conversationController?.conversationService;
    _conversationService?.addListener(_onConversationsChanged);
  }

  @override
  void dispose() {
    eventManager.unsubscribe('plugin_loaded', _onPluginLoaded);
    _conversationService?.removeListener(_onConversationsChanged);
    super.dispose();
  }

  void _onConversationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: Text(widget.group.title),
      largeTitle: widget.group.title,
      enableLargeTitle: false,
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.lg,
                theme.spacing.md,
                theme.spacing.lg,
                theme.spacing.xl,
              ),
              itemCount: _leaves.length,
              separatorBuilder: (_, __) => SizedBox(height: theme.spacing.md),
              itemBuilder: (context, index) =>
                  _buildTopicTile(theme, _leaves[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopicTile(AppThemeData theme, TopicNode topic) {
    final count = _conversationCount(topic);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showTopicSheet(topic),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm + 2,
        ),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surface,
          radius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    topic.title,
                    style: DsTypography.body.copyWith(
                      color: theme.text,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (topic.depthLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      topic.depthLabel!,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: dsSketchDecoration(
                  theme: theme,
                  fillColor: theme.primary,
                  circle: true,
                ),
                child: Text(
                  '$count',
                  style: DsTypography.caption.copyWith(
                    fontSize: 10,
                    color: theme.onPrimary,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            DsIcon(DsIconKind.chevronRight, size: 16, color: theme.textSub),
          ],
        ),
      ),
    );
  }

  int? _conversationCount(TopicNode topic) {
    final counts = TopicChatService.instance.conversationCounts(
      widget.collection,
    );
    final count = widget.collection.conversationCountFor(topic, counts);
    return count > 0 ? count : null;
  }

  // ========== 话题会话 ==========

  Future<void> _showTopicSheet(TopicNode topic) async {
    final theme = DSThemeBridge.resolve(context);
    await SmoothBottomSheet.showWithTitle<void>(
      context: context,
      title: topic.title,
      child: Builder(
        builder: (sheetContext) {
          final conversations = TopicChatService.instance.conversationsFor(
            widget.collection,
            topic,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SmoothSheetAction(
                icon: DsIconKind.plus,
                label: 'openai_topicNewConversation'.tr,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _createAndOpen(topic);
                },
              ),
              if (conversations.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    theme.spacing.lg,
                    theme.spacing.md,
                    theme.spacing.lg,
                    theme.spacing.xs,
                  ),
                  child: Text(
                    'openai_topicConversations'.tr,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ),
                ...conversations.asMap().entries.map(
                  (entry) => _buildConversationTile(
                    theme,
                    topic,
                    entry.key + 1,
                    entry.value,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildConversationTile(
    AppThemeData theme,
    TopicNode topic,
    int index,
    Conversation conversation,
  ) {
    final time = DateFormat('MM-dd HH:mm').format(conversation.lastMessageAt);
    return Padding(
      padding: EdgeInsets.only(
        left: theme.spacing.md,
        right: theme.spacing.md,
        bottom: theme.spacing.sm,
      ),
      child: Container(
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surface,
          radius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openConversation(conversation),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacing.md,
                    vertical: theme.spacing.sm + 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'openai_topicConversationLabel'.trParams({
                              'index': '$index',
                            }),
                            style: DsTypography.body.copyWith(
                              color: theme.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            time,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                        ],
                      ),
                      if (conversation.lastMessagePreview?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 2),
                        Text(
                          conversation.lastMessagePreview!,
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: theme.spacing.sm),
              child: DSIconButton(
                icon: DsIconKind.trash,
                size: 32,
                color: Colors.transparent,
                iconColor: theme.textSub,
                tooltip: 'openai_topicDeleteConversation'.tr,
                onPressed: () =>
                    _confirmDeleteConversation(topic, conversation),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteConversation(
    TopicNode topic,
    Conversation conversation,
  ) async {
    final theme = DSThemeBridge.resolve(context);
    final confirm = await showDSDialog<bool>(
      context: context,
      theme: theme,
      builder: (dialogContext) => DSDialog(
        title: 'openai_topicDeleteConversation'.tr,
        message: 'openai_topicDeleteConfirm'.tr,
        cancelText: 'app_cancel'.tr,
        confirmText: 'openai_topicDeleteConversation'.tr,
        confirmVariant: DSButtonVariant.destructive,
        onConfirm: () => Navigator.pop(dialogContext, true),
        onCancel: () => Navigator.pop(dialogContext, false),
      ),
    );
    if (confirm != true) return;
    await _conversationService?.deleteConversation(conversation.id);
    if (mounted) {
      toastService.showToast('openai_topicConversationDeleted'.tr);
      // 会话删完后收起话题 sheet，回到话题列表
      if (TopicChatService.instance
          .conversationsFor(widget.collection, topic)
          .isEmpty) {
        Navigator.of(context).maybePop();
      }
    }
  }

  Future<void> _createAndOpen(TopicNode topic) async {
    try {
      final conversation = await TopicChatService.instance.createConversation(
        collection: widget.collection,
        topic: topic,
      );
      if (!mounted) return;
      _openConversation(conversation);
    } catch (e) {
      if (mounted) {
        toastService.showToast('${'openai_topicCreateFailed'.tr}: $e');
      }
    }
  }

  void _openConversation(Conversation conversation) async {
    final controller = AgentChatPlugin.instance.conversationController;
    if (controller == null) {
      toastService.showToast('openai_topicChatUnavailable'.tr);
      return;
    }
    // 合集 agent 存在独立存储（extra storage），会话按 agentId 解析前
    // 需注入临时列表（app 重启后临时表为空）
    final collection = TopicChatService.instance.collectionById(
      TopicChatService.topicInfoOf(conversation)?.collectionId ?? '',
    );
    if (collection != null) {
      await TopicChatService.instance.ensureCollectionAgent(collection);
    }
    if (!mounted) return;
    NavigationHelper.push(
      context,
      ChatScreen(
        conversation: conversation,
        storage: AgentChatPlugin.instance.storage,
        conversationService: controller.conversationService,
        getSettings: () => AgentChatPlugin.instance.settings,
      ),
    );
  }
}
