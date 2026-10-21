import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/screens/channel_list/channel_list_screen.dart';
import 'package:aboutme/plugins/chat/screens/timeline/timeline_screen.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'chat_config_service.dart';

/// 负责构建聊天插件的UI界面
class UIService {
  final ChatConfigService _configService;
  final ChatPlugin _plugin;

  UIService(
    ChatConfigService settingsService,
    ChatConfigService userService,
    this._plugin,
  ) : _configService = settingsService;

  Future<void> initialize() async {
    // 初始化UI服务相关的内容
  }

  Widget buildCardView(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final channels = _plugin.channelService.channels;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部图标和标题
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _plugin.color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_plugin.icon, size: 24, color: _plugin.color),
              ),
              const SizedBox(width: 12),
              Text(
                'chat_name'.tr,
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 统计信息卡片 - 两行显示
          Column(
            children: [
              // 第一行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'chat_channelCount'.tr,
                        style: DsTypography.body.copyWith(color: theme.textSub),
                      ),
                      Text(
                        '${channels.length}',
                        style: DsTypography.body.copyWith(
                          color: theme.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const VerticalDivider(),
                  Column(
                    children: [
                      Text(
                        'chat_totalMessages'.tr,
                        style: DsTypography.body.copyWith(color: theme.textSub),
                      ),
                      Text(
                        '${_plugin.channelService.getTotalMessageCount()}',
                        style: DsTypography.body.copyWith(
                          color: theme.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 第二行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'chat_totalMessages'.tr,
                        style: DsTypography.body.copyWith(color: theme.textSub),
                      ),
                      Text(
                        '${_plugin.channelService.getTodayMessageCount()}',
                        style: DsTypography.body.copyWith(
                          color:
                              _plugin.channelService.getTodayMessageCount() > 0
                                  ? theme.primary
                                  : theme.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildMainView(BuildContext context) {
    final channels = _plugin.channelService.channels;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: TabBarView(
          children: [
            // 频道列表标签页
            ChannelListScreen(channels: channels, chatPlugin: _plugin),
            // 时间线标签页
            TimelineScreen(chatPlugin: _plugin),
          ],
        ),
        bottomNavigationBar: DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return TabBar(
                labelColor: theme.primary,
                unselectedLabelColor: theme.textSub,
                tabs: [
                  Tab(
                    icon: DsIcon(
                      DsIconKind.chat,
                      size: 22,
                      color: theme.primary,
                    ),
                    text: 'chat_channelsTab'.tr,
                  ),
                  Tab(
                    icon: DsIcon(
                      DsIconKind.list,
                      size: 22,
                      color: theme.textSub,
                    ),
                    text: 'chat_timelineTab'.tr,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildChatSettingsCard(BuildContext context, StateSetter setState) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return JellyBox(
              radius: theme.radii.lg,
              raised: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'chat_chatSettings'.tr,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                  ),
                  _buildSwitchRow(
                    theme,
                    label: 'chat_showAvatarInChat'.tr,
                    value: _configService.showAvatarInChat,
                    onChanged:
                        (value) => setState(() {
                          _configService.setShowAvatarInChat(value);
                        }),
                  ),
                  _buildSwitchRow(
                    theme,
                    label: 'chat_playSoundOnSend'.tr,
                    value: _configService.playSoundOnSend,
                    onChanged:
                        (value) => setState(() {
                          _configService.setPlaySoundOnSend(value);
                        }),
                  ),
                  _buildSwitchRow(
                    theme,
                    label: 'chat_showAvatarInTimeline'.tr,
                    value: _configService.showAvatarInTimeline,
                    onChanged:
                        (value) => setState(() {
                          _configService.setShowAvatarInTimeline(value);
                        }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 设置开关行
  Widget _buildSwitchRow(
    AppThemeData theme, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: DsTypography.body.copyWith(color: theme.text),
            ),
          ),
          DSSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
