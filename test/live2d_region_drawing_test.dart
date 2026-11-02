// 绘制模式草稿矩形状态机回归：
// 修复前 bug——onPanUpdate 用上一帧草稿的 center 当新起点，触摸板慢速
// 拖动时起点不断向指针漂移，最终矩形塌缩成点被丢弃（实机日志：
// down(0.289,0.266) → up 草稿 w=0.002 h=0.001）。本测试直接驱动
// 编辑器在用的 Live2DDraftSession，断言原点在多次 move 中保持锁定。
import 'package:aboutme/plugins/live2d/screens/live2d_region_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Live2DDraftSession 框选状态机', () {
    test('pointer-down 原点在多次 move 中保持固定（实机轨迹回归）', () {
      final session = Live2DDraftSession(
        pointer: 7,
        start: const Offset(0.289, 0.266),
      );
      // 实机日志中同一根指针的连续 move 终点
      const stops = [
        Offset(0.373, 0.276),
        Offset(0.418, 0.286),
        Offset(0.543, 0.335),
        Offset(0.581, 0.353),
        Offset(0.659, 0.392),
        Offset(0.676, 0.400),
        Offset(0.701, 0.413),
        Offset(0.704, 0.414),
        Offset(0.708, 0.416),
      ];
      for (final stop in stops) {
        session.move(stop);
        // 修复点：起点绝不能从上一帧草稿反推（漂移即失败）
        expect(
          session.draft!.topLeft,
          const Offset(0.289, 0.266),
          reason: 'move 到 $stop 后起点漂移到 ${session.draft!.topLeft}',
        );
      }
      final rect = session.commit();
      expect(rect, isNotNull);
      // 修复后预期边界：固定起点到终点的包围盒（约 w=.419 h=.150）
      expect(rect!.left, closeTo(0.289, 1e-9));
      expect(rect.top, closeTo(0.266, 1e-9));
      expect(rect.right, closeTo(0.708, 1e-9));
      expect(rect.bottom, closeTo(0.416, 1e-9));
      expect(rect.width, closeTo(0.419, 1e-9));
      expect(rect.height, closeTo(0.150, 1e-9));
      expect(session.pointer, 7, reason: '应保留触发指针 id 供日志核对');
    });

    test('反向拖拽（往左上）归一化为正向矩形并提交', () {
      final session = Live2DDraftSession(
        pointer: 1,
        start: const Offset(0.7, 0.4),
      );
      session.move(const Offset(0.3, 0.2));
      expect(session.draft, const Rect.fromLTRB(0.3, 0.2, 0.7, 0.4));
      expect(session.commit(), isNotNull);
    });

    test('斜向反向（起点为右下角）同样保持原点', () {
      final session = Live2DDraftSession(
        pointer: 4,
        start: const Offset(0.9, 0.9),
      );
      session.move(const Offset(0.85, 0.95));
      session.move(const Offset(0.5, 0.6));
      session.move(const Offset(0.52, 0.58));
      // 草稿 = 固定原点与「最后一次」终点的包围盒，中间点不持久
      expect(session.draft!.bottomRight, const Offset(0.9, 0.9));
      expect(session.draft!.topLeft, const Offset(0.52, 0.58));
      expect(session.commit(), isNotNull);
    });

    test('过小拖动视为误触丢弃', () {
      final session = Live2DDraftSession(
        pointer: 2,
        start: const Offset(0.5, 0.5),
      );
      session.move(const Offset(0.502, 0.501));
      expect(session.commit(), isNull);
    });

    test('仅 down 无 move 时无草稿、不提交', () {
      final session = Live2DDraftSession(
        pointer: 3,
        start: const Offset(0.2, 0.2),
      );
      expect(session.draft, isNull);
      expect(session.commit(), isNull);
    });
  });
}
