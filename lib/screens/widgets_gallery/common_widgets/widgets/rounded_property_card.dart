/// 圆角属性卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 照片核心视觉保留（墨线像框画在照片之上）/ 标题 / 手绘元数据行
/// （日历、时钟、云朵）/ 主色操作行。
library;

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 属性元数据项
class PropertyMetadataItem {
  final IconData icon;
  final String label;

  const PropertyMetadataItem({
    required this.icon,
    required this.label,
  });

  factory PropertyMetadataItem.fromJson(Map<String, dynamic> json) {
    return PropertyMetadataItem(
      icon: _iconFromString(json['icon'] as String? ?? ''),
      label: json['label'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'icon': _iconToString(icon), 'label': label};
  }

  static IconData _iconFromString(String iconString) {
    // 简单的图标映射，实际使用中可以扩展
    switch (iconString) {
      case 'Icons.calendar_today':
        return Icons.calendar_today;
      case 'Icons.schedule':
        return Icons.schedule;
      case 'Icons.cloud_queue':
        return Icons.cloud_queue;
      default:
        return Icons.info;
    }
  }

  static String _iconToString(IconData icon) {
    // 简单的图标映射，实际使用中可以扩展
    if (icon == Icons.calendar_today) return 'Icons.calendar_today';
    if (icon == Icons.schedule) return 'Icons.schedule';
    if (icon == Icons.cloud_queue) return 'Icons.cloud_queue';
    return 'Icons.info';
  }
}

/// 圆角属性卡片小组件
class RoundedPropertyCardWidget extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String date;
  final String time;
  final String temperature;
  final String description;
  final String actionLabel;
  final IconData actionIcon;
  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;
  /// 小组件尺寸
  final HomeWidgetSize size;

  const RoundedPropertyCardWidget({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.date,
    required this.time,
    required this.temperature,
    required this.description,
    required this.actionLabel,
    required this.actionIcon,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory RoundedPropertyCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return RoundedPropertyCardWidget(
      title: props['title'] as String? ?? '',
      imageUrl: props['imageUrl'] as String? ?? '',
      date: props['date'] as String? ?? '',
      time: props['time'] as String? ?? '',
      temperature: props['temperature'] as String? ?? '',
      description: props['description'] as String? ?? '',
      actionLabel: props['actionLabel'] as String? ?? '',
      actionIcon: PropertyMetadataItem._iconFromString(props['actionIcon'] as String? ?? 'Icons.my_location'),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<RoundedPropertyCardWidget> createState() => _RoundedPropertyCardWidgetState();
}

class _RoundedPropertyCardWidgetState extends State<RoundedPropertyCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 340,
        height: widget.inline ? double.maxFinite : 520,
        radius: BorderRadius.circular(24 * widget.size.scale),
        padding: widget.size.getPadding(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部图片区域（照片核心视觉保留，墨线像框画在照片之上）
            _buildImageSection(theme),

            SizedBox(height: widget.size.getItemSpacing()),

            // 内容区域
            _buildContentSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(AppThemeData theme) {
    final frameRadius = BorderRadius.circular(12 * widget.size.scale);
    return Container(
      height: 240,
      foregroundDecoration: dsSketchDecoration(
        theme: theme,
        radius: frameRadius,
      ),
      child: ClipRRect(
        borderRadius: frameRadius,
        child: FadeInImage(
          placeholder: MemoryImage(kTransparentImage),
          image: NetworkImage(widget.imageUrl),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          imageErrorBuilder: (context, error, stackTrace) {
            return Container(
              color: theme.surfaceAlt,
              child: DsIcon(
                DsIconKind.image,
                size: 64,
                color: theme.textSub,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContentSection(AppThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Text(
          widget.title,
          style: TextStyle(
            fontSize: widget.size.getTitleFontSize(),
            fontWeight: FontWeight.w700,
            color: theme.text,
            height: 1.2,
          ),
        ),
        SizedBox(height: widget.size.getTitleSpacing()),

        // 元数据行
        _buildMetadataRow(),
        SizedBox(height: widget.size.getItemSpacing()),

        // 描述文本
        Text(
          widget.description,
          style: TextStyle(
            fontSize: widget.size.getSubtitleFontSize(),
            fontWeight: FontWeight.w400,
            color: theme.textSub,
            height: 1.6,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: widget.size.getTitleSpacing()),

        // 操作按钮
        _buildActionButton(theme),
      ],
    );
  }

  Widget _buildMetadataRow() {
    final metadataItems = [
      PropertyMetadataItem(icon: Icons.calendar_today, label: widget.date),
      PropertyMetadataItem(icon: Icons.schedule, label: widget.time),
      PropertyMetadataItem(icon: Icons.cloud_queue, label: widget.temperature),
    ];

    return Wrap(
      spacing: widget.size.getItemSpacing() * 2,
      runSpacing: widget.size.getItemSpacing(),
      children: metadataItems.map((item) {
        return _MetadataItemWidget(
          icon: item.icon,
          label: item.label,
          animation: _animation,
          size: widget.size,
        );
      }).toList(),
    );
  }

  Widget _buildActionButton(AppThemeData theme) {
    return InkWell(
      onTap: () {
        // TODO: 实现导航逻辑
      },
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WiredIcon(
            icon: widget.actionIcon,
            size: widget.size.getIconSize() * 0.8,
            color: theme.primary,
            drawConfig: theme.wired.drawConfig,
          ),
          SizedBox(width: widget.size.getItemSpacing()),
          Text(
            widget.actionLabel,
            style: TextStyle(
              fontSize: widget.size.getSubtitleFontSize(),
              fontWeight: FontWeight.w600,
              color: theme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 元数据项组件
class _MetadataItemWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _MetadataItemWidget({
    required this.icon,
    required this.label,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WiredIcon(
          icon: icon,
          size: size.getIconSize() * 0.7,
          color: theme.textSub,
          drawConfig: theme.wired.drawConfig,
        ),
        SizedBox(width: size.getSmallSpacing()),
        Text(
          label,
          style: TextStyle(
            fontSize: size.getLegendFontSize() + 1,
            fontWeight: FontWeight.w500,
            color: theme.textSub,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// 透明图片占位符
final Uint8List kTransparentImage = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
