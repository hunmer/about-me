import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/screens/onboarding/plugin_onboarding_screen.dart';
import 'package:aboutme/screens/startup/startup_gate.dart';
import 'package:aboutme/screens/route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _OnboardingPlugin extends PluginBase {
  @override
  String get id => 'startup_onboarding_regression';

  @override
  Future<void> initialize() async {}

  @override
  Widget buildMainView(BuildContext context) =>
      const Scaffold(body: Text('new plugin'));

  @override
  List<PluginOnboardingStep> getOnboardingSteps(BuildContext context) => const [
    PluginOnboardingStep(
      title: 'plugin setup',
      description: 'setup description',
    ),
  ];
}

void main() {
  testWidgets('恢复插件被替换后，关闭首次引导并返回不会停留在启动页', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    var homeBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [RouteHistoryManager.instance],
        initialRoute: AppRoutes.startup,
        onGenerateInitialRoutes: (initialRoute) => [
          MaterialPageRoute<void>(
            settings: RouteSettings(name: initialRoute),
            builder: (_) => const StartupGate(),
          ),
        ],
        routes: {
          AppRoutes.jellyHome: (_) {
            homeBuilds++;
            return const Scaffold(body: Text('home'));
          },
        },
      ),
    );
    await tester.pump();

    // 模拟启动恢复的插件；切换插件时，该路由会被移除。
    NavigationHelper.push(
      navigatorKey.currentContext!,
      const Scaffold(body: Text('restored plugin')),
      routeName: '/plugin/restored',
    );
    await tester.pumpAndSettle();
    PluginManager.instance.openPlugin(
      navigatorKey.currentContext!,
      _OnboardingPlugin(),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PluginOnboardingScreen), findsOneWidget);
    expect(find.text('restored plugin'), findsNothing);
    expect(homeBuilds, 0);

    // 关闭引导仍停在插件，随后返回才创建首页。
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('new plugin'), findsOneWidget);
    expect(homeBuilds, 0);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.byType(StartupGate), findsNothing);
    expect(navigatorKey.currentState!.canPop(), isFalse);
    expect(homeBuilds, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
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
