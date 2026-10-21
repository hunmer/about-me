import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/main.dart' show WidgetUriHandler;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('widget URI loading preserves the navigator and its routes', (
    tester,
  ) async {
    final startup = AppStartupState.instance;
    final navigatorKey = GlobalKey<NavigatorState>();
    addTearDown(startup.clearInitialWidgetUri);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (_, child) => WidgetUriHandler(child: child!),
        home: const Scaffold(body: Text('home')),
      ),
    );
    final navigator = navigatorKey.currentState!;
    startup.setInitialWidgetUri(Uri.parse('aboutme://task'));
    await tester.pump();
    expect(navigatorKey.currentState, same(navigator));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('widget target')),
      ),
    );
    await tester.pump();
    startup.clearInitialWidgetUri();
    await tester.pumpAndSettle();
    expect(navigatorKey.currentState, same(navigator));
    expect(navigator.canPop(), isTrue);
    expect(find.text('widget target'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
