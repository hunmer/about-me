import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:super_cupertino_navigation_bar/utils/navigation_bar_static_components.dart';
import 'package:super_cupertino_navigation_bar/utils/persistent_nav_bar.dart';

import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/openai/moments/widgets/photo_viewer_screen.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';

import '../widgets/moments_shared.dart';

/// 朋友圈 · 回忆页（宿主页 tab 1）：
/// 全部动态的图片按标签筛选，双列便签瀑布流归档
class MomentsMemoriesScreen extends StatefulWidget {
  const MomentsMemoriesScreen({super.key});

  @override
  State<MomentsMemoriesScreen> createState() => _MomentsMemoriesScreenState();
}

class _MomentsMemoriesScreenState extends State<MomentsMemoriesScreen> {
  final _moments = MomentsService.instance;
  final _navBarKeys = NavigationBarStaticComponentsKeys();
  String? _filter; // null = 全部

  @override
  void initState() {
    super.initState();
    _moments.addListener(_onChanged);
    _moments.loadPosts();
  }

  @override
  void dispose() {
    _moments.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final posts =
        _filter == null
            ? _moments.posts
            : _moments.posts.where((p) => p.tag == _filter).toList();
    final images =
        posts.expand((p) => p.images).toList(growable: false);

    return Scaffold(
      backgroundColor: theme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PersistentNavigationBar(
            components: NavigationBarStaticComponents(
              keys: _navBarKeys,
              route: null,
              userLeading: const SizedBox(width: 38),
              automaticallyImplyLeading: false,
              automaticallyImplyTitle: false,
              previousPageTitle: null,
              userMiddle: Text(
                'moments_tabMemories'.tr,
                style: DsTypography.title.copyWith(color: theme.text),
              ),
              userTrailing: const SizedBox(width: 38),
              userLargeTitle: null,
              largeTitleActions: null,
              appbarBottom: null,
              padding: null,
              large: false,
            ),
          ),
          Expanded(
            child:
                images.isEmpty
                    ? Center(
                      child: Text(
                        _moments.posts.isEmpty
                            ? 'moments_collectionsEmptyNoPosts'.tr
                            : 'moments_collectionsEmptyNoImages'.tr,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    )
                    : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 34,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                2,
                                20,
                                6,
                              ),
                              children: [
                                InterestPill(
                                  label: 'moments_filterAll'.tr,
                                  selected: _filter == null,
                                  onTap:
                                      () => setState(() => _filter = null),
                                ),
                                const SizedBox(width: 6),
                                for (final tag in MomentTags.all) ...[
                                  TagPill(
                                    tag: tag,
                                    selected: _filter == tag.key,
                                    onTap:
                                        () => setState(
                                          () => _filter = tag.key,
                                        ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 140),
                          sliver: SliverToBoxAdapter(
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
                                          for (
                                            var i = col;
                                            i < images.length;
                                            i += 2
                                          )
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(
                                                    bottom: 16,
                                                  ),
                                              // 瀑布流 cell 便签化（窄卡小贴条）
                                              child: HandDrawnStickyItem(
                                                tiltKey: images[i],
                                                tapeWidth: 56,
                                                tapeHeight: 18,
                                                child: GestureDetector(
                                                  onTap:
                                                      () => _openViewer(
                                                        images,
                                                        i,
                                                      ),
                                                  child: Container(
                                                    height: _heightOf(i),
                                                    padding:
                                                        const EdgeInsets.all(
                                                          3,
                                                        ),
                                                    decoration:
                                                        dsSketchDecoration(
                                                          theme: theme,
                                                          fillColor:
                                                              theme.surface,
                                                          radius:
                                                              theme.radii.md,
                                                          seed:
                                                              images[i]
                                                                  .hashCode,
                                                        ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          theme.radii.sm,
                                                      child: MomentImage(
                                                        path: images[i],
                                                      ),
                                                    ),
                                                  ),
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
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  /// 瀑布流伪随机高度（与个人主页合集共用节奏）
  static const _heights = [
    128.0,
    100.0,
    142.0,
    108.0,
    134.0,
    104.0,
    124.0,
    114.0,
  ];

  double _heightOf(int index) => _heights[index % _heights.length];

  void _openViewer(List<String> images, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PhotoViewerScreen(
              imageRelativePaths: images,
              initialIndex: index,
            ),
      ),
    );
  }
}
