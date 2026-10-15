import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

void main() {
  testWidgets('showDSToast 最小复现', (tester) async {
    await tester.pumpWidget(
      DSThemeBridge(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showDSToast(context, message: 'hi'),
                child: const Text('toast'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('toast'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('hi'), findsOneWidget);
  });
}
