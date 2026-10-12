import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skribble/skribble.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: Center(child: child)),
        ),
      );

  testWidgets('WiredDialog', (t) async {
    await t.pumpWidget(wrap(const WiredDialog(child: Text('d'))));
    await t.pump();
    expect(t.takeException(), isNull);
  });
  testWidgets('WiredBadge', (t) async {
    await t.pumpWidget(wrap(const WiredBadge(label: '3', child: Icon(Icons.mail))));
    await t.pump();
    expect(t.takeException(), isNull);
  });
  testWidgets('WiredTooltip', (t) async {
    await t.pumpWidget(wrap(const WiredTooltip(message: 'm', child: Icon(Icons.help))));
    await t.pump();
    expect(t.takeException(), isNull);
  });
  testWidgets('WiredProgress value', (t) async {
    await t.pumpWidget(wrap(const SizedBox(width: 300, child: WiredProgress(value: 0.5))));
    await t.pump();
    expect(t.takeException(), isNull);
  });
  testWidgets('WiredProgress indeterminate', (t) async {
    await t.pumpWidget(wrap(const SizedBox(width: 300, child: WiredProgress())));
    await t.pump();
    expect(t.takeException(), isNull);
  });
  testWidgets('WiredCircularProgress', (t) async {
    await t.pumpWidget(wrap(const WiredCircularProgress(value: 0.5)));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
