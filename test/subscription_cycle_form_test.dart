import 'package:aboutme/widgets/form_fields/index.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cycle callback patches the visible wrapped date field', (
    tester,
  ) async {
    late FormBuilderWrapperState form;
    final startDate = DateTime(2026, 1, 1);
    final callbacks = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DSThemeBridge(child: child!),
        home: Scaffold(
          body: FormBuilderWrapper(
            onStateReady: (state) => form = state,
            config: FormConfig(
              showSubmitButton: false,
              onSubmit: (_) async {},
              fields: [
                FormFieldConfig(
                  name: 'endDate',
                  type: FormFieldType.date,
                ),
                FormFieldConfig(
                  name: 'days',
                  type: FormFieldType.subscriptionCycle,
                  initialValue: 30,
                  extra: {
                    'quarterlyLabel': 'Quarterly',
                    'yearlyLabel': 'Yearly',
                  },
                  onChanged: (value) {
                    callbacks.add(value as int);
                    form.patchValue({
                      'endDate': startDate.add(Duration(days: value)),
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Quarterly'));
    await tester.pump();
    expect(callbacks, [90]);
    expect(form.currentValues['endDate'], DateTime(2026, 4, 1));
    expect(find.text('2026-04-01'), findsOneWidget);

    await tester.tap(find.text('Yearly'));
    await tester.pump();
    expect(callbacks, [90, 365]);
    expect(form.currentValues['endDate'], DateTime(2027, 1, 1));
    expect(find.text('2027-01-01'), findsOneWidget);
  });
}
