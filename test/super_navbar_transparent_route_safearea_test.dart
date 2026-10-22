import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_cupertino_navigation_bar/super_cupertino_navigation_bar.dart';

void main() {
  for (final opaque in [true, false]) {
    testWidgets('全屏页面 opaque=$opaque 保留状态栏安全区', (tester) async {
      tester.view.padding = const FakeViewPadding(top: 72);
      tester.view.viewPadding = const FakeViewPadding(top: 72);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(),
      ));
      navigatorKey.currentState!.push(PageRouteBuilder<void>(
        opaque: opaque,
        pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
          body: SuperScaffold(
            transitionBetweenRoutes: false,
            forceCollapsed: true,
            appBar: SuperAppBar(
              title: const Text('安全区标题'),
              alwaysShowTitle: true,
              largeTitle: SuperLargeTitle(enabled: false, largeTitle: '标题'),
              searchBar: SuperSearchBar(enabled: false),
            ),
            body: const SizedBox(),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('安全区标题')).dy,
          greaterThanOrEqualTo(72));
    });
  }
}
