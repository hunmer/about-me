import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

void main() {
  testWidgets('debug 布局结构', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed:
                    () => SmoothBottomSheet.showForm<void>(
                      context: context,
                      title: 'Test Sheet',
                      child: const SizedBox(
                        width: 300,
                        height: 120,
                        child: Text('form-body'),
                      ),
                      onSave: () {},
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.text('form-body'));
    // ignore: avoid_print
    print('FORM_BODY_RECT: $rect');
    final sheetRect = tester.getRect(find.text('Test Sheet'));
    // ignore: avoid_print
    print('SHEET_RECT: $sheetRect');
  });
}
