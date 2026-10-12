import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/plugins/checkin/controllers/checkin_list_controller.dart';
import 'package:aboutme/plugins/checkin/models/checkin_item.dart';
import 'checkin_item_card.dart';

class CheckinItemList extends StatelessWidget {
  final List<CheckinItem> items;
  final String group;
  final int groupIndex;
  final CheckinListController controller;
  final VoidCallback onStateChanged;

  const CheckinItemList({
    super.key,
    required this.items,
    required this.group,
    required this.groupIndex,
    required this.controller,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false, // 禁用默认拖拽手柄
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) {

      },
      itemBuilder: (context, index) {
        final item = items[index];
        final itemIndex = controller.checkinItems.indexOf(item);

        // key 必须在列表直接子级（WiredDraw）上；挂载即描画入场
        return WiredDraw(
          key: ValueKey('item_${item.id}_$index'),
          child: CheckinItemCard(
            item: item,
            index: index,
            itemIndex: itemIndex,
            controller: controller,
            onStateChanged: onStateChanged,
          ),
        );
      },
    );
  }
}