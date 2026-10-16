import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'controllers/channel_list_controller.dart';
import 'widgets/channel_tile.dart';
import 'widgets/channel_group_selector.dart';
import 'widgets/channel_action_sheet.dart';
import 'widgets/channel_dialogs/channel_dialog.dart';

class ChannelListScreen extends StatefulWidget {
  final List<Channel> channels;
  final ChatPlugin chatPlugin;
  final ChannelListController? controller;
  final VoidCallback? onAddChannel;

  const ChannelListScreen({
    super.key,
    required this.channels,
    required this.chatPlugin,
    this.controller,
    this.onAddChannel,
  });

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> {
  late final ChannelListController _controller;
  late final bool _shouldDisposeController;

  @override
  void initState() {
    super.initState();
    // 如果传入了控制器，使用它；否则创建新的
    if (widget.controller != null) {
      _controller = widget.controller!;
      _shouldDisposeController = false;
    } else {
      _controller = ChannelListController(
        channels: widget.channels,
        chatPlugin: widget.chatPlugin,
      );
      _shouldDisposeController = true;
    }

    _controller.addListener(() {
      if (mounted) {
        // 使用 postFrameCallback 确保在构建完成后调用 setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // 只有当自己创建控制器时才释放它
    if (_shouldDisposeController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: Text('chat_channelList'.tr),
      largeTitle: 'chat_channelListTitle'.tr,
      enableSearchBar: true,
      searchPlaceholder: 'chat_searchPlaceholder'.tr,
      onSearchChanged: (query) {
        _controller.setSearchQuery(query);
      },
      onSearchSubmitted: (query) {
        _controller.setSearchQuery(query);
      },
      body: Column(
        children: [
          ChannelGroupSelector(
            selectedGroup: _controller.selectedGroup,
            availableGroups: _controller.availableGroups,
            onGroupSelected: (group) {
              _controller.saveSelectedGroup(group);
            },
          ),
          Expanded(
            child: _controller.filteredChannels.isEmpty
                ? Center(
                  child: DSEmptyState(
                    icon: DsIconKind.chat,
                    title: 'chat_channelList'.tr,
                    actionLabel: 'chat_newChannel'.tr,
                    onAction: widget.onAddChannel ?? () {},
                  ),
                )
                : ReorderableListView.builder(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: _controller.filteredChannels.length,
                    onReorder: _controller.reorderChannels,
                    itemBuilder: (context, index) {
                      final channel = _controller.filteredChannels[index];
                      // 手绘便签:随机倾斜 + 贴条(角度由 channel.id 哈希确定);
                      // key 必须留在 ReorderableListView 直接子项上供拖拽排序。
                      // 挂载即播墨线描画入场（design.md §10）
                      // vertical 8×2 = 16px 间距,容纳贴条顶部出血避免压盖
                      return HandDrawnStickyItem(
                        key: ValueKey(channel.id),
                        tiltKey: channel.id,
                        child: WiredDraw(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: ChannelTile(
                              channel: channel,
                              onBeforeOpen: () {
                                // 在打开聊天页面之前设置当前频道
                                widget.chatPlugin.channelService
                                    .setCurrentChannel(channel);
                              },
                              onLongPress: () =>
                                  _showChannelActionSheet(channel),
                              onEdit: (channel) =>
                                  _showEditChannelDialog(channel),
                              // 滑动删除已带嵌套二次确认，直接执行删除
                              onDelete: (channel) =>
                                  _controller.deleteChannel(channel.id),
                            ),
                          ),
                        ),
                      );
                    },
                    buildDefaultDragHandles: false,
                  ),
          ),
        ],
      ),
      enableLargeTitle: true,
      previousPageTitle: 'chat_back'.tr,
    );
  }

  void _showEditChannelDialog(Channel channel) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => ChannelDialog(
        isEditMode: true,
        channel: channel,
        onUpdateChannel: _controller.updateChannel,
      ),
    );
  }

  /// 长按频道弹出操作菜单（编辑/固定/封存/删除）
  void _showChannelActionSheet(Channel channel) {
    ChannelActionSheet.show(
      context: context,
      channel: channel,
      onEdit: () => _showEditChannelDialog(channel),
      onTogglePin: () => _controller.togglePin(channel),
      onToggleArchive: () => _controller.toggleArchive(channel),
      onDelete: () => _controller.deleteChannel(channel.id),
    );
  }
}
