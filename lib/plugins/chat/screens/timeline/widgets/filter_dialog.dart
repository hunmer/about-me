import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/screens/timeline/models/timeline_filter.dart';

/// 高级过滤器对话框
class FilterDialog extends StatefulWidget {
  final TimelineFilter filter;
  final ChatPlugin chatPlugin;

  const FilterDialog({
    super.key,
    required this.filter,
    required this.chatPlugin,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late TimelineFilter _filter;
  late List<Channel> _availableChannels;
  late List<User> _availableUsers;

  @override
  void initState() {
    super.initState();
    // 创建过滤器的副本以便在对话框中编辑
    _filter = widget.filter.copyWith();

    // 获取所有可用的频道和用户
    _availableChannels = widget.chatPlugin.channelService.channels;

    // 从所有频道中收集唯一的用户
    final Set<String> userIds = {};
    final List<User> users = [];

    for (final channel in _availableChannels) {
      for (final message in channel.messages) {
        if (!userIds.contains(message.user.id)) {
          userIds.add(message.user.id);
          users.add(message.user);
        }
      }
    }

    _availableUsers = users;
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 440),
            child: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    'chat_advancedFilter'.tr,
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.lg),

                  // 搜索范围选项
                  Text(
                    'chat_searchIn'.tr,
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.sm),

                  _buildCheckRow(
                    theme,
                    label: 'chat_channelNames'.tr,
                    value: _filter.includeChannels,
                    onChanged: (value) {
                      setState(() {
                        _filter.includeChannels = value ?? true;
                      });
                    },
                  ),
                  _buildCheckRow(
                    theme,
                    label: 'chat_usernames'.tr,
                    value: _filter.includeUsernames,
                    onChanged: (value) {
                      setState(() {
                        _filter.includeUsernames = value ?? true;
                      });
                    },
                  ),
                  _buildCheckRow(
                    theme,
                    label: 'chat_messageContent'.tr,
                    value: _filter.includeContent,
                    onChanged: (value) {
                      setState(() {
                        _filter.includeContent = value ?? true;
                      });
                    },
                  ),

                  _buildDivider(theme),

                  // 元数据过滤选项
                  Text(
                    'chat_metadataFilters'.tr,
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.sm),

                  // AI 消息过滤选项
                  _buildCheckRow(
                    theme,
                    label: 'chat_aiMessages'.tr,
                    subtitle: 'chat_filterAiMessages'.tr,
                    value: _filter.isAI,
                    tristate: true,
                    onChanged: (value) {
                      setState(() {
                        _filter.isAI = value;
                      });
                    },
                  ),

                  // 收藏消息过滤选项
                  _buildCheckRow(
                    theme,
                    label: 'chat_favoriteMessages'.tr,
                    subtitle: 'chat_showOnlyFavorites'.tr,
                    value: _filter.isFavorite,
                    tristate: true,
                    onChanged: (value) {
                      setState(() {
                        _filter.isFavorite = value;
                      });
                    },
                  ),

                  _buildDivider(theme),

                  // 日期范围选择
                  Text(
                    'chat_dateRange'.tr,
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.sm),

                  Row(
                    children: [
                      Expanded(
                        child: DSButton(
                          icon: DsIconKind.calendar,
                          label:
                              _filter.startDate != null
                                  ? '${_filter.startDate!.day}/${_filter.startDate!.month}/${_filter.startDate!.year}'
                                  : 'chat_startDate'.tr,
                          variant: DSButtonVariant.outline,
                          size: DSButtonSize.sm,
                          onPressed: () => _selectDate(context, true),
                        ),
                      ),
                      SizedBox(width: theme.spacing.sm),
                      Expanded(
                        child: DSButton(
                          icon: DsIconKind.calendar,
                          label:
                              _filter.endDate != null
                                  ? '${_filter.endDate!.day}/${_filter.endDate!.month}/${_filter.endDate!.year}'
                                  : 'chat_endDate'.tr,
                          variant: DSButtonVariant.outline,
                          size: DSButtonSize.sm,
                          onPressed: () => _selectDate(context, false),
                        ),
                      ),
                    ],
                  ),

                  if (_filter.startDate != null || _filter.endDate != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: DSButton(
                        label: 'chat_clearDates'.tr,
                        variant: DSButtonVariant.ghost,
                        size: DSButtonSize.sm,
                        onPressed: () {
                          setState(() {
                            _filter.startDate = null;
                            _filter.endDate = null;
                          });
                        },
                      ),
                    ),

                  _buildDivider(theme),

                  // 频道选择
                  Text(
                    'chat_selectChannels'.tr,
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.sm),

                  if (_availableChannels.isEmpty)
                    Text(
                      'chat_noChannelsAvailable'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    )
                  else
                    Wrap(
                      spacing: theme.spacing.sm,
                      runSpacing: theme.spacing.sm,
                      children:
                          _availableChannels.map((channel) {
                            final isSelected = _filter.selectedChannelIds
                                .contains(channel.id);
                            return DSChip(
                              label: channel.title,
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _filter.selectedChannelIds.add(channel.id);
                                  } else {
                                    _filter.selectedChannelIds.remove(
                                      channel.id,
                                    );
                                  }
                                });
                              },
                            );
                          }).toList(),
                    ),

                  SizedBox(height: theme.spacing.lg),

                  // 用户选择
                  Text(
                    'chat_selectUsers'.tr,
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.sm),

                  if (_availableUsers.isEmpty)
                    Text(
                      'chat_noUsersAvailable'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    )
                  else
                    Wrap(
                      spacing: theme.spacing.sm,
                      runSpacing: theme.spacing.sm,
                      children:
                          _availableUsers.map((user) {
                            final isSelected = _filter.selectedUserIds.contains(
                              user.id,
                            );
                            return DSChip(
                              label: user.username,
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _filter.selectedUserIds.add(user.id);
                                  } else {
                                    _filter.selectedUserIds.remove(user.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                    ),

                  SizedBox(height: theme.spacing.lg),

                  // 操作按钮
                  Row(
                    children: [
                      Expanded(
                        child: DSButton(
                          label: 'app_cancel'.tr,
                          variant: DSButtonVariant.outline,
                          size: DSButtonSize.sm,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      SizedBox(width: theme.spacing.sm),
                      Expanded(
                        child: DSButton(
                          label: 'app_reset'.tr,
                          variant: DSButtonVariant.ghost,
                          size: DSButtonSize.sm,
                          onPressed: () {
                            _filter.reset();
                            setState(() {});
                          },
                        ),
                      ),
                      SizedBox(width: theme.spacing.sm),
                      Expanded(
                        child: DSButton(
                          label: 'app_apply'.tr,
                          size: DSButtonSize.sm,
                          onPressed: () {
                            Navigator.of(context).pop(_filter.toJson());
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 勾选行
  Widget _buildCheckRow(
    AppThemeData theme, {
    required String label,
    String? subtitle,
    required bool? value,
    bool tristate = false,
    required ValueChanged<bool?> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs / 2),
      child: Row(
        children: [
          DSCheckbox(value: value, tristate: tristate, onChanged: onChanged),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: DsTypography.body.copyWith(color: theme.text),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 分隔线
  Widget _buildDivider(AppThemeData theme) {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(vertical: theme.spacing.md),
      color: theme.stroke.withValues(alpha: 0.5),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? _filter.startDate : _filter.endDate;
    final now = DateTime.now();

    final DateTime? picked = await _showDSDatePicker(
      context,
      initialDate ?? now,
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _filter.startDate = picked;
          // 确保结束日期不早于开始日期
          if (_filter.endDate != null && _filter.endDate!.isBefore(picked)) {
            _filter.endDate = picked;
          }
        } else {
          _filter.endDate = picked;
          // 确保开始日期不晚于结束日期
          if (_filter.startDate != null && _filter.startDate!.isAfter(picked)) {
            _filter.startDate = picked;
          }
        }
      });
    }
  }
}

/// 果冻日期选择对话框：DSDatePicker + 确认按钮
Future<DateTime?> _showDSDatePicker(BuildContext context, DateTime initial) {
  DateTime selected = initial;
  return showDSDialog<DateTime>(
    context: context,
    theme: DSThemeBridge.resolve(context),
    builder:
        (context) => DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return JellyBox(
                radius: theme.radii.xxl,
                padding: EdgeInsets.all(theme.spacing.xl),
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DSDatePicker(
                      value: initial,
                      initialMonth: initial,
                      onChanged: (date) => selected = date,
                    ),
                    SizedBox(height: theme.spacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: DSButton(
                            label: 'app_cancel'.tr,
                            variant: DSButtonVariant.outline,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        SizedBox(width: theme.spacing.md),
                        Expanded(
                          child: DSButton(
                            label: 'app_ok'.tr,
                            onPressed:
                                () => Navigator.of(context).pop(selected),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
  );
}
