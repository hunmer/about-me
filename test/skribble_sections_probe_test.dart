import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/design_system_gallery/sections/skribble_controls_section.dart';
import 'package:aboutme/screens/design_system_gallery/sections/skribble_data_section.dart';
import 'package:aboutme/screens/design_system_gallery/sections/skribble_feedback_section.dart';
import 'package:aboutme/screens/design_system_gallery/sections/skribble_inputs_section.dart';

void main() {
  Widget wrap(Widget child) => AppTheme(
        data: AppThemeData.light(),
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
      );

  testWidgets('SK-1 controls', (tester) async {
    await tester.pumpWidget(wrap(const SkribbleControlsSection()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('SK-2 inputs', (tester) async {
    await tester.pumpWidget(wrap(const SkribbleInputsSection()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('SK-3 feedback', (tester) async {
    await tester.pumpWidget(wrap(const SkribbleFeedbackSection()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('SK-4 data', (tester) async {
    await tester.pumpWidget(wrap(const SkribbleDataSection()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
