import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/linked_task_flow_card.dart';

/// 连线任务流卡片示例
class LinkedTaskFlowCardExample extends StatelessWidget {
  LinkedTaskFlowCardExample({super.key});

  // 演示数据用 static final（static const 热重载不生效）
  static final _items = [
    LinkedTaskItemData(
      title: 'Visual Design',
      assignee: 'Mike',
      progress: 30,
      avatarColor: Color(0xFF4A90D9),
    ),
    LinkedTaskItemData(
      title: 'Frontend Admin',
      assignee: 'Ellizabeth',
      progress: 40,
      avatarColor: Color(0xFFD99B16),
    ),
    LinkedTaskItemData(
      title: 'Backend Develop',
      assignee: 'Alex',
      progress: 10,
      avatarColor: Color(0xFF29B6F6),
    ),
  ];

  static final _purpleItems = [
    LinkedTaskItemData(title: 'Product Research', assignee: 'Sophia', progress: 65),
    LinkedTaskItemData(title: 'UX Prototype', assignee: 'James', progress: 35),
    LinkedTaskItemData(title: 'Data Pipeline', assignee: 'Liam', progress: 80),
    LinkedTaskItemData(title: 'Release Notes', assignee: 'Olivia', progress: 20),
  ];

  final _defaultKey = GlobalKey();
  final _purpleKey = GlobalKey();
  final _inlineKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('连线任务流卡片')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          for (final key in [_defaultKey, _purpleKey, _inlineKey]) {
            LinkedTaskFlowCardWidget.replayOf(key);
          }
        },
        icon: const Icon(Icons.replay),
        label: const Text('重播动画'),
      ),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('默认主题（参考效果图，可点击卡片）'),
              const SizedBox(height: 8),
              Center(
                child: LinkedTaskFlowCardWidget(
                  key: _defaultKey,
                  items: _items,
                  onItemTap: (i) => debugPrint('点击任务 $i'),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('自定义配色（紫色 + 关闭斜纹 + 4 条任务）'),
              const SizedBox(height: 8),
              Center(
                child: LinkedTaskFlowCardWidget(
                  key: _purpleKey,
                  items: _purpleItems,
                  backgroundFrom: const Color(0xFF8B5CF6),
                  backgroundTo: const Color(0xFF7C3AED),
                  cardColor: const Color(0xFFD8B4FE),
                  showStripes: false,
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('内联窄容器（按宽度自适应缩放）'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 300,
                  height: 340,
                  child: LinkedTaskFlowCardWidget(
                    key: _inlineKey,
                    items: _items,
                    inline: true,
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
