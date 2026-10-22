/// 最近联系人卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题栏（计数 primary 墨色）/ 联系人列表（数据色圆形图标徽章或
/// 首字母主色徽章、墨线分隔线）/ "+N" 手绘小按钮。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 最近联系人卡片小组件
class RecentContactCardWidget extends StatelessWidget {
  /// 联系人数量
  final int contactCount;

  /// 标签
  final String label;

  /// 联系人列表
  final List<RecentContactItem> contacts;

  /// 更多数量
  final int moreCount;

  /// 是否为内联模式
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const RecentContactCardWidget({
    super.key,
    required this.contactCount,
    required this.label,
    required this.contacts,
    this.moreCount = 0,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory RecentContactCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final contactsList = (props['contacts'] as List<dynamic>?)
            ?.map((e) => RecentContactItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return RecentContactCardWidget(
      contactCount: (props['contactCount'] as int?) ?? 0,
      label: props['label'] as String? ?? '',
      contacts: contactsList,
      moreCount: (props['moreCount'] as int?) ?? 0,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return SizedBox.expand(
      child: WiredDraw(
        child: DsSketchPanel(
          theme: theme,
          width: inline ? double.maxFinite : null,
          height: inline ? double.maxFinite : null,
          radius: BorderRadius.circular(24 * size.scale),
          padding: size.getPadding(),
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.getItemSpacing(),
                    vertical: size.getItemSpacing() / 2,
                  ),
                  child: Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: size.getSubtitleFontSize(),
                          color: theme.text,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$contactCount',
                        style: TextStyle(
                          color: theme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: size.getSubtitleFontSize(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 联系人列表
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.getItemSpacing() / 2,
                    ),
                    shrinkWrap: true,
                    itemCount: contacts.length + (moreCount > 0 ? 1 : 0),
                    separatorBuilder: (context, index) => Container(
                      height: 1,
                      color: theme.ink.withValues(alpha: 0.18),
                    ),
                    itemBuilder: (context, index) {
                      if (index < contacts.length) {
                        final contact = contacts[index];
                        return _buildContactItem(context, contact, size, theme);
                      } else {
                        // 显示"更多"项
                        return _buildMoreItem(context, size, theme);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context,
    RecentContactItem contact,
    HomeWidgetSize size,
    AppThemeData theme,
  ) {
    return InkWell(
      onTap: () => _navigateToDetail(context, contact.id),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: size.getItemSpacing() / 2),
        child: Row(
          children: [
            _buildAvatar(context, contact, size, theme),
            SizedBox(width: size.getItemSpacing()),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    contact.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: size.getSubtitleFontSize(),
                      color: theme.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (contact.lastContactTime.isNotEmpty)
                    Text(
                      contact.lastContactTime,
                      style: TextStyle(
                        color: theme.textSub,
                        fontSize: size.getSubtitleFontSize(),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    RecentContactItem contact,
    HomeWidgetSize size,
    AppThemeData theme,
  ) {
    final avatarSize = size.getIconSize();
    final iconSize = avatarSize * 0.5;
    final icon = dynamicIconData(
      contact.iconCodePoint,
      fontFamily: 'MaterialIcons',
    );
    final color = Color(contact.iconColorValue);

    if (contact.hasAvatar) {
      // 图标徽章：数据色浅底 + 墨线描边（大圆角被 rough 引擎钳成圆）
      return Container(
        width: avatarSize,
        height: avatarSize,
        decoration: dsSketchDecoration(
          theme: theme,
          radius: BorderRadius.circular(avatarSize / 2),
          fillColor: color.withValues(alpha: 0.2),
        ),
        child: Center(
          child: WiredIcon(
            icon: icon,
            size: iconSize,
            color: color,
            drawConfig: theme.wired.drawConfig,
          ),
        ),
      );
    }

    // 首字母徽章：主色实底 + 墨线描边
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(avatarSize / 2),
        fillColor: theme.primary,
      ),
      child: Center(
        child: Text(
          contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: avatarSize * 0.4,
            fontWeight: FontWeight.bold,
            color: theme.onPrimary,
          ),
        ),
      ),
    );
  }

  /// "+N" 更多按钮：surfaceAlt 实底 + 墨线描边
  Widget _buildMoreItem(
    BuildContext context,
    HomeWidgetSize size,
    AppThemeData theme,
  ) {
    return Center(
      child: GestureDetector(
        onTap: () => _navigateToMore(context),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: size.getSmallSpacing() * 2,
            vertical: size.getSmallSpacing(),
          ),
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(12 * size.scale),
            fillColor: theme.surfaceAlt,
          ),
          child: Text(
            '+$moreCount',
            style: TextStyle(
              fontSize: size.getSubtitleFontSize(),
              fontWeight: FontWeight.w600,
              color: theme.primary,
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, String contactId) {
    // TODO: 导航到联系人详情页
    debugPrint('Navigate to contact: $contactId');
  }

  void _navigateToMore(BuildContext context) {
    // TODO: 显示更多联系人列表
    debugPrint('Show more contacts');
  }
}

/// 最近联系人项数据模型
class RecentContactItem {
  final String id;
  final String name;
  final String lastContactTime;
  final bool hasAvatar;
  final int iconCodePoint;
  final int iconColorValue;

  RecentContactItem({
    required this.id,
    required this.name,
    required this.lastContactTime,
    this.hasAvatar = false,
    required this.iconCodePoint,
    required this.iconColorValue,
  });

  factory RecentContactItem.fromJson(Map<String, dynamic> json) {
    return RecentContactItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lastContactTime: json['lastContactTime'] as String? ?? '',
      hasAvatar: json['hasAvatar'] as bool? ?? false,
      iconCodePoint: (json['icon'] as int?) ?? 0,
      iconColorValue: (json['iconColor'] as int?) ?? 0xFF9C27B0,
    );
  }
}
