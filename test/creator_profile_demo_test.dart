import 'package:aboutme/widgets/creator_profile_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creator profile supports follow, like, tabs and scroll reset', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: CreatorProfileDemo()));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('@popelz'), findsOneWidget);
    expect(find.text('282'), findsOneWidget);

    await tester.tap(find.text('282'));
    await tester.pump();
    expect(find.text('283'), findsOneWidget);

    await tester.tap(find.text('Follow on'));
    await tester.pump();
    expect(find.text('Following on'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Follow on'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('creator_profile_tab_0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('131.4K'), findsOneWidget);

    final scrollView = find.byType(CustomScrollView);
    await tester.drag(scrollView, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('creator_profile_tab_2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Autumn capsule wardrobe'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
  });
}
