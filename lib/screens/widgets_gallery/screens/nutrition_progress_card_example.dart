import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/split_column_progress_bar_card.dart';

/// 营养进度卡片示例
class NutritionProgressCardExample extends StatelessWidget {
  const NutritionProgressCardExample({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('营养进度卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('小尺寸'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: SplitColumnProgressBarCard(
                      size: const SmallSize(),
                      leftData: ColumnProgressData(current: 470, total: 1830, unit: 'Cal'),
                      leftConfig: LeftSectionConfig(
                        icon: '🔥',
                        label: 'Calories',
                      ),
                      rightItems: [
                        ProgressItemData(
                          icon: '🍔',
                          name: 'Protein',
                          current: 66,
                          total: 94,
                          color: const Color(0xFF34D399),
                          subtitle: '早餐 / 午餐',
                        ),
                        ProgressItemData(
                          icon: '🍉',
                          name: 'Carbs',
                          current: 35,
                          total: 64,
                          color: const Color(0xFFFED7AA),
                          subtitle: '全麦面包',
                        ),
                        ProgressItemData(
                          icon: '🥛',
                          name: 'Fats',
                          current: 21,
                          total: 32,
                          color: const Color(0xFF3B82F6),
                          subtitle: '坚果 / 鳄梨',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('中尺寸'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: SplitColumnProgressBarCard(
                      size: const MediumSize(),
                      leftData: ColumnProgressData(current: 470, total: 1830, unit: 'Cal'),
                      leftConfig: LeftSectionConfig(
                        icon: '🔥',
                        label: 'Calories',
                      ),
                      rightItems: [
                        ProgressItemData(
                          icon: '🍔',
                          name: 'Protein',
                          current: 66,
                          total: 94,
                          color: const Color(0xFF34D399),
                          subtitle: '早餐 / 午餐',
                        ),
                        ProgressItemData(
                          icon: '🍉',
                          name: 'Carbs',
                          current: 35,
                          total: 64,
                          color: const Color(0xFFFED7AA),
                          subtitle: '全麦面包',
                        ),
                        ProgressItemData(
                          icon: '🥛',
                          name: 'Fats',
                          current: 21,
                          total: 32,
                          color: const Color(0xFF3B82F6),
                          subtitle: '坚果 / 鳄梨',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大尺寸'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: SplitColumnProgressBarCard(
                      size: const LargeSize(),
                      leftData: ColumnProgressData(current: 470, total: 1830, unit: 'Cal'),
                      leftConfig: LeftSectionConfig(
                        icon: '🔥',
                        label: 'Calories',
                      ),
                      rightItems: [
                        ProgressItemData(
                          icon: '🍔',
                          name: 'Protein',
                          current: 66,
                          total: 94,
                          color: const Color(0xFF34D399),
                          subtitle: '早餐 / 午餐',
                        ),
                        ProgressItemData(
                          icon: '🍉',
                          name: 'Carbs',
                          current: 35,
                          total: 64,
                          color: const Color(0xFFFED7AA),
                          subtitle: '全麦面包',
                        ),
                        ProgressItemData(
                          icon: '🥛',
                          name: 'Fats',
                          current: 21,
                          total: 32,
                          color: const Color(0xFF3B82F6),
                          subtitle: '坚果 / 鳄梨',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('中宽尺寸 (4x1)'),
                const SizedBox(height: 8),
                SizedBox(
                  width: MediaQuery.of(context).size.width - 32,
                  height: 280,
                  child: SplitColumnProgressBarCard(
                    size: const WideSize(),
                    leftData: ColumnProgressData(current: 470, total: 1830, unit: 'Cal'),
                    leftConfig: LeftSectionConfig(
                      icon: '🔥',
                      label: 'Calories',
                    ),
                    rightItems: [
                      ProgressItemData(
                        icon: '🍔',
                        name: 'Protein',
                        current: 66,
                        total: 94,
                        color: const Color(0xFF34D399),
                        subtitle: '早餐 / 午餐',
                      ),
                      ProgressItemData(
                        icon: '🍉',
                        name: 'Carbs',
                        current: 35,
                        total: 64,
                        color: const Color(0xFFFED7AA),
                        subtitle: '全麦面包',
                      ),
                      ProgressItemData(
                        icon: '🥛',
                        name: 'Fats',
                        current: 21,
                        total: 32,
                        color: const Color(0xFF3B82F6),
                        subtitle: '坚果 / 鳄梨',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大宽尺寸 (4x2)'),
                const SizedBox(height: 8),
                SizedBox(
                  width: MediaQuery.of(context).size.width - 32,
                  height: 350,
                  child: SplitColumnProgressBarCard(
                    size: const Wide2Size(),
                    leftData: ColumnProgressData(current: 470, total: 1830, unit: 'Cal'),
                    leftConfig: LeftSectionConfig(
                      icon: '🔥',
                      label: 'Calories',
                    ),
                    rightItems: [
                      ProgressItemData(
                        icon: '🍔',
                        name: 'Protein',
                        current: 66,
                        total: 94,
                        color: const Color(0xFF34D399),
                        subtitle: '早餐 / 午餐',
                      ),
                      ProgressItemData(
                        icon: '🍉',
                        name: 'Carbs',
                        current: 35,
                        total: 64,
                        color: const Color(0xFFFED7AA),
                        subtitle: '全麦面包',
                      ),
                      ProgressItemData(
                        icon: '🥛',
                        name: 'Fats',
                        current: 21,
                        total: 32,
                        color: const Color(0xFF3B82F6),
                        subtitle: '坚果 / 鳄梨',
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
