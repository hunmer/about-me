import 'dart:convert';
import 'dart:io';

import 'package:aboutme/plugins/live2d/video/video_pet_import.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _sheet = VideoPetSpritesheet(
  frameWidth: 2,
  frameHeight: 2,
  columns: 1,
  rows: 1,
  frameCount: 1,
  fps: 12,
);
const _idle = VideoPetAnimation(
  id: 'idle',
  name: 'idle',
  sources: {'webp': 'spritesheet/idle.webp'},
  spritesheet: _sheet,
);
final _manifest = VideoPetManifest(
  id: 'custom',
  name: 'custom',
  canvasWidth: 2,
  canvasHeight: 2,
  idleAnimationId: 'idle',
  animations: [_idle.copyWith(audio: 'audio/idle.m4a')],
);
Uint8List _bytes(VideoPetManifest manifest) =>
    Uint8List.fromList(utf8.encode(jsonEncode(manifest.toJson())));
Uint8List _zip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

class _Defaults extends VideoPetImportService {
  const _Defaults(this.defaults) : super(persistToDisk: false);
  final VideoPetManifest defaults;
  @override
  Future<VideoPetPackage> loadDefault() async => VideoPetPackage(
    manifest: defaults,
    baseUri: 'assets/live2d/video/dsh_pet/',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = VideoPetImportService(persistToDisk: false);

  test('bundled new animations include playable audio assets', () async {
    final package = await service.loadDefault();
    package.manifest.validate();
    for (final id in ['工作加班', '熬夜刷手机']) {
      final animation = package.manifest.animation(id)!;
      expect(animation.spritesheet!.frameCount, 360);
      expect(animation.spritesheet!.fps, 12);
      expect(animation.audio, 'audio/$id.m4a');
      final bytes = await rootBundle.load(
        Uri.decodeFull(package.resolveSource(animation.audio!)),
      );
      expect(bytes.lengthInBytes, greaterThan(0));
    }
  });

  test(
    'ZIP audio survives serialization with correct MIME and source mapping',
    () async {
      final package = await service.importBytes(
        _zip({
          'pet/manifest.json': _bytes(_manifest),
          'pet/spritesheet/idle.webp': [1, 2, 3],
          'pet/audio/idle.m4a': [4, 5, 6],
        }),
        fileName: 'pet.zip',
      );
      final mappings = Map<String, String>.from(
        jsonDecode(jsonEncode(package.resolvedSources)) as Map,
      );
      final restored = await service.prepareForPlayback(
        VideoPetManifest.fromJson(
          jsonDecode(jsonEncode(package.manifest.toJson())),
        ),
        baseUri: package.baseUri,
        resolvedSources: mappings,
      );
      final audio = Uri.parse(
        restored.resolveSource(restored.manifest.animations.single.audio!),
      ).data!;
      expect(audio.mimeType, 'audio/mp4');
      expect(audio.contentAsBytes(), [4, 5, 6]);
      expect(
        Uri.parse(restored.resolveSource(_idle.imageSource!)).data!.mimeType,
        'image/webp',
      );
    },
  );

  test('ZIP rejects missing audio and traversal references', () async {
    for (final source in [
      'audio/missing.m4a',
      '../../outside.m4a',
      '%2e%2e/%2e%2e/outside.m4a',
    ]) {
      final invalid = _manifest.copyWith(
        animations: [_idle.copyWith(audio: source)],
      );
      await expectLater(
        service.importBytes(
          _zip({
            'pet/manifest.json': _bytes(invalid),
            'pet/spritesheet/idle.webp': [1],
          }),
          fileName: 'pet.zip',
        ),
        throwsFormatException,
      );
    }
  });

  test('ZIP allows external audio without bundling it', () async {
    const source = 'https://example.com/audio.m4a';
    final manifest = _manifest.copyWith(
      animations: [_idle.copyWith(audio: source)],
    );
    final package = await service.importBytes(
      _zip({
        'manifest.json': _bytes(manifest),
        'spritesheet/idle.webp': [1],
      }),
      fileName: 'pet.zip',
    );
    expect(package.resolveSource(source), source);
    expect(package.resolvedSources.length, 1);
  });

  test(
    'local JSON copies audio and no longer relies on original files',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'video-pet-audio-',
      );
      try {
        await Directory('${directory.path}/spritesheet').create();
        await Directory('${directory.path}/audio').create();
        await File('${directory.path}/spritesheet/idle.webp').writeAsBytes([1]);
        await File('${directory.path}/audio/idle.m4a').writeAsBytes([7, 8]);
        final package = await service.importBytes(
          _bytes(_manifest),
          fileName: 'manifest.json',
          sourceUri: File('${directory.path}/manifest.json').uri.toString(),
        );
        await directory.delete(recursive: true);
        final audio = Uri.parse(package.resolveSource('audio/idle.m4a')).data!;
        expect(audio.mimeType, 'audio/mp4');
        expect(audio.contentAsBytes(), [7, 8]);
        expect(package.resolvedSources.length, 2);
      } finally {
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    },
  );

  test(
    'JSON without a base rejects relative audio even for absolute images',
    () async {
      final manifest = _manifest.copyWith(
        animations: [
          _idle.copyWith(
            sources: {'webp': 'https://example.com/idle.webp'},
            audio: 'audio/idle.m4a',
          ),
        ],
      );
      await expectLater(
        service.importBytes(_bytes(manifest), fileName: 'pet.json'),
        throwsFormatException,
      );
    },
  );

  test(
    'bundled audio refresh and new actions preserve user settings',
    () async {
      final defaults = _manifest.copyWith(
        id: 'dsh-pet',
        animations: [
          _idle.copyWith(audio: 'audio/idle.m4a'),
          _idle.copyWith(id: 'new', name: 'new', audio: 'audio/new.m4a'),
        ],
        metadata: {
          'bundledAdditions': ['new'],
        },
      );
      final service = _Defaults(defaults);
      final old = defaults.copyWith(
        animations: [_idle.copyWith(enabled: false)],
        metadata: {'custom': 42},
      );
      final prepared = await service.prepareForPlayback(old);
      expect(prepared.manifest.animation('idle')!.audio, 'audio/idle.m4a');
      expect(prepared.manifest.animation('idle')!.enabled, false);
      expect(prepared.manifest.animation('new')!.audio, 'audio/new.m4a');
      expect(prepared.manifest.metadata['custom'], 42);
      final again = await service.prepareForPlayback(prepared.manifest);
      expect(again.manifest.toJson(), prepared.manifest.toJson());
      final removed = prepared.manifest.copyWith(
        animations: [prepared.manifest.animation('idle')!],
      );
      expect(
        (await service.prepareForPlayback(removed)).manifest.animation('new'),
        isNull,
      );
      final custom = await service.prepareForPlayback(
        old,
        baseUri: 'file:///custom/',
      );
      expect(custom.manifest.animation('idle')!.audio, isNull);
      expect(custom.manifest.animation('new'), isNull);
    },
  );
}
