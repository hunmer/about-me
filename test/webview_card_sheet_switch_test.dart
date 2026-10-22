import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/plugins/webview/screens/components/webview_add_card_sheet.dart';

/// 复现：卡片表单底部抽屉内点击切换控件（DSSegmentedControl）无反应
void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    required Widget child,
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

  testWidgets('添加卡片表单：点击分段控件可切换到本地文件模式', (tester) async {
    await openSheet(tester, child: const WebViewAddCardSheet());

    // 初始为在线 URL 模式：项目名输入不显示
    expect(find.textContaining('项目名称'), findsNothing);

    // 点击"本地文件"分段选项（测试环境未配 Get 翻译，.tr 原样返回 key）
    await tester.tap(find.text('webview_card_type_local'));
    await tester.pumpAndSettle();

    // 切换后应出现项目名输入与路径提示
    expect(find.textContaining('项目名称'), findsWidgets);
    expect(find.textContaining('URL 将自动生成'), findsOneWidget);
  });

  // 桌面端鼠标点击（真实点击常带轻微位移，与抽屉拖拽手势竞争）
  testWidgets('添加卡片表单：鼠标点击（带轻微位移）分段控件', (tester) async {
    await openSheet(tester, child: const WebViewAddCardSheet());

    final center = tester.getCenter(find.text('webview_card_type_local'));
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(gesture.removePointer);
    await gesture.down(center);
    await tester.pump(kPressTimeout);
    await gesture.moveBy(const Offset(0, 8));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('项目名称'),
      findsWidgets,
      reason: '鼠标点击带 8px 位移时切换应仍然生效',
    );
  });
}
