import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/plugins/openai/aliveness/models/agent_state.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/models/memory_fragment.dart';
import 'package:aboutme/plugins/openai/aliveness/data/question_pool.dart';
import 'package:aboutme/plugins/openai/aliveness/services/behavior_executor.dart';
import 'package:aboutme/plugins/openai/aliveness/services/chat_import_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/schedule_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';

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

    test('ttsServiceId 可显式清除回 null（跟随全局）', () {
      const config = AlivenessConfig(enabled: true, ttsServiceId: 'svc-1');
      // 普通 copyWith 不影响
      expect(config.copyWith(enabled: false).ttsServiceId, 'svc-1');
      // 显式传 null 清除
      final cleared = config.copyWith(ttsServiceId: null);
      expect(cleared.ttsServiceId, isNull);
      // 序列化：null 不落盘，fromJson 兼容
      expect(cleared.toJson().containsKey('ttsServiceId'), isFalse);
      expect(
        AlivenessConfig.fromJson(config.toJson()).ttsServiceId,
        'svc-1',
      );
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

    test('换行优先：每行一条（AI 主动分条）', () {
      const text = '吃了吗\n刚点了外卖\n等下到';
      final bubbles = executor.splitIntoBubbles(text, 5);
      expect(bubbles.length, 3);
      expect(bubbles, ['吃了吗', '刚点了外卖', '等下到']);
    });

    test('超过上限时尾部行合并且内容无丢失', () {
      const text = '第一句话完整表达\n第二句话也完整\n第三句话继续\n第四句收尾\n第五句补充\n最后一句';
      final bubbles = executor.splitIntoBubbles(text, 3);
      expect(bubbles.length, 3);
      expect(bubbles.first, '第一句话完整表达');
      expect(bubbles.last, '第三句话继续第四句收尾第五句补充最后一句');
      // 内容无丢失（换行被消费，其余字符全保留）
      expect(bubbles.join(), text.replaceAll('\n', ''));
    });

    test('单字语气碎片并入前一条，正常短句独立成条', () {
      const text = '我今天遇到件好笑的事\n嗯\n就是楼下那只猫学会开冰箱了';
      final bubbles = executor.splitIntoBubbles(text, 5);
      expect(bubbles.length, 2);
      expect(bubbles.first, '我今天遇到件好笑的事嗯');
      expect(bubbles.last, '就是楼下那只猫学会开冰箱了');
    });

    test('markdown 列表符号被清理', () {
      const text = '1. 今天好累啊\n2. 加班到现在';
      final bubbles = executor.splitIntoBubbles(text, 5);
      expect(bubbles, ['今天好累啊', '加班到现在']);
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

  group('MemoryFragment 自我碎片', () {
    test('isSelf 序列化往返无损，默认为用户记忆', () {
      final self = MemoryFragment(
        id: 'f1',
        content: '我周末要去爬山',
        tags: ['爬山', '周末'],
        isSelf: true,
      );
      final restored = MemoryFragment.fromJson(self.toJson());
      expect(restored.isSelf, isTrue);

      final user = MemoryFragment(
        id: 'f2',
        content: '用户在准备面试',
        tags: ['面试'],
      );
      expect(user.isSelf, isFalse);
      // 旧数据无 isSelf 键 → 默认用户记忆
      final json = user.toJson()..remove('isSelf');
      expect(MemoryFragment.fromJson(json).isSelf, isFalse);
    });

    test('核心记忆排除自我碎片，自我摘要只含自我碎片', () async {
      // buildCoreMemorySummary / buildSelfSummary 走存储，这里验证激活标注格式
      final fragments = [
        MemoryFragment(id: 'a', content: '用户喜欢吉他', tags: ['吉他']),
        MemoryFragment(id: 'b', content: '我在学法语', tags: ['法语'], isSelf: true),
      ];
      final activated = MemoryService.activate(fragments, '法语');
      expect(activated, hasLength(1));
      expect(activated.single.isSelf, isTrue);
    });
  });

  group('ScheduleService 日程', () {
    final day = DateTime(2026, 10, 5);

    test('parseSchedule 解析正常 JSON 数组并按时间排序', () {
      const text = '[{"start":"09:00","end":"09:30","title":"早饭","desc":"豆浆油条"},'
          '{"start":"07:30","end":"08:00","title":"起床"}]';
      final entries = ScheduleService.parseSchedule(text, day);
      expect(entries, hasLength(2));
      expect(entries.first.title, '起床');
      expect(entries.first.start, DateTime(2026, 10, 5, 7, 30));
      expect(entries.last.description, '豆浆油条');
    });

    test('parseSchedule 容忍 markdown 包裹与前置思考文本', () {
      const text = '好的，这是安排：\n```json\n'
          '[{"start":"08:00","end":"08:30","title":"晨跑"}]\n```\n以上。';
      final entries = ScheduleService.parseSchedule(text, day);
      expect(entries, hasLength(1));
      expect(entries.single.title, '晨跑');
    });

    test('parseSchedule 修正 end<=start 的条目并跳过非法时间', () {
      const text = '['
          '{"start":"12:00","end":"11:00","title":"倒置时间"},'
          '{"start":"25:00","end":"26:00","title":"非法小时"},'
          '{"start":"13:00","end":"14:00","title":"正常"}'
          ']';
      final entries = ScheduleService.parseSchedule(text, day);
      expect(entries, hasLength(2));
      expect(entries.first.end, entries.first.start.add(const Duration(minutes: 30)));
    });

    test('buildScheduleContext 命中当前时段并给出前后安排', () {
      final schedule = AgentSchedule(date: day, entries: [
        ScheduleEntry(
          start: DateTime(2026, 10, 5, 12, 0),
          end: DateTime(2026, 10, 5, 13, 30),
          title: '午饭',
        ),
        ScheduleEntry(
          start: DateTime(2026, 10, 5, 14, 0),
          end: DateTime(2026, 10, 5, 15, 0),
          title: '练吉他',
        ),
        ScheduleEntry(
          start: DateTime(2026, 10, 5, 18, 0),
          end: DateTime(2026, 10, 5, 19, 0),
          title: '晚饭',
        ),
      ]);
      final ctx = ScheduleService.instance.buildScheduleContext(
        schedule,
        now: DateTime(2026, 10, 5, 14, 30),
      );
      expect(ctx, contains('14:30'));
      expect(ctx, contains('你正在练吉他'));
      expect(ctx, contains('之前你刚午饭完毕'));
      expect(ctx, contains('18:00 你要做的是：晚饭'));
      expect(ctx, contains('12:00 午饭 → 14:00 练吉他 → 18:00 晚饭'));
    });

    test('buildScheduleContext 空档时间不声称正在做事', () {
      final schedule = AgentSchedule(date: day, entries: [
        ScheduleEntry(
          start: DateTime(2026, 10, 5, 12, 0),
          end: DateTime(2026, 10, 5, 13, 0),
          title: '午饭',
        ),
      ]);
      final ctx = ScheduleService.instance.buildScheduleContext(
        schedule,
        now: DateTime(2026, 10, 5, 15, 0),
      );
      expect(ctx, contains('空档时间'));
      expect(ctx, isNot(contains('你正在')));
    });

    test('toActivityRecords 保留时间与标题（activity UI 复用）', () {
      final schedule = AgentSchedule(date: day, entries: [
        ScheduleEntry(
          start: DateTime(2026, 10, 5, 9, 0),
          end: DateTime(2026, 10, 5, 9, 40),
          title: '晨跑',
          description: '河边五公里',
        ),
      ]);
      final records = ScheduleService.instance.toActivityRecords(schedule);
      expect(records, hasLength(1));
      expect(records.single.title, '晨跑');
      expect(records.single.description, '河边五公里');
      expect(records.single.startTime, DateTime(2026, 10, 5, 9, 0));
    });
  });

  group('ChatImportService 分块与解析', () {
    test('短文本不分块，空文本返回空', () {
      expect(ChatImportService.splitChunks(''), isEmpty);
      expect(ChatImportService.splitChunks('   '), isEmpty);
      expect(ChatImportService.splitChunks('你好'), ['你好']);
    });

    test('长文本按行边界分块且内容无损', () {
      final line = '这是一行聊天内容，长度合适。';
      final text = List.filled(600, line).join('\n'); // 约 9000 字符
      final chunks = ChatImportService.splitChunks(text, chunkChars: 3000);
      expect(chunks.length, greaterThan(1));
      // 每块都在上限附近且不超过原上限太多（行边界只可能提前切）
      for (final c in chunks) {
        expect(c.length, lessThanOrEqualTo(3000));
      }
      // 重组后内容一致（trim 只影响块首尾空白）
      expect(chunks.join('\n'), text);
    });

    test('parseChunkResponse 容忍 markdown 包裹与前置思考文本', () {
      final raw = '思考中…\n```json\n{"memories":['
          '{"content":"用户在准备面试","tags":["面试","求职"],"emotion":"neutral","importance":0.8},'
          '{"content":"用户喜欢爬山","tags":["爬山","运动"],"importance":0.7}]}'
          '\n```';
      final extraction = ChatImportService.parseChunkResponse(raw)!;
      expect(extraction.memories, hasLength(2));
      expect(extraction.memories.first.content, '用户在准备面试');
      expect(extraction.memories.first.tags, ['面试', '求职']);
      expect(extraction.memories.last.importance, 0.7);
      expect(extraction.observations, isEmpty);
    });

    test('parseChunkResponse 同时解析 memories 与 observations', () {
      final raw = '{"memories":[{"content":"用户养了只猫","tags":["猫","宠物"],"importance":0.8}],'
          '"observations":["TA说话简短干脆","TA常用省略号结尾"]}';
      final extraction = ChatImportService.parseChunkResponse(raw)!;
      expect(extraction.memories, hasLength(1));
      expect(extraction.observations, ['TA说话简短干脆', 'TA常用省略号结尾']);
    });

    test('parseChunkResponse 超过单块上限只取前 N 条', () {
      final items = List.generate(
        12,
        (i) => '{"content":"事实$i","tags":["t"]}',
      ).join(',');
      final obs = List.generate(8, (i) => '"观察$i"').join(',');
      final drafts = ChatImportService.parseChunkResponse(
        '{"memories":[$items],"observations":[$obs]}',
      )!;
      expect(drafts.memories, hasLength(8));
      expect(drafts.memories.last.content, '事实7');
      expect(drafts.observations, hasLength(5)); // 每块观察上限 5
    });

    test('parseChunkResponse 无 JSON 或空数组容错', () {
      expect(ChatImportService.parseChunkResponse('没有任何 JSON'), isNull);
      // 空数组 → 空提取而非 null
      final empty = ChatImportService.parseChunkResponse(
        '{"memories":[],"observations":[]}',
      )!;
      expect(empty.memories, isEmpty);
      expect(empty.observations, isEmpty);
    });

    test('parsePersona 解析人设并校验必填', () {
      const raw = '```json\n{"name":"阿澜","persona":"你是阿澜……（说话简短，爱用省略号）"}\n```';
      final draft = ChatImportService.parsePersona(raw)!;
      expect(draft.name, '阿澜');
      expect(draft.persona, startsWith('你是阿澜'));
      // 缺字段返回 null
      expect(ChatImportService.parsePersona('{"name":"阿澜"}'), isNull);
      expect(ChatImportService.parsePersona('无 JSON'), isNull);
    });

    test('buildAgentFromPersona 克隆模板配置并替换人设', () {
      final template = AIAgent(
        id: 'tpl',
        name: '模板',
        description: '',
        tags: const [],
        serviceProviderId: 'sp1',
        baseUrl: 'https://api.test',
        headers: const {'Authorization': 'Bearer x'},
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        model: 'deepseek-flash',
      );
      final agent = ChatImportService.buildAgentFromPersona(
        template,
        const PersonaDraft(name: '阿澜', persona: '你是阿澜'),
      );
      expect(agent.id, isNot('tpl'));
      expect(agent.name, '阿澜');
      expect(agent.effectiveSystemPrompt, '你是阿澜');
      // 模型配置完整克隆
      expect(agent.model, 'deepseek-flash');
      expect(agent.serviceProviderId, 'sp1');
      expect(agent.headers['Authorization'], 'Bearer x');
    });

    test('loadFromFiles 遍历 zip 内文本条目并跳过非文本', () async {
      final archive = Archive()
        ..add(ArchiveFile.string('chat/a.txt', '用户：今天面试通过了'))
        ..add(ArchiveFile.string('notes.md', '# 周报'))
        ..add(ArchiveFile.string('pic.png', 'binary'));
      final zip = ZipEncoder().encodeBytes(archive);
      final tmp = File(
        '${Directory.systemTemp.path}/aliveness_import_test_${DateTime.now().millisecondsSinceEpoch}.zip',
      );
      await tmp.writeAsBytes(zip);
      addTearDown(() => tmp.delete());

      final texts = await ChatImportService.instance.loadFromFiles([tmp]);
      expect(texts, hasLength(2)); // png 被扩展名过滤
      expect(texts.first.name, 'chat/a.txt');
      expect(texts.first.content, contains('面试'));
      expect(texts.map((t) => t.name), containsAll(['chat/a.txt', 'notes.md']));
    });

    test('微信导出 messages.json 转干净对话文本', () {
      final raw = jsonEncode({
        'schemaVersion': 1,
        'conversation': {'displayName': '嘘', 'isGroup': false},
        'messages': [
          {
            'createTimeText': '2026-01-31 23:04:14',
            'renderType': 'text',
            'isSent': true,
            'senderDisplayName': 'Hum。',
            'content': '所以你是不是已经本能的说不要香菜哈哈',
          },
          {
            'createTimeText': '2026-01-31 23:04:27',
            'renderType': 'text',
            'isSent': true,
            'senderDisplayName': 'Hum。',
            'content': '还行吧味道',
          },
          {
            'createTimeText': '2026-02-01 08:10:00',
            'renderType': 'text',
            'isSent': false,
            'senderDisplayName': '嘘',
            'content': '我连煎饼果子都不吃了',
          },
          {
            'createTimeText': '2026-02-01 09:00:00',
            'renderType': 'voice',
            'isSent': false,
            'senderDisplayName': '嘘',
            'voiceTranscript': '',
          },
          {
            // 图片类未导出内容：空 content 应被跳过
            'createTimeText': '2026-02-01 09:01:00',
            'renderType': 'image',
            'isSent': false,
            'senderDisplayName': '嘘',
            'content': '',
          },
        ],
      });
      final out = ChatImportService.tryFormatWeChatExport(raw)!;
      expect(out, contains('与「嘘」的聊天记录'));
      expect(out, contains('—— 2026-01-31 ——'));
      expect(out, contains('23:04 我：所以你是不是已经本能的说不要香菜哈哈'));
      expect(out, contains('08:10 嘘：我连煎饼果子都不吃了'));
      // 日期切换插入分隔行
      expect(out, contains('—— 2026-02-01 ——'));
      // 无转写语音保留标记
      expect(out, contains('09:00 嘘：[语音]'));
      // 空内容消息不出现在输出
      expect(out, isNot(contains('09:01')));
    });

    test('微信导出识别失败返回 null（普通 JSON / 纯文本 / 空 messages）', () {
      expect(ChatImportService.tryFormatWeChatExport('{"a":1}'), isNull);
      expect(ChatImportService.tryFormatWeChatExport('[1,2,3]'), isNull);
      expect(ChatImportService.tryFormatWeChatExport('不是json'), isNull);
      expect(
        ChatImportService.tryFormatWeChatExport('{"messages":[]}'),
        isNull,
      );
      expect(
        ChatImportService.tryFormatWeChatExport(
          '{"messages":[{"content":"无renderType特征"}]}',
        ),
        isNull,
      );
    });
  });
}
