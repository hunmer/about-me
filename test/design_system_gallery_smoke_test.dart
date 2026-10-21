import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/screens/design_system_gallery/design_system_gallery_screen.dart';

/// 画廊改为分类导航布局：逐个切换分类，每个分类整页渲染不崩溃
void main() {
  const categories = [
    '按钮', '输入', '选择器', '控件', '数据展示', '反馈浮层', '导航', '布局装饰', '令牌',
  ];

  testWidgets('设计系统画廊：逐分类切换整页渲染不崩溃', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    await tester.pumpWidget(
      const MaterialApp(home: DesignSystemGalleryScreen()),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 逐个点击分类 chip（切换动画 150ms），确认该分类整屏渲染无异常
    for (final label in categories) {
      await tester.ensureVisible(find.text(label).last);
      await tester.tap(find.text(label).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull, reason: '「$label」分类渲染异常');

      // 分类内滚动两屏，触发懒加载与底部内容
      for (var i = 0; i < 3; i++) {
        await tester.drag(
          find.byType(Scrollable).last,
          const Offset(0, -600),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '「$label」第 $i 屏渲染异常');
      }
    }
    // 卸载组件树，并推进 fake clock 让零时 Timer 触发完毕（避免 timersPending 断言）
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 120));
  });
}
