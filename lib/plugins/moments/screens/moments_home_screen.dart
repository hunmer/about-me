import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';

import '../widgets/moments_compose_sheet.dart';
import '../widgets/moments_shared.dart';
import 'moments_feed_screen.dart';
import 'moments_memories_screen.dart';
import 'moments_profile_screen.dart';

/// 朋友圈插件宿主页：底部圆盘 dock 即 tabs，
/// 在一处容器内切换三个页面（动态流 / 回忆 / 我的主页），
/// 不跳转路由；agent 个人主页仍是 push 的子页面
class MomentsHomeScreen extends StatefulWidget {
  const MomentsHomeScreen({super.key});

  @override
  State<MomentsHomeScreen> createState() => _MomentsHomeScreenState();
}

class _MomentsHomeScreenState extends State<MomentsHomeScreen> {
  final _feedKey = GlobalKey<MomentsFeedScreenState>();
  int _current = 0;

  @override
  void initState() {
    super.initState();
    MomentsService.instance.loadPosts();
  }

  Future<void> _openCompose() async {
    await showDSBottomSheet<void>(
      context: context,
      title: 'moments_composeTitle'.tr,
      builder: (_) => const MomentsComposeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      extendBody: true,
      body: IndexedStack(
        index: _current,
        children: [
          MomentsFeedScreen(key: _feedKey),
          const MomentsMemoriesScreen(),
          const MomentsProfileScreen(embedded: true),
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
