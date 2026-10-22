/// 睡眠阶段气泡图小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘时间范围选择器（surfaceAlt 底 + 选中纸底块）/ 淡墨网格与时间标签 /
/// 睡眠阶段气泡（核心视觉保留：数据色圆角气泡逐个浮现，仅去柔影）/
/// 图例（数据色手绘色块）。气泡错峰入场动画保留。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 睡眠阶段类型
enum SleepStageType { core, rem, postREM, deep }

/// 睡眠阶段数据模型
class SleepStageData {
  final SleepStageType type;
  final double left; // 0-100
  final double topPercent; // 0-100
  final double widthPercent; // 0-100
  final double height;

  const SleepStageData({
    required this.type,
    required this.left,
    required this.topPercent,
    required this.widthPercent,
    required this.height,
  });

  /// 从 JSON 创建
  factory SleepStageData.fromJson(Map<String, dynamic> json) {
    return SleepStageData(
      type: SleepStageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SleepStageType.core,
      ),
      left: (json['left'] as num).toDouble(),
      topPercent: (json['topPercent'] as num).toDouble(),
      widthPercent: (json['widthPercent'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'left': left,
      'topPercent': topPercent,
      'widthPercent': widthPercent,
      'height': height,
    };
  }
}

/// 睡眠阶段图表小组件
class CardBubbleChartDisplay extends StatefulWidget {
  /// 睡眠阶段数据列表
  final List<SleepStageData> sleepStages;

  /// 初始选中的标签索引
  final int selectedTab;

  /// 是否显示工具提示
  final bool showTooltip;

  /// 时间标签列表
  final List<String> timeLabels;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const CardBubbleChartDisplay({
    super.key,
    required this.sleepStages,
    this.selectedTab = 1,
    this.showTooltip = true,
    this.timeLabels = const ['11:00', '12:00', '13:00', '14:00', '15:00'],
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory CardBubbleChartDisplay.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final stagesList = props['sleepStages'] as List<dynamic>?;
    final sleepStages = stagesList
            ?.map((e) => SleepStageData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final timeLabelsList = props['timeLabels'] as List<dynamic>?;
    final timeLabels = timeLabelsList
            ?.map((e) => e.toString())
            .toList() ??
        const ['11:00', '12:00', '13:00', '14:00', '15:00'];

    return CardBubbleChartDisplay(
      sleepStages: sleepStages,
      selectedTab: props['selectedTab'] as int? ?? 1,
      showTooltip: props['showTooltip'] as bool? ?? true,
      timeLabels: timeLabels,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<CardBubbleChartDisplay> createState() =>
      _CardBubbleChartDisplayState();
}

class _CardBubbleChartDisplayState extends State<CardBubbleChartDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _selectedTab = 1;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.selectedTab;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
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
    final scale = widget.size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : null,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 时间范围选择器
            _buildTabSelector(theme),
            SizedBox(height: widget.size.getTitleSpacing()),
            // 睡眠阶段图表
            _buildChart(theme),
            SizedBox(height: widget.size.getTitleSpacing()),
            // 图例
            _buildLegend(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(AppThemeData theme) {
    final tabs = ['1 Day', '1 Week', '1 Month', '1 Year', 'All Time'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(16),
        fillColor: theme.surfaceAlt,
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                // 选中项：手绘纸底小卡
                decoration: isSelected
                    ? dsSketchDecoration(
                        theme: theme,
                        radius: BorderRadius.circular(12),
                        fillColor: theme.surface,
                      )
                    : null,
                child: Text(
                  tabs[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? theme.text : theme.textSub,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildChart(AppThemeData theme) {
    final chartWidth = 280.0;
    final chartHeight = 200.0;

    return SizedBox(
      height: chartHeight,
      width: chartWidth,
      child: Stack(
        children: [
          // 淡墨网格线
          ...List.generate(5, (index) {
            final x = (chartWidth / 4) * index;
            return Positioned(
              left: x,
              top: 0,
              bottom: 24,
              child: Container(
                width: 1,
                color: theme.ink.withValues(alpha: 0.18),
              ),
            );
          }),
          // 时间标签
          Positioned(
            left: 4,
            right: 4,
            bottom: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: widget.timeLabels.map((time) {
                return Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.textSub,
                  ),
                );
              }).toList(),
            ),
          ),
          // 睡眠阶段气泡
          ...widget.sleepStages.asMap().entries.map((entry) {
            final index = entry.key;
            final stage = entry.value;
            final step = 0.08;
            final start = (index * step).clamp(0.0, 0.92);
            final end = (0.5 + index * step).clamp(0.0, 1.0);

            final itemAnimation = CurvedAnimation(
              parent: _animationController,
              curve: Interval(start, end, curve: Curves.easeOutCubic),
            );

            return _SleepStageBubble(
              stage: stage,
              chartWidth: chartWidth,
              chartHeight: chartHeight - 32,
              animation: itemAnimation,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLegend(AppThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _LegendItem(
          theme: theme,
          color: const Color(0xFF9CB573),
          label: 'Core',
        ),
        _LegendItem(
          theme: theme,
          color: const Color(0xFF8D6E63),
          label: 'REM',
        ),
        _LegendItem(
          theme: theme,
          color: const Color(0xFFF4CD26),
          label: 'Post-REM',
        ),
        _LegendItem(
          theme: theme,
          color: const Color(0xFFC8B6F9),
          label: 'Deep',
        ),
      ],
    );
  }
}

/// 睡眠阶段气泡组件
///
/// 核心视觉保留：数据色圆角气泡 + 错峰生长动画，仅去除柔影。
class _SleepStageBubble extends StatelessWidget {
  final SleepStageData stage;
  final double chartWidth;
  final double chartHeight;
  final Animation<double> animation;

  const _SleepStageBubble({
    required this.stage,
    required this.chartWidth,
    required this.chartHeight,
    required this.animation,
  });

  Color _getColor() {
    switch (stage.type) {
      case SleepStageType.core:
        return const Color(0xFF9CB573);
      case SleepStageType.rem:
        return const Color(0xFFE99547);
      case SleepStageType.postREM:
        return const Color(0xFFF4CD26);
      case SleepStageType.deep:
        return const Color(0xFFC8B6F9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final width = (chartWidth * stage.widthPercent / 100) * animation.value;
        final height = stage.height * animation.value;

        return Positioned(
          left: (chartWidth * stage.left / 100),
          top: (chartHeight * stage.topPercent / 100),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(width / 2),
            ),
          ),
        );
      },
    );
  }
}

/// 图例项组件（数据色手绘色块 + 标签）
class _LegendItem extends StatelessWidget {
  final AppThemeData theme;
  final Color color;
  final String label;

  const _LegendItem({
    required this.theme,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(6),
            fillColor: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.text,
          ),
        ),
      ],
    );
  }
}
