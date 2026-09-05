import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 渲染图标，支持 emoji 字符串和 MaterialIcons codePoint
Widget _renderIcon(String icon, {required double size}) {
  // 尝试解析为 MaterialIcons codePoint
  final codePoint = int.tryParse(icon);
  if (codePoint != null) {
    return Icon(dynamicIconData(codePoint, fontFamily: 'MaterialIcons'), size: size);
  }
  // 否则作为普通 emoji 字符串处理
  return Text(icon, style: TextStyle(fontSize: size));
}

/// 列进度数据模型
class ColumnProgressData {
  final double current;
  final double total;
  final String unit;

  const ColumnProgressData({
    required this.current,
    required this.total,
    required this.unit,
  });

  /// 从 JSON 创建
  factory ColumnProgressData.fromJson(Map<String, dynamic> json) {
    return ColumnProgressData(
      current: (json['current'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {'current': current, 'total': total, 'unit': unit};
  }
}

/// 左侧区域配置
class LeftSectionConfig {
  final String icon;
  final String label;
  final String? subtext; // 可选的副标题，显示在进度条下方

  const LeftSectionConfig({
    this.icon = '🔥',
    this.label = 'Calories',
    this.subtext,
  });

  /// 从 JSON 创建
  factory LeftSectionConfig.fromJson(Map<String, dynamic> json) {
    return LeftSectionConfig(
      icon: json['icon'] as String? ?? '🔥',
      label: json['label'] as String? ?? 'Calories',
      subtext: json['subtext'] as String?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'icon': icon,
      'label': label,
      if (subtext != null) 'subtext': subtext,
    };
  }
}

/// 进度项数据模型
class ProgressItemData {
  final String icon;
  final String name;
  final double current;
  final double total;
  final Color color;

  /// 可选的副标题（如时间范围）
  final String? subtitle;

  const ProgressItemData({
    required this.icon,
    required this.name,
    required this.current,
    required this.total,
    required this.color,
    this.subtitle,
  });

  /// 从 JSON 创建
  factory ProgressItemData.fromJson(Map<String, dynamic> json) {
    return ProgressItemData(
      icon: json['icon'] as String? ?? '',
      name: json['name'] as String? ?? '',
      current: (json['current'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      color: Color(json['color'] as int? ?? 0xFF000000),
      subtitle: json['subtitle'] as String?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'icon': icon,
      'name': name,
      'current': current,
      'total': total,
      'color': color.value,
      if (subtitle != null) 'subtitle': subtitle,
    };
  }
}

/// 左右分栏进度条卡片小组件
class SplitColumnProgressBarCard extends StatefulWidget {
  /// 左侧数据（用于进度条）
  final ColumnProgressData? leftData;

  /// 左侧区域配置（图标、标签等）
  final LeftSectionConfig? leftConfig;

  /// 右侧进度项列表
  final List<ProgressItemData>? rightItems;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const SplitColumnProgressBarCard({
    super.key,
    this.leftData,
    this.leftConfig,
    this.rightItems,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory SplitColumnProgressBarCard.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    // 解析左侧数据
    ColumnProgressData? leftData;
    if (props['leftData'] != null) {
      leftData = ColumnProgressData.fromJson(
        props['leftData'] as Map<String, dynamic>,
      );
    }

    // 解析左侧配置
    LeftSectionConfig? leftConfig;
    if (props['leftConfig'] != null) {
      leftConfig = LeftSectionConfig.fromJson(
        props['leftConfig'] as Map<String, dynamic>,
      );
    }

    // 解析右侧数据
    final rightItems =
        (props['rightItems'] as List<dynamic>?)
            ?.map((e) => ProgressItemData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return SplitColumnProgressBarCard(
      leftData: leftData,
      leftConfig: leftConfig,
      rightItems: rightItems,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<SplitColumnProgressBarCard> createState() =>
      _SplitColumnProgressBarCardState();
}

class _SplitColumnProgressBarCardState extends State<SplitColumnProgressBarCard>
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final leftData =
        widget.leftData ??
        const ColumnProgressData(current: 0, total: 100, unit: '');
    final leftConfig = widget.leftConfig ?? const LeftSectionConfig();
    final rightItems = widget.rightItems ?? const [];

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _animation.value)),
            child: Container(
              width: widget.inline ? double.maxFinite : 360,
              height: widget.inline ? double.maxFinite : 180,
              padding: widget.size.getPadding(),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF374151) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _LeftSection(
                      data: leftData,
                      config: leftConfig,
                      animation: _animation,
                      size: widget.size,
                    ),
                  ),
                  Container(
                    width: 1,
                    margin: EdgeInsets.symmetric(
                      horizontal: widget.size.getPadding().horizontal / 2,
                    ),
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.1)
                            : const Color(0xFFE5E7EB),
                  ),
                  Expanded(
                    child: _RightSection(
                      items: rightItems,
                      animation: _animation,
                      size: widget.size,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LeftSection extends StatelessWidget {
  final ColumnProgressData data;
  final LeftSectionConfig config;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _LeftSection({
    required this.data,
    required this.config,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // 根据 size 计算各种尺寸
    final iconSize = size.getIconSize();
    final labelFontSize = size.getSubtitleFontSize();
    final valueFontSize = size.getLargeFontSize() * 0.5; // 约 18/24/28
    final unitFontSize = size.getSubtitleFontSize();
    final progressBarHeight =
        size.getStrokeWidth() * size.progressStrokeScale * 2.5; // 约 6/8/10
    const subtextFontSizeScale = 0.75; // 副文本相对于 subtitleFontSize 的比例
    final subtextFontSize = labelFontSize * subtextFontSizeScale; // 约 9/10.5/12
    final smallSpacing = size.getSmallSpacing();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _renderIcon(config.icon, size: iconSize),
            SizedBox(width: smallSpacing),
            Text(
              config.label,
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : const Color(0xFF9CA3AF),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        SizedBox(height: size.getItemSpacing()),
        SizedBox(
          height: valueFontSize * 1.4, // 根据字体大小计算容器高度
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: valueFontSize * 1.3,
                child: AnimatedFlipCounter(
                  value: data.current * animation.value,
                  fractionDigits: 0,
                  textStyle: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    height: 1.0,
                  ),
                ),
              ),
              SizedBox(width: smallSpacing * 0.7),
              SizedBox(
                height: unitFontSize * 1.3,
                child: Text(
                  data.unit,
                  style: TextStyle(
                    fontSize: unitFontSize,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: size.getItemSpacing()),
        Container(
          height: progressBarHeight,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF4B5563) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(progressBarHeight / 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(progressBarHeight / 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor:
                    (data.total > 0 ? data.current / data.total : 0) *
                    animation.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(progressBarHeight / 2),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (config.subtext != null) ...[
          SizedBox(height: size.getItemSpacing()),
          SizedBox(
            height: subtextFontSize * 1.4,
            child: Text(
              config.subtext!,
              style: TextStyle(
                fontSize: subtextFontSize,
                fontWeight: FontWeight.w600,
                color: primaryColor,
                height: 1.0,
              ),
            ),
          ),
        ] else ...[
          SizedBox(height: size.getItemSpacing()),
          SizedBox(
            height: subtextFontSize * 1.4,
            child: Text(
              '${(data.total - data.current).toInt()} ${data.unit} remaining',
              style: TextStyle(
                fontSize: subtextFontSize,
                fontWeight: FontWeight.w600,
                color: primaryColor,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _RightSection extends StatelessWidget {
  final List<ProgressItemData> items;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _RightSection({
    required this.items,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(height: size.getItemSpacing()),
              _ProgressItem(
                data: items[i],
                animation: animation,
                index: i,
                size: size,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressItem extends StatelessWidget {
  final ProgressItemData data;
  final Animation<double> animation;
  final int index;
  final HomeWidgetSize size;

  const _ProgressItem({
    required this.data,
    required this.animation,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final step = 0.08;
    final end = (0.6 + index * step).clamp(0.0, 1.0);
    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(index * step, end, curve: Curves.easeOutCubic),
    );

    final progress = data.total > 0 ? data.current / data.total : 0;

    // 根据 size 计算各种尺寸
    final iconSize = size.getIconSize() * 0.6; // 约 11/14/17
    final nameFontSize = size.getSubtitleFontSize() * 0.85; // 约 10/12/14
    final subtitleFontSize = size.getLegendFontSize(); // 约 10/12/14
    final valueFontSize = size.getSubtitleFontSize() * 0.85; // 约 10/12/14
    final progressBarHeight =
        size.getStrokeWidth() * size.progressStrokeScale * 1.5; // 约 3.6/4.8/6
    final smallSpacing = size.getSmallSpacing();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _renderIcon(data.icon, size: iconSize),
                      SizedBox(width: smallSpacing),
                      Expanded(
                        child: Text(
                          data.name,
                          style: TextStyle(
                            fontSize: nameFontSize,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? Colors.grey.shade100
                                    : const Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (data.subtitle != null) ...[
                    SizedBox(height: size.getItemSpacing() / 4),
                    Padding(
                      padding: EdgeInsets.only(
                        left: iconSize + smallSpacing,
                      ), // Align with name (icon width + spacing)
                      child: Text(
                        data.subtitle!,
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w400,
                          color:
                              isDark
                                  ? Colors.grey.shade500
                                  : const Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: valueFontSize * 1.4,
              child: AnimatedFlipCounter(
                value: data.current * itemAnimation.value,
                fractionDigits: data.current % 1 != 0 ? 1 : 0,
                textStyle: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w700,
                  color: data.color,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: size.getItemSpacing() / 2),
        Container(
          height: progressBarHeight,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF4B5563) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(progressBarHeight / 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(progressBarHeight / 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress * itemAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: data.color,
                    borderRadius: BorderRadius.circular(progressBarHeight / 2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
