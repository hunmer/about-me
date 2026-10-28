import 'dart:convert';

import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

/// 帧数 10、fps 12 的最小精灵图，合法帧 0..9。
const _sheet = VideoPetSpritesheet(
  frameWidth: 64,
  frameHeight: 64,
  columns: 5,
  rows: 2,
  frameCount: 10,
  fps: 12,
);

const _base = VideoPetAnimation(
  id: 'walk',
  name: '走路',
  facing: 'left',
  sources: {'png': 'walk.png'},
  spritesheet: _sheet,
);

VideoPetLocomotion _seg(int start, int end, double speed) =>
    VideoPetLocomotion(startFrame: start, endFrame: end, speed: speed);

/// 模拟真实落盘链路：toJson → jsonEncode → jsonDecode → fromJson。
VideoPetAnimation _roundtrip(VideoPetAnimation animation) =>
    VideoPetAnimation.fromJson(
      jsonDecode(jsonEncode(animation.toJson())) as Map<String, dynamic>,
    );

List<List<dynamic>> _lists(VideoPetAnimation animation) =>
    animation.moving!.map((segment) => segment.toJsonList()).toList();

void main() {
  group('moving 三态 JSON roundtrip', () {
    test('缺省 moving：toJson 省略 moving 与 locomotion，解析回 null（默认连续移动）', () {
      const animation = _base;
      expect(animation.moving, isNull);

      final json = animation.toJson();
      expect(json.containsKey('moving'), isFalse);
      expect(json.containsKey('locomotion'), isFalse);

      final parsed = _roundtrip(animation);
      expect(parsed.moving, isNull);
      expect(parsed.facing, 'left');
      parsed.validate();
    });

    test('moving: [] 输出空数组并 roundtrip 回空列表（全程不位移）', () {
      final animation = _base.copyWith(moving: const []);
      expect(animation.moving, isNotNull);
      expect(animation.moving, isEmpty);

      final json = animation.toJson();
      expect(json.containsKey('locomotion'), isFalse);
      expect(json['moving'], isEmpty);

      final parsed = _roundtrip(animation);
      expect(parsed.moving, isNotNull);
      expect(parsed.moving, isEmpty);
      parsed.validate();
    });

    test('多段 moving 输出三元数组，顺序与数值保持，roundtrip 相等', () {
      final animation = _base.copyWith(
        moving: [_seg(0, 2, 1.0), _seg(4, 6, 2.5), _seg(8, 9, 0.5)],
      );

      final json = animation.toJson();
      expect(json.containsKey('locomotion'), isFalse);
      final movingJson = json['moving'] as List<dynamic>;
      expect(movingJson, [
        [0, 2, 1.0],
        [4, 6, 2.5],
        [8, 9, 0.5],
      ]);
      for (final entry in movingJson) {
        final values = entry as List<dynamic>;
        expect(values, hasLength(3));
        expect(values[0], isA<int>());
        expect(values[1], isA<int>());
        expect(values[2], isA<num>());
      }

      final parsed = _roundtrip(animation);
      expect(_lists(parsed), [
        [0, 2, 1.0],
        [4, 6, 2.5],
        [8, 9, 0.5],
      ]);
      parsed.validate();
    });
  });

  group('旧 locomotion 兼容', () {
    test('仅有旧 locomotion 对象时读取为单段 moving，导出不再写旧字段', () {
      final json = _base.toJson()
        ..['locomotion'] = {'startFrame': 1, 'endFrame': 3, 'speed': 2};

      final parsed = VideoPetAnimation.fromJson(json);
      expect(parsed.moving, hasLength(1));
      final segment = parsed.moving!.single;
      expect(segment.startFrame, 1);
      expect(segment.endFrame, 3);
      expect(segment.speed, 2.0);
      expect(segment.speed, isA<double>());
      parsed.validate();

      final out = parsed.toJson();
      expect(out.containsKey('locomotion'), isFalse);
      expect(out['moving'], [
        [1, 3, 2.0],
      ]);
    });

    test('moving 与 locomotion 同时存在时以 moving 为准（含空数组）', () {
      final emptyMoving = _base.toJson()
        ..['moving'] = <dynamic>[]
        ..['locomotion'] = {'startFrame': 0, 'endFrame': 4, 'speed': 9.0};
      final parsedEmpty = VideoPetAnimation.fromJson(emptyMoving);
      expect(parsedEmpty.moving, isEmpty);

      final segments = _base.toJson()
        ..['moving'] = [
          [5, 7, 3.0],
        ]
        ..['locomotion'] = {'startFrame': 0, 'endFrame': 4, 'speed': 9.0};
      final parsedSegments = VideoPetAnimation.fromJson(segments);
      expect(_lists(parsedSegments), [
        [5, 7, 3.0],
      ]);
    });

    test('moving 为 JSON null 时仍回退读旧 locomotion（文档化行为）', () {
      final json = _base.toJson()
        ..['moving'] = null
        ..['locomotion'] = {'startFrame': 0, 'endFrame': 1, 'speed': 1.5};

      final parsed = VideoPetAnimation.fromJson(json);
      expect(_lists(parsed), [
        [0, 1, 1.5],
      ]);
    });

    test('fromJson 拒绝结构非法的 moving', () {
      final cases = <String, Map<String, dynamic>>{
        '非数组': (_base.toJson()..['moving'] = 5),
        '项不是数组': (_base.toJson()..['moving'] = ['x']),
        '项长度不是 3': (_base.toJson()..['moving'] = [
          [0, 1],
        ]),
        '起止帧非整数': (_base.toJson()..['moving'] = [
          [0.5, 2, 1.0],
        ]),
        '速度非数字': (_base.toJson()..['moving'] = [
          [0, 1, 'fast'],
        ]),
      };
      for (final entry in cases.entries) {
        expect(
          () => VideoPetAnimation.fromJson(entry.value),
          throwsFormatException,
          reason: entry.key,
        );
      }
    });

    test('fromJson 只校验结构，帧范围与顺序留给 validate()', () {
      final json = _base.toJson()
        ..['moving'] = [
          [5, 1, 2.0],
          [2, 3, 1.0],
        ];
      final parsed = VideoPetAnimation.fromJson(json);
      expect(parsed.moving, hasLength(2));
      expect(parsed.validate, throwsFormatException);
    });
  });

  group('copyWith moving 三态', () {
    test('省略保留原值；moving: null 清除；moving: [] 显式不位移', () {
      final animation = _base.copyWith(moving: [_seg(0, 1, 2.0)]);

      final preserved = animation.copyWith(name: '改名');
      expect(preserved.moving, isNotNull);
      expect(_lists(preserved), [
        [0, 1, 2.0],
      ]);

      final cleared = animation.copyWith(moving: null);
      expect(cleared.moving, isNull);
      expect(cleared.toJson().containsKey('moving'), isFalse);

      final none = animation.copyWith(moving: const []);
      expect(none.moving, isNotNull);
      expect(none.moving, isEmpty);
      expect(none.toJson()['moving'], isEmpty);
    });

    test('copyWith 产出的 moving 列表不可变', () {
      final animation = _base.copyWith(moving: [_seg(0, 1, 1.0)]);
      expect(() => animation.moving!.add(_seg(2, 3, 1.0)), throwsUnsupportedError);
      expect(
        () => animation.moving![0] = _seg(2, 3, 1.0),
        throwsUnsupportedError,
      );
    });

    test('copyWith(facing: "") 清除朝向，省略/ null 保留', () {
      final left = _base.copyWith(facing: 'left');
      expect(left.copyWith(facing: '').facing, '');
      expect(left.copyWith(name: 'x').facing, 'left');
      expect(left.copyWith(facing: null).facing, 'left');
      expect(left.copyWith(facing: 'right').facing, 'right');
    });
  });

  group('validate 拒绝非法 moving', () {
    VideoPetAnimation withMoving(List<VideoPetLocomotion> segments) =>
        _base.copyWith(moving: segments);

    test('帧越界被拒绝：start < 0、end == frameCount、end > frameCount', () {
      for (final segment in [
        _seg(-1, 2, 1.0),
        _seg(0, 10, 1.0),
        _seg(2, 12, 1.0),
      ]) {
        expect(
          withMoving([segment]).validate,
          throwsFormatException,
          reason: 'start=${segment.startFrame} end=${segment.endFrame}',
        );
      }
    });

    test('逆序被拒绝：start > end', () {
      expect(withMoving([_seg(5, 4, 1.0)]).validate, throwsFormatException);
      expect(
        withMoving([
          _seg(0, 2, 1.0),
          _seg(8, 6, 1.0),
        ]).validate,
        throwsFormatException,
      );
    });

    test('重叠与乱序被拒绝；相邻段、带间隙的段合法', () {
      expect(
        withMoving([
          _seg(0, 3, 1.0),
          _seg(2, 5, 1.0),
        ]).validate,
        throwsFormatException,
      );
      expect(
        withMoving([
          _seg(4, 6, 1.0),
          _seg(0, 2, 1.0),
        ]).validate,
        throwsFormatException,
      );
      // 相邻（next.start == prev.end + 1）与留间隙都合法。
      withMoving([
        _seg(0, 1, 1.0),
        _seg(2, 3, 1.0),
      ]).validate();
      withMoving([
        _seg(0, 1, 1.0),
        _seg(3, 4, 1.0),
      ]).validate();
    });

    test('速度必须是有限正数：0 / 负数 / NaN / ±Infinity 全部拒绝', () {
      for (final speed in [
        0.0,
        -1.0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          withMoving([_seg(0, 1, speed)]).validate,
          throwsFormatException,
          reason: 'speed=$speed',
        );
      }
      // 正小数速度合法。
      withMoving([_seg(0, 1, 0.1)]).validate();
    });

    test('无 spritesheet 时 moving 非法（含空数组），moving 为 null 合法', () {
      const noSheet = VideoPetAnimation(
        id: 'walk',
        name: '走路',
        sources: {'webm': 'walk.webm'},
      );
      expect(noSheet.moving, isNull);
      noSheet.validate();

      expect(
        () => noSheet.copyWith(moving: const []).validate(),
        throwsFormatException,
      );
      expect(
        () => noSheet.copyWith(moving: [_seg(0, 1, 1.0)]).validate(),
        throwsFormatException,
      );
    });

    test('边界帧合法：0 与 frameCount - 1 均可作为起止帧', () {
      withMoving([_seg(0, 0, 1.0)]).validate();
      withMoving([_seg(9, 9, 1.0)]).validate();
      withMoving([_seg(0, 9, 2.5)]).validate();
    });
  });
}
