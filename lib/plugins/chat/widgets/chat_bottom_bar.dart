import 'package:aboutme/plugins/chat/screens/channel_list/channel_list_screen.dart';
import 'package:get/get.dart';
import 'package:aboutme/plugins/chat/screens/stats/chat_stats_screen.dart';
import 'package:aboutme/plugins/chat/screens/timeline/timeline_screen.dart';
import 'package:aboutme/plugins/chat/screens/tags/tags_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/custom_bottom_bar.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/screens/channel_list/controllers/channel_list_controller.dart';
import 'package:aboutme/plugins/chat/screens/channel_list/widgets/chat_channel_form.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/core/route/route_history_manager.dart';

/// Chat 插件的底部栏组件
/// 提供频道列表和时间线两个 Tab 的切换功能
class ChatBottomBar extends StatefulWidget {
  final ChatPlugin plugin;

  const ChatBottomBar({super.key, required this.plugin});

  @override
  State<ChatBottomBar> createState() => _ChatBottomBarState();
}

class _ChatBottomBarState extends State<ChatBottomBar>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _currentPage;
  final GlobalKey _bottomBarKey = GlobalKey();
  late ChannelListController _channelListController;

  // 统计页刷新令牌：每次切到统计 tab 递增，触发重新统计
  int _statsRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _tabController = TabController(length: 4, vsync: this);
    _channelListController = ChannelListController(
      channels: widget.plugin.channelService.channels,
      chatPlugin: widget.plugin,
    );
    _tabController.animation?.addListener(() {
      final value = _tabController.animation!.value.round();
      if (value != _currentPage && mounted) {
        setState(() {
          _currentPage = value;
          if (value == 3) _statsRefreshToken++;
        });
        // 更新路由上下文
        _updateRouteContext(value);
      }
    });

    // 初始化时设置路由上下文
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRouteContext(_currentPage);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _channelListController.dispose();
    super.dispose();
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到当前tab状态
  void _updateRouteContext(int tabIndex) {
    String pageId;
    String title;

    switch (tabIndex) {
      case 0:
        pageId = '/chat/channels';
        title = 'chat_channelsTab'.tr;
        break;
      case 1:
        pageId = '/chat/timeline';
        title = 'chat_timelineTab'.tr;
        break;
      case 2:
        pageId = '/chat/tags';
        title = 'chat_tagsTab'.tr;
        break;
      case 3:
        pageId = '/chat/stats';
        title = 'chat_statsTab'.tr;
        break;
      default:
        pageId = '/chat';
        title = 'chat_name'.tr;
    }

    RouteHistoryManager.updateCurrentContext(
      pageId: pageId,
      title: title,
      params: {'tabIndex': tabIndex},
    );
  }

  /// 显示创建频道的底部弹层
  void _showAddChannelDialog() {
    // 获取当前激活的频道分类，排除"全部"和"未分组"
    String? defaultGroup = _channelListController.selectedGroup;
    if (defaultGroup == "all" || defaultGroup == "ungrouped") {
      defaultGroup = null;
    }

    SmoothBottomSheet.show(
      context: context,
      builder:
          (context) => ChatChannelForm(
            asSheet: true,
            onAddChannel: (channel) async {
              await _channelListController.addChannel(channel);
            },
            defaultGroup: defaultGroup,
          ),
    );
  }

  /// 构建 FAB（根据当前 tab 决定是否显示）
  Widget? _buildFab() {
    // 只有在频道 tab 时才显示 FAB
    if (_currentPage != 0) {
      return null;
    }
    return DSFab(
      icon: DsIconKind.chat,
      color: widget.plugin.color,
      iconColor:
          widget.plugin.color.computeLuminance() < 0.5
              ? DsColors.white
              : DsColors.night,
      onPressed: _showAddChannelDialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // Builder 让取色在主题桥内执行，可读取 AppTheme
      child: Builder(
        builder:
            (context) => CustomBottomBar(
              currentIndex: _currentPage,
              tabController: _tabController,
              bottomBarKey: _bottomBarKey,
              body:
                  (context, controller) => TabBarView(
                    controller: _tabController,
                    dragStartBehavior: DragStartBehavior.start,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // Tab0: 频道列表
                      ChannelListScreen(
                        channels: widget.plugin.channelService.channels,
                        chatPlugin: widget.plugin,
                        controller: _channelListController,
                        onAddChannel: _showAddChannelDialog,
                      ),
                      // Tab1: 时间线
                      TimelineScreen(chatPlugin: widget.plugin),
                      // Tab2: 标签
                      TagsScreen(chatPlugin: widget.plugin),
                      // Tab3: 消息统计
                      ChatStatsScreen(
                        chatPlugin: widget.plugin,
                        refreshToken: _statsRefreshToken,
                      ),
                    ],
                  ),
              fab: _buildFab(),
              items: [
                DSNavItem(icon: DsIconKind.chat, label: 'chat_channelsTab'.tr),
                DSNavItem(icon: DsIconKind.clock, label: 'chat_timelineTab'.tr),
                DSNavItem(icon: DsIconKind.tag, label: 'chat_tagsTab'.tr),
                DSNavItem(icon: DsIconKind.chart, label: 'chat_statsTab'.tr),
              ],
            ),
      ),
    );
  }
}
