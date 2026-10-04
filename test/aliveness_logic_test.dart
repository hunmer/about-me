import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/plugins/openai/aliveness/models/agent_state.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/models/memory_fragment.dart';
import 'package:aboutme/plugins/openai/aliveness/data/question_pool.dart';
import 'package:aboutme/plugins/openai/aliveness/services/behavior_executor.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_service.dart';

void main() {
  group('AlivenessConfig 序列化与钳制', () {
    test('空 JSON 全部落到安全默认值且关闭', () {
      final config = AlivenessConfig.fromJson(const {});
      expect(config.enabled, isFalse);
      expect(config.maxBubbles, 5);
      expect(config.laziness, 0.5);
      expect(config.proactiveEnabled, isFalse);
      expect(config.voiceEnabled, isFalse);
    });

    test('越界值被钳制到合法区间', () {
      final config = AlivenessConfig.fromJson(const {
        'enabled': true,
        'maxBubbles': 99,
        'laziness': 3.0,
      });
      expect(config.maxBubbles, 5);
      expect(config.laziness, 1.0);
    });

    test('toJson/fromJson 往返无损', () {
      const config = AlivenessConfig(
        enabled: true,
        bufferMinSec: 5,
        bufferMaxSec: 60,
        maxBubbles: 3,
        laziness: 0.8,
        proactiveEnabled: true,
        proactiveCooldownMin: 120,
        proactiveDailyLimit: 2,
        quietHours: [22, 7],
        voiceEnabled: true,
      );
      final restored = AlivenessConfig.fromJson(config.toJson());
      expect(restored.enabled, config.enabled);
      expect(restored.bufferMinSec, 5);
      expect(restored.maxBubbles, 3);
      expect(restored.laziness, 0.8);
      expect(restored.proactiveEnabled, isTrue);
      expect(restored.proactiveCooldownMin, 120);
      expect(restored.proactiveDailyLimit, 2);
      expect(restored.quietHours, [22, 7]);
      expect(restored.voiceEnabled, isTrue);
    });

    test('旧数据（无 alivenessConfig 键）不破坏解析', () {
      // 模拟 agents.json 中旧 agent 条目：字段缺失时返回关闭的默认配置
      final config = AlivenessConfig.fromJson(const {'enabled': false});
      expect(config.enabled, isFalse);
    });
  });

  group('BehaviorExecutor.splitIntoBubbles', () {
    final executor = BehaviorExecutor.instance;

    test('短文本不拆分', () {
      final bubbles = executor.splitIntoBubbles('嗯，好呀。', 5);
      expect(bubbles.length, 1);
      expect(bubbles.first, contains('好呀'));
    });

    test('多句长文按句末标点拆分为多条', () {
      const text = '今天过得怎么样呀？我跟你说，我今天遇到了一件特别好笑的事！'
          '就是楼下那只猫，它居然学会开冰箱了。你说离谱不离谱？我还拍了个视频，等下发给你看。';
      final bubbles = executor.splitIntoBubbles(text, 5);
      expect(bubbles.length, greaterThan(1));
      expect(bubbles.length, lessThanOrEqualTo(5));
      // 拼回完整内容（无丢失）
      expect(bubbles.join(), text);
    });

    test('maxBubbles=1 时强制单条', () {
      const text = '第一句。第二句！第三句？';
      final bubbles = executor.splitIntoBubbles(text, 1);
      expect(bubbles.length, 1);
    });

    test('换行优先拆分', () {
      const text = '吃了吗\n刚点了外卖\n等下到';
      final bubbles = executor.splitIntoBubbles(text, 5);
      expect(bubbles.length, 3);
    });
  });

  group('AgentState 状态机', () {
    test('闲置后能量恢复、亲密度衰减', () {
      final tired = AgentState(
        energy: 0.2,
        intimacy: 0.8,
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      final recovered = tired.decayTo(DateTime.now(), intimacyHalfLifeDays: 14);
      expect(recovered.energy, greaterThan(0.2));
      expect(recovered.intimacy, lessThan(0.8));
      expect(recovered.intimacy, greaterThan(0.4)); // 2天不应衰减过半
    });

    test('从未持久化（updatedAt=null）不衰减', () {
      const fresh = AgentState(energy: 0.5, intimacy: 0.9);
      final decayed = fresh.decayTo(DateTime.now());
      expect(decayed.energy, 0.5);
      expect(decayed.intimacy, 0.9);
    });

    test('互动后消耗能量、提升亲密度', () {
      const state = AgentState(energy: 0.9, intimacy: 0.3);
      final next = state.applyAfterInteraction(
        generatedLength: 120,
        userEmotion: -0.5,
        userMessageCount: 2,
      );
      expect(next.energy, lessThan(0.9));
      expect(next.intimacy, greaterThan(0.3));
      expect(next.mood, lessThan(state.mood)); // 情绪向用户负面情绪靠拢
      expect(next.lastInteractionAt, isNotNull);
    });
  });

  group('MemoryFragment 遗忘曲线', () {
    test('权重随时间衰减，手动标记不衰减', () {
      final old = MemoryFragment(
        id: '1',
        content: '用户喜欢猫',
        tags: ['猫'],
        importance: 0.8,
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
      );
      expect(old.weight(halfLifeDays: 14), closeTo(0.4, 0.05));

      final marked = MemoryFragment(
        id: '2',
        content: '用户生日是5月1日',
        tags: ['生日'],
        importance: 0.8,
        userMarked: true,
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
      );
      expect(marked.weight(), 1.0);
    });
  });

  group('MemoryService.activate 激活扩散', () {
    test('一级激活：聊到话题才想起相关记忆', () {
      final fragments = [
        MemoryFragment(id: '1', content: '用户养了一只猫叫年糕', tags: ['猫', '宠物']),
        MemoryFragment(id: '2', content: '用户在准备考研', tags: ['考研', '学习']),
        MemoryFragment(id: '3', content: '用户喜欢雨天', tags: ['下雨', '天气']),
      ];
      final activated = MemoryService.activate(fragments, '我家猫今天好黏人');
      expect(activated.length, 1);
      expect(activated.first.content, contains('年糕'));
    });

    test('二级联想：共享标签的相关记忆被扩散激活', () {
      final fragments = [
        MemoryFragment(
          id: '1',
          content: '用户养了一只猫叫年糕',
          tags: ['猫', '宠物'],
        ),
        MemoryFragment(id: '2', content: '用户想领养一只狗', tags: ['宠物', '狗']),
        MemoryFragment(id: '3', content: '用户在准备考研', tags: ['考研']),
      ];
      // 直接命中"猫"，通过共享标签"宠物"联想出"狗"
      final activated = MemoryService.activate(fragments, '猫好可爱');
      expect(
        activated.any((f) => f.content.contains('年糕')),
        isTrue,
      );
      expect(activated.any((f) => f.content.contains('狗')), isTrue);
      expect(activated.any((f) => f.content.contains('考研')), isFalse);
    });

    test('Top-K 截断与归档排除', () {
      final fragments = List.generate(
        10,
        (i) => MemoryFragment(id: '$i', content: '音乐记忆$i', tags: ['音乐']),
      );
      fragments.first.archived = true;
      final activated = MemoryService.activate(fragments, '来听音乐', k: 3);
      expect(activated.length, 3);
      expect(activated.any((f) => f.id == '0'), isFalse);
    });
  });

  group('QuestionPool 亲密度问题池', () {
    test("低亲密度只能解锁基础问题", () {
      final pool = QuestionPool.unlocked(0.1);
      expect(pool, contains('你平时喜欢听什么类型的音乐？'));
      expect(pool.any((q) => q.contains('安全感')), isFalse);
    });

    test('高亲密度解锁全部深度问题', () {
      final pool = QuestionPool.unlocked(0.9);
      expect(pool.any((q) => q.contains('安全感')), isTrue);
    });

    test('已问过的问题被过滤', () {
      final picked = QuestionPool.pickUnasked(
        0.9,
        [QuestionPool.low.first, QuestionPool.mid.first],
      );
      expect(picked, isNotNull);
      expect(picked, isNot(QuestionPool.low.first));
      expect(picked, isNot(QuestionPool.mid.first));
    });

    test('全部问完返回 null', () {
      final all = [...QuestionPool.low, ...QuestionPool.mid, ...QuestionPool.high];
      expect(QuestionPool.pickUnasked(0.9, all), isNull);
    });
  });
}
