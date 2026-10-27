import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:path/path.dart' as p;
import 'package:super_cupertino_navigation_bar/utils/navigation_bar_static_components.dart';
import 'package:super_cupertino_navigation_bar/utils/persistent_nav_bar.dart';

import 'package:aboutme/core/data/sdk_media_service.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/openai/moments/widgets/agent_avatar.dart';
import 'package:aboutme/widgets/gallery_viewer.dart';
import 'package:aboutme/utils/file_picker_helper.dart';
import 'package:aboutme/widgets/arc_context_menu.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

import '../widgets/moment_stickers.dart';
import '../widgets/moments_shared.dart';

/// 朋友圈 · 个人主页（手绘纸墨风：墨线头像环 + SVG 刻贴纸悬浮 + 回忆合集）
///
/// [agentId] 为空时展示「我」的主页
class MomentsProfileScreen extends StatefulWidget {
  final String? agentId;

  /// true = 作为宿主页 tab 内嵌（无返回按钮）；
  /// false/默认 = push 的子页面（agent 主页，带返回按钮）
  final bool embedded;

  const MomentsProfileScreen({super.key, this.agentId, this.embedded = false});

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
  final _navBarKeys = NavigationBarStaticComponentsKeys();
  final _moments = MomentsService.instance;
  AIAgent? _agent;
  String? _activeTag; // null = 合集卡片视图

  bool get isUser => widget.agentId == null || widget.agentId!.isEmpty;

  String get _displayName =>
      isUser ? 'moments_me'.tr : (_agent?.name ?? 'moments_unknownAgent'.tr);

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

  String get _authorKey => isUser ? MomentPost.userAuthorId : widget.agentId!;

  /// 封面解析：显式背景 > agent 头像 >（用户）null
  String? _resolveCoverPath() {
    final explicit = _moments.profileBgOf(_authorKey);
    if (explicit != null && explicit.isNotEmpty) return explicit;
    if (!isUser) return _agent?.avatarUrl;
    return null;
  }

  /// 固定头部：返回 / 标题 / 更多
  /// 包内 PersistentNavigationBar；仅 push 子页面（agent 主页）使用，
  /// embedded（宿主页 tab）的顶栏由宿主页统一渲染
  Widget _buildNavBar() {
    final theme = AppTheme.of(context);
    return PersistentNavigationBar(
      components: NavigationBarStaticComponents(
        keys: _navBarKeys,
        route: null,
        userLeading: DSIconButton(
          icon: DsIconKind.chevronLeft,
          size: 38,
          color: theme.surface,
          iconColor: theme.text,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        automaticallyImplyLeading: false,
        automaticallyImplyTitle: false,
        previousPageTitle: null,
        userMiddle: Text(
          'moments_profileTitle'.tr,
          style: DsTypography.title.copyWith(color: theme.text),
        ),
        userTrailing: DSIconButton(
          icon: DsIconKind.more,
          size: 38,
          onPressed: () => ToastService.instance.showToast(
            'moments_linkCopied'.trParams({'name': _displayName}),
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

  /// 顶部封面：显式背景 > agent 头像 > （用户）上传占位
  Widget _buildCover(AppThemeData theme) {
    final explicit = _moments.profileBgOf(_authorKey);
    final hasExplicit = explicit != null && explicit.isNotEmpty;
    final path = _resolveCoverPath();
    if (path == null || path.isEmpty) {
      if (!isUser) return const SizedBox.shrink();
      // 用户未设置背景：上传占位
      return GestureDetector(
        onTap: _uploadBg,
        child: Container(
          height: 110,
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: theme.surfaceAlt,
            radius: theme.radii.lg,
            hachure: true,
            seed: 22,
          ),
          child: Center(
            child: InterestPill(
              label: 'moments_changeBg'.tr,
              leading: DsIcon(DsIconKind.image, size: 12),
              selected: true,
              onTap: _uploadBg,
            ),
          ),
        ),
      );
    }
    // 长按封面弹圆盘快捷菜单：有自定义背景时可恢复默认
    return ArcContextMenu.actions(
      actions: hasExplicit ? _bgActions() : const [],
      showMore: _showBgOptions,
      child: MomentsCover(
        path: path,
        height: 230,
        overlay: isUser
            ? InterestPill(
                label: 'moments_changeBg'.tr,
                leading: DsIcon(DsIconKind.image, size: 12),
                onTap: _uploadBg,
              )
            : null,
      ),
    );
  }

  Future<void> _uploadBg() async {
    try {
      final files = await FilePickerHelper.pickImages(multiple: false);
      if (files.isEmpty) return;
      final file = files.first;
      var name = p.basename(file.path);
      if (!name.contains('.')) name = '$name.png';
      final asset = await SdkMediaService.uploadBytes(
        await file.readAsBytes(),
        name,
      );
      await _moments.setProfileBg(_authorKey, asset.reference);
      if (mounted) ToastService.instance.showToast('moments_bgSet'.tr);
    } catch (e) {
      if (mounted) {
        ToastService.instance.showToast(
          'moments_publishFailed'.trParams({'error': '$e'}),
        );
      }
    }
  }

  /// 长按快捷菜单项（圆盘与底部 sheet 共用）
  List<ArcMenuItem> _bgActions() => [
        ArcMenuItem(
          icon: DsIconKind.refresh,
          label: 'moments_bgReset'.tr,
          onTap: () async {
            await _moments.clearProfileBg(_authorKey);
            if (mounted) {
              ToastService.instance.showToast('moments_bgResetDone'.tr);
            }
          },
        ),
      ];

  void _showBgOptions() {
    SmoothBottomSheet.showActionList(
      context: context,
      title: 'moments_imageActions'.tr,
      actions: _bgActions(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final posts = _posts;
    final liked = posts.where((p) => p.liked).length;
    final commentCount = posts.fold<int>(
      0,
      (sum, p) => sum + p.comments.length,
    );
    // 有封面图（显式背景或 agent 头像）时头部透明浮在封面上
    final coverPath = _resolveCoverPath();
    final hasCover = coverPath != null && coverPath.isNotEmpty;

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCover(theme),
            _buildAvatarArea(theme),
            _buildIdentity(theme, posts.length, liked, commentCount),
            _buildPills(theme, posts),
          ],
        ),
      ),
      SliverToBoxAdapter(child: _buildCollections(theme)),
      // 占满剩余视口：内容少时页面也不留大片空白，
      // 底部同时为磨砂 dock 预留透出空间
      const SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: 130),
          child: SizedBox.expand(),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: theme.background,
      // 内容延伸到 dock 后面，矮窗口下整页可滚
      extendBody: true,
      // 顶栏：embedded 由宿主页统一渲染（封面延伸/顶部避让同由宿主页处理）；
      // push 子页面（agent 主页）自带返回顶栏，设封面时浮在封面上
      body: widget.embedded
          ? CustomScrollView(slivers: slivers)
          : hasCover
          ? Stack(
              children: [
                Positioned.fill(child: CustomScrollView(slivers: slivers)),
                Positioned(top: 0, left: 0, right: 0, child: _buildNavBar()),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildNavBar(),
                Expanded(child: CustomScrollView(slivers: slivers)),
              ],
            ),
    );
  }

  /// 头像 + 四枚 SVG 刻贴纸悬浮（复刻参考稿：辣椒/炸弹/鸡尾酒/Figma）
  Widget _buildAvatarArea(AppThemeData theme) {
    return SizedBox(
      height: 210,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -6,
            left: 48,
            child: const MomentSticker(kind: stickerChili, rotation: -0.09),
          ),
          Positioned(
            top: 8,
            right: 44,
            child: const MomentSticker(kind: stickerBomb, rotation: 0.14),
          ),
          Positioned(
            bottom: 16,
            left: 22,
            child: const MomentSticker(kind: stickerCocktail, rotation: -0.1),
          ),
          Positioned(
            bottom: 14,
            right: 24,
            child: const MomentSticker(kind: stickerFigma, rotation: 0.23),
          ),
          // 中央头像：墨线圆环 + 纸底
          Container(
            width: 144,
            height: 144,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(6),
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: theme.surface,
              stroke: theme.ink.withValues(alpha: 0.7),
              strokeWidth: 2.2,
              circle: true,
              seed: 2,
            ),
            child: ClipOval(
              child: isUser
                  ? const UserAvatar(size: 128)
                  : AgentAvatar(agent: _agent, size: 128),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentity(
    AppThemeData theme,
    int postCount,
    int liked,
    int comments,
  ) {
    final bio = isUser ? 'moments_bioUser'.tr : (_agent?.description ?? '');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Text(
            _displayName,
            style: DsTypography.title.copyWith(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: theme.text,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatButton(
                theme: theme,
                label: 'moments_statPosts'.tr,
                value: postCount,
              ),
              const SizedBox(width: 16),
              _StatButton(
                theme: theme,
                label: 'moments_statLikes'.tr,
                value: liked,
              ),
              const SizedBox(width: 16),
              _StatButton(
                theme: theme,
                label: 'moments_statComments'.tr,
                value: comments,
              ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              bio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
        ],
      ),
    );
  }

  /// 标签软糖行：主题色光球徽章 + 高频标签 Top3
  Widget _buildPills(AppThemeData theme, List<MomentPost> posts) {
    final counts = <String, int>{};
    for (final p in posts) {
      counts[p.tag] = (counts[p.tag] ?? 0) + 1;
    }
    final topTags = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InterestPill(
            label: '${posts.length}',
            leading: Container(
              width: 14,
              height: 14,
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: theme.primary,
                circle: true,
                seed: 17,
              ),
            ),
          ),
          for (final entry in topTags.take(3)) ...[
            const SizedBox(width: 6),
            TagPill(
              tag: MomentTags.byKey(entry.key),
              onTap: () => ToastService.instance.showToast(
                'moments_tagCount'.trParams({
                  'tag': MomentTags.byKey(entry.key).label,
                  'n': '${entry.value}',
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollections(AppThemeData theme) {
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
                    Text(
                      'moments_collectionsTitle'.tr,
                      style: DsTypography.heading.copyWith(
                        fontSize: 16,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeTag == null
                          ? 'moments_collectionsSub'.tr
                          : 'moments_collectionsSubDetail'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
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
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor: theme.surfaceAlt,
                      radius: theme.radii.pill,
                      seed: 18,
                    ),
                    child: Text(
                      'moments_backCollections'.tr,
                      style: DsTypography.label.copyWith(
                        fontSize: 10.5,
                        color: theme.primaryText,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                _posts.isEmpty
                    ? 'moments_collectionsEmptyNoPosts'.tr
                    : 'moments_collectionsEmptyNoImages'.tr,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ),
          )
        else if (_activeTag == null)
          _buildCarousel(theme, groups)
        else
          _buildGroupDetail(theme, groups),
      ],
    );
  }

  /// 合集卡片横滑轮播（错落 + 墨线文件夹）
  Widget _buildCarousel(AppThemeData theme, List<_TagGroup> groups) {
    final cardW = 148.0;
    final overlap = 22.0;
    final listWidth = cardW + (groups.length - 1) * (cardW - overlap);
    return SizedBox(
      height: 236,
      child: SingleChildScrollView(
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
                  top: i.isEven ? 26 : 8,
                  child: Transform.rotate(
                    angle: i.isEven ? -0.087 : 0.087,
                    child: _CollectionCard(
                      group: groups[i],
                      onTap: () =>
                          setState(() => _activeTag = groups[i].tag.key),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 合集详情：标签 chips + 双列瀑布流（便签化）
  Widget _buildGroupDetail(AppThemeData theme, List<_TagGroup> groups) {
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
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                  decoration: dsSketchDecoration(
                    theme: theme,
                    fillColor: active ? theme.primary : theme.surface,
                    stroke: theme.ink.withValues(alpha: active ? 0.7 : 0.45),
                    radius: theme.radii.pill,
                    seed: index + 60,
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
                        style: DsTypography.label.copyWith(
                          fontSize: 11,
                          color: active ? theme.onPrimary : theme.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var col = 0; col < 2; col++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: col == 1 ? 5 : 0,
                      right: col == 0 ? 5 : 0,
                    ),
                    child: Column(
                      children: [
                        for (var i = col; i < group.images.length; i += 2)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            // 瀑布流 cell 便签化（窄卡小贴条，design.md §11）
                            child: HandDrawnStickyItem(
                              tiltKey: '${group.tag.key}#$i',
                              tapeWidth: 56,
                              tapeHeight: 18,
                              child: _MasonryImage(
                                path: group.images[i],
                                height:
                                    _masonryHeights[i % _masonryHeights.length],
                                onTap: () => _openGroupViewer(group, i),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _openGroupViewer(_TagGroup group, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GalleryViewer(
          title: '${group.tag.emoji} ${group.tag.label}',
          entranceAnimation: true,
          showFileActions: true,
          photos: [
            for (final p in group.images) GalleryPhoto(url: p),
          ],
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

/// 统计数字按钮
class _StatButton extends StatelessWidget {
  final AppThemeData theme;
  final String label;
  final int value;

  const _StatButton({
    required this.theme,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$value',
            style: DsTypography.label.copyWith(fontSize: 12, color: theme.text),
          ),
          TextSpan(text: ' $label', style: DsTypography.caption),
        ],
      ),
    );
  }
}

/// 瀑布流图片项（墨线圆角相框，点击进全屏查看）
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
    final theme = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surface,
          radius: theme.radii.md,
          seed: path.hashCode & 0x7fffffff,
        ),
        child: ClipRRect(
          borderRadius: theme.radii.sm,
          child: MomentImage(path: path),
        ),
      ),
    );
  }
}

/// 墨线文件夹合集卡片（纸底 + 底部标签条）
class _CollectionCard extends StatelessWidget {
  final _TagGroup group;
  final VoidCallback onTap;

  const _CollectionCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        height: 186,
        padding: const EdgeInsets.all(4),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surface,
          radius: theme.radii.lg,
          seed: group.tag.key.hashCode & 0x7fffffff,
        ),
        child: ClipRRect(
          borderRadius: theme.radii.md,
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
                  decoration: dsSketchDecoration(
                    theme: theme,
                    fillColor: theme.ink.withValues(alpha: 0.55),
                    radius: theme.radii.pill,
                    seed: 19,
                  ),
                  child: Text(
                    'moments_albums'.trParams({'n': '${group.images.length}'}),
                    style: DsTypography.label.copyWith(
                      fontSize: 9.5,
                      color: theme.paper,
                    ),
                  ),
                ),
              ),
              // 底部标签条
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  color: theme.paper.withValues(alpha: 0.92),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📂 ${group.tag.emoji} ${group.tag.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsTypography.heading.copyWith(
                          fontSize: 13.5,
                          color: theme.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'moments_collectionMeta'.trParams({
                          'n': '${group.images.length}',
                        }),
                        style: DsTypography.label.copyWith(
                          fontSize: 10,
                          color: theme.textSub,
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
    );
  }
}
