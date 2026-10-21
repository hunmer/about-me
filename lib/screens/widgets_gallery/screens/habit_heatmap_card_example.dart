import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/habit_heatmap_card.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 习惯打卡热力图卡片示例
class HabitHeatmapCardExample extends StatelessWidget {
  const HabitHeatmapCardExample({super.key});

  // 演示数据用 static final（static const 热重载不生效）
  static final _drinkWaterCells = [
    [2, 0, 2, 2, 0, 3, 3, 0, 0, 0],
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 4],
    [3, 1, 2, 3, 0, 3, 3, 3, 0, 0],
    [1, 2, 0, 0, 1, 1, 2, 3, 0, 0],
    [2, 0, 3, 1, 3, 2, 1, 3, 3, 0],
    [0, 0, 0, 1, 0, 0, 0, 1, 0, 0],
    [0, 1, 0, 3, 2, 2, 0, 3, 3, 0],
  ];

  static final _journalingCells = [
    [3, 2, 0, 3, 0, 0, 3, 0, 0, 3],
    [3, 2, 0, 3, 1, 2, 2, 3, 2, 2],
    [3, 3, 2, 3, 3, 2, 3, 2, 1, 0],
    [3, 0, 2, 0, 3, 3, 1, 1, 2, 0],
    [0, 1, 1, 0, 0, 0, 0, 1, 0, 0],
    [3, 2, 2, 1, 0, 0, 3, 2, 1, 0],
    [1, 0, 0, 0, 0, 3, 3, 1, 2, 0],
  ];

  static final _playDogCells = [
    [0, 3, 2, 1, 3, 0, 3, 2, 2, 1],
    [3, 1, 0, 2, 3, 3, 3, 2, 1, 1],
    [0, 3, 2, 0, 0, 0, 0, 0, 0, 0],
    [1, 0, 3, 2, 0, 1, 0, 1, 0, 0],
    [0, 3, 3, 1, 1, 2, 1, 3, 0, 0],
    [0, 0, 1, 2, 1, 2, 1, 0, 0, 0],
    [3, 0, 2, 2, 1, 2, 0, 0, 1, 0],
  ];

  static final _readCells = [
    [2, 3, 1, 0, 2, 0, 2, 0, 1, 2],
    [2, 0, 0, 0, 0, 3, 0, 0, 3, 2],
    [1, 0, 2, 0, 2, 2, 2, 2, 1, 0],
    [1, 0, 0, 1, 1, 0, 3, 1, 3, 0],
    [0, 2, 0, 1, 3, 0, 0, 0, 1, 0],
    [0, 0, 0, 1, 2, 3, 0, 1, 1, 0],
    [0, 2, 0, 0, 3, 1, 0, 0, 3, 0],
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('习惯打卡热力图卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('蓝紫主题（未打卡 Check-In）'),
                const SizedBox(height: 8),
                Center(
                  child: HabitHeatmapCard(
                    title: 'Drink water',
                    icon: Icons.water_drop,
                    cells: _drinkWaterCells,
                    checkInCount: 0,
                    theme: HabitHeatmapTheme.drinkWater,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('绿色主题（已打卡 x1）'),
                const SizedBox(height: 8),
                Center(
                  child: HabitHeatmapCard(
                    title: 'Journaling',
                    icon: Icons.edit_note,
                    cells: _journalingCells,
                    checkInCount: 1,
                    theme: HabitHeatmapTheme.journaling,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('黄色主题（已打卡 x2）'),
                const SizedBox(height: 8),
                Center(
                  child: HabitHeatmapCard(
                    title: 'Play dog',
                    icon: Icons.pets,
                    cells: _playDogCells,
                    checkInCount: 2,
                    theme: HabitHeatmapTheme.playDog,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('橙色主题（已打卡 x3）'),
                const SizedBox(height: 8),
                Center(
                  child: HabitHeatmapCard(
                    title: 'Read',
                    icon: Icons.menu_book,
                    cells: _readCells,
                    checkInCount: 3,
                    theme: HabitHeatmapTheme.read,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('小尺寸（仅热力图）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: HabitHeatmapCard(
                      title: 'Drink water',
                      icon: Icons.water_drop,
                      cells: _drinkWaterCells,
                      checkInCount: 1,
                      theme: HabitHeatmapTheme.drinkWater,
                      size: const SmallSize(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('宽条尺寸（图左文右）'),
                const SizedBox(height: 8),
                Center(
                  child: HabitHeatmapCard(
                    title: 'Read',
                    icon: Icons.menu_book,
                    cells: _readCells,
                    checkInCount: 1,
                    theme: HabitHeatmapTheme.read,
                    size: const Wide2Size(),
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
