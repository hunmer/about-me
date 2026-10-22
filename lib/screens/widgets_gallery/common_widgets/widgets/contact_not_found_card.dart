/// 联系人未找到卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// danger 手绘人形图标 + 姓名（danger 墨色）/ 未找到消息。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 联系人未找到卡片小组件
class ContactNotFoundCardWidget extends StatelessWidget {
  /// 联系人名称
  final String name;

  /// 未找到消息
  final String message;

  /// 是否为内联模式
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const ContactNotFoundCardWidget({
    super.key,
    required this.name,
    required this.message,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory ContactNotFoundCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return ContactNotFoundCardWidget(
      name: props['name'] as String? ?? '',
      message: props['message'] as String? ?? '',
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
          child: Row(
            children: [
              DsIcon(
                DsIconKind.personOff,
                size: size.getIconSize(),
                color: theme.danger,
              ),
              SizedBox(width: size.getItemSpacing()),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: theme.danger,
                        fontSize: size.getTitleFontSize(),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: size.getItemSpacing() / 2),
                    Text(
                      message,
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
      ),
    );
  }
}
