import 'dart:convert';
import 'dart:io';

import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:aboutme/screens/jelly_home/live2d_zip_import.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d_models.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('live2d_zip_test_');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Archive buildZip(List<String> names, Map<String, List<int>> contents) {
    final archive = Archive();
    for (final name in names) {
      archive.addFile(
        ArchiveFile(name, contents[name]!.length, contents[name]!),
      );
    }
    return archive;
  }

  test('导入单模型 zip：提取 model3.json、解析动作、过滤垃圾文件', () async {
    final modelJson = utf8.encode(
      jsonEncode({
        'FileReferences': {
          'Moc': 'character.moc3',
          'Textures': ['textures/texture_00.png'],
          'Motions': {
            'Idle': [
              {'File': 'motions/idle.motion3.json', 'Name': '待机'},
            ],
          },
        },
      }),
    );
    final zip = ZipEncoder().encode(
      buildZip([
        'hitori/character.model3.json',
        'hitori/textures/texture_00.png',
        '__MACOSX/hitori/._character.model3.json',
        'hitori/.DS_Store',
        '../evil.txt',
      ], {
        'hitori/character.model3.json': modelJson,
        'hitori/textures/texture_00.png': [1, 2, 3],
        '__MACOSX/hitori/._character.model3.json': utf8.encode('junk'),
        'hitori/.DS_Store': utf8.encode('junk'),
        '../evil.txt': utf8.encode('evil'),
      }),
    );

    final models = await Live2DZipImport.importBytes(
      zip,
      zipName: 'hitori.zip',
      targetDir: tempDir,
    );

    expect(models, hasLength(1));
    final model = models.single;
    expect(model.label, 'hitori');
    expect(model.modelFile, 'character.model3.json');
    expect(model.modelDir, '${tempDir.path}/hitori/');
    expect(model.motions, hasLength(1));
    expect(model.motions.single.label, '待机');
    // 垃圾文件与目录穿越条目不落盘
    expect(await File(p.join(tempDir.path, 'hitori', '.DS_Store')).exists(),
        isFalse);
    expect(await File(p.join(tempDir.parent.path, 'evil.txt')).exists(),
        isFalse);
  });

  test('多模型 zip 按目录深度排序，浅层在前', () async {
    final emptyJson = utf8.encode(jsonEncode({'FileReferences': {}}));
    final zip = ZipEncoder().encode(
      buildZip([
        'pack/inner/deep.model3.json',
        'pack/top.model3.json',
      ], {
        'pack/inner/deep.model3.json': emptyJson,
        'pack/top.model3.json': emptyJson,
      }),
    );

    final models = await Live2DZipImport.importBytes(
      zip,
      zipName: 'pack.zip',
      targetDir: tempDir,
    );

    expect(models, hasLength(2));
    expect(models.first.modelFile, 'top.model3.json');
    expect(models.first.label, 'pack');
    expect(models.last.label, 'pack · deep');
  });

  test('无 model3.json 的 zip 返回空列表并清理目录', () async {
    final zip = ZipEncoder().encode(
      buildZip(['readme.txt'], {'readme.txt': utf8.encode('hi')}),
    );

    final models = await Live2DZipImport.importBytes(
      zip,
      zipName: 'plain.zip',
      targetDir: tempDir,
    );

    expect(models, isEmpty);
    expect(await tempDir.exists(), isFalse);
  });

  test('导入记录序列化 roundtrip 保留动作', () {
    final model = Live2DModelDefinition(
      label: 'hitori',
      modelDir: '/somewhere/hitori/',
      modelFile: 'character.model3.json',
      thumbPath: 'live2d_thumbs/hitori.webp',
      motions: const [
        Live2DMotionDefinition(
          group: 'Idle',
          index: 0,
          label: '待机',
          hasSound: true,
        ),
      ],
    );

    final restored = importedModelFromJson(importedModelToJson(model));

    expect(restored.label, model.label);
    expect(restored.modelDir, model.modelDir);
    expect(restored.modelFile, model.modelFile);
    expect(restored.thumbPath, model.thumbPath);
    expect(restored.motions.single.group, 'Idle');
    expect(restored.motions.single.hasSound, isTrue);
  });

  test('parseModels 解析并继承 thumbUrl', () {
    final catalog = {
      'models': {
        'name': 'Eikanya/Live2d-model',
        'thumbUrl': 'https://example.com/cover.png',
        'children': [
          {
            'name': 'group',
            'children': [
              {
                'name': '001',
                'thumbUrl': 'pics/001.png',
                'files': ['a/xxx.model3.json'],
              },
              {'name': '002', 'files': ['b/yyy.model3.json']},
            ],
          },
        ],
      },
    };

    final items = Live2DOnlineCatalog.parseModels(catalog);

    expect(items, hasLength(2));
    // 自身相对路径 → 拼 CDN 前缀
    expect(
      items.first.thumbUrl,
      'https://cdn.jsdelivr.net/gh/Eikanya/Live2d-model@master/pics/001.png',
    );
    // 无自身 thumbUrl → 继承祖先的绝对 URL
    expect(items.last.thumbUrl, 'https://example.com/cover.png');
  });

  test('modelDefinitionForArchive 匹配导入记录时带回动作列表', () {
    final archive = Live2DArchive(
      id: 'a1',
      name: '测试',
      modelLabel: 'hitori',
      modelDir: '/somewhere/hitori/',
      modelFile: 'character.model3.json',
      agentId: null,
    );
    final imported = [
      Live2DModelDefinition(
        label: 'hitori',
        modelDir: '/somewhere/hitori/',
        modelFile: 'character.model3.json',
        motions: const [
          Live2DMotionDefinition(group: 'Idle', index: 0, label: '待机'),
        ],
      ),
    ];

    final matched = modelDefinitionForArchive(
      archive,
      importedModels: imported,
    );

    expect(matched, isNotNull);
    expect(matched!.motions, hasLength(1));
    // 未匹配导入记录时回退为无动作定义
    final fallback = modelDefinitionForArchive(archive, importedModels: const []);
    expect(fallback!.motions, isEmpty);
  });
}
