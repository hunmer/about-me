import 'dart:io';

import 'package:aboutme/plugins/live2d/live2d_asset_paths.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temporary;
  late String support;
  const oldSupport =
      '/var/mobile/Containers/Data/Application/OLD/Library/Application Support';

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('live2d_paths_');
    support = p.join(temporary.path, 'Library', 'Application Support');
  });

  tearDown(() async => temporary.delete(recursive: true));

  test('迁移模型和视频包 URI，包括动作图片音频及映射', () async {
    final model = File(
      p.join(support, 'live2d_models', 'zip_1', 'avatar.model3.json'),
    );
    final image = File(
      p.join(support, 'video_pet_packages', 'pack_1', 'media', 'idle.png'),
    );
    final audio = File(
      p.join(support, 'video_pet_packages', 'pack_1', 'media', 'idle.mp3'),
    );
    for (final file in [model, image, audio]) {
      await file.parent.create(recursive: true);
      await file.writeAsString('test');
    }
    final oldModel = '$oldSupport/live2d_models/zip_1/';
    final oldImage = Uri.file(
      '$oldSupport/video_pet_packages/pack_1/media/idle.png',
    ).toString();
    final oldAudio = Uri.file(
      '$oldSupport/video_pet_packages/pack_1/media/idle.mp3',
    ).toString();
    final migrated = relocateLive2DAssetPaths({
      'modelDir': oldModel,
      'videoBaseUri': Uri.directory(
        '$oldSupport/video_pet_packages/pack_1',
      ).toString(),
      'videoManifest': {
        'animations': [
          {
            'sources': {'png': oldImage},
            'audio': oldAudio,
          },
        ],
      },
      'videoResolvedSources': {
        'https://example.com/idle.png': oldImage,
        oldAudio: oldImage,
      },
      'tapMessages': {'head': 'hello'},
      'external': 'https://example.com/model',
    }, support)!;

    expect(migrated['modelDir'], '${model.parent.path}/');
    expect(
      migrated['videoBaseUri'],
      Uri.directory(image.parent.parent.path).toString(),
    );
    final animations = (migrated['videoManifest'] as Map)['animations'] as List;
    expect((animations.first['sources'] as Map)['png'], image.uri.toString());
    expect(animations.first['audio'], audio.uri.toString());
    expect(
      (migrated['videoResolvedSources'] as Map)['https://example.com/idle.png'],
      image.uri.toString(),
    );
    expect(
      (migrated['videoResolvedSources'] as Map)[audio.uri.toString()],
      image.uri.toString(),
    );
    expect(migrated['tapMessages'], isA<Map<String, dynamic>>());
    expect(migrated['external'], 'https://example.com/model');
    expect(relocateLive2DAssetPaths(migrated, support), isNull);
  });

  test('目标文件不存在或源不属于应用管理目录时不修改', () {
    expect(
      relocateLive2DAssetPaths({
        'modelDir': '$oldSupport/live2d_models/lost/model3.json',
        'external': '/private/Documents/live2d_models/user/model3.json',
      }, support),
      isNull,
    );
  });
}
