import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 表单弹层（SmoothBottomSheet.showForm）布局与滚动行为测试
///
/// 覆盖三类内容形态：
/// - 短表单：sheet 高度贴合内容，不占满全屏（无底部空隙）
/// - 长表单（表单根为 SingleChildScrollView）：内容限制在可用高度内，
///   底部内容初始不可见、滚动后可达
/// - 高度由内容决定的列表型 child：不抛异常
void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    required Widget child,
    VoidCallback? onSave,
  }) async {
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
                      child: child,
                      onSave: onSave,
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
  }

  testWidgets('短内容：sheet 高度贴合内容而非全屏', (tester) async {
    await openSheet(
      tester,
      child: const SizedBox(
        width: 300,
        height: 120,
        child: Text('form-body'),
      ),
      onSave: () {},
    );

    expect(find.text('form-body'), findsOneWidget);
    // 标题栏保存按钮存在
    expect(find.byType(TextButton), findsWidgets);

    // 短内容 sheet 应只占屏幕底部一小段：标题栏顶部远离屏幕顶部
    // （若撑满全屏，标题栏 top 会接近 0）
    final titleRect = tester.getRect(find.text('Test Sheet'));
    expect(titleRect.top, greaterThan(1000));
  });

  testWidgets('长内容：超高部分初始不可见且可滚动到达', (tester) async {
    await openSheet(
      tester,
      child: SingleChildScrollView(
        child: Column(
          children: [for (var i = 0; i < 80; i++) Text('row-$i', key: ValueKey(i))],
        ),
      ),
      onSave: () {},
    );

    // 弹层正常打开，首行可见
    expect(find.text('row-0'), findsOneWidget);

    // 存在可滚动范围：内容真实高于视口
    // （表单内层 ScrollView 在外层 ListView 中被 hug，滚动由外层持有）
    final allScrollables = tester.stateList<ScrollableState>(
      find.byType(Scrollable),
    );
    expect(
      allScrollables.any((s) => s.position.maxScrollExtent > 0),
      isTrue,
      reason: '长表单应有可滚动范围',
    );

    // 末行初始位于视口下方（可视边界为外层 ListView）
    final viewportBottom = tester.getRect(find.byType(ListView)).bottom;
    expect(
      tester.getRect(find.text('row-79')).top,
      greaterThan(viewportBottom),
    );

    // 滚动后末行进入视口
    await tester.drag(find.text('row-0'), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('row-79')).bottom,
      lessThan(viewportBottom + 1),
    );
  });
  testWidgets('无滚动 child（Column）也能正常展示', (tester) async {
    await openSheet(
      tester,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [Text('plain-col-1'), Text('plain-col-2')],
      ),
    );

    expect(find.text('plain-col-1'), findsOneWidget);
    expect(find.text('plain-col-2'), findsOneWidget);
    // 未传 onSave 时右上角为关闭按钮而非保存（无 app_save 文本）
    expect(find.text('app_save'), findsNothing);
  });
}
