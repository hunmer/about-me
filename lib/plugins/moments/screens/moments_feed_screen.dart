import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/openai/moments/widgets/agent_avatar.dart';
import 'package:aboutme/plugins/openai/moments/widgets/photo_viewer_screen.dart';
import 'package:aboutme/utils/file_picker_helper.dart';
import 'package:aboutme/utils/image_utils.dart';

import '../widgets/moments_shared.dart';
import 'moments_profile_screen.dart';

/// 朋友圈动态作者（我 / 某个 agent）
class MomentsAuthorInfo {
  final String id; // agentId 或 MomentPost.userAuthorId
  final AIAgent? agent;

  const MomentsAuthorInfo({required this.id, this.agent});

  bool get isUser => id == MomentPost.userAuthorId;

  String get name => isUser ? '我' : (agent?.name ?? '未知助手');

  Widget avatar({double size = 40}) {
    if (isUser) return UserAvatar(size: size);
    return AgentAvatar(agent: agent, size: size);
  }
}

/// 朋友圈 · 动态流（复刻参考稿 Instagram Feed 界面：
/// 天空头部 + 头像故事栏 + 标签筛选 + 投稿卡片 + 玻璃 dock）
class MomentsFeedScreen extends StatefulWidget {
  const MomentsFeedScreen({super.key});

  @override
  State<MomentsFeedScreen> createState() => _MomentsFeedScreenState();
}

class _MomentsFeedScreenState extends State<MomentsFeedScreen> {
  final _moments = MomentsService.instance;
  final _scrollController = ScrollController();
  final Map<String, AIAgent> _agents = {};
  final Set<String> _seenAuthors = {};
  final Set<String> _savedPostIds = {};
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
                  (p.isUserPost
                      ? MomentPost.userAuthorId
                      : p.agentId) ==
                  author.id,
            )
            .take(8)
            .toList();
    if (items.isEmpty) {
      _openCompose();
      return;
    }
    setState(() => _seenAuthors.add(author.id));
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ComposeSheet(),
    );
  }

  void _confirmDelete(MomentPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('删除这条动态？'),
            content: const Text('删除后不可恢复'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除'),
              ),
            ],
          ),
    );
    if (ok == true) {
      await _moments.deletePost(post.id);
      if (mounted) ToastService.instance.showToast('已删除');
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts =
        _filter == null
            ? _moments.posts
            : _moments.posts.where((p) => p.tag == _filter).toList();
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: MomentsPalette.pageBg,
      body: Stack(
        children: [
          MomentsSkyHeader(height: 255),
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: topInset + 6),
                _buildTopBar(),
                _buildStories(),
                _buildFilters(),
                Expanded(
                  child:
                      posts.isEmpty
                          ? _buildEmpty()
                          : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(top: 4, bottom: 120),
                            itemCount: posts.length,
                            itemBuilder: (context, index) {
                              final post = posts[index];
                              return MomentFeedCard(
                                key: ValueKey(post.id),
                                post: post,
                                author: _authorOf(post),
                                saved: _savedPostIds.contains(post.id),
                                onToggleSave:
                                    () => setState(
                                      () =>
                                          _savedPostIds.contains(post.id)
                                              ? _savedPostIds.remove(post.id)
                                              : _savedPostIds.add(post.id),
                                    ),
                                onOpenProfile:
                                    () => _openProfile(_authorOf(post)),
                                onDelete: () => _confirmDelete(post),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
          // 底部白色薄雾 + 玻璃 dock
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 96,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MomentsPalette.pageBg.withValues(alpha: 0),
                      MomentsPalette.pageBg.withValues(alpha: 0.9),
                      MomentsPalette.pageBg,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Center(
              child: GlassDock(
                items: [
                  GlassDockItem(
                    icon: Icons.home_rounded,
                    active: true,
                    onTap: () {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    },
                  ),
                  GlassDockItem(
                    icon: Icons.add_photo_alternate_outlined,
                    onTap: _openCompose,
                  ),
                  GlassDockItem(
                    icon: Icons.history_rounded,
                    onTap:
                        () => ToastService.instance.showToast(
                          '⚡ 动态将自动归档至回忆合集',
                        ),
                  ),
                  GlassDockItem(
                    icon: Icons.person_outline_rounded,
                    onTap:
                        () => _openProfile(
                          const MomentsAuthorInfo(
                            id: MomentPost.userAuthorId,
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final unread = _todayAgentPostCount;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.add,
            onTap: _openCompose,
          ),
          const Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '朋友圈',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                      shadows: [
                        Shadow(
                          color: Color(0x47005FB4),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 6),
                  _SkyBadge(label: 'Feed'),
                ],
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleIconButton(
                icon: Icons.favorite_border_rounded,
                onTap:
                    () => ToastService.instance.showToast(
                      unread > 0 ? '☁️ TA 们最近更新了 $unread 条动态' : '暂无新的互动',
                    ),
              ),
              if (unread > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF43F5E),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStories() {
    final authors = _storyAuthors(_moments.posts);
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        itemCount: authors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final author = authors[index];
          final seen = _seenAuthors.contains(author.id);
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
            label: '✨ 全部',
            style: MomentPillStyle.blue,
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wb_cloudy_outlined,
            size: 56,
            color: MomentsPalette.skyMid.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 14),
          const Text(
            '还没有动态',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MomentsPalette.inkSoft,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '点左上角 + 投稿，或对 TA 说「发一条朋友圈」',
            style: TextStyle(fontSize: 12, color: MomentsPalette.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// 标题旁的白色小徽章
class _SkyBadge extends StatelessWidget {
  final String label;

  const _SkyBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0284C7),
          height: 1,
        ),
      ),
    );
  }
}

/// 故事栏头像（渐变彩环 + 角标贴纸 + 名字）
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
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        seen
                            ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFCBD5E1), Color(0xFFE2E8F0)],
                            )
                            : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF0088FF),
                                Color(0xFF38BDF8),
                                Color(0xFFF472B6),
                              ],
                            ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0E74D6).withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(child: author.avatar(size: 54)),
                  ),
                ),
                // 角标贴纸：我为 ➕，agent 用其最常用标签 emoji
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color:
                          author.isUser
                              ? MomentsPalette.activeBlue
                              : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        author.isUser ? '＋' : '☁️',
                        style: TextStyle(
                          fontSize: author.isUser ? 11 : 10,
                          fontWeight: FontWeight.bold,
                          color:
                              author.isUser
                                  ? Colors.white
                                  : MomentsPalette.inkSoft,
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
              author.isUser ? '我' : author.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: MomentsPalette.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 投稿卡片（参考稿 .feed-card）
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
    ToastService.instance.showToast('💬 评论已发布');
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final tag = MomentTags.byKey(post.tag);
    final sourceLabel = switch (post.source) {
      'user' => '我的投稿',
      'manual' => '代 TA 发布',
      _ => 'TA 的动态',
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(tag, sourceLabel),
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPhotoFrame(),
          ] else if (post.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTextCard(),
          ],
          const SizedBox(height: 12),
          _buildActions(),
          const SizedBox(height: 10),
          if (post.text.isNotEmpty && post.images.isNotEmpty) _buildCaption(),
          if (post.comments.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildComments(),
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
                            child: TextField(
                              controller: _commentController,
                              focusNode: _commentFocus,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: '写下你的评论…',
                                hintStyle: const TextStyle(
                                  fontSize: 12,
                                  color: MomentsPalette.inkFaint,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: const BorderSide(
                                    color: MomentsPalette.skyChip,
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _submitComment(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _submitComment,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0EA5E9),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '发送',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
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

  Widget _buildHeader(MomentTag tag, String sourceLabel) {
    final post = widget.post;
    return Row(
      children: [
        GestureDetector(
          onTap: widget.onOpenProfile,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: widget.author.avatar(size: 40),
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
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: MomentsPalette.ink,
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
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: MomentsPalette.inkFaint,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: widget.onDelete,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.more_horiz_rounded,
              size: 16,
              color: MomentsPalette.inkFaint,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoFrame() {
    final post = widget.post;
    return GestureDetector(
      onTap: _openViewer,
      onDoubleTap: _doubleTapLike,
      child: Container(
        height: 225,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 10),
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MomentImage(path: post.images[_activeImage]),
              // 双击爱心迸发
              if (_burstKey > 0)
                Positioned.fill(
                  child: IgnorePointer(child: _HeartBurst(key: ValueKey(_burstKey))),
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
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_activeImage + 1}/${post.images.length}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
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
                                          ? Colors.white
                                          : Colors.white.withValues(
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
                const Positioned(
                  bottom: 10,
                  right: 12,
                  child: _DoubleTapHint(),
                ),
            ],
          ),
        ),
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

  /// 纯文字动态：柔和蓝灰卡片（保留白描边+阴影的视觉语言）
  Widget _buildTextCard() {
    return GestureDetector(
      onDoubleTap: _doubleTapLike,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1F5F9), Color(0xFFE8F1FB)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.1),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Stack(
          children: [
            Text(
              widget.post.text,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.6,
                color: MomentsPalette.ink,
              ),
            ),
            if (_burstKey > 0)
              Positioned.fill(child: _HeartBurst(key: ValueKey(_burstKey))),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    final post = widget.post;
    return Row(
      children: [
        InterestPill(
          label: post.liked ? '已赞' : '赞',
          leading: Icon(
            post.liked ? Icons.favorite : Icons.favorite_border,
            size: 13,
            color: post.liked ? const Color(0xFFE11D48) : MomentsPalette.inkSoft,
          ),
          style: post.liked ? MomentPillStyle.pink : MomentPillStyle.blue,
          selected: post.liked,
          onTap: () => MomentsService.instance.toggleLike(post.id),
        ),
        const SizedBox(width: 6),
        InterestPill(
          label: '${post.comments.length}',
          leading: const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 12,
            color: Color(0xFF0284C7),
          ),
          style: MomentPillStyle.blue,
          onTap: () {
            setState(() => _commentBoxOpen = !_commentBoxOpen);
            if (_commentBoxOpen) _commentFocus.requestFocus();
          },
        ),
        const SizedBox(width: 6),
        InterestPill(
          label: '分享',
          leading: const Icon(
            Icons.send_outlined,
            size: 12,
            color: Color(0xFF7E22CE),
          ),
          style: MomentPillStyle.purple,
          onTap: () => ToastService.instance.showToast('🚀 已分享给密友圈'),
        ),
        const Spacer(),
        GestureDetector(
          onTap: widget.onToggleSave,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color:
                  widget.saved
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.saved ? Icons.bookmark_rounded : Icons.bookmark_border,
              size: 15,
              color:
                  widget.saved
                      ? const Color(0xFFF59E0B)
                      : MomentsPalette.inkFaint,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaption() {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: widget.author.name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: MomentsPalette.ink,
            ),
          ),
          const TextSpan(text: '  '),
          TextSpan(text: widget.post.text),
        ],
      ),
      style: const TextStyle(
        fontSize: 11.5,
        height: 1.5,
        color: Color(0xFF334155),
      ),
    );
  }

  Widget _buildComments() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
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
                      text: c.isAgent ? widget.author.name : '我',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: MomentsPalette.ink,
                      ),
                    ),
                    TextSpan(text: '：${c.text}'),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Color(0xFF475569),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 双击点赞提示角标
class _DoubleTapHint extends StatelessWidget {
  const _DoubleTapHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        '双击图片点赞 ❤️',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 双击触发的爱心迸发动画（参考稿 .heart-burst）
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
                child: Icon(
                  Icons.favorite_rounded,
                  size: 74,
                  color: const Color(0xFFF43F5E),
                  shadows: [
                    Shadow(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.45),
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 发布投稿底部面板（参考稿 compose modal：文案 + 标签 + 配图）
class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet();

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _textController = TextEditingController();
  final List<File> _images = [];
  String _tag = MomentTags.defaultKey;
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remain = MomentsService.maxImagesPerPost - _images.length;
    if (remain <= 0) {
      ToastService.instance.showToast('最多 ${MomentsService.maxImagesPerPost} 张图片');
      return;
    }
    final files = await FilePickerHelper.pickImages(multiple: true);
    if (files.isEmpty) return;
    setState(() => _images.addAll(files.take(remain)));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final text = _textController.text.trim();
    if (text.isEmpty && _images.isEmpty) {
      ToastService.instance.showToast('写点什么或添加一张图片吧');
      return;
    }
    setState(() => _submitting = true);
    try {
      // 挑选的图片归档到朋友圈图片目录，转相对路径存储
      final relPaths = <String>[];
      for (final file in _images) {
        final ext = p.extension(file.path);
        relPaths.add(
          await ImageUtils.saveBytesToAppDirectory(
            await file.readAsBytes(),
            MomentsService.imagesDir,
            extension: ext.isEmpty ? '.png' : ext,
          ),
        );
      }
      await MomentsService.instance.addPost(
        agentId: MomentPost.userAuthorId,
        text: text,
        images: relPaths,
        source: 'user',
        tag: _tag,
      );
      if (mounted) {
        Navigator.pop(context);
        ToastService.instance.showToast('🎉 新投稿已发布至顶部！');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ToastService.instance.showToast('发布失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const Text(
              '✨ 发布新投稿',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: MomentsPalette.ink,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 3,
              minLines: 2,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: '分享此刻的生活、心情或见闻…',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: MomentsPalette.inkFaint,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.all(12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: MomentsPalette.skyChip),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '选择标签：',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: MomentsPalette.inkFaint,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in MomentTags.all)
                  TagPill(
                    tag: tag,
                    selected: _tag == tag.key,
                    onTap: () => setState(() => _tag = tag.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _images.length; i++)
                    Container(
                      width: 72,
                      height: 72,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              _images[i],
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap:
                                  () => setState(() => _images.removeAt(i)),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 26,
                        color: MomentsPalette.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _submit,
              child: Container(
                width: double.infinity,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0088FF), Color(0xFF38BDF8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child:
                    _submitting
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text(
                          '立即发布至朋友圈',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 故事查看器（复刻参考稿 story viewer：分段进度 + 左右点按切换 + 贴纸回应）
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
    final post = widget.posts[_index];
    final tag = MomentTags.byKey(post.tag);

    return Scaffold(
      backgroundColor: const Color(0xF20B1220),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                children: [
                  // 分段进度条
                  Row(
                    children: [
                      for (var i = 0; i < widget.posts.length; i++)
                        Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
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
                      ClipOval(
                        child: widget.author.avatar(size: 36),
                      ),
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
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${tag.emoji} ${tag.label}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${formatRelativeTime(post.createdAt)} · 第 ${_index + 1}/${widget.posts.length} 条',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.7),
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
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
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
                      // 左 1/3 上一条，右 1/3 下一条
                      final w = context.size?.width ?? 1;
                      final x = details.localPosition.dx;
                      if (x < w / 3) {
                        _prev();
                      } else {
                        _next();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (post.images.isNotEmpty)
                              MomentImage(path: post.images.first)
                            else
                              DecoratedBox(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF169AFF),
                                      Color(0xFF3CB2FF),
                                      Color(0xFF7DCDFF),
                                    ],
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Center(
                                    child: Text(
                                      post.text,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        height: 1.7,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
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
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.75),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Text(
                                    post.text,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
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
            // 贴纸回应 + 下一条
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
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (final emoji in const ['🌶️', '🍸', '💣', '❤️', '✨'])
                            GestureDetector(
                              onTap:
                                  () => ToastService.instance.showToast(
                                    '已发送贴纸回应 $emoji',
                                  ),
                              child: Text(emoji, style: const TextStyle(fontSize: 16)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0EA5E9).withValues(
                              alpha: 0.4,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        '下一条 →',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
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
    if (widget.filled || (!widget.active && _controller.value >= 1)) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }
    if (!widget.active) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _controller,
      builder:
          (context, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _controller.value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
    );
  }
}
