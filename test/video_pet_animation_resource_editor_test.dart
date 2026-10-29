import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/screens/video_pet_animation_resource_editor.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 逐动画 facing / moving 编辑器（VideoPetAnimationResourceEditor）的
/// widget 回归：三态语义、非法输入不外泄、切换动画重置草稿。
void main() {
  const spritesheet = VideoPetSpritesheet(
    frameWidth: 32,
    frameHeight: 32,
    columns: 10,
    rows: 10,
    frameCount: 100,
    fps: 12,
  );

  VideoPetAnimation anim({
    String id = 'walk',
    String facing = '',
    List<VideoPetLocomotion>? moving,
  }) => VideoPetAnimation(
    id: id,
    name: id,
    facing: facing,
    sources: const {'webp': 'a.webp'},
    spritesheet: spritesheet,
    moving: moving,
  );

  /// 可热替换动画的测试壳：编辑器提交回写 [current]，切动画走 [replace]。
  late _HarnessState harness;

  Future<void> pump(WidgetTester tester, VideoPetAnimation initial) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _Harness(
            initial: initial,
            onReady: (state) => harness = state,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openDropdown(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  group('facing 下拉', () {
    testWidgets('未设置/向左/向右三态分别提交 ""/left/right', (tester) async {
      await pump(tester, anim());
      expect(harness.current.facing, '');

      await openDropdown(tester, const ValueKey('videoPetFacing'));
      await tester.tap(find.text('原始朝左').last);
      await tester.pumpAndSettle();
      expect(harness.current.facing, 'left');

      await openDropdown(tester, const ValueKey('videoPetFacing'));
      await tester.tap(find.text('未设置').last);
      await tester.pumpAndSettle();
      expect(harness.current.facing, '');

      await openDropdown(tester, const ValueKey('videoPetFacing'));
      await tester.tap(find.text('原始朝右').last);
      await tester.pumpAndSettle();
      expect(harness.current.facing, 'right');
    });
  });

  group('moving 三态', () {
    testWidgets('默认 → 全程不位移 → 默认：分别提交 [] 与 null', (tester) async {
      await pump(tester, anim());
      expect(harness.current.moving, isNull);

      await openDropdown(tester, const ValueKey('videoPetMovingMode'));
      await tester.tap(find.text('全程不位移').last);
      await tester.pumpAndSettle();
      expect(harness.current.moving, isNotNull);
      expect(harness.current.moving, isEmpty);

      await openDropdown(tester, const ValueKey('videoPetMovingMode'));
      await tester.tap(find.text('默认连续移动').last);
      await tester.pumpAndSettle();
      expect(harness.current.moving, isNull);
    });

    testWidgets('切到分段模式补一段默认段并立即提交', (tester) async {
      await pump(tester, anim());
      await openDropdown(tester, const ValueKey('videoPetMovingMode'));
      await tester.tap(find.text('分段移动').last);
      await tester.pumpAndSettle();
      expect(harness.current.moving, isNotNull);
      expect(
        harness.current.moving!.single.toJsonList(),
        [0, 0, 1.0],
      );
    });

    testWidgets('已有分段回填输入框；删光所有段 = 全程不位移', (tester) async {
      await pump(
        tester,
        anim(moving: const [
          VideoPetLocomotion(startFrame: 10, endFrame: 30, speed: 2.5),
        ]),
      );
      expect(
        tester.widget<DSInput>(
          find.byKey(const ValueKey('videoPetMovingStart-0')),
        ).controller!.text,
        '10',
      );
      expect(
        tester.widget<DSInput>(
          find.byKey(const ValueKey('videoPetMovingEnd-0')),
        ).controller!.text,
        '30',
      );
      expect(
        tester.widget<DSInput>(
          find.byKey(const ValueKey('videoPetMovingSpeed-0')),
        ).controller!.text,
        '2.5',
      );

      await tester.tap(find.byKey(const ValueKey('videoPetMovingDelete-0')));
      await tester.pumpAndSettle();
      expect(harness.current.moving, isNotNull);
      expect(harness.current.moving, isEmpty);
    });
  });

  group('分段编辑与校验', () {
    testWidgets('新增两段不同速度，按序提交为三元数组', (tester) async {
      await pump(tester, anim());
      await openDropdown(tester, const ValueKey('videoPetMovingMode'));
      await tester.tap(find.text('分段移动').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('videoPetMovingStart-0')),
        '10',
      );
      await tester.enterText(
        find.byKey(const ValueKey('videoPetMovingEnd-0')),
        '30',
      );
      await tester.enterText(
        find.byKey(const ValueKey('videoPetMovingSpeed-0')),
        '2.5',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('videoPetMovingAdd')));
      await tester.pumpAndSettle();
      // 新段默认从上一段 end+1 开始（31..31，速度 1），先改速度。
      await tester.enterText(
        find.byKey(const ValueKey('videoPetMovingEnd-1')),
        '60',
      );
      await tester.enterText(
        find.byKey(const ValueKey('videoPetMovingSpeed-1')),
        '4.0',
      );
      await tester.pump();

      expect(
        harness.current.moving!
            .map((segment) => segment.toJsonList())
            .toList(),
        [
          [10, 30, 2.5],
          [31, 60, 4.0],
        ],
      );
      // 导出仍是三元数组。
      final movingJson = harness.current.toJson()['moving'] as List<dynamic>;
      expect(movingJson, [
        [10, 30, 2.5],
        [31, 60, 4.0],
      ]);
    });

    testWidgets('非法输入显示错误且不外泄非法值：越界 / 非整数 / 逆序 / 零速度 / 重叠',
        (tester) async {
      await pump(
        tester,
        anim(moving: const [
          VideoPetLocomotion(startFrame: 10, endFrame: 30, speed: 2.5),
        ]),
      );
      // 注意：逐字段输入可能产生「瞬时合法」的中间提交（合法即提交是既有
      // 行为），因此这里断言不变量：任何时刻草稿都是合法 moving，且刚输入
      // 的非法组合绝不出现在已提交值里。
      void expectDraftLegal() {
        // ignore: avoid_catches_without_on_clauses
        expect(() => harness.current.validate(), returnsNormally);
      }

      Future<void> editSegment0(String start, String end, String speed) async {
        await tester.enterText(
          find.byKey(const ValueKey('videoPetMovingStart-0')),
          start,
        );
        await tester.enterText(
          find.byKey(const ValueKey('videoPetMovingEnd-0')),
          end,
        );
        await tester.enterText(
          find.byKey(const ValueKey('videoPetMovingSpeed-0')),
          speed,
        );
        await tester.pump();
      }

      // 帧号越界（end == frameCount）。
      await editSegment0('0', '100', '2');
      expect(find.byKey(const ValueKey('videoPetMovingError-0')), findsOneWidget);
      expectDraftLegal();
      expect(harness.current.moving!.every((s) => s.endFrame < 100), isTrue);

      // 非整数帧号。
      await editSegment0('1.5', '30', '2');
      expect(find.byKey(const ValueKey('videoPetMovingError-0')), findsOneWidget);
      expectDraftLegal();
      expect(harness.current.moving!.every((s) => s.startFrame != 1), isTrue);

      // 逆序。
      await editSegment0('30', '10', '2');
      expect(find.byKey(const ValueKey('videoPetMovingError-0')), findsOneWidget);
      expectDraftLegal();
      expect(
        harness.current.moving!.every((s) => s.startFrame <= s.endFrame),
        isTrue,
      );

      // 零速度与负速度。
      for (final bad in ['0', '-1']) {
        await editSegment0('10', '30', bad);
        expect(
          find.byKey(const ValueKey('videoPetMovingError-0')),
          findsOneWidget,
        );
        expectDraftLegal();
        expect(harness.current.moving!.every((s) => s.speed > 0), isTrue);
      }

      // 修正后错误消失并提交。
      await editSegment0('10', '30', '3');
      expect(
        find.byKey(const ValueKey('videoPetMovingError-0')),
        findsNothing,
      );
      expect(harness.current.moving!.single.speed, 3);
    });

    testWidgets('重叠段阻止提交；「按起始帧排序」可修复顺序', (tester) async {
      // 放大视口，保证排序按钮不被裁剪、tap 能命中。
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(
        tester,
        anim(moving: const [
          VideoPetLocomotion(startFrame: 10, endFrame: 40, speed: 2),
        ]),
      );
      await tester.tap(find.byKey(const ValueKey('videoPetMovingAdd')));
      await tester.pumpAndSettle();
      // 新段默认 41..41；改成起始帧更小的 5..8（乱序：起始帧小于第一段）。
      await tester.enterText(
        find.byKey(const ValueKey('videoPetMovingStart-1')),
        '5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('videoPetMovingEnd-1')),
        '8',
      );
      await tester.enterText(
        find.byKey(const ValueKey('videoPetMovingSpeed-1')),
        '3',
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('videoPetMovingError-1')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('videoPetMovingSort')));
      await tester.pumpAndSettle();
      // 排序后 5..8 在前、10..40 在后，顺序合法，错误消失并提交。
      expect(find.byKey(const ValueKey('videoPetMovingError-1')), findsNothing);
      expect(
        harness.current.moving!
            .map((segment) => segment.toJsonList())
            .toList(),
        [
          [5, 8, 3.0],
          [10, 40, 2.0],
        ],
      );
    });

    testWidgets('中间输入态（空字符串、小数点）不外泄非法值', (tester) async {
      await pump(
        tester,
        anim(moving: const [
          VideoPetLocomotion(startFrame: 0, endFrame: 5, speed: 1),
        ]),
      );
      final lastValid = harness.current;
      await tester.enterText(
        find.byKey(const ValueKey('videoPetMovingSpeed-0')),
        '',
      );
      await tester.pump();
      expect(harness.current, same(lastValid));

      await tester.enterText(
        find.byKey(const ValueKey('videoPetMovingSpeed-0')),
        '2.',
      );
      await tester.pump();
      expect(harness.current, same(lastValid));

      await tester.enterText(
        find.byKey(const ValueKey('videoPetMovingSpeed-0')),
        '2.5',
      );
      await tester.pump();
      expect(harness.current.moving!.single.speed, 2.5);
    });
  });

  group('切换动画', () {
    testWidgets('切到另一动画重置输入草稿；回切保留已提交配置', (tester) async {
      final left = anim(
        id: 'left',
        facing: 'left',
        moving: const [
          VideoPetLocomotion(startFrame: 10, endFrame: 30, speed: 2.5),
        ],
      );
      final right = anim(id: 'right');
      await pump(tester, left);

      // 先编辑 left 的分段速度。
      await tester.enterText(
        find.byKey(const ValueKey('videoPetMovingSpeed-0')),
        '9',
      );
      await tester.pump();
      final leftEdited = harness.current;
      expect(leftEdited.moving!.single.speed, 9);

      // 切到 right：无分段，模式回默认。
      harness.replace(right);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('videoPetMovingStart-0')),
        findsNothing,
      );

      // 回切 left：显示的是已提交的 9，而不是原始的 2.5。
      harness.replace(leftEdited);
      await tester.pumpAndSettle();
      expect(
        tester.widget<DSInput>(
          find.byKey(const ValueKey('videoPetMovingStart-0')),
        ).controller!.text,
        '10',
      );
      expect(
        tester.widget<DSInput>(
          find.byKey(const ValueKey('videoPetMovingSpeed-0')),
        ).controller!.text,
        '9',
      );
      expect(harness.current.moving!.single.speed, 9);
    });
  });

  group('缺少 spritesheet', () {
    testWidgets('朝向可编辑；不位移 / 分段移动禁用并说明原因', (tester) async {
      final plain = VideoPetAnimation(
        id: 'float',
        name: '漂浮',
        sources: const {'webm': 'float.webm'},
      );
      await pump(tester, plain);
      expect(find.byKey(const ValueKey('videoPetFacing')), findsOneWidget);

      await openDropdown(tester, const ValueKey('videoPetFacing'));
      await tester.tap(find.text('原始朝右').last);
      await tester.pumpAndSettle();
      expect(harness.current.facing, 'right');

      await openDropdown(tester, const ValueKey('videoPetMovingMode'));
      // 分段移动 / 全程不位移对无 spritesheet 动画禁用：点击不生效。
      await tester.tap(find.text('分段移动').last, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(harness.current.moving, isNull);
      expect(find.textContaining('缺少 spritesheet'), findsOneWidget);
    });
  });
}

/// 测试壳：持有 [current]，编辑器 onChanged 回写；[replace] 通知父级换动画。
class _Harness extends StatefulWidget {
  const _Harness({required this.initial, required this.onReady});

  final VideoPetAnimation initial;
  final ValueChanged<_HarnessState> onReady;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late VideoPetAnimation current = widget.initial;

  @override
  void initState() {
    super.initState();
    widget.onReady(this);
  }

  /// 热替换编辑器展示的动画（模拟父级切换选中动作）。
  void replace(VideoPetAnimation next) => setState(() => current = next);

  @override
  Widget build(BuildContext context) => VideoPetAnimationResourceEditor(
    key: ValueKey('animationResource-${current.id}'),
    animation: current,
    onChanged: (next) => setState(() => current = next),
  );
}
