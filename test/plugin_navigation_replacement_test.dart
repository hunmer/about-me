import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/screens/routing/route_helpers.dart';

class _RouteLabel extends StatelessWidget {
  const _RouteLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Text(label));
  }
}

void main() {
  testWidgets('清理插件栈时保留首页并保留目标路由名', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        initialRoute: '/jelly_home',
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => _RouteLabel(settings.name ?? 'unknown'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/plugin/a'),
        builder: (_) => const _RouteLabel('A'),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/plugin/a/details'),
        builder: (_) => const _RouteLabel('A details'),
      ),
    );
    await tester.pumpAndSettle();

    navigatorKey.currentState!.pushAndRemoveUntil<void>(
      RouteHelpers.createRoute<void>(
        const _RouteLabel('B'),
        settings: const RouteSettings(name: '/plugin/b'),
      ),
      (route) =>
          route.settings.name == '/jelly_home' ||
          (route.settings.name?.startsWith('/jelly_home/') ?? false),
    );
    await tester.pumpAndSettle();

    expect(find.text('B'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    expect(find.text('A details'), findsNothing);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('/jelly_home'), findsOneWidget);
  });
}
