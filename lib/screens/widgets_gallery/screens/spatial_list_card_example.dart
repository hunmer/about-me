import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/spatial_list_card.dart';

class SpatialListCardExample extends StatelessWidget {
  const SpatialListCardExample({super.key});

  static final _customItems = [
    const SpatialListItemData(
      kind: SpatialListItemKind.note,
      width: 158,
      height: 156,
      collapsedOffset: Offset(2, 16),
      expandedOffset: Offset(-4, 56),
      collapsedScale: 0.76,
      expandedScale: 1.03,
      angle: -6,
    ),
    ...SpatialListCardWidget.defaultItems.where(
      (item) => item.kind != SpatialListItemKind.note,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('空间清单卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('默认清单（点击标题或画布展开，展开后可拖动）'),
              const SizedBox(height: 8),
              const Center(child: SpatialListCardWidget()),
              const SizedBox(height: 24),
              _buildSectionTitle('自定义内容与初始展开'),
              const SizedBox(height: 8),
              Center(
                child: SpatialListCardWidget(
                  title: 'Weekly Market',
                  subtitle: 'Fresh ingredients for the week',
                  updatedLabel: 'Just now',
                  itemCount: 8,
                  noteTitle: 'Shopping note',
                  noteAuthor: 'Alex',
                  noteContent:
                      'Choose seasonal vegetables and remember the sparkling water.',
                  items: _customItems,
                  initialExpanded: true,
                  size: const Large3Size(),
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
