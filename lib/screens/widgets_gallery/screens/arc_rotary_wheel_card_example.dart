import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/arc_rotary_wheel_card.dart';

/// 弧形圆盘选择卡片示例（单一默认尺寸）
class ArcRotaryWheelCardExample extends StatefulWidget {
  const ArcRotaryWheelCardExample({super.key});

  @override
  State<ArcRotaryWheelCardExample> createState() =>
      _ArcRotaryWheelCardExampleState();
}

class _ArcRotaryWheelCardExampleState extends State<ArcRotaryWheelCardExample> {
  /// 演示数据不用 static const（热重载不生效，见 handoff 坑 3）
  static final List<ArcWheelItemData> _workoutItems = [
    ArcWheelItemData(
      id: 'running',
      label: '跑步',
      icon: Icons.directions_run,
      color: Color(0xFF7BDCC5),
      value: 'running',
    ),
    ArcWheelItemData(
      id: 'sleep',
      label: '睡眠',
      icon: Icons.bedtime,
      color: Color(0xFF6094EA),
      value: 'sleep',
    ),
    ArcWheelItemData(
      id: 'skipping',
      label: '跳绳',
      icon: Icons.loop,
      color: Color(0xFFEB805D),
      value: 'skipping',
    ),
    ArcWheelItemData(
      id: 'power-training',
      label: '力量训练',
      icon: Icons.fitness_center,
      color: Color(0xFFE35D54),
      value: 'power-training',
    ),
    ArcWheelItemData(
      id: 'cycling',
      label: '骑行',
      icon: Icons.directions_bike,
      color: Color(0xFFD467C1),
      value: 'cycling',
    ),
    ArcWheelItemData(
      id: 'swimming',
      label: '游泳',
      icon: Icons.pool,
      color: Color(0xFF6BB4F6),
      value: 'swimming',
    ),
    ArcWheelItemData(
      id: 'tennis',
      label: '网球',
      icon: Icons.sports_tennis,
      color: Color(0xFFF1C045),
      value: 'tennis',
    ),
    ArcWheelItemData(
      id: 'basketball',
      label: '篮球',
      icon: Icons.sports_basketball,
      color: Color(0xFFB3B0EA),
      value: 'basketball',
    ),
    ArcWheelItemData(
      id: 'yoga',
      label: '瑜伽',
      icon: Icons.self_improvement,
      color: Color(0xFF5BC1A5),
      value: 'yoga',
    ),
  ];

  int _selected = 4;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('弧形圆盘选择卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('默认尺寸（唯一尺寸）'),
                const SizedBox(height: 8),
                Center(
                  child: ArcRotaryWheelCardWidget(
                    title: '今日运动',
                    items: _workoutItems,
                    initialIndex: _selected,
                    onSelect: (index) {
                      if (mounted) setState(() => _selected = index);
                    },
                    onItemTap: (index) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '点击打开：${_workoutItems[index].label}',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '当前选中：${_workoutItems[_selected].label}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('说明'),
                const SizedBox(height: 8),
                Text(
                  '选项沿右侧大圆弧排布，拖拽 / 甩动 / 滚轮 / 点击选择，'
                  '弹簧吸附到最近档位；圆弧轨道与指针由 skribble 手绘。'
                  '该组件仅提供一个默认尺寸（2x3），宽度自适应等比缩放。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: isDark ? Colors.white54 : Colors.black45,
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
