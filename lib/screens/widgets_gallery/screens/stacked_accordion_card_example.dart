import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/stacked_accordion_card.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 堆叠手风琴卡片示例
///
/// 演示各尺寸下的堆叠卡片组：点击卡片展开（手风琴互斥），
/// 进度条生长与条目交错渐入。数据用 static final（热重载生效）。
class StackedAccordionCardExample extends StatelessWidget {
  const StackedAccordionCardExample({super.key});

  /// 与参考 HTML 一致的演示数据
  static final List<StackedAccordionCardData> _demoItems = [
    ...kStackedAccordionDemoItems,
  ];

  /// 中文演示数据（展示自定义配色与长文本）
  static final List<StackedAccordionCardData> _zhItems = [
    StackedAccordionCardData(
      title: '日常开销',
      percentage: '¥1,280.50',
      tags: ['本月', '32 笔'],
      progress: 0.64,
      progressLabel: '预算使用',
      progressValue: '支出 ¥1280 / 预算 ¥2000',
      entries: [
        StackedAccordionEntryData(term: '餐饮', subtitle: '10/12 · -¥286.00'),
        StackedAccordionEntryData(term: '交通', subtitle: '10/11 · -¥56.50'),
        StackedAccordionEntryData(term: '房租', subtitle: '10/01 · -¥850.00'),
        StackedAccordionEntryData(term: '工资', subtitle: '10/01 · +¥8600.00'),
      ],
      backgroundColor: const Color(0xFF3B50D6),
    ),
    StackedAccordionCardData(
      title: '储蓄账户',
      percentage: '¥23,600.00',
      tags: ['固定存款'],
      progress: 0.79,
      progressLabel: '年度目标',
      progressValue: '已存 ¥23600 / 目标 ¥30000',
      entries: [
        StackedAccordionEntryData(term: '自动转入', subtitle: '10/15 · +¥2000.00'),
        StackedAccordionEntryData(term: '利息', subtitle: '10/01 · +¥38.20'),
      ],
      backgroundColor: const Color(0xFFDCFA76),
    ),
    StackedAccordionCardData(
      title: '信用卡',
      percentage: '-¥1,024.00',
      tags: ['待还款', '6 笔'],
      progress: 0.34,
      progressLabel: '额度使用',
      progressValue: '已用 ¥1024 / 额度 ¥3000',
      entries: [
        StackedAccordionEntryData(term: '购物', subtitle: '10/14 · -¥599.00'),
        StackedAccordionEntryData(term: '订阅服务', subtitle: '10/13 · -¥68.00'),
        StackedAccordionEntryData(term: '外卖', subtitle: '10/12 · -¥357.00'),
      ],
      backgroundColor: const Color(0xFFEC582A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('堆叠手风琴卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('标准尺寸（Large3Size，点击展开，手风琴互斥）'),
              const SizedBox(height: 8),
              Center(
                child: StackedAccordionCardWidget(
                  items: _demoItems,
                  size: const Large3Size(),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('中文数据（自定义配色，亮底/深底自动切换文字色）'),
              const SizedBox(height: 8),
              Center(
                child: StackedAccordionCardWidget(
                  items: _zhItems,
                  initiallyExpandedIndex: 0,
                  size: const Large3Size(),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('宽尺寸（Wide2Size，inline 撑满宽度）'),
              const SizedBox(height: 8),
              StackedAccordionCardWidget(
                items: _demoItems,
                inline: true,
                size: const Wide2Size(),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('小尺寸（SmallSize，紧凑档）'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 210,
                  child: StackedAccordionCardWidget(
                    items: _zhItems,
                    size: const SmallSize(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    );
  }
}
