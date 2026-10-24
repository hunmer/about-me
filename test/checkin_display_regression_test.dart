import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/plugins/checkin/controllers/checkin_list_controller.dart';
import 'package:aboutme/plugins/checkin/models/checkin_item.dart';
import 'package:aboutme/plugins/checkin/screens/checkin_list_screen/checkin_list_screen.dart';
import 'package:aboutme/plugins/checkin/screens/checkin_record_screen.dart';
import 'package:aboutme/widgets/common/checkin_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Controller extends CheckinListController {
  _Controller(BuildContext context)
    : super(context: context, onStateChanged: () {});

  List<CheckinItem> items = [];

  @override
  List<CheckinItem> get checkinItems => items;
}

CheckinItem _item(String note) => CheckinItem(
  id: 'water',
  name: '喝水',
  icon: Icons.water_drop,
  checkInRecords: {
    '2026-10-24': [
      CheckinRecord(
        startTime: DateTime(2026, 10, 24, 8),
        endTime: DateTime(2026, 10, 24, 9),
        checkinTime: DateTime(2026, 10, 24, 9),
        note: note,
      ),
    ],
  },
);

void main() {
  test('快速打卡只有 checkinTime 时可加载整批项目和记录', () {
    final json = _item('快速打卡').toJson();
    json['checkInRecords'] = {
      '2026-10-24': [
        {'id': 'quick', 'checkinTime': '2026-10-24T05:11:37.435Z'},
      ],
    };
    final items = [
      _item('完整记录').toJson(),
      json,
    ].map(CheckinItemDto.fromJson).toList();
    final dto = items.last.checkInRecords['2026-10-24']!.single;
    expect(dto.startTime, dto.checkinTime);
    expect(dto.endTime, dto.checkinTime);
    expect(items.first.checkInRecords['2026-10-24']!.single.note, '完整记录');

    final local = CheckinItem.fromJson(
      json,
    ).checkInRecords['2026-10-24']!.single;
    expect(local.checkinTime.isUtc, isFalse);
    expect(local.startTime, dto.checkinTime.toLocal());
    expect(local.endTime, dto.checkinTime.toLocal());
  });

  test('数据接口创建的项目省略图标颜色仍可还原已有记录', () {
    final json = _item('已有记录').toJson()
      ..remove('icon')
      ..remove('color');
    final item = CheckinItemDto.fromJson(json);
    expect(item.icon, 57527);
    expect(item.color, 4280391411);
    expect(item.checkInRecords['2026-10-24']!.single.note, '已有记录');
  });

  testWidgets('列表在项目快照替换后展示最新数据', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late _Controller controller;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            controller = _Controller(context)..items = [_item('旧记录')];
            return CheckinListScreen(controller: controller);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CheckinItemCardWidget), findsOneWidget);

    controller.items = [_item('新记录')];
    EventManager.instance.broadcast('checkin_refresh', EventArgs());
    await tester.pumpAndSettle();
    final card = tester.widget<CheckinItemCardWidget>(
      find.byType(CheckinItemCardWidget),
    );
    expect(card.item.checkInRecords['2026-10-24']!.single.note, '新记录');
    expect(tester.takeException(), isNull);
  });

  testWidgets('记录页使用最新项目并响应同步和删除', (tester) async {
    late _Controller controller;
    final oldItem = _item('旧记录');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            controller = _Controller(context)..items = [_item('新记录')];
            return CheckinRecordScreen(
              checkinItem: oldItem,
              controller: controller,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('新记录'), findsOneWidget);
    expect(find.text('旧记录'), findsNothing);

    controller.items = [_item('同步记录')];
    EventManager.instance.broadcast('checkin_refresh', EventArgs());
    await tester.pumpAndSettle();
    expect(find.text('同步记录'), findsOneWidget);

    controller.items = [];
    EventManager.instance.broadcast('checkin_refresh', EventArgs());
    await tester.pumpAndSettle();
    expect(find.text('同步记录'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
