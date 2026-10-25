import 'dart:io';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/openai/aliveness/services/chat_import_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _TemporaryPaths extends PathProviderPlatform {
  _TemporaryPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late PathProviderPlatform originalPaths;
  final template = AIAgent(
    id: 'template-agent',
    name: '模板',
    description: '',
    tags: const [],
    serviceProviderId: 'provider',
    baseUrl: 'https://example.invalid',
    headers: const {},
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    model: 'test-model',
    alivenessConfig: const AlivenessConfig(
      enabled: true,
      memoryEnabled: true,
      memoryIds: ['template-library', 'another-library'],
    ),
  );
  final service = ChatImportService.instance;
  const texts = [ImportedChatText(name: 'chat.txt', content: '我：喜欢猫\nTA：好呀')];

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('chat-import-service-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TemporaryPaths(temporary.path);
    globalStorage = StorageManager();
    await AboutmeDataService.instance.initialize();
  });

  tearDownAll(() async {
    await AboutmeDataService.instance.data.dispose();
    PathProviderPlatform.instance = originalPaths;
    await temporary.delete(recursive: true);
  });

  setUp(() async {
    await AboutmeDataService.instance.call('openai', 'alivenessSetDoc', {
      'kind': 'memory_libraries',
      'doc': {'libraries': []},
    });
  });

  for (final createAgent in [false, true]) {
    group(createAgent ? '创建 AI 并导入' : '仅导入记忆', () {
      test('未选库或空 ID 拒绝，不回退到 agent 或模板绑定', () async {
        for (final memoryId in [null, '', '  ']) {
          await expectLater(
            service.analyze(
              agent: template,
              texts: texts,
              memoryId: memoryId,
              createAgent: createAgent,
            ),
            throwsA(
              isA<ChatImportException>().having(
                (e) => e.message,
                'message',
                contains('先选择'),
              ),
            ),
          );
        }
        expect(await AlivenessStore.instance.loadMemoryLibraries(), isEmpty);
      });

      test('不存在的库和 agent ID 均拒绝，不自动创建目标库', () async {
        for (final id in ['missing-library', template.id]) {
          await expectLater(
            service.analyze(
              agent: template,
              texts: texts,
              memoryId: id,
              createAgent: createAgent,
            ),
            throwsA(
              isA<ChatImportException>().having(
                (e) => e.message,
                'message',
                contains('记忆管理创建'),
              ),
            ),
          );
        }
        expect(await AlivenessStore.instance.loadMemoryLibraries(), isEmpty);
      });

      test('已有库也不隐式采用，需要传入明确目标', () async {
        final library = await AlivenessStore.instance.createMemoryLibrary('日常');
        await expectLater(
          service.analyze(
            agent: template,
            texts: const [],
            createAgent: createAgent,
          ),
          throwsA(isA<ChatImportException>()),
        );
        final result = await service.analyze(
          agent: template,
          texts: const [],
          memoryId: library.id,
          createAgent: createAgent,
        );
        expect(result.totalChunks, 0);
        expect(result.createdAgentId, isNull);
        expect(
          await AlivenessStore.instance.loadMemoryLibraries(),
          hasLength(1),
        );
      });

      test('选定已有库后可取消，不改动库内容', () async {
        final library = await AlivenessStore.instance.createMemoryLibrary('目标');
        await AlivenessStore.instance.saveMemory(library.id, {'fragments': []});
        final result = await service.analyze(
          agent: template,
          texts: texts,
          memoryId: library.id,
          createAgent: createAgent,
          shouldCancel: () => true,
        );
        expect(result.cancelled, isTrue);
        expect(result.addedFragments, 0);
        expect(result.createdAgentId, isNull);
        expect(await AlivenessStore.instance.loadMemory(library.id), {
          'fragments': [],
        });
      });
    });
  }

  test('新 AI 清空模板的多个绑定，保留模型与开关且不修改模板', () {
    final created = ChatImportService.buildAgentFromPersona(
      template,
      const PersonaDraft(name: '阿澜', persona: '你是阿澜'),
    );
    expect(created.id, isNot(template.id));
    expect(created.model, template.model);
    expect(created.alivenessConfig!.memoryIds, isEmpty);
    expect(created.alivenessConfig!.hasMemory, isFalse);
    expect(created.alivenessConfig!.memoryEnabled, isTrue);
    expect(created.alivenessConfig!.enabled, isTrue);
    expect(template.alivenessConfig!.memoryIds, [
      'template-library',
      'another-library',
    ]);
  });

  test('无活人感配置的模板创建新 AI 时仍无库', () {
    final noConfig = AIAgent.fromJson(
      template.toJson()..remove('alivenessConfig'),
    );
    final created = ChatImportService.buildAgentFromPersona(
      noConfig,
      const PersonaDraft(name: '新 AI', persona: '你是新 AI'),
    );
    expect(created.alivenessConfig, isNull);
  });
}
