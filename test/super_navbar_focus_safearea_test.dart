// 按 app 内 SuperCupertinoNavigationWrapper 的真实结构复现:
// Scaffold(默认 resizeToAvoidBottomInset) > SuperScaffold(pinned 搜索)
// 聚焦收缩动画完成后,搜索框顶部应仍处于状态栏安全区(padding.top)之下。
import 'package:flutter/cupertino.dart' show CupertinoSearchTextField;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_cupertino_navigation_bar/super_cupertino_navigation_bar.dart';
import 'package:super_cupertino_navigation_bar/utils/store.dart';

void main() {
  setUp(() {
    Store.instance.searchBarHasFocus.value = false;
    Store.instance.searchBarResultVisible.value = false;
    Store.instance.searchBarAnimationStatus.value =
        SearchBarAnimationStatus.paused;
    Store.instance.scrollOffset.value = 0;
  });

  Future<void> pumpScene(
    WidgetTester tester, {
    required FocusNode focusNode,
    double keyboard = 0,
    double topInset = 100,
    bool enableLargeTitle = true,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          padding: EdgeInsets.only(top: topInset),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: Scaffold(
          body: SuperScaffold(
            appBar: SuperAppBar(
              largeTitle: SuperLargeTitle(
                enabled: enableLargeTitle,
                largeTitle: 'T',
              ),
              searchBar: SuperSearchBar(
                searchFocusNode: focusNode,
                height: 44,
                scrollBehavior: SearchBarScrollBehavior.pinned,
                resultBehavior: SearchBarResultBehavior.neverVisible,
              ),
            ),
            body: const SizedBox(),
          ),
        ),
      ),
    ));
  }

  Future<double> searchFieldTop(WidgetTester tester) =>
      Future.value(tester.getTopLeft(find.byType(CupertinoSearchTextField).first).dy);

  testWidgets('Scaffold+pinned:聚焦收缩后搜索框在安全边距下', (tester) async {
    const topInset = 100.0;
    final focusNode = FocusNode();
    await pumpScene(tester, focusNode: focusNode);
    await tester.pumpAndSettle();

    focusNode.requestFocus();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    final top = await searchFieldTop(tester);
    expect(top, closeTo(topInset + 8, 1.0),
      reason: '聚焦收缩后搜索框顶部应为 $topInset+8,实际 $top',
    );
  });

  testWidgets('Scaffold+pinned:聚焦后键盘弹出仍保持安全边距', (tester) async {
    const topInset = 100.0;
    final focusNode = FocusNode();
    await pumpScene(tester, focusNode: focusNode);
    await tester.pumpAndSettle();

    focusNode.requestFocus();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    // 键盘弹出(Scaffold resize 重建)
    await pumpScene(tester, focusNode: focusNode, keyboard: 300);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    final top = await searchFieldTop(tester);
    expect(top, closeTo(topInset + 8, 1.0),
      reason: '键盘弹出后搜索框顶部应为 $topInset+8,实际 $top',
    );
  });

  testWidgets('Scaffold+pinned+无大标题:聚焦收缩后仍在安全边距下',
      (tester) async {
    const topInset = 100.0;
    final focusNode = FocusNode();
    await pumpScene(tester, focusNode: focusNode, enableLargeTitle: false);
    await tester.pumpAndSettle();

    focusNode.requestFocus();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    final top = await searchFieldTop(tester);
    expect(top, closeTo(topInset + 8, 1.0),
      reason: '聚焦收缩后搜索框顶部应为 $topInset+8,实际 $top',
    );
  });
}
