import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/spatial_list_card.dart';

void main() {
  testWidgets('空间清单卡片支持折叠、展开、拖动和复位', (tester) async {
    bool? expanded;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SpatialListCardWidget(
              onExpandedChanged: (value) => expanded = value,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('spatial_list_card'))).height,
      204,
    );
    await tester.tap(find.byKey(const Key('spatial_list_header')));
    await tester.pumpAndSettle();
    expect(expanded, isTrue);
    expect(
      tester.getSize(find.byKey(const Key('spatial_list_card'))).height,
      438,
    );

    await tester.drag(
      find.byKey(const Key('spatial_list_canvas')),
      const Offset(-100, 0),
    );
    await tester.pump();
    final viewport = tester.widget<Transform>(
      find.byKey(const Key('spatial_list_minimap_viewport')),
    );
    expect(viewport.transform.getTranslation().x, 9);

    await tester.tap(find.byKey(const Key('spatial_list_header')));
    await tester.pumpAndSettle();
    expect(expanded, isFalse);
    expect(
      tester.getSize(find.byKey(const Key('spatial_list_card'))).height,
      204,
    );
  });

  test('fromProps 解析通用配置和默认尺寸', () {
    final widget = SpatialListCardWidget.fromProps(const {
      'title': 'Groceries',
      'itemCount': 3,
      'initialExpanded': true,
      'items': [
        {
          'kind': 'custom',
          'svg': '<svg xmlns="http://www.w3.org/2000/svg"/>',
          'quantity': 2,
          'width': 80,
          'height': 90,
          'collapsedOffset': [0, 10],
          'expandedOffset': [20, 30],
        },
      ],
    }, const Large3Size());

    expect(widget.title, 'Groceries');
    expect(widget.itemCount, 3);
    expect(widget.initialExpanded, isTrue);
    expect(widget.items.single.quantity, 2);
    expect(widget.items.single.expandedOffset, const Offset(20, 30));
    expect(widget.size, isA<Large3Size>());
  });
}
