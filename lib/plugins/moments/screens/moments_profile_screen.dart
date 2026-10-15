import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/openai/moments/widgets/agent_avatar.dart';
import 'package:aboutme/plugins/openai/moments/widgets/photo_viewer_screen.dart';

import '../widgets/moments_shared.dart';

/// 朋友圈 · 个人主页（复刻参考稿 Profile 界面：
/// 天空云朵头部 + 贴纸环绕头像 + 软糖标签 + 回忆合集卡片/瀑布流 + 玻璃 dock）
///
/// [agentId] 为空时展示「我」的主页
class MomentsProfileScreen extends StatefulWidget {
  final String? agentId;

  const MomentsProfileScreen({super.key, this.agentId});

  @override
  State<MomentsProfileScreen> createState() => _MomentsProfileScreenState();
}

/// 按标签聚合的图片合集
class _TagGroup {
  final MomentTag tag;
  final List<String> images = [];

  _TagGroup(this.tag);
}

/// 瀑布流伪随机高度（取自参考稿数据）
const _masonryHeights = [118.0, 92.0, 132.0, 100.0, 126.0, 96.0, 116.0, 106.0];

class _MomentsProfileScreenState extends State<MomentsProfileScreen> {
  final _moments = MomentsService.instance;
  AIAgent? _agent;
  String? _activeTag; // null = 合集卡片视图

  bool get isUser => widget.agentId == null || widget.agentId!.isEmpty;

  @override
  void initState() {
    super.initState();
    _moments.addListener(_onChanged);
    _moments.loadPosts();
    _loadAgent();
  }

  @override
  void dispose() {
    _moments.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAgent() async {
    if (isUser) {
      setState(() {});
      return;
    }
    try {
      final agent = await AgentController().getAgent(widget.agentId!);
      if (mounted) {
        setState(() {
          _agent = agent;
        });
      }
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  List<MomentPost> get _posts => _moments.posts
      .where((p) => isUser ? p.isUserPost : p.agentId == widget.agentId)
      .toList();

  List<_TagGroup> get _groups {
    final groups = <String, _TagGroup>{};
    for (final post in _posts) {
      if (post.images.isEmpty) continue;
      final tag = MomentTags.byKey(post.tag);
      final group = groups.putIfAbsent(tag.key, () => _TagGroup(tag));
      group.images.addAll(post.images);
    }
    final list = groups.values.toList()
      ..sort((a, b) => b.images.length.compareTo(a.images.length));
    return list;
  }

  void _backToFeed() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed('/moments');
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    final liked = posts.where((p) => p.liked).length;
    final commentCount = posts.fold<int>(
      0,
      (sum, p) => sum + p.comments.length,
    );
    final topInset = MediaQuery.of(context).padding.top;
    final name = isUser ? '我' : (_agent?.name ?? '未知助手');

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: Stack(
        children: [
          MomentsSkyHeader(height: 328, profileVariant: true),
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: topInset + 6),
                _buildTopBar(name),
                _buildAvatarArea(),
                _buildIdentity(name, posts.length, liked, commentCount),
                _buildPills(posts),
                Expanded(child: _buildCollections()),
              ],
            ),
          ),
          // 底部薄雾 + dock
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 110,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFF6F8FC).withValues(alpha: 0),
                      const Color(0xFFF6F8FC).withValues(alpha: 0.9),
                      const Color(0xFFF6F8FC),
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
                    onTap: _backToFeed,
                  ),
                  GlassDockItem(
                    icon: Icons.photo_library_outlined,
                    onTap: () {
                      setState(() => _activeTag = null);
                    },
                  ),
                  GlassDockItem(
                    icon: Icons.history_rounded,
                    onTap:
                        () => ToastService.instance.showToast(
                          '🕒 已归档 ${posts.length} 条回忆',
                        ),
                  ),
                  const GlassDockItem(
                    icon: Icons.person_rounded,
                    active: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconColor: const Color(0xFF1E293B),
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Profile',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Color(0x47005FB4),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          CircleIconButton(
            icon: Icons.more_horiz_rounded,
            onTap:
                () => ToastService.instance.showToast('✨ 已复制 $name 的主页链接'),
          ),
        ],
      ),
    );
  }

  /// 头像 + 四枚漂浮贴纸（参考稿 4 枚刻贴纸改为 emoji 徽章实现）
  Widget _buildAvatarArea() {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(top: -2, left: 48, child: _FloatingSticker.emoji('🌶️', rotation: -0.09)),
          Positioned(top: 10, right: 42, child: _FloatingSticker.emoji('💣', rotation: 0.14)),
          Positioned(bottom: 14, left: 24, child: _FloatingSticker.emoji('🍸', rotation: -0.1)),
          Positioned(bottom: 12, right: 26, child: _FloatingSticker.emoji('🎨', rotation: 0.23)),
          // 中央头像：影棚灰底 + 白描边 + 底部白雾
          Container(
            width: 144,
            height: 144,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(0, -0.6),
                colors: [Color(0xFF52525B), Color(0xFF27272A), Color(0xFF18181B)],
              ),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F3C6E).withValues(alpha: 0.16),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipOval(
                    child: isUser ? const UserAvatar(size: 128) : AgentAvatar(agent: _agent, size: 128),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 34,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.68),
                            Colors.white.withValues(alpha: 0.95),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentity(String name, int postCount, int liked, int comments) {
    final bio = isUser ? '记录我和 TA 们的日常瞬间 ☁️' : (_agent?.description ?? '');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: MomentsPalette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatButton(label: '动态', value: postCount),
              const SizedBox(width: 16),
              _StatButton(label: '获赞', value: liked),
              const SizedBox(width: 16),
              _StatButton(label: '评论', value: comments),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              bio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: MomentsPalette.inkFaint,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 标签软糖行：渐变光球等级徽章 + 高频标签 Top3
  Widget _buildPills(List<MomentPost> posts) {
    final counts = <String, int>{};
    for (final p in posts) {
      counts[p.tag] = (counts[p.tag] ?? 0) + 1;
    }
    final topTags =
        counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InterestPill(
            label: '${posts.length}',
            style: MomentPillStyle.purple,
            leading: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF9333EA),
                    Color(0xFFD946EF),
                    Color(0xFFF472B6),
                  ],
                ),
              ),
            ),
          ),
          for (final entry in topTags.take(3)) ...[
            const SizedBox(width: 6),
            TagPill(
              tag: MomentTags.byKey(entry.key),
              onTap:
                  () => ToastService.instance.showToast(
                    '「${MomentTags.byKey(entry.key).label}」共 ${entry.value} 条动态',
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollections() {
    final groups = _groups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '回忆合集',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: MomentsPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeTag == null ? '左右滑动浏览 · 点击合集查看全部照片' : '已打开合集 · 点击标签快速切换',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: MomentsPalette.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (_activeTag != null)
                GestureDetector(
                  onTap: () => setState(() => _activeTag = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '‹ 返回合集',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0EA5E9),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child:
              groups.isEmpty
                  ? Center(
                    child: Text(
                      _posts.isEmpty ? '还没有动态' : '暂无图片，发条带图动态试试',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MomentsPalette.inkFaint,
                      ),
                    ),
                  )
                  : _activeTag == null
                  ? _buildCarousel(groups)
                  : _buildGroupDetail(groups),
        ),
      ],
    );
  }

  /// 合集卡片横滑轮播（扇形错落 + 毛玻璃文件夹）
  Widget _buildCarousel(List<_TagGroup> groups) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = 148.0;
        final overlap = 22.0;
        final height = constraints.maxHeight;
        final listWidth = cardW + (groups.length - 1) * (cardW - overlap);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: SizedBox(
            width: listWidth,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < groups.length; i++)
                  Positioned(
                    left: i * (cardW - overlap),
                    top: height > 220 ? (i.isEven ? 24 : 6) : (i.isEven ? 16 : 0),
                    child: Transform.rotate(
                      angle: i.isEven ? -0.087 : 0.087,
                      child: _CollectionCard(
                        group: groups[i],
                        onTap:
                            () => setState(
                              () => _activeTag = groups[i].tag.key,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 合集详情：标签 chips + 双列瀑布流
  Widget _buildGroupDetail(List<_TagGroup> groups) {
    final group = groups.firstWhere(
      (g) => g.tag.key == _activeTag,
      orElse: () => groups.first,
    );
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final g = groups[index];
              final active = g.tag.key == group.tag.key;
              return GestureDetector(
                onTap: () => setState(() => _activeTag = g.tag.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                  decoration: BoxDecoration(
                    color:
                        active
                            ? null
                            : Colors.white,
                    gradient:
                        active
                            ? const LinearGradient(
                              colors: [Color(0xFF0088FF), Color(0xFF38BDF8)],
                            )
                            : null,
                    border:
                        active
                            ? null
                            : Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow:
                        active
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0088FF,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                  ),
                  child: Row(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: MomentImage(path: g.images.first),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${g.tag.emoji} ${g.tag.label}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 110),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < 2; col++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: col == 1 ? 5 : 0, right: col == 0 ? 5 : 0),
                      child: Column(
                        children: [
                          for (var i = col; i < group.images.length; i += 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _MasonryImage(
                                path: group.images[i],
                                height: _masonryHeights[i % _masonryHeights.length],
                                onTap: () => _openGroupViewer(group, i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openGroupViewer(_TagGroup group, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PhotoViewerScreen(
              imageRelativePaths: group.images,
              initialIndex: initialIndex,
            ),
      ),
    );
  }
}

/// 统计数字按钮
class _StatButton extends StatelessWidget {
  final String label;
  final int value;

  const _StatButton({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$value',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          TextSpan(
            text: ' $label',
            style: const TextStyle(
              fontSize: 12,
              color: MomentsPalette.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// 漂浮 emoji 贴纸徽章（替代参考稿的 SVG 刻贴纸）
class _FloatingSticker extends StatefulWidget {
  final String emoji;
  final double rotation;

  const _FloatingSticker({required this.emoji, required this.rotation});

  factory _FloatingSticker.emoji(String emoji, {required double rotation}) =>
      _FloatingSticker(emoji: emoji, rotation: rotation);

  @override
  State<_FloatingSticker> createState() => _FloatingStickerState();
}

class _FloatingStickerState extends State<_FloatingSticker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    )..repeat();
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
        // 缓慢正弦漂浮（±4px，循环无跳变）
        final dy = -4 + -4 * math.sin(_controller.value * 2 * math.pi);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: widget.rotation + 0.05 * (0.5 + 0.5 * _controller.value),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0E4173).withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(widget.emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 毛玻璃文件夹合集卡片（参考稿 .collection-card + .collection-folder）
class _CollectionCard extends StatelessWidget {
  final _TagGroup group;
  final VoidCallback onTap;

  const _CollectionCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        height: 186,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 3.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MomentImage(path: group.images.first),
              // 数量角标
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '📁 ${group.images.length}',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // 毛玻璃文件夹底部
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 88,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                      alignment: Alignment.bottomLeft,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.34),
                            Colors.white.withValues(alpha: 0.58),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📂 ${group.tag.emoji} ${group.tag.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: MomentsPalette.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '共 ${group.images.length} 张照片',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
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
}

/// 瀑布流图片项（白描边圆角卡片，点击进全屏查看）
class _MasonryImage extends StatelessWidget {
  final String path;
  final double height;
  final VoidCallback onTap;

  const _MasonryImage({
    required this.path,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: MomentImage(path: path),
        ),
      ),
    );
  }
}
