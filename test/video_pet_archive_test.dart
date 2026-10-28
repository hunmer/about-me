import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d_models.dart';

void main() {
  const manifest = VideoPetManifest(
    id: 'test',
    name: '测试视频',
    canvasWidth: 640,
    canvasHeight: 360,
    animations: [
      VideoPetAnimation(
        id: 'idle',
        name: '待机',
        sources: {'png': 'spritesheet/待机.png'},
        spritesheet: VideoPetSpritesheet(
          frameWidth: 192,
          frameHeight: 108,
          columns: 10,
          rows: 13,
          frameCount: 121,
          fps: 12,
        ),
      ),
    ],
    idleAnimationId: 'idle',
    regions: [
      VideoPetRegion(
        id: 'head',
        name: '头部',
        x: .4,
        y: .2,
        width: .2,
        height: .3,
      ),
    ],
  );

  test('旧档案保持 Live2D 模式', () {
    final archive = Live2DArchive.fromJson({'id': 'old', 'modelLabel': 'Mao'});
    expect(archive.isVideo, isFalse);
    expect(modelDefinitionForArchive(archive)?.isVideo, isFalse);
  });

  for (final format in ['webp', 'png']) {
    test('$format 视频档案持久化包含交互配置与资源映射', () {
      final archive = Live2DArchive(
        id: 'video',
        name: '视频档案',
        modelLabel: '',
        modelDir: '',
        modelFile: '',
        agentId: null,
        displayMode: 'video',
        videoManifest: manifest.copyWith(
          animations: [
            manifest.animations.single.copyWith(
              sources: {format: 'spritesheet/待机.$format'},
            ),
          ],
        ),
        videoBaseUri: 'https://example.com/pet/',
        videoResolvedSources: {
          'https://example.com/pet/spritesheet/%E5%BE%85%E6%9C%BA.$format':
              'data:image/$format;base64,AQID',
        },
      );
      final restored = Live2DArchive.fromJson(
        jsonDecode(jsonEncode(archive.toJson())) as Map<String, dynamic>,
      );
      expect(restored.isVideo, isTrue);
      expect(restored.videoManifest!.hitTest(.5, .3)?.id, 'head');
      expect(restored.videoResolvedSources, archive.videoResolvedSources);
      final model = modelDefinitionForArchive(restored)!;
      expect(model.isVideo, isTrue);
      expect(model.modelDir, 'https://example.com/pet/');
      expect(model.label, '测试视频');
      expect(model.videoManifest?.idleAnimationId, 'idle');
      expect(model.videoManifest!.animations.single.imageFormat, format);
      expect(restored.videoManifest!.toJson(), archive.videoManifest!.toJson());
      expect(
        restored.videoManifest!.animations.single.spritesheet,
        manifest.animations.single.spritesheet,
      );
      expect(model.motions, isEmpty);
    });
  }

  test('取消编辑的档案草稿不修改原配置', () {
    final original = Live2DArchive.fromJson({
      'id': 'old',
      'modelLabel': 'Mao',
      'tapMessages': {'head': '原台词'},
    });
    final draft = Live2DArchive.fromJson(original.toJson());
    draft.displayMode = 'video';
    draft.videoManifest = manifest;
    draft.tapMessages['head'] = '新台词';
    expect(original.isVideo, isFalse);
    expect(original.tapMessages['head'], '原台词');
  });
}
