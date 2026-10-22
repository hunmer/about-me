/// 联系人卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 数据色圆形图标徽章（实底墨线描边）/ 姓名 + 时间 / 标签小徽章。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 联系人卡片小组件
class ContactCardWidget extends StatelessWidget {
  /// 联系人 ID
  final String id;

  /// 联系人姓名
  final String name;

  /// 电话号码
  final String? phone;

  /// 最后联系时间
  final String lastContactTime;

  /// 是否有头像
  final bool hasAvatar;

  /// 图标
  final int iconCodePoint;

  /// 图标颜色
  final int iconColorValue;

  /// 标签
  final List<String>? tags;

  /// 是否为内联模式
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const ContactCardWidget({
    super.key,
    required this.id,
    required this.name,
    this.phone,
    required this.lastContactTime,
    this.hasAvatar = false,
    required this.iconCodePoint,
    required this.iconColorValue,
    this.tags,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory ContactCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return ContactCardWidget(
      id: props['id'] as String? ?? '',
      name: props['name'] as String? ?? '',
      phone: props['phone'] as String?,
      lastContactTime: props['lastContactTime'] as String? ?? '',
      hasAvatar: props['hasAvatar'] as bool? ?? false,
      iconCodePoint: (props['icon'] as int?) ?? 0,
      iconColorValue: (props['iconColor'] as int?) ?? 0xFF9C27B0,
      tags: (props['tags'] as List<dynamic>?)
              ?.cast<String>()
              .toList(),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final icon = dynamicIconData(iconCodePoint, fontFamily: 'MaterialIcons');
    final color = Color(iconColorValue);

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: inline ? double.maxFinite : null,
        height: inline ? double.maxFinite : null,
        radius: BorderRadius.circular(24 * size.scale),
        padding: size.getPadding(),
        child: Row(
          children: [
            _buildAvatar(theme, icon, color),
            SizedBox(width: size.getItemSpacing()),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: size.getTitleFontSize(),
                      color: theme.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: size.getItemSpacing() / 2),
                  Text(
                    lastContactTime,
                    style: TextStyle(
                      color: theme.textSub,
                      fontSize: size.getSubtitleFontSize(),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tags != null && tags!.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: tags!
                          .take(3)
                          .map((tag) => _buildTag(theme, tag))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 标签小徽章：surfaceAlt 实底 + 墨线描边
  Widget _buildTag(AppThemeData theme, String tag) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size.getSmallSpacing(),
        vertical: 2,
      ),
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(8 * size.scale),
        fillColor: theme.surfaceAlt,
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: size.getLegendFontSize(),
          color: theme.textSub,
        ),
      ),
    );
  }

  /// 头像徽章：数据色浅底 + 手绘图标本体
  Widget _buildAvatar(AppThemeData theme, IconData icon, Color color) {
    final avatarSize = size.getIconSize();
    return Container(
      width: avatarSize,
      height: avatarSize,
      // 大圆角被 rough 引擎自动钳制成圆
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(avatarSize / 2),
        fillColor: color.withValues(alpha: 0.2),
      ),
      child: Center(
        child: WiredIcon(
          icon: icon,
          size: avatarSize * 0.5,
          color: color,
          drawConfig: theme.wired.drawConfig,
        ),
      ),
    );
  }
}
