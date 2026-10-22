import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 图片展示卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 左侧图片（圆角裁切，图片视觉保留）+ 右侧信息区
/// （墨线圆形图标按钮 / 日期徽章 / 手绘星形评分）。
class ImageDisplayCardWidget extends StatefulWidget {
  /// 图片 URL
  final String imageUrl;

  /// 标题（支持换行）
  final String title;

  /// 标签文本（如 "Upcoming"）
  final String label;

  /// 日期文本
  final String date;

  /// 评分（0-5）
  final double rating;

  /// 右上角图标
  final IconData? icon;

  /// 主色调（用于评分和标签）
  final Color? primaryColor;

  /// 强调色（用于标签）
  final Color? accentColor;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const ImageDisplayCardWidget({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.label,
    required this.date,
    required this.rating,
    this.icon,
    this.primaryColor,
    this.accentColor,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory ImageDisplayCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return ImageDisplayCardWidget(
      imageUrl: props['imageUrl'] as String? ?? '',
      title: props['title'] as String? ?? '',
      label: props['label'] as String? ?? '',
      date: props['date'] as String? ?? '',
      rating: (props['rating'] as num?)?.toDouble() ?? 0.0,
      icon:
          props['icon'] != null
              ? dynamicIconData(props['icon'] as int, fontFamily: 'MaterialIcons')
              : null,
      primaryColor:
          props['primaryColor'] != null
              ? Color(props['primaryColor'] as int)
              : null,
      accentColor:
          props['accentColor'] != null
              ? Color(props['accentColor'] as int)
              : null,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<ImageDisplayCardWidget> createState() => _ImageDisplayCardWidgetState();
}

class _ImageDisplayCardWidgetState extends State<ImageDisplayCardWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // 数据色 props 保留，缺省走主题
    final primaryColor = widget.primaryColor ?? theme.primary;
    final accentColor = widget.accentColor ?? theme.warning;

    // 根据尺寸计算容器尺寸
    final containerWidth =
        widget.inline
            ? double.maxFinite
            : (widget.size.width >= 4
                ? double.maxFinite
                : 380.0 * widget.size.scale);
    final imageIconSize = widget.size.getFeaturedIconSize();

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: DsSketchPanel(
          theme: theme,
          width: containerWidth,
          radius: BorderRadius.circular(24 * widget.size.scale),
          padding: widget.size.getPadding(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左侧图片区域
              _buildImageArea(theme, imageSize: imageIconSize),
              SizedBox(width: widget.size.getItemSpacing() * 2),

              // 右侧信息区域
              Expanded(
                child: _buildInfoArea(theme, primaryColor, accentColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 左侧图片区域
  Widget _buildImageArea(AppThemeData theme, {required double imageSize}) {
    final imageSizeValue = widget.size.getFeaturedImageSize();
    final borderRadius = imageSizeValue * 0.2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        widget.imageUrl,
        width: imageSizeValue,
        height: imageSizeValue,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // 加载失败兜底：纸底方块 + 断图图标
          return Container(
            width: imageSizeValue,
            height: imageSizeValue,
            color: theme.surfaceAlt,
            child: WiredIcon(
              icon: Icons.broken_image,
              size: imageSizeValue * 0.4,
              color: theme.textSub,
              drawConfig: theme.wired.drawConfig,
            ),
          );
        },
      ),
    );
  }

  /// 右侧信息区域
  Widget _buildInfoArea(
    AppThemeData theme,
    Color primaryColor,
    Color accentColor,
  ) {
    final iconSize = widget.size.getThumbnailIconSize();
    final iconContainerSize = iconSize * 1.3;
    final labelFontSize = widget.size.getLegendFontSize();
    final titleFontSize = widget.size.getSubtitleFontSize();
    const ratingIconSize = 18.0;
    const ratingTextSize = 13.0;
    const dateFontSize = 11.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部：标签 + 图标
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 标签
            Expanded(
              child: Container(
                margin: EdgeInsets.only(top: widget.size.getItemSpacing() / 2),
                child: Text(
                  widget.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.15 * 3, // 0.15em ≈ 3px
                    color: accentColor,
                  ),
                ),
              ),
            ),

            // 图标按钮：墨线圆形徽章
            if (widget.icon != null)
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
                // 大圆角被 rough 引擎自动钳制成圆
                decoration: dsSketchDecoration(
                  theme: theme,
                  radius: BorderRadius.circular(iconContainerSize / 2),
                  fillColor: theme.surfaceAlt,
                ),
                child: WiredIcon(
                  icon: widget.icon!,
                  size: iconSize * 0.75,
                  color: theme.textSub,
                  drawConfig: theme.wired.drawConfig,
                ),
              ),
          ],
        ),

        SizedBox(height: widget.size.getItemSpacing() / 2),

        // 标题
        Text(
          widget.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
            color: theme.text,
            height: 1.2,
          ),
        ),

        const Spacer(),

        // 底部：日期 + 评分
        // Small 和 Medium 尺寸下换行展示
        if (widget.size is SmallSize || widget.size is MediumSize)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日期徽章
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.size.getItemSpacing() * 1.5,
                  vertical: widget.size.getItemSpacing() * 0.75,
                ),
                decoration: dsSketchDecoration(
                  theme: theme,
                  radius: BorderRadius.circular(12),
                  fillColor: theme.surfaceAlt,
                ),
                child: Text(
                  widget.date,
                  style: TextStyle(
                    fontSize: dateFontSize,
                    fontWeight: FontWeight.bold,
                    color: theme.textSub,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(height: widget.size.getItemSpacing()),
              // 评分
              Row(
                children: [
                  DsIcon(DsIconKind.star, size: ratingIconSize, color: primaryColor),
                  SizedBox(width: widget.size.getItemSpacing() / 2),
                  SizedBox(
                    height: ratingTextSize + 2,
                    child: Center(
                      child: Text(
                        widget.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: ratingTextSize,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          // 大尺寸下同一行展示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 日期徽章
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.size.getItemSpacing() * 1.5,
                  vertical: widget.size.getItemSpacing() * 0.75,
                ),
                decoration: dsSketchDecoration(
                  theme: theme,
                  radius: BorderRadius.circular(12),
                  fillColor: theme.surfaceAlt,
                ),
                child: Text(
                  widget.date,
                  style: TextStyle(
                    fontSize: dateFontSize,
                    fontWeight: FontWeight.bold,
                    color: theme.textSub,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // 评分
              Row(
                children: [
                  DsIcon(DsIconKind.star, size: ratingIconSize, color: primaryColor),
                  SizedBox(width: widget.size.getItemSpacing() / 2),
                  SizedBox(
                    height: ratingTextSize + 2,
                    child: Center(
                      child: Text(
                        widget.rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: ratingTextSize,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
