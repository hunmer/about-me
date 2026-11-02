// 精灵图区域台词（VideoPetRegion.messages）纯逻辑回归：
// 序列化旧档兼容/多条往返/空白过滤/命中优先级/随机台词池。
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';

VideoPetManifest _manifestWith(List<VideoPetRegion> regions) =>
    VideoPetManifest(
      id: 'pet',
      name: 'Pet',
      idleAnimationId: 'idle',
      // webm 单源动画：无需 spritesheet，可通过 validate
      animations: [
        const VideoPetAnimation(
          id: 'idle',
          name: 'Idle',
          sources: {'webm': 'idle.webm'},
        ),
      ],
      regions: regions,
    );

void main() {
  group('VideoPetRegion.messages 序列化', () {
    test('旧档缺 messages 字段：解析为空且再序列化不产出该键', () {
      final manifest = VideoPetManifest.fromJson(
        _manifestWith(const []).toJson(),
      );
      // 旧档无区域时同样不应崩；补一条无 messages 的区域 JSON
      final legacyRegion = Map<String, dynamic>.from(
        VideoPetRegion.fromJson({
          'id': 'head',
          'name': 'Head',
          'x': 0.1,
          'y': 0.1,
          'width': 0.2,
          'height': 0.2,
        }).toJson(),
      );
      expect(legacyRegion.containsKey('messages'), isFalse);
      final reparsed = VideoPetRegion.fromJson(legacyRegion);
      expect(reparsed.messages, isEmpty);
      expect(reparsed.effectiveMessages, isEmpty);
      expect(manifest.regions, isEmpty);
    });

    test('多条台词 JSON 往返保序保留', () {
      final region = VideoPetRegion.fromJson({
        'id': 'body',
        'name': 'Body',
        'x': 0.2,
        'y': 0.3,
        'width': 0.4,
        'height': 0.3,
        'messages': ['你好呀', '在忙吗？', '嘿嘿~'],
      });
      expect(region.messages, ['你好呀', '在忙吗？', '嘿嘿~']);
      final json = region.toJson();
      expect(json['messages'], ['你好呀', '在忙吗？', '嘿嘿~']);
      expect(VideoPetRegion.fromJson(json).messages, region.messages);
    });

    test('纯空白台词过滤：effectiveMessages 剔除，序列化不落盘', () {
      final region = VideoPetRegion.fromJson({
        'id': 'hand',
        'name': 'Hand',
        'x': 0,
        'y': 0,
        'width': 0.1,
        'height': 0.1,
        'messages': ['  ', '', '\t', ' 拍拍 '],
      });
      expect(region.effectiveMessages, ['拍拍']);
      // 空白行不写回 JSON
      expect(region.toJson()['messages'], ['拍拍']);
      // 全空白时整个键省略
      final allBlank = VideoPetRegion.fromJson({
        'id': 'leg',
        'name': 'Leg',
        'x': 0,
        'y': 0,
        'width': 0.1,
        'height': 0.1,
        'messages': [' ', ''],
      });
      expect(allBlank.toJson().containsKey('messages'), isFalse);
    });

    test('messages 非字符串数组抛 FormatException', () {
      expect(
        () => VideoPetRegion.fromJson({
          'id': 'bad',
          'name': 'Bad',
          'x': 0,
          'y': 0,
          'width': 0.1,
          'height': 0.1,
          'messages': [1, 2],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('copyWith 替换 messages 不影响原对象（不串区数据）', () {
      const region = VideoPetRegion(
        id: 'a',
        name: 'A',
        x: 0,
        y: 0,
        width: 0.5,
        height: 0.5,
        messages: ['旧台词'],
      );
      final updated = region.copyWith(messages: ['新台词1', '新台词2']);
      expect(region.messages, ['旧台词']);
      expect(updated.messages, ['新台词1', '新台词2']);
      // 未传 messages 时原样保留
      expect(region.copyWith(name: 'B').messages, ['旧台词']);
    });
  });

  group('命中优先级与台词选取', () {
    final manifest = _manifestWith(const [
      VideoPetRegion(
        id: 'low',
        name: 'Low',
        x: 0,
        y: 0,
        width: 0.6,
        height: 0.6,
        priority: 1,
        messages: ['低优先级台词'],
      ),
      VideoPetRegion(
        id: 'high',
        name: 'High',
        x: 0.3,
        y: 0.3,
        width: 0.4,
        height: 0.4,
        priority: 5,
        messages: ['高优先级台词A', '高优先级台词B'],
      ),
    ]);

    test('hitTest 重叠区域取优先级最高者；停用后回退', () {
      expect(manifest.hitTest(0.4, 0.4)!.id, 'high');
      final disabled = manifest.copyWith(
        regions: [
          manifest.regions[0],
          manifest.regions[1].copyWith(enabled: false),
        ],
      );
      expect(disabled.hitTest(0.4, 0.4)!.id, 'low');
    });

    test('regionFor 按 id 优先、名称兜底、皆空返回 null', () {
      expect(manifest.regionFor('high', null)!.id, 'high');
      expect(manifest.regionFor(null, 'High')!.id, 'high');
      expect(manifest.regionFor('unknown', 'High')!.id, 'high');
      expect(manifest.regionFor('unknown', 'Nope'), isNull);
      expect(manifest.regionFor(null, null), isNull);
      expect(manifest.regionFor('', '  '), isNull);
    });

    test('随机挑选：固定种子下覆盖全部台词且不越池（非空集合）', () {
      final messages = manifest.regionFor('high', null)!.effectiveMessages;
      expect(messages, isNotEmpty);
      final random = math.Random(7);
      final drawn = <String>{};
      for (var i = 0; i < 300; i++) {
        final message = messages[random.nextInt(messages.length)];
        // 每次抽取都必须落在台词池内
        expect(messages.contains(message), isTrue);
        drawn.add(message);
      }
      // 固定种子 300 次：三条台词全部被抽到（既验证覆盖，又不依赖
      // 「随机一定不重复」的错觉）
      expect(drawn, messages.toSet());
    });
  });
}
