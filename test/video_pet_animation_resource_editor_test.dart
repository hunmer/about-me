import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/screens/video_pet_animation_resource_editor.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 逐动画 facing / moving 编辑器（VideoPetAnimationResourceEditor）的
/// widget 回归：三态语义、分帧 sheet 选择起止帧、重叠/速度校验、
/// 切换动画重置草稿。
void main() {
  // 4 列 x 2 行 = 8 帧精灵图，生成真实 PNG data URI 供分帧网格加载。
  final sheetImage = img.Image(width: 128, height: 64, numChannels: 4);
  for (var frame = 0; frame < 8; frame++) {
    final x0 = (frame % 4) * 32;
    final y0 = (frame ~/ 4) * 32;
    for (var y = y0; y < y0 + 32; y++) {
      for (var x = x0; x < x0 + 32; x++) {
        sheetImage.setPixelRgba(x, y, 40 + frame * 20, 120, 200, 255);
      }
    }
  }
  final pngUri = Uri.dataFromBytes(
    img.encodePng(sheetImage),
    mimeType: 'image/png',
  ).toString();

  const spritesheet = VideoPetSpritesheet(
    frameWidth: 32,
    frameHeight: 32,
    columns: 4,
    rows: 2,
    frameCount: 8,
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
    sources: {'png': pngUri},
    spritesheet: spritesheet,
    moving: moving,
  );

  /// 可热替换动画的测试壳：编辑器提交回写 [current]，切动画走 [replace]。
  late _HarnessState harness;

  Future<void> pump(WidgetTester tester, VideoPetAnimation initial) async {
    // 放大视口：分帧 sheet 较高，默认 800x600 会裁剪帧格。
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

  /// 打开新增区间 sheet。
  Future<void> openAddSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('videoPetMovingAdd')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('videoPetMovingSheet')), findsOneWidget);
  }

  bool confirmEnabled(WidgetTester tester) =>
      tester
          .widget<DSButton>(
            find.byKey(const ValueKey('videoPetMovingSheetConfirm')),
          )
          .onPressed !=
      null;

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

    testWidgets('切到分段模式为空列表起步并展示新增按钮', (tester) async {
      await pump(tester, anim());
      await openDropdown(tester, const ValueKey('videoPetMovingMode'));
      await tester.tap(find.text('分段移动').last);
      await tester.pumpAndSettle();
      expect(harness.current.moving, isNotNull);
      expect(harness.current.moving, isEmpty);
      expect(find.byKey(const ValueKey('videoPetMovingAdd')), findsOneWidget);
    });

    testWidgets('已有分段展示为段列表；删光所有段 = 全程不位移', (tester) async {
      await pump(
        tester,
        anim(moving: const [
          VideoPetLocomotion(startFrame: 1, endFrame: 3, speed: 2.5),
        ]),
      );
      expect(find.byKey(const ValueKey('videoPetMovingSegment-0')), findsOneWidget);
      expect(find.textContaining('帧 1–3'), findsOneWidget);
      expect(find.textContaining('2.5'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('videoPetMovingDelete-0')));
      await tester.pumpAndSettle();
      expect(harness.current.moving, isNotNull);
      expect(harness.current.moving, isEmpty);
    });
  });

  group('分帧 sheet 新增', () {
    testWidgets('点选起止帧后插入默认速度 1 的段', (tester) async {
      await pump(tester, anim());
      await openDropdown(tester, const ValueKey('videoPetMovingMode'));
      await tester.tap(find.text('分段移动').last);
      await tester.pumpAndSettle();

      await openAddSheet(tester);
      expect(confirmEnabled(tester), isFalse);
      await tester.tap(find.byKey(const ValueKey('videoPetFrameCell-1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('videoPetFrameCell-3')));
      await tester.pump();
      expect(confirmEnabled(tester), isTrue);

      await tester.tap(
        find.byKey(const ValueKey('videoPetMovingSheetConfirm')),
      );
      await tester.pumpAndSettle();
      expect(harness.current.moving!.single.toJsonList(), [1, 3, 1.0]);
    });

    testWidgets('反序点选自动交换起止；速度可编辑', (tester) async {
      await pump(tester, anim());
      await openDropdown(tester, const ValueKey('videoPetMovingMode'));
      await tester.tap(find.text('分段移动').last);
      await tester.pumpAndSettle();
      await openAddSheet(tester);

      await tester.tap(find.byKey(const ValueKey('videoPetFrameCell-5')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('videoPetFrameCell-2')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('videoPetMovingSheetSpeed')),
        '2.5',
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('videoPetMovingSheetConfirm')),
      );
      await tester.pumpAndSettle();
      expect(harness.current.moving!.single.toJsonList(), [2, 5, 2.5]);
    });

    testWidgets('非法速度禁用确认；取消不改动', (tester) async {
      await pump(tester, anim());
      await openDropdown(tester, const ValueKey('videoPetMovingMode'));
      await tester.tap(find.text('分段移动').last);
      await tester.pumpAndSettle();
      await openAddSheet(tester);

      await tester.tap(find.byKey(const ValueKey('videoPetFrameCell-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('videoPetFrameCell-7')));
      await tester.pump();
      expect(confirmEnabled(tester), isTrue);

      for (final bad in ['0', '-1', 'abc', '']) {
        await tester.enterText(
          find.byKey(const ValueKey('videoPetMovingSheetSpeed')),
          bad,
        );
        await tester.pump();
        expect(confirmEnabled(tester), isFalse, reason: 'speed "$bad"');
      }

      // 取消：无任何提交。
      await tester.tap(
        find.byKey(const ValueKey('videoPetMovingSheetCancel')),
      );
      await tester.pumpAndSettle();
      expect(harness.current.moving, isEmpty);
    });
  });

  group('分帧 sheet 重叠校验与编辑', () {
    testWidgets('与既有段重叠禁选禁确认；不重叠可插入并按起始帧排序', (
      tester,
    ) async {
      await pump(
        tester,
        anim(moving: const [
          VideoPetLocomotion(startFrame: 0, endFrame: 2, speed: 1),
        ]),
      );
      await openAddSheet(tester);

      // 帧重叠：选 1（落在既有 0..2 内，被禁选不生效），只能选 3 起。
      await tester.tap(
        find.byKey(const ValueKey('videoPetFrameCell-1')),
        warnIfMissed: false,
      );
      await tester.pump();
      // 既有区间占用的帧未成为起点。
      await tester.tap(find.byKey(const ValueKey('videoPetFrameCell-3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('videoPetFrameCell-4')));
      await tester.pump();
      expect(confirmEnabled(tester), isTrue);

      await tester.tap(
        find.byKey(const ValueKey('videoPetMovingSheetConfirm')),
      );
      await tester.pumpAndSettle();
      expect(
        harness.current.moving!
            .map((segment) => segment.toJsonList())
            .toList(),
        [
          [0, 2, 1.0],
          [3, 4, 1.0],
        ],
      );
    });

    testWidgets('手选重叠区间显示错误并禁用确认', (tester) async {
      await pump(
        tester,
        anim(moving: const [
          VideoPetLocomotion(startFrame: 2, endFrame: 4, speed: 1),
        ]),
      );
      await openAddSheet(tester);

      await tester.tap(find.byKey(const ValueKey('videoPetFrameCell-0')));
      await tester.pump();
      // 2..4 被占用不可选，但 0..5 区间整体与 2..4 重叠。
      await tester.tap(
        find.byKey(const ValueKey('videoPetFrameCell-2')),
        warnIfMissed: false,
      );
      await tester.pump();
      // 占用帧点击无效，起点仍是 0；改点 5 作终点 → 0..5 与 2..4 重叠。
      await tester.tap(find.byKey(const ValueKey('videoPetFrameCell-5')));
      await tester.pump();
      expect(confirmEnabled(tester), isFalse);
      expect(
        find.byKey(const ValueKey('videoPetMovingSheetError')),
        findsOneWidget,
      );

      // 换成不重叠的 6..7 后可确认。
      await tester.tap(find.byKey(const ValueKey('videoPetFrameCell-6')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('videoPetFrameCell-7')));
      await tester.pump();
      expect(confirmEnabled(tester), isTrue);
    });

    testWidgets('编辑既有段：回填选择与速度，保存后替换', (tester) async {
      await pump(
        tester,
        anim(moving: const [
          VideoPetLocomotion(startFrame: 1, endFrame: 3, speed: 2.5),
        ]),
      );

      await tester.tap(find.byKey(const ValueKey('videoPetMovingEdit-0')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DSInput>(
              find.byKey(const ValueKey('videoPetMovingSheetSpeed')),
            )
            .controller!
            .text,
        '2.5',
      );
      // 回填后直接可保存。
      expect(confirmEnabled(tester), isTrue);

      await tester.enterText(
        find.byKey(const ValueKey('videoPetMovingSheetSpeed')),
        '4',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('videoPetMovingSheetConfirm')),
      );
      await tester.pumpAndSettle();
      expect(harness.current.moving!.single.toJsonList(), [1, 3, 4.0]);
    });

    testWidgets('删除一段保留其余段', (tester) async {
      await pump(
        tester,
        anim(moving: const [
          VideoPetLocomotion(startFrame: 0, endFrame: 1, speed: 1),
          VideoPetLocomotion(startFrame: 4, endFrame: 5, speed: 2),
        ]),
      );
      await tester.tap(find.byKey(const ValueKey('videoPetMovingDelete-0')));
      // 消化 DSIconButton tooltip 的 150ms 隐藏定时器。
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 200));
      expect(harness.current.moving!.single.toJsonList(), [4, 5, 2.0]);
    });
  });

  group('切换动画', () {
    testWidgets('切到另一动画重置；回切保留已提交配置', (tester) async {
      final left = anim(
        id: 'left',
        facing: 'left',
        moving: const [
          VideoPetLocomotion(startFrame: 1, endFrame: 3, speed: 2.5),
        ],
      );
      final right = anim(id: 'right');
      await pump(tester, left);

      // 切到 right：无分段，模式回默认。
      harness.replace(right);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('videoPetMovingSegment-0')),
        findsNothing,
      );

      // 回切 left：段列表仍在，已提交配置保留。
      harness.replace(left);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('videoPetMovingSegment-0')), findsOneWidget);
      expect(find.textContaining('帧 1–3'), findsOneWidget);
      expect(harness.current.moving!.single.speed, 2.5);
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
