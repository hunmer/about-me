import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:super_cupertino_navigation_bar/utils/navigation_bar_static_components.dart';
import 'package:super_cupertino_navigation_bar/utils/persistent_nav_bar.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

import '../widgets/moments_compose_sheet.dart';
import '../widgets/moments_shared.dart';
import 'moments_feed_screen.dart';
import 'moments_memories_screen.dart';
import 'moments_profile_screen.dart';

/// 朋友圈插件宿主页：顶部统一导航栏 + 底部圆盘 dock 即 tabs，
/// 在一处容器内切换三个页面（动态流 / 回忆 / 我的主页），
/// 不跳转路由；agent 个人主页仍是 push 的子页面（自带返回顶栏）
class MomentsHomeScreen extends StatefulWidget {
  const MomentsHomeScreen({super.key});

  @override
  State<MomentsHomeScreen> createState() => _MomentsHomeScreenState();
}

class _MomentsHomeScreenState extends State<MomentsHomeScreen> {
  final _feedKey = GlobalKey<MomentsFeedScreenState>();
  final _navBarKeys = NavigationBarStaticComponentsKeys();
  final _moments = MomentsService.instance;
  int _current = 0;

  /// 与 [PersistentNavigationBar] 默认工具栏高度保持一致
  static const _navToolbarHeight = 56.0;

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

  Future<void> _openCompose() async {
    await SmoothBottomSheet.showWithTitle<void>(
      context: context,
      title: 'moments_composeTitle'.tr,
      child: const MomentsComposeSheet(),
    );
  }

  /// 24h 内 agent 新帖数（铃铛未读角标）
  int get _todayAgentPostCount {
    final now = DateTime.now();
    return _moments.posts
        .where((p) => !p.isUserPost && now.difference(p.createdAt).inHours < 24)
        .length;
  }

  /// 统一顶栏：标题与尾部动作随 tab 切换
  /// （动态流 = 互动铃铛 / 回忆 = 占位 / 我的主页 = 更多）
  Widget _buildNavBar(AppThemeData theme) {
    Widget trailing;
    switch (_current) {
      case 0:
        final unread = _todayAgentPostCount;
        trailing = Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DSIconButton(
                icon: DsIconKind.heart,
                size: 38,
                onPressed: () => ToastService.instance.showToast(
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
        );
      case 2:
        trailing = DSIconButton(
          icon: DsIconKind.more,
          size: 38,
          onPressed: () => ToastService.instance.showToast(
            'moments_linkCopied'.trParams({'name': 'moments_me'.tr}),
          ),
        );
      default:
        trailing = const SizedBox(width: 38);
    }

    final title = switch (_current) {
      1 => 'moments_tabMemories'.tr,
      2 => 'moments_profileTitle'.tr,
      _ => 'moments_name'.tr,
    };

    return PersistentNavigationBar(
      components: NavigationBarStaticComponents(
        keys: _navBarKeys,
        route: null,
        // 等宽占位与尾部动作对称，保持标题居中
        userLeading: const SizedBox(width: 38),
        automaticallyImplyLeading: false,
        automaticallyImplyTitle: false,
        previousPageTitle: null,
        userMiddle: Text(
          title,
          style: DsTypography.title.copyWith(color: theme.text),
        ),
        userTrailing: trailing,
        userLargeTitle: null,
        largeTitleActions: null,
        appbarBottom: null,
        padding: null,
        large: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // 动态流/我的 tab 设了背景图：封面延伸到状态栏后，
    // 透明导航栏浮在封面上；否则内容下移避让，导航栏固定。
    // IndexedStack 恒在 Stack 内仅变 padding，浮动/固定切换不重建子页 State
    final hasCover =
        _current != 1 &&
        (_moments.profileBgOf(MomentPost.userAuthorId)?.isNotEmpty ?? false);
    final topAvoid = MediaQuery.of(context).padding.top + _navToolbarHeight;

    return Scaffold(
      backgroundColor: theme.background,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: hasCover ? 0 : topAvoid),
              child: IndexedStack(
                index: _current,
                children: [
                  MomentsFeedScreen(key: _feedKey),
                  const MomentsMemoriesScreen(),
                  const MomentsProfileScreen(embedded: true),
                ],
              ),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _buildNavBar(theme)),
        ],
      ),
      bottomNavigationBar: MomentsDock(
        activeIndex: _current,
        onHome: () {
          // 已在首页：回顶部；否则切到首页
          if (_current == 0) {
            _feedKey.currentState?.scrollToTop();
          } else {
            setState(() => _current = 0);
          }
        },
        onMemories: () => setState(() => _current = 1),
        onMe: () => setState(() => _current = 2),
        onCompose: () => unawaited(_openCompose()),
      ),
    );
  }
}
