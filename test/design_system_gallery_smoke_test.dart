import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/screens/design_system_gallery/design_system_gallery_screen.dart';

/// 临时验证：skribble 示例区并入后的画廊整页可渲染
void main() {
  testWidgets('设计系统画廊（含 skribble 示例区）整页渲染不崩溃', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    await tester.pumpWidget(
      const MaterialApp(home: DesignSystemGalleryScreen()),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 滚到底部逐屏渲染（触发 SK-1~SK-4 与懒加载内容）
    for (var i = 0; i < 30; i++) {
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -600),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '第 $i 屏渲染异常');
    }
    // 卸载组件树，并推进 fake clock 让 flutter_animate 的
    // 零时 Timer 触发完毕（避免 timersPending 断言）
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 120));
  });
}
