import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:super_cupertino_navigation_bar/utils/navigation_bar_static_components.dart';
import 'package:super_cupertino_navigation_bar/utils/persistent_nav_bar.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/openai/moments/widgets/agent_avatar.dart';
import 'package:aboutme/plugins/openai/moments/widgets/photo_viewer_screen.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

import '../widgets/moments_compose_sheet.dart';
import '../widgets/moments_shared.dart';
import 'moments_profile_screen.dart';

/// 朋友圈动态作者（我 / 某个 agent）
class MomentsAuthorInfo {
  final String id; // agentId 或 MomentPost.userAuthorId
  final AIAgent? agent;

  const MomentsAuthorInfo({required this.id, this.agent});

  bool get isUser => id == MomentPost.userAuthorId;

  String get name =>
      isUser ? 'moments_me'.tr : (agent?.name ?? 'moments_unknownAgent'.tr);

  Widget avatar({double size = 40}) {
    if (isUser) return UserAvatar(size: size);
    return AgentAvatar(agent: agent, size: size);
  }
}

/// 朋友圈 · 动态流（手绘纸墨风：墨线卡片便签化 + 弧形圆盘 dock）
class MomentsFeedScreen extends StatefulWidget {
  const MomentsFeedScreen({super.key});

  @override
  State<MomentsFeedScreen> createState() => MomentsFeedScreenState();
}

class MomentsFeedScreenState extends State<MomentsFeedScreen> {
  final _moments = MomentsService.instance;
  final _scrollController = ScrollController();
  final _navBarKeys = NavigationBarStaticComponentsKeys();
  final Map<String, AIAgent> _agents = {};
  String? _filter; // null = 全部

  @override
  void initState() {
    super.initState();
    _moments.addListener(_onChanged);
    _moments.loadPosts();
    _loadAgents();
  }

  @override
  void dispose() {
    _moments.removeListener(_onChanged);
    _scrollController.dispose();
    super.dispose();
  }

  /// 供宿主页 tab 调用：已在本页时点击「首页」回到顶部
  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAgents() async {
    try {
      final controller = AgentController();
      await controller.loadAgents();
      if (!mounted) return;
      setState(() {
        for (final agent in controller.agents) {
          _agents[agent.id] = agent;
        }
      });
    } catch (e) {
      debugPrint('[Moments] 加载 agent 失败: $e');
    }
  }

  MomentsAuthorInfo _authorOf(MomentPost post) => MomentsAuthorInfo(
    id: post.isUserPost ? MomentPost.userAuthorId : post.agentId,
    agent: _agents[post.agentId],
  );

  /// 故事栏作者：我置顶，agent 按最近发帖排序
  List<MomentsAuthorInfo> _storyAuthors(List<MomentPost> posts) {
    final latest = <String, DateTime>{};
    for (final post in posts) {
      final key = post.isUserPost ? MomentPost.userAuthorId : post.agentId;
      if (latest[key] == null || post.createdAt.isAfter(latest[key]!)) {
        latest[key] = post.createdAt;
      }
    }
    final agentIds =
        latest.keys
            .where((k) => k != MomentPost.userAuthorId)
            .toList()
          ..sort((a, b) => latest[b]!.compareTo(latest[a]!));
    return [
      const MomentsAuthorInfo(id: MomentPost.userAuthorId),
      for (final id in agentIds) MomentsAuthorInfo(id: id, agent: _agents[id]),
    ];
  }

  int get _todayAgentPostCount {
    final now = DateTime.now();
    return _moments.posts
        .where(
          (p) => !p.isUserPost && now.difference(p.createdAt).inHours < 24,
        )
        .length;
  }

  void _openProfile(MomentsAuthorInfo author) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (_, __, ___) => MomentsProfileScreen(
              agentId: author.isUser ? null : author.id,
            ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  void _openStory(MomentsAuthorInfo author, List<MomentPost> posts) {
    final items =
        posts
            .where(
              (p) =>
                  (p.isUserPost ? MomentPost.userAuthorId : p.agentId) ==
                  author.id,
            )
            .take(8)
            .toList();
    if (items.isEmpty) {
      unawaited(_openCompose());
      return;
    }
    unawaited(_moments.markAuthorSeen(author.id));
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder:
            (_, __, ___) => StoryViewerScreen(author: author, posts: items),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  Future<void> _openCompose() async {
    await SmoothBottomSheet.showWithTitle(
      context: context,
      title: 'moments_composeTitle'.tr,
      child: const MomentsComposeSheet(),
    );
  }

  void _confirmDelete(MomentPost post) async {
    final ok = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder:
                  (ctx) => DSDialog(
                    title: 'moments_deleteTitle'.tr,
                    message: 'moments_deleteMessage'.tr,
                    cancelText: 'app_cancel'.tr,
                    confirmText: 'app_delete'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onConfirm: () => Navigator.pop(dialogContext, true),
                    onCancel: () => Navigator.pop(dialogContext, false),
                  ),
            ),
          ),
    );
    if (ok == true) {
      await _moments.deletePost(post.id);
      if (mounted) ToastService.instance.showToast('moments_deleted'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final posts =
        _filter == null
            ? _moments.posts
            : _moments.posts.where((p) => p.tag == _filter).toList();
    final unread = _todayAgentPostCount;
    final coverPath = _moments.profileBgOf(MomentPost.userAuthorId);
    final hasCover = coverPath != null && coverPath.isNotEmpty;

    final navBar = _buildNavBar(theme, unread);
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child:
            hasCover
                ? MomentsCover(path: coverPath, height: 210)
                : _buildFeedBanner(theme),
      ),
      SliverToBoxAdapter(child: _buildStories(theme)),
      SliverToBoxAdapter(child: _buildFilters()),
      if (posts.isEmpty)
        SliverToBoxAdapter(
          child: SizedBox(height: 320, child: _buildEmpty(theme)),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
          sliver: SliverList.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              // 便签化：贴条 + 倾斜 + 悬浮（design.md §11）
              return HandDrawnStickyItem(
                tiltKey: post.id,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MomentFeedCard(
                    post: post,
                    author: _authorOf(post),
                    saved: _moments.isPostSaved(post.id),
                    onToggleSave: () => _moments.togglePostSaved(post.id),
                    onOpenProfile: () => _openProfile(_authorOf(post)),
                    onDelete: () => _confirmDelete(post),
                  ),
                ),
              );
            },
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: theme.background,
      extendBody: true,
      // 设置了背景图：头部透明浮在封面上（封面延伸到状态栏后）；
      // 未设置：常规固定头部 + 签名统计横幅
      body:
          hasCover
              ? Stack(
                children: [
                  Positioned.fill(
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: slivers,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: navBar,
                  ),
                ],
              )
              : Column(
                children: [
                  navBar,
                  Expanded(
                    // 全部内容进滚动区，任意窗口高度都不会溢出
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: slivers,
                    ),
                  ),
                ],
              ),
    );
  }

  /// 固定头部：标题 + 互动铃铛（投稿入口已移至底部 dock 右侧圆钮）
  Widget _buildNavBar(AppThemeData theme, int unread) {
    return PersistentNavigationBar(
      components: NavigationBarStaticComponents(
        keys: _navBarKeys,
        route: null,
        userLeading: null,
        automaticallyImplyLeading: false,
        automaticallyImplyTitle: false,
        previousPageTitle: null,
        userMiddle: Text(
          'moments_name'.tr,
          style: DsTypography.title.copyWith(color: theme.text),
        ),
        userTrailing: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DSIconButton(
                icon: DsIconKind.heart,
                size: 38,
                onPressed:
                    () => ToastService.instance.showToast(
                      unread > 0
                          ? 'moments_interactNew'.trParams({'n': '$unread'})
                          : 'moments_interactNone'.tr,
                    ),
              ),
              if (unread > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: theme.danger,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unread',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: theme.onDanger,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        userLargeTitle: null,
        largeTitleActions: null,
        appbarBottom: null,
        padding: null,
        large: false,
      ),
    );
  }

  /// 未设背景图时的顶部手写签名 + 统计横幅
  Widget _buildFeedBanner(AppThemeData theme) {
    final now = DateTime.now();
    final today =
        _moments.posts
            .where((p) => now.difference(p.createdAt).inHours < 24)
            .length;
    final buddies =
        _moments.posts
            .where((p) => !p.isUserPost)
            .map((p) => p.agentId)
            .toSet()
            .length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        radius: theme.radii.lg,
        hachure: true,
        hachureColor: theme.hatch,
        seed: 33,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'moments_feedTagline'.tr,
                  style: DsTypography.heading.copyWith(
                    fontSize: 14,
                    color: theme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'moments_feedSubline'.tr,
                  style: DsTypography.caption.copyWith(
                    color: theme.textSub,
                  ),
                ),
              ],
            ),
          ),
          InterestPill(
            label: 'moments_feedToday'.trParams({'n': '$today'}),
            leading: DsIcon(DsIconKind.clock, size: 12),
          ),
          const SizedBox(width: 6),
          InterestPill(
            label: 'moments_feedBuddies'.trParams({'n': '$buddies'}),
            leading: DsIcon(DsIconKind.user, size: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStories(AppThemeData theme) {
    final authors = _storyAuthors(_moments.posts);
    return SizedBox(
      // 上下内边距 12+4 + 头像 66 + 间距 5 + 名字 ~16
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        itemCount: authors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final author = authors[index];
          final seen = _moments.isAuthorSeen(author.id);
          final posts = _moments.posts;
          return _StoryAvatar(
            author: author,
            seen: seen,
            onTap: () => _openStory(author, posts),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
        children: [
          InterestPill(
            label: 'moments_filterAll'.tr,
            selected: _filter == null,
            onTap: () => setState(() => _filter = null),
          ),
          const SizedBox(width: 6),
          for (final tag in MomentTags.all) ...[
            TagPill(
              tag: tag,
              selected: _filter == tag.key,
              onTap: () => setState(() => _filter = tag.key),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(AppThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIcon(
            DsIconKind.image,
            size: 54,
            color: theme.textSub.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 14),
          Text(
            'moments_emptyTitle'.tr,
            style: DsTypography.heading.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 6),
          Text(
            'moments_emptyHint'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ],
      ),
    );
  }
}

/// 故事栏头像（墨线圆环 + 角标贴纸 + 名字）
class _StoryAvatar extends StatelessWidget {
  final MomentsAuthorInfo author;
  final bool seen;
  final VoidCallback onTap;

  const _StoryAvatar({
    required this.author,
    required this.seen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: 66,
            height: 66,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: dsSketchDecoration(
                    theme: theme,
                    fillColor: theme.surface,
                    stroke: seen
                        ? theme.stroke
                        : theme.primaryText.withValues(alpha: 0.9),
                    strokeWidth: 2.2,
                    circle: true,
                    seed: author.id.hashCode & 0x7fffffff,
                  ),
                  child: ClipOval(child: author.avatar(size: 54)),
                ),
                // 角标贴纸：我为 ＋，agent 用云朵
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor:
                          author.isUser ? theme.primary : theme.surface,
                      stroke: theme.ink.withValues(alpha: 0.6),
                      circle: true,
                      seed: 7,
                    ),
                    child: Center(
                      child: Text(
                        author.isUser ? '＋' : '☁️',
                        style: TextStyle(
                          fontSize: author.isUser ? 11 : 10,
                          fontWeight: FontWeight.bold,
                          color:
                              author.isUser ? theme.onPrimary : theme.textSub,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 64,
            child: Text(
              author.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DsTypography.label.copyWith(
                fontSize: 11,
                color: theme.textSub,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 投稿卡片（手绘墨线卡片：头像行 / 图片墨线相框 / 软糖操作行 / 评论）
class MomentFeedCard extends StatefulWidget {
  final MomentPost post;
  final MomentsAuthorInfo author;
  final bool saved;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleSave;

  const MomentFeedCard({
    super.key,
    required this.post,
    required this.author,
    this.saved = false,
    this.onOpenProfile,
    this.onDelete,
    this.onToggleSave,
  });

  @override
  State<MomentFeedCard> createState() => _MomentFeedCardState();
}

class _MomentFeedCardState extends State<MomentFeedCard> {
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();
  int _activeImage = 0;
  int _burstKey = 0;
  bool _commentBoxOpen = false;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _doubleTapLike() {
    if (!widget.post.liked) {
      MomentsService.instance.toggleLike(widget.post.id);
    }
    setState(() => _burstKey++);
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    await MomentsService.instance.addComment(widget.post.id, text);
    ToastService.instance.showToast('moments_commentDone'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final post = widget.post;
    final tag = MomentTags.byKey(post.tag);
    final sourceLabel = switch (post.source) {
      'user' => 'moments_sourceUser'.tr,
      'manual' => 'moments_sourceManual'.tr,
      _ => 'moments_sourceAgent'.tr,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        radius: theme.radii.lg,
        seed: post.id.hashCode & 0x7fffffff,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, tag, sourceLabel),
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPhotoFrame(theme),
          ] else if (post.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTextCard(theme),
          ],
          const SizedBox(height: 12),
          _buildActions(theme),
          const SizedBox(height: 10),
          if (post.text.isNotEmpty && post.images.isNotEmpty)
            _buildCaption(theme),
          if (post.comments.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildComments(theme),
          ],
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child:
                _commentBoxOpen
                    ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: DSInput(
                              controller: _commentController,
                              focusNode: _commentFocus,
                              hint: 'moments_commentHint'.tr,
                              onSubmitted: (_) => _submitComment(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InterestPill(
                            label: 'moments_send'.tr,
                            selected: true,
                            onTap: () => unawaited(_submitComment()),
                          ),
                        ],
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppThemeData theme, MomentTag tag, String sourceLabel) {
    final post = widget.post;
    return Row(
      children: [
        GestureDetector(
          onTap: widget.onOpenProfile,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: theme.surface,
              stroke: theme.ink.withValues(alpha: 0.5),
              circle: true,
              seed: 11,
            ),
            child: widget.author.avatar(size: 38),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: widget.onOpenProfile,
                      child: Text(
                        widget.author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsTypography.heading.copyWith(
                          fontSize: 13.5,
                          color: theme.text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TagPill(
                    tag: tag,
                    fontSize: 10,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$sourceLabel · ${formatRelativeTime(post.createdAt)}',
                style: DsTypography.caption.copyWith(
                  fontSize: 10.5,
                  color: theme.textSub,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: widget.onDelete,
          child: DsIcon(DsIconKind.more, size: 18, color: theme.textSub),
        ),
      ],
    );
  }

  Widget _buildPhotoFrame(AppThemeData theme) {
    final post = widget.post;
    return GestureDetector(
      onTap: _openViewer,
      onDoubleTap: _doubleTapLike,
      onLongPress: _showImageActions,
      child: Container(
        height: 225,
        padding: const EdgeInsets.all(4),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surfaceAlt,
          radius: theme.radii.md,
          seed: 21,
        ),
        child: ClipRRect(
          borderRadius: theme.radii.sm,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MomentImage(path: post.images[_activeImage]),
              if (_burstKey > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _HeartBurst(key: ValueKey(_burstKey)),
                  ),
                ),
              if (post.images.length > 1) ...[
                Positioned(
                  top: 10,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor: theme.ink.withValues(alpha: 0.5),
                      radius: theme.radii.pill,
                      seed: 3,
                    ),
                    child: Text(
                      '${_activeImage + 1}/${post.images.length}',
                      style: DsTypography.label.copyWith(
                        fontSize: 9.5,
                        color: theme.paper,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: dsSketchDecoration(
                        theme: theme,
                        fillColor: theme.ink.withValues(alpha: 0.45),
                        radius: theme.radii.pill,
                        seed: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < post.images.length; i++)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _activeImage = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: i == _activeImage ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color:
                                      i == _activeImage
                                          ? theme.paper
                                          : theme.paper.withValues(
                                            alpha: 0.45,
                                          ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else
                Positioned(
                  bottom: 10,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor: theme.ink.withValues(alpha: 0.4),
                      radius: theme.radii.pill,
                      seed: 5,
                    ),
                    child: Text(
                      'moments_doubleTapLike'.tr,
                      style: DsTypography.label.copyWith(
                        fontSize: 9.5,
                        color: theme.paper,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 长按帖子图片：设为该作者的主页背景（拷贝归档，帖子删除不受影响）
  void _showImageActions() {
    final post = widget.post;
    SmoothBottomSheet.showWithTitle<void>(
      context: context,
      title: 'moments_imageActions'.tr,
      child: SmoothSheetAction(
        icon: DsIconKind.image,
        label: 'moments_setBg'.trParams({'name': widget.author.name}),
        onTap: () async {
          Navigator.pop(context);
          await MomentsService.instance.setProfileBg(
            post.isUserPost ? MomentPost.userAuthorId : post.agentId,
            post.images[_activeImage],
            copy: true,
          );
          ToastService.instance.showToast('moments_bgSet'.tr);
        },
      ),
    );
  }

  void _openViewer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PhotoViewerScreen(
              imageRelativePaths: widget.post.images,
              initialIndex: _activeImage,
            ),
      ),
    );
  }

  /// 纯文字动态：次级表面墨线卡片
  Widget _buildTextCard(AppThemeData theme) {
    return GestureDetector(
      onDoubleTap: _doubleTapLike,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surfaceAlt,
          radius: theme.radii.md,
          seed: 31,
        ),
        child: Stack(
          children: [
            Text(
              widget.post.text,
              style: DsTypography.body.copyWith(height: 1.6),
            ),
            if (_burstKey > 0)
              Positioned.fill(child: _HeartBurst(key: ValueKey(_burstKey))),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(AppThemeData theme) {
    final post = widget.post;
    return Row(
      children: [
        InterestPill(
          label: post.liked ? 'moments_liked'.tr : 'moments_like'.tr,
          leading: DsIcon(DsIconKind.heart, size: 13),
          selected: post.liked,
          onTap: () => MomentsService.instance.toggleLike(post.id),
        ),
        const SizedBox(width: 6),
        InterestPill(
          label: '${post.comments.length}',
          leading: DsIcon(DsIconKind.chat, size: 12),
          onTap: () {
            setState(() => _commentBoxOpen = !_commentBoxOpen);
            if (_commentBoxOpen) _commentFocus.requestFocus();
          },
        ),
        const SizedBox(width: 6),
        InterestPill(
          label: 'moments_share'.tr,
          leading: DsIcon(DsIconKind.send, size: 12),
          onTap:
              () => ToastService.instance.showToast('moments_shareDone'.tr),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            widget.onToggleSave?.call();
            ToastService.instance.showToast(
              widget.saved ? 'moments_saved'.tr : 'moments_unsaved'.tr,
            );
          },
          child: DsIcon(
            widget.saved ? DsIconKind.star : DsIconKind.star,
            size: 18,
            color:
                widget.saved ? theme.warning : theme.textSub.withValues(
                  alpha: 0.7,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaption(AppThemeData theme) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: widget.author.name,
            style: TextStyle(fontWeight: FontWeight.w700, color: theme.text),
          ),
          const TextSpan(text: '  '),
          TextSpan(text: widget.post.text),
        ],
      ),
      style: DsTypography.caption.copyWith(height: 1.5, color: theme.textSub),
    );
  }

  Widget _buildComments(AppThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.stroke.withValues(alpha: 0.6)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in widget.post.comments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: c.isAgent ? widget.author.name : 'moments_me'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                      ),
                    ),
                    TextSpan(text: '：${c.text}'),
                  ],
                ),
                style: DsTypography.caption.copyWith(
                  height: 1.4,
                  color: theme.textSub,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 双击触发的爱心迸发动画
class _HeartBurst extends StatefulWidget {
  const _HeartBurst({super.key});

  @override
  State<_HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<_HeartBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutBack.transform(_controller.value);
        final fade = 1.0 - _controller.value;
        return Center(
          child: Transform.translate(
            offset: Offset(0, -40 * _controller.value),
            child: Transform.rotate(
              angle: (t - 0.5) * 0.5,
              child: Opacity(
                opacity: fade.clamp(0, 1),
                child: DsIcon(
                  DsIconKind.heart,
                  size: 72,
                  color: theme.danger,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 故事查看器（分段进度 + 左右点按切换 + 贴纸回应）
class StoryViewerScreen extends StatefulWidget {
  final MomentsAuthorInfo author;
  final List<MomentPost> posts;

  const StoryViewerScreen({
    super.key,
    required this.author,
    required this.posts,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 4500), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_index < widget.posts.length - 1) {
      setState(() => _index++);
      _schedule();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prev() {
    if (!mounted) return;
    if (_index > 0) {
      setState(() => _index--);
      _schedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final post = widget.posts[_index];
    final tag = MomentTags.byKey(post.tag);

    return Scaffold(
      // 沉浸式查看器：墨色底 + 纸色前景（主题 token）
      backgroundColor: theme.ink,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < widget.posts.length; i++)
                        Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: theme.paper.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: _SegmentFill(
                              key: ValueKey('seg_${_index}_$i'),
                              filled: i < _index,
                              active: i == _index,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ClipOval(child: widget.author.avatar(size: 36)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.author.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DsTypography.heading.copyWith(
                                      fontSize: 12,
                                      color: theme.paper,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: dsSketchDecoration(
                                    theme: theme,
                                    fillColor: theme.paper.withValues(
                                      alpha: 0.2,
                                    ),
                                    radius: theme.radii.pill,
                                    seed: 8,
                                  ),
                                  child: Text(
                                    '${tag.emoji} ${tag.label}',
                                    style: DsTypography.label.copyWith(
                                      fontSize: 10,
                                      color: theme.paper,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${formatRelativeTime(post.createdAt)} · '
                              'moments_storySeq'.trParams({
                                'i': '${_index + 1}',
                                'n': '${widget.posts.length}',
                              }),
                              style: DsTypography.caption.copyWith(
                                fontSize: 10,
                                color: theme.paper.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: dsSketchDecoration(
                            theme: theme,
                            fillColor: theme.paper.withValues(alpha: 0.15),
                            circle: true,
                            seed: 12,
                          ),
                          child: DsIcon(
                            DsIconKind.close,
                            size: 16,
                            color: theme.paper,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: AspectRatio(
                  aspectRatio: 0.72,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final w = context.size?.width ?? 1;
                      final x = details.localPosition.dx;
                      if (x < w / 3) {
                        _prev();
                      } else {
                        _next();
                      }
                    },
                    child: Container(
                      decoration: dsSketchDecoration(
                        theme: theme,
                        fillColor: theme.paper.withValues(alpha: 0.06),
                        stroke: theme.paper.withValues(alpha: 0.5),
                        radius: theme.radii.lg,
                        seed: 13,
                      ),
                      child: ClipRRect(
                        borderRadius: theme.radii.lg,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (post.images.isNotEmpty)
                              MomentImage(path: post.images.first)
                            else
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    post.text,
                                    textAlign: TextAlign.center,
                                    style: DsTypography.heading.copyWith(
                                      fontSize: 16,
                                      height: 1.7,
                                      color: theme.paper,
                                    ),
                                  ),
                                ),
                              ),
                            if (post.images.isNotEmpty)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  color: theme.ink.withValues(alpha: 0.55),
                                  child: Text(
                                    post.text,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: DsTypography.caption.copyWith(
                                      color: theme.paper,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: dsSketchDecoration(
                        theme: theme,
                        fillColor: theme.paper.withValues(alpha: 0.12),
                        radius: theme.radii.pill,
                        seed: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (final emoji in const ['🌶️', '🍸', '💣', '❤️', '✨'])
                            GestureDetector(
                              onTap:
                                  () => ToastService.instance.showToast(
                                    'moments_storyReaction'.trParams({
                                      'emoji': emoji,
                                    }),
                                  ),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InterestPill(
                    label: 'moments_storyNext'.tr,
                    selected: true,
                    onTap: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 故事进度分段填充（当前段 4.5s 线性填充）
class _SegmentFill extends StatefulWidget {
  final bool filled;
  final bool active;

  const _SegmentFill({super.key, required this.filled, required this.active});

  @override
  State<_SegmentFill> createState() => _SegmentFillState();
}

class _SegmentFillState extends State<_SegmentFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
      value: widget.active ? 0 : 1,
    );
    if (widget.active) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    if (widget.filled || (!widget.active && _controller.value >= 1)) {
      return Container(
        decoration: BoxDecoration(
          color: theme.paper,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }
    if (!widget.active) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder:
          (context, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _controller.value,
            child: Container(
              decoration: BoxDecoration(
                color: theme.paper,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
    );
  }
}
