import 'package:aboutme/screens/route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup replacement is the root and detail swipe still works', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: ThemeData(platform: TargetPlatform.iOS),
        initialRoute: AppRoutes.startup,
        onGenerateInitialRoutes: AppRoutes.generateInitialRoutes,
        routes: AppRoutes.routes,
        onGenerateRoute: AppRoutes.generateRoute,
      ),
    );
    await tester.pump();

    // 启动分流前就必须是单页栈，不能创建隐藏的旧首页。
    expect(navigatorKey.currentState!.canPop(), isFalse);

    navigatorKey.currentState!.pushReplacement(
      CupertinoPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.jellyHome),
        builder: (_) => const Scaffold(body: Text('home')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(5, 300), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isFalse);

    // 详情页仍然能够通过 iOS 手势返回首页。
    navigatorKey.currentState!.push(
      CupertinoPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('detail')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    await tester.dragFrom(const Offset(5, 300), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('detail'), findsNothing);
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });
}
