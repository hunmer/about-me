import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoAdaptiveTextSelectionToolbar,
        cupertinoTextSelectionHandleControls;
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildInput(TextEditingController controller) {
    return MaterialApp(
      home: AppTheme(
        data: AppThemeData.light(),
        child: Center(
          child: SizedBox(width: 300, child: DSInput(controller: controller)),
        ),
      ),
    );
  }

  testWidgets('点击输入框后 Ctrl+A 全选文本', (tester) async {
    final controller = TextEditingController(text: 'select all text');
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildInput(controller));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.down(tester.getCenter(find.byType(EditableText)));
    await mouse.up();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 15),
    );
  });

  testWidgets('鼠标拖拽可以选中文本', (tester) async {
    final controller = TextEditingController(text: 'drag selection text');
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildInput(controller));

    final inputRect = tester.getRect(find.byType(EditableText));
    final gesture = await tester.startGesture(
      inputRect.centerLeft + const Offset(2, 0),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(inputRect.centerLeft + const Offset(70, 0));
    await gesture.up();
    await tester.pump();

    expect(controller.selection.isCollapsed, isFalse);
    expect(controller.selection.start, 0);
    expect(controller.selection.end, greaterThan(0));
  });

  testWidgets('iOS 启用粘贴菜单、选区和原生选择手柄', (tester) async {
    final controller = TextEditingController(text: 'selectable text');
    addTearDown(controller.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(buildInput(controller));

      final editableText = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editableText.contextMenuBuilder, isNotNull);
      expect(editableText.selectionColor, isNotNull);
      expect(editableText.showSelectionHandles, isTrue);
      expect(
        editableText.selectionControls,
        same(cupertinoTextSelectionHandleControls),
      );

      final state = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      final menu = state.widget.contextMenuBuilder!(
        state.context,
        state,
      );
      expect(menu, isA<CupertinoAdaptiveTextSelectionToolbar>());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS 长按输入框显示文本选择菜单', (tester) async {
    final controller = TextEditingController(text: 'selectable text');
    addTearDown(controller.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(buildInput(controller));
      await tester.longPressAt(tester.getCenter(find.byType(EditableText)));
      await tester.pumpAndSettle();

      expect(controller.selection.isCollapsed, isFalse);
      expect(
        find.byType(CupertinoAdaptiveTextSelectionToolbar),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS 空输入框聚焦后长按可以粘贴剪贴板文本', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => switch (call.method) {
        'Clipboard.hasStrings' => <String, dynamic>{'value': true},
        'Clipboard.getData' => <String, dynamic>{'text': 'clipboard text'},
        _ => null,
      },
    );
    try {
      await tester.pumpWidget(buildInput(controller));
      await tester.tap(find.byType(EditableText));
      await tester.pumpAndSettle();
      await tester.longPress(find.byType(EditableText));
      await tester.pumpAndSettle();

      expect(find.text('Paste'), findsOneWidget);
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();

      expect(controller.text, 'clipboard text');
    } finally {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
