import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_import.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';

const _webpBase64 =
    'UklGRnoAAABXRUJQVlA4WAoAAAAQAAAAAwAAAQAAQUxQSAkAAAAA/wD/AAAAAAAAVlA4IEoAAACwAgCdASoEAAIAAkA4JagCdLoB+AH4gM4AyQAHugAA/uLq9tR1fu/9UwcuikwBkGvtw//Kv/8sD2DXyoeHWd/+WB7Br5UP/OMAAA==';

const _sheet = VideoPetSpritesheet(
  frameWidth: 192,
  frameHeight: 108,
  columns: 10,
  rows: 13,
  frameCount: 121,
  fps: 12,
);
const _animation = VideoPetAnimation(
  id: 'idle',
  name: '待机',
  sources: {'png': 'spritesheet/待机.png'},
  spritesheet: _sheet,
);
const _manifest = VideoPetManifest(
  id: 'pet',
  name: '宠物',
  animations: [_animation],
  idleAnimationId: 'idle',
);
const _region = VideoPetRegion(
  id: 'head',
  name: '头',
  x: .2,
  y: .2,
  width: .4,
  height: .4,
);

Uint8List _zip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

List<int> _jsonBytes(VideoPetManifest manifest) =>
    utf8.encode(jsonEncode(manifest.toJson()));

// Build a legacy-name stored ZIP with a valid Info-ZIP 0x7075 path field.
Uint8List _legacyUnicodeZip() {
  final body = BytesBuilder();
  final directory = BytesBuilder();
  List<int> u16(int value) =>
      (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List();
  List<int> u32(int value) =>
      (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();
  final manifest = _manifest.copyWith(
    animations: [
      _animation.copyWith(sources: {'png': '待机.png'}),
    ],
  );
  final entries = <List<int>, List<int>>{
    ascii.encode('manifest.json'): _jsonBytes(manifest),
    [0xb4, 0xfd, 0xbb, 0xfa, ...ascii.encode('.png')]: [1, 2, 3],
  };
  var index = 0;
  for (final entry in entries.entries) {
    final name = entry.key;
    final data = entry.value;
    final unicode = utf8.encode(index++ == 0 ? 'manifest.json' : '待机.png');
    final extra = [
      ...u16(0x7075),
      ...u16(5 + unicode.length),
      1,
      ...u32(getCrc32(name)),
      ...unicode,
    ];
    final offset = body.length;
    body.add([
      ...u32(0x04034b50),
      ...u16(20),
      ...u16(0),
      ...u16(0),
      ...u16(0),
      ...u16(0),
      ...u32(getCrc32(data)),
      ...u32(data.length),
      ...u32(data.length),
      ...u16(name.length),
      ...u16(extra.length),
      ...name,
      ...extra,
      ...data,
    ]);
    directory.add([
      ...u32(0x02014b50),
      ...u16(20),
      ...u16(20),
      ...u16(0),
      ...u16(0),
      ...u16(0),
      ...u16(0),
      ...u32(getCrc32(data)),
      ...u32(data.length),
      ...u32(data.length),
      ...u16(name.length),
      ...u16(extra.length),
      ...u16(0),
      ...u16(0),
      ...u16(0),
      ...u32(0),
      ...u32(offset),
      ...name,
      ...extra,
    ]);
  }
  final centralOffset = body.length;
  body.add(directory.toBytes());
  body.add([
    ...u32(0x06054b50),
    ...u16(0),
    ...u16(0),
    ...u16(entries.length),
    ...u16(entries.length),
    ...u32(directory.length),
    ...u32(centralOffset),
    ...u16(0),
  ]);
  return body.toBytes();
}

class _FixtureImportService extends VideoPetImportService {
  const _FixtureImportService(this.manifest) : super(persistToDisk: false);

  final VideoPetManifest manifest;

  @override
  Future<VideoPetPackage> loadDefault() async => VideoPetPackage(
    manifest: manifest,
    baseUri: 'assets/live2d/video/dsh_pet/',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'JSON round trip, old schema fallback and immutable parsed collections',
    () {
      final parsed = VideoPetManifest.fromJson(
        _manifest
            .copyWith(
              regions: [_region.copyWith(click: const VideoPetBinding())],
              metadata: {'source': '测试'},
            )
            .toJson(),
      );
      expect(
        VideoPetManifest.fromJson(parsed.toJson()).toJson(),
        parsed.toJson(),
      );
      expect(parsed.schemaVersion, 1);
      expect(parsed.animation('idle')?.name, '待机');
      expect(parsed.animation('missing'), isNull);
      expect(() => parsed.animations.add(_animation), throwsUnsupportedError);
      expect(
        () => parsed.animation('idle')!.sources['mov'] = 'a.mov',
        throwsUnsupportedError,
      );
      expect(parsed.animation('idle')!.spritesheet, _sheet);
      expect(() => parsed.metadata['foo'] = true, throwsUnsupportedError);
      expect(parsed.regions.single.hover, isNull);
      expect(parsed.regions.single.click!.animationIds, isEmpty);
      expect(parsed.regions.single.copyWith(click: null).click, isNull);
      final legacy = _manifest.toJson()..remove('schemaVersion');
      expect(VideoPetManifest.fromJson(legacy).schemaVersion, 1);
    },
  );

  test('movement defaults, optional directions, roundtrip and validation', () {
    final legacy = VideoPetManifest.fromJson(
      _manifest.toJson()..remove('movement'),
    );
    expect(legacy.movement.enabled, isFalse);
    expect(legacy.movement.speed, 40);
    final defaults = VideoPetMovement.fromJson({});
    expect(defaults.speed, 40);
    expect(defaults.minIdleSeconds, 5);
    expect(defaults.maxIdleSeconds, 15);
    expect(defaults.enabled, isFalse);
    expect(defaults.dragAnimationId, isEmpty);
    final movement = defaults.copyWith(leftAnimationId: 'idle');
    expect(movement.enabled, isFalse);
    final walking = movement.copyWith(
      rightAnimationId: 'idle',
      turnLeftAnimationId: 'idle',
      turnRightAnimationId: 'idle',
      dragAnimationId: 'idle',
      speed: 60,
      minIdleSeconds: 0,
      maxIdleSeconds: 2,
    );
    final configured = _manifest.copyWith(movement: walking);
    final restored = VideoPetManifest.fromJson(configured.toJson());
    expect(restored.movement.enabled, isTrue);
    expect(restored.toJson(), configured.toJson());
    expect(configured.copyWith().movement, same(walking));
    expect(configured.copyWith(movement: null).movement, same(walking));
    for (final bad in [
      walking.copyWith(leftAnimationId: 'missing'),
      walking.copyWith(rightAnimationId: 'missing'),
      walking.copyWith(turnLeftAnimationId: 'missing'),
      walking.copyWith(turnRightAnimationId: 'missing'),
      walking.copyWith(dragAnimationId: 'missing'),
      walking.copyWith(speed: 0),
      walking.copyWith(speed: -1),
      walking.copyWith(speed: double.nan),
      walking.copyWith(minIdleSeconds: -1),
      walking.copyWith(minIdleSeconds: 3),
      walking.copyWith(maxIdleSeconds: double.infinity),
    ]) {
      expect(
        () => VideoPetManifest.fromJson(
          _manifest.copyWith(movement: bad).toJson(),
        ),
        throwsFormatException,
      );
    }
    expect(
      () =>
          VideoPetManifest.fromJson({..._manifest.toJson(), 'movement': 'bad'}),
      throwsFormatException,
    );
  });

  test('custom fixture WebP roundtrip preserves source, format and grid', () {
    final webp = _manifest.copyWith(
      animations: [
        _animation.copyWith(sources: {'webp': 'spritesheet/待机.webp'}),
      ],
    );
    final restored = VideoPetManifest.fromJson(
      jsonDecode(jsonEncode(webp.toJson())),
    );
    expect(restored.toJson(), webp.toJson());
    expect(restored.animations.single.imageFormat, 'webp');
    expect(restored.animations.single.imageSource, 'spritesheet/待机.webp');
    expect(restored.animations.single.spritesheet, _sheet);
    expect(_animation.imageFormat, 'png');
    expect(_animation.imageSource, 'spritesheet/待机.png');
    final legacy = _animation.copyWith(
      sources: {'webm': 'idle.webm', 'mov': 'idle.mov'},
      spritesheet: null,
    );
    final parsed = VideoPetManifest.fromJson(
      _manifest.copyWith(animations: [legacy]).toJson(),
    );
    expect(parsed.animations.single.imageSource, isNull);
    expect(parsed.animations.single.sources, legacy.sources);
  });

  test('custom fixture rejects conflicting image sources and metadata', () {
    for (final animation in [
      _animation.copyWith(sources: {'png': 'idle.png', 'webp': 'idle.webp'}),
      _animation.copyWith(sources: {'webp': 'idle.webp', 'webm': 'idle.webm'}),
      _animation.copyWith(sources: {'webp': 'idle.webp'}, spritesheet: null),
      _animation.copyWith(spritesheet: null),
      _animation.copyWith(sources: {'webm': 'idle.webm'}),
      _animation.copyWith(sources: {'webp': 'idle.png'}),
      _animation.copyWith(sources: {'png': 'idle.webp'}),
      _animation.copyWith(sources: {'webp': 'data:image/png;base64,AQID'}),
      _animation.copyWith(sources: {'png': 'data:image/webp;base64,AQID'}),
    ]) {
      expect(
        () => VideoPetManifest.fromJson(
          _manifest.copyWith(animations: [animation]).toJson(),
        ),
        throwsFormatException,
        reason: animation.sources.toString(),
      );
    }
  });

  test('copyWith snapshots input collections without mutating original', () {
    final list = <VideoPetAnimation>[_animation];
    final copy = _manifest.copyWith(name: '新名字', animations: list);
    list.clear();
    expect(copy.animations.length, 1);
    expect(_manifest.name, '宠物');
  });

  test(
    'validation rejects duplicate IDs, unknown references, schema and invalid geometry',
    () {
      final invalid = <VideoPetManifest>[
        _manifest.copyWith(schemaVersion: 2),
        _manifest.copyWith(animations: [_animation, _animation]),
        _manifest.copyWith(idleAnimationId: 'missing'),
        _manifest.copyWith(canvasWidth: double.nan),
        _manifest.copyWith(canvasHeight: 0),
        _manifest.copyWith(
          hover: const VideoPetBinding(animationIds: ['missing']),
        ),
        _manifest.copyWith(click: const VideoPetBinding(strategy: 'shuffle')),
        _manifest.copyWith(regions: [_region, _region]),
        _manifest.copyWith(regions: [_region.copyWith(x: -.1)]),
        _manifest.copyWith(regions: [_region.copyWith(width: .9)]),
        _manifest.copyWith(
          regions: [_region.copyWith(height: double.infinity)],
        ),
        _manifest.copyWith(
          regions: [
            _region.copyWith(
              click: const VideoPetBinding(animationIds: ['missing']),
            ),
          ],
        ),
        _manifest.copyWith(
          animations: [
            _animation.copyWith(sources: {'webm': 'javascript:alert(1)'}),
          ],
        ),
        _manifest.copyWith(
          animations: [
            _animation.copyWith(sources: {'mp4': 'a.mp4'}),
          ],
        ),
      ];
      for (final manifest in invalid) {
        expect(manifest.validate, throwsFormatException);
      }
      expect(
        () => VideoPetManifest.fromJson({
          ..._manifest.toJson(),
          'schemaVersion': 2,
        }),
        throwsFormatException,
      );
      expect(
        () => VideoPetManifest.fromJson({
          ..._manifest.toJson(),
          'animations': ['bad'],
        }),
        throwsFormatException,
      );
      expect(
        () => VideoPetManifest.fromJson({
          ..._manifest.toJson(),
          'canvasWidth': 'wide',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'hitTest chooses highest enabled priority and preserves stable ties',
    () {
      final manifest = _manifest.copyWith(
        regions: [
          _region,
          _region.copyWith(id: 'higher', priority: 5),
          _region.copyWith(id: 'tie', priority: 5),
          _region.copyWith(id: 'disabled', priority: 100, enabled: false),
        ],
      );
      expect(manifest.hitTest(.4, .4)?.id, 'higher');
      expect(manifest.hitTest(.2, .2)?.id, 'higher');
      expect(manifest.hitTest(.9, .9), isNull);
      for (final point in [-.1, 1.1, double.nan, double.infinity]) {
        expect(manifest.hitTest(point, .4), isNull);
        expect(manifest.hitTest(.4, point), isNull);
      }
    },
  );

  test(
    'source resolution uses Uri.resolve for assets, files, HTTP and mappings',
    () {
      for (final base in [
        'assets/pet/',
        'file:///D:/pet/',
        'https://example.com/pet/',
      ]) {
        expect(
          _animation.resolveSource('png', Uri.parse(base)),
          Uri.parse(base).resolve('spritesheet/待机.png'),
        );
      }
      expect(_animation.resolveSource('mov', Uri.parse('assets/')), isNull);
      final package = VideoPetPackage(
        manifest: _manifest,
        baseUri: 'assets/pet/',
        resolvedSources: {
          Uri.parse('assets/pet/').resolve('spritesheet/待机.png').toString():
              'data:image/png;base64,AQID',
        },
      );
      expect(
        package.resolveSource('spritesheet/待机.png'),
        'data:image/png;base64,AQID',
      );
    },
  );

  const memoryService = VideoPetImportService(persistToDisk: false);
  test('custom legacy video-only package is rejected for playback', () async {
    const legacy = VideoPetManifest(
      id: 'custom-pet',
      name: '旧自定义包',
      animations: [
        VideoPetAnimation(
          id: 'idle',
          name: '待机',
          sources: {'webm': 'idle.webm'},
        ),
      ],
      idleAnimationId: 'idle',
    );
    await expectLater(
      memoryService.prepareForPlayback(legacy, baseUri: 'file:///tmp/'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('转换为 PNG/WebP'),
        ),
      ),
    );
  });

  test(
    'legacy GBK ZIP restores Chinese names using Unicode Path metadata',
    () async {
      final package = await memoryService.importBytes(
        _legacyUnicodeZip(),
        fileName: 'legacy.zip',
      );
      expect(
        Uri.parse(package.resolveSource('待机.png')).data!.contentAsBytes(),
        [1, 2, 3],
      );
    },
  );

  test(
    'nested Chinese ZIP resources produce serializable persistent data URI mappings',
    () async {
      final bytes = _zip({
        '宠物/manifest.json': _jsonBytes(_manifest),
        '宠物/spritesheet/待机.png': [1, 2, 3],
      });
      final package = await memoryService.importBytes(
        bytes,
        fileName: '宠物.zip',
      );
      final restored = VideoPetPackage(
        manifest: VideoPetManifest.fromJson(
          jsonDecode(jsonEncode(package.manifest.toJson())),
        ),
        baseUri: package.baseUri,
        resolvedSources: Map<String, String>.from(
          jsonDecode(jsonEncode(package.resolvedSources)),
        ),
      );
      final uri = Uri.parse(restored.resolveSource(_animation.sources['png']!));
      expect(uri.data!.mimeType, 'image/png');
      expect(uri.data!.contentAsBytes(), [1, 2, 3]);
    },
  );

  test('custom fixture WebP ZIP and JSON survive serialization', () async {
    final bytes = base64Decode(_webpBase64);
    final webp = _manifest.copyWith(
      animations: [
        _animation.copyWith(sources: {'webp': 'spritesheet/待机.webp'}),
      ],
    );
    final imported = await memoryService.importBytes(
      _zip({
        '宠物/manifest.json': _jsonBytes(webp),
        '宠物/spritesheet/待机.webp': bytes,
      }),
      fileName: 'pet.zip',
    );
    final restored = VideoPetPackage(
      manifest: VideoPetManifest.fromJson(
        jsonDecode(jsonEncode(imported.manifest.toJson())),
      ),
      baseUri: imported.baseUri,
      resolvedSources: Map<String, String>.from(
        jsonDecode(jsonEncode(imported.resolvedSources)),
      ),
    );
    final uri = Uri.parse(
      restored.resolveSource(restored.manifest.animations.single.imageSource!),
    );
    expect(uri.data!.mimeType, 'image/webp');
    expect(uri.data!.contentAsBytes(), bytes);
    for (final source in [
      uri.toString(),
      'https://example.com/待机.webp?version=2',
    ]) {
      final result = await memoryService.importBytes(
        Uint8List.fromList(
          _jsonBytes(
            webp.copyWith(
              animations: [
                _animation.copyWith(sources: {'webp': source}),
              ],
            ),
          ),
        ),
        fileName: 'pet.json',
      );
      expect(result.resolveSource(source), Uri.parse(source).toString());
      expect(result.manifest.animations.single.imageFormat, 'webp');
    }
    await expectLater(
      memoryService.importBytes(
        _zip({'manifest.json': _jsonBytes(webp)}),
        fileName: 'missing.zip',
      ),
      throwsFormatException,
    );
  });

  test(
    'ZIP rejects missing sources, ambiguity and directory traversal',
    () async {
      final samples = [
        {'manifest.json': _jsonBytes(_manifest)},
        {
          'one/manifest.json': _jsonBytes(_manifest),
          'two/manifest.json': _jsonBytes(_manifest),
        },
        {
          'manifest.json': _jsonBytes(_manifest),
          '../escape.png': [1],
        },
        {
          'manifest.json': _jsonBytes(_manifest),
          '/escape.png': [1],
        },
        {
          'manifest.json': _jsonBytes(_manifest),
          'C:/escape.png': [1],
        },
        {
          'manifest.json': _jsonBytes(
            _manifest.copyWith(
              animations: [
                _animation.copyWith(sources: {'png': '../../outside.png'}),
              ],
            ),
          ),
        },
      ];
      for (final files in samples) {
        await expectLater(
          memoryService.importBytes(_zip(files), fileName: 'bad.zip'),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'Web JSON requires standalone resources and accepts HTTP/data sources',
    () async {
      await expectLater(
        memoryService.importBytes(
          Uint8List.fromList(_jsonBytes(_manifest)),
          fileName: 'pet.json',
        ),
        throwsFormatException,
      );
      for (final source in [
        'https://example.com/a.png',
        'data:image/png;base64,AQID',
      ]) {
        final manifest = _manifest.copyWith(
          animations: [
            _animation.copyWith(sources: {'png': source}),
          ],
        );
        final result = await memoryService.importBytes(
          Uint8List.fromList(_jsonBytes(manifest)),
          fileName: 'pet.json',
        );
        expect(result.resolveSource(source), source);
      }
    },
  );

  test(
    'native ZIP and local JSON copy media to persistent application directory',
    () async {
      final temp = Directory.systemTemp.createTempSync('video_pet_test_');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => temp.path);
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await temp.delete(recursive: true);
      });
      const service = VideoPetImportService();
      final zipPackage = await service.importBytes(
        _zip({
          '中文/manifest.json': _jsonBytes(_manifest),
          '中文/spritesheet/待机.png': [4, 5, 6],
        }),
        fileName: 'pet.zip',
      );
      expect(
        await File.fromUri(
          Uri.parse(zipPackage.resolveSource(_animation.sources['png']!)),
        ).readAsBytes(),
        [4, 5, 6],
      );
      final original = File.fromUri(temp.uri.resolve('spritesheet/待机.png'));
      await original.parent.create(recursive: true);
      await original.writeAsBytes([7, 8, 9]);
      final jsonPackage = await service.importBytes(
        Uint8List.fromList(_jsonBytes(_manifest)),
        fileName: 'manifest.json',
        sourceUri: temp.uri.resolve('manifest.json').toString(),
      );
      await original.delete();
      expect(
        await File.fromUri(
          Uri.parse(jsonPackage.resolveSource(_animation.sources['png']!)),
        ).readAsBytes(),
        [7, 8, 9],
      );
    },
  );

  test('custom fixture WebP and PNG imports persist correct files', () async {
    final temp = Directory.systemTemp.createTempSync('video_pet_webp_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => temp.path);
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await temp.delete(recursive: true);
    });
    const service = VideoPetImportService();
    for (final format in ['webp', 'png']) {
      final bytes = format == 'webp' ? base64Decode(_webpBase64) : [7, 8, 9];
      final source = 'spritesheet/待机.$format';
      final manifest = _manifest.copyWith(
        animations: [
          _animation.copyWith(sources: {format: source}),
        ],
      );
      final zipped = await service.importBytes(
        _zip({'宠物/manifest.json': _jsonBytes(manifest), '宠物/$source': bytes}),
        fileName: 'pet.zip',
      );
      final zipFile = File.fromUri(Uri.parse(zipped.resolveSource(source)));
      expect(zipFile.path, endsWith('.$format'));
      expect(await zipFile.readAsBytes(), bytes);
      final original = File.fromUri(
        temp.uri.resolve(Uri(path: source).toString()),
      );
      await original.parent.create(recursive: true);
      await original.writeAsBytes(bytes);
      final imported = await service.importBytes(
        Uint8List.fromList(_jsonBytes(manifest)),
        fileName: 'manifest.json',
        sourceUri: temp.uri.resolve('manifest.json').toString(),
      );
      final copied = Uri.parse(imported.resolveSource(source));
      expect(copied.path, endsWith('/media/0.$format'));
      await original.delete();
      expect(await File.fromUri(copied).readAsBytes(), bytes);
      final storedManifest = File.fromUri(copied.resolve('../manifest.json'));
      final reimported = await service.importBytes(
        await storedManifest.readAsBytes(),
        fileName: 'manifest.json',
        sourceUri: storedManifest.uri.toString(),
      );
      expect(
        await File.fromUri(
          Uri.parse(
            reimported.resolveSource(
              reimported.manifest.animations.single.imageSource!,
            ),
          ),
        ).readAsBytes(),
        bytes,
      );
      await original.writeAsBytes(bytes);
      final memory = await memoryService.importBytes(
        Uint8List.fromList(_jsonBytes(manifest)),
        fileName: 'manifest.json',
        sourceUri: temp.uri.resolve('manifest.json').toString(),
      );
      await original.delete();
      final data = Uri.parse(memory.resolveSource(source)).data!;
      expect(data.mimeType, 'image/$format');
      expect(data.contentAsBytes(), bytes);
    }
  });

  test(
    'custom fixture refreshes bundled PNG and migrates legacy video',
    () async {
      const freshSheet = VideoPetSpritesheet(
        frameWidth: 640,
        frameHeight: 360,
        columns: 10,
        rows: 12,
        frameCount: 120,
        fps: 12,
      );
      final fresh = _manifest.copyWith(
        id: 'dsh-pet',
        animations: [
          _animation.copyWith(
            sources: {'webp': 'spritesheet/待机.webp'},
            spritesheet: freshSheet,
          ),
        ],
      );
      final service = _FixtureImportService(fresh);
      final saved = fresh.copyWith(
        name: '我的宠物',
        animations: [_animation.copyWith(name: '自定义待机', category: '我的分类')],
        hover: const VideoPetBinding(
          animationIds: ['idle'],
          strategy: 'sequence',
        ),
        click: const VideoPetBinding(animationIds: ['idle']),
        regions: [_region.copyWith(click: const VideoPetBinding())],
      );
      final prepared = await service.prepareForPlayback(
        saved,
        baseUri: 'assets/live2d/video/dsh_pet/',
      );
      expect(
        prepared.manifest.toJson(),
        saved
            .copyWith(
              animations: [
                saved.animations.single.copyWith(
                  sources: fresh.animations.single.sources,
                  spritesheet: freshSheet,
                ),
              ],
            )
            .toJson(),
      );
      final mapping = {
        'assets/live2d/video/dsh_pet/spritesheet/待机.png':
            'data:image/png;base64,AQID',
      };
      for (final package in [
        await service.prepareForPlayback(saved, baseUri: 'file:///saved-copy/'),
        await service.prepareForPlayback(
          saved,
          baseUri: 'assets/live2d/video/dsh_pet/',
          resolvedSources: mapping,
        ),
        await service.prepareForPlayback(
          saved.copyWith(id: 'custom'),
          baseUri: 'assets/live2d/video/dsh_pet/',
        ),
      ]) {
        expect(package.manifest.animations.single.imageFormat, 'png');
        expect(package.manifest.animations.single.spritesheet, _sheet);
      }
      final mapped = await service.prepareForPlayback(
        saved,
        baseUri: 'assets/live2d/video/dsh_pet/',
        resolvedSources: mapping,
      );
      expect(mapped.resolvedSources, mapping);
      final legacy = saved.copyWith(
        animations: [
          saved.animations.single.copyWith(
            sources: {'webm': 'idle.webm', 'mov': 'idle.mov'},
            spritesheet: null,
          ),
        ],
      );
      final migrated = await service.prepareForPlayback(
        VideoPetManifest.fromJson(legacy.toJson()),
        baseUri: 'https://old.example/',
        resolvedSources: const {'idle.webm': 'data:video/webm;base64,AA=='},
      );
      expect(migrated.manifest.toJson(), prepared.manifest.toJson());
      expect(migrated.baseUri, prepared.baseUri);
      expect(migrated.resolvedSources, isEmpty);
    },
  );

  test('legacy built-in manifest migrates to bundled WebP resources', () async {
    const service = VideoPetImportService(persistToDisk: false);
    final defaults = await service.loadDefault();
    final legacy = defaults.manifest.copyWith(
      animations: [
        for (final animation in defaults.manifest.animations)
          animation.copyWith(
            sources: {'webm': 'webm/${animation.id}.webm'},
            spritesheet: null,
          ),
      ],
    );
    final prepared = await service.prepareForPlayback(
      legacy,
      baseUri: 'https://old.example/video/',
      resolvedSources: const {
        'https://old.example/video/webm/待机呼吸休闲.webm':
            'data:video/webm;base64,AA==',
      },
    );
    expect(prepared.baseUri, defaults.baseUri);
    expect(prepared.resolvedSources, isEmpty);
    expect(prepared.manifest.animations, hasLength(106));
    expect(
      prepared.manifest.animations.every((a) => a.sources.keys.length == 1),
      isTrue,
    );
    expect(
      prepared.manifest.animations.every((a) => a.imageFormat == 'webp'),
      isTrue,
    );
    expect(
      prepared.manifest.animations.every((a) => a.spritesheet != null),
      isTrue,
    );
  });

  test(
    'saved bundled PNG grids refresh without losing interaction edits',
    () async {
      const service = VideoPetImportService(persistToDisk: false);
      final defaults = await service.loadDefault();
      final saved = VideoPetManifest.fromJson(
        defaults.manifest
            .copyWith(
              name: '我的宠物',
              regions: [_region],
              click: const VideoPetBinding(),
              animations: [
                for (final animation in defaults.manifest.animations)
                  animation.copyWith(
                    name: '自定义 ${animation.name}',
                    sources: {'png': 'spritesheet/${animation.id}.png'},
                    spritesheet: _sheet,
                  ),
              ],
            )
            .toJson(),
      );
      final prepared = await service.prepareForPlayback(
        saved,
        baseUri: defaults.baseUri,
      );
      expect(prepared.manifest.name, saved.name);
      expect(prepared.manifest.regions.single.toJson(), _region.toJson());
      expect(prepared.manifest.click.toJson(), saved.click.toJson());
      expect(prepared.manifest.hover.toJson(), saved.hover.toJson());
      expect(prepared.manifest.idleAnimationId, saved.idleAnimationId);
      for (final animation in prepared.manifest.animations) {
        final bundled = defaults.manifest.animation(animation.id)!;
        expect(animation.name, '自定义 ${bundled.name}');
        expect(animation.sources, bundled.sources);
        expect(animation.spritesheet, bundled.spritesheet);
      }
      final copied = await service.prepareForPlayback(
        saved,
        baseUri: 'file:///saved-copy/',
      );
      expect(copied.manifest.animations.first.spritesheet, _sheet);
      final mapped = await service.prepareForPlayback(
        saved,
        baseUri: defaults.baseUri,
        resolvedSources: const {'old.png': 'data:image/png;base64,AA=='},
      );
      expect(mapped.manifest.animations.first.spritesheet, _sheet);
      expect(mapped.resolvedSources, isNotEmpty);
    },
  );

  test('default asset manifest contains 106 WebP spritesheets', () async {
    const service = VideoPetImportService();
    final package = await service.loadDefault();
    expect(package.baseUri, 'assets/live2d/video/dsh_pet/');
    expect(package.manifest.animations.length, 106);
    expect(package.manifest.canvasWidth, 640);
    expect(package.manifest.canvasHeight, 360);
    expect(package.manifest.idleAnimationId, '待机呼吸休闲');
    expect(package.manifest.click.animationIds.length, 5);
    for (final animation in package.manifest.animations) {
      expect(animation.sources.keys, ['webp']);
      final sheet = animation.spritesheet!;
      expect(sheet.frameWidth, 640);
      expect(sheet.frameHeight, 360);
      expect(sheet.fps, 12);
      expect(sheet.columns, 8);
      expect(sheet.frameCount, anyOf(59, 120));
      if (sheet.frameCount == 120) expect(sheet.rows, 15);
      final source = animation.imageSource!;
      final file = File.fromUri(Uri.parse(package.resolveSource(source)));
      expect(file.existsSync(), isTrue, reason: source);
      expect(file.lengthSync(), inExclusiveRange(0, 1000000));
    }
    expect(
      package.manifest.metadata['commit'],
      'b78e3fcf92ac78cee569aed7cc27eeb2a8d51757',
    );
  });
}
