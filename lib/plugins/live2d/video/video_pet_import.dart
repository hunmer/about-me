import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'video_pet_manifest.dart';
import 'video_pet_import_stub.dart'
    if (dart.library.io) 'video_pet_import_io.dart'
    as platform;

class VideoPetPackage {
  const VideoPetPackage({
    required this.manifest,
    required this.baseUri,
    this.resolvedSources = const {},
  });

  final VideoPetManifest manifest;
  final String baseUri;

  /// Keys are baseUri.resolve(source); values are persistent file or data URIs.
  final Map<String, String> resolvedSources;

  String resolveSource(String source) {
    final resolved = Uri.parse(baseUri).resolve(source).toString();
    return resolvedSources[resolved] ?? resolved;
  }
}

class VideoPetImportService {
  const VideoPetImportService({this.persistToDisk = true});

  /// False keeps ZIP media in persistent data URI mappings (also used on Web).
  final bool persistToDisk;

  Future<VideoPetPackage> loadDefault() async => VideoPetPackage(
    manifest: _decode(
      await rootBundle.loadString(kDefaultVideoPetManifestAsset),
    ),
    baseUri: Uri.parse(kDefaultVideoPetManifestAsset).resolve('.').toString(),
  );

  /// Prepares a parsed package for the spritesheet-only runtime.
  ///
  /// Built-in manifests are refreshed from bundled metadata by animation id
  /// when using bundled assets, whose grids can change between app versions.
  /// Legacy video mappings are dropped during migration. Custom video-only
  /// packages fail with a conversion error instead of falling back to video.
  Future<VideoPetPackage> prepareForPlayback(
    VideoPetManifest manifest, {
    String? baseUri,
    Map<String, String> resolvedSources = const {},
  }) async {
    manifest.validate();
    final isBuiltIn = manifest.id == 'dsh-pet';
    final needsMigration = manifest.animations.any(
      (animation) =>
          animation.spritesheet == null || animation.imageSource == null,
    );
    final bundledBase = Uri.parse(
      kDefaultVideoPetManifestAsset,
    ).resolve('.').toString();
    final usesBundledAssets =
        resolvedSources.isEmpty &&
        (baseUri == null || baseUri.isEmpty || baseUri == bundledBase);
    if (isBuiltIn && (needsMigration || usesBundledAssets)) {
      final defaults = await loadDefault();
      final defaultById = <String, VideoPetAnimation>{
        for (final animation in defaults.manifest.animations)
          animation.id: animation,
      };
      final migrated = <VideoPetAnimation>[];
      for (final animation in manifest.animations) {
        final replacement = defaultById[animation.id];
        if (replacement == null ||
            replacement.spritesheet == null ||
            replacement.imageSource == null) {
          throw FormatException(
            '内置动作 ${animation.name} 缺少 PNG/WebP 精灵图，请先生成资源',
          );
        }
        migrated.add(
          animation.copyWith(
            sources: replacement.sources,
            spritesheet: replacement.spritesheet,
          ),
        );
      }
      var movement = _shouldFillDefaultMovement(manifest.movement)
          ? _defaultMovement(
              defaults.manifest,
              migrated,
            ).copyWith(dragAnimationId: manifest.movement.dragAnimationId)
          : manifest.movement;
      final dragId = defaults.manifest.movement.dragAnimationId;
      if (movement.dragAnimationId.isEmpty &&
          dragId.isNotEmpty &&
          migrated.any((a) => a.id == dragId)) {
        movement = movement.copyWith(dragAnimationId: dragId);
      }
      final migratedManifest = manifest.copyWith(
        animations: migrated,
        movement: movement,
      );
      migratedManifest.validate();
      return VideoPetPackage(
        manifest: migratedManifest,
        baseUri: defaults.baseUri,
      );
    }
    if (!isBuiltIn && needsMigration) {
      throw const FormatException('自定义视频宠物资源包仍使用视频源，请转换为 PNG/WebP 精灵图后再播放');
    }
    final packageBase = (baseUri == null || baseUri.isEmpty) && isBuiltIn
        ? Uri.parse(kDefaultVideoPetManifestAsset).resolve('.').toString()
        : baseUri ?? '';
    return VideoPetPackage(
      manifest: manifest,
      baseUri: packageBase,
      resolvedSources: Map.unmodifiable(resolvedSources),
    );
  }

  bool _shouldFillDefaultMovement(VideoPetMovement movement) =>
      movement.leftAnimationId.isEmpty &&
      movement.rightAnimationId.isEmpty &&
      movement.turnLeftAnimationId.isEmpty &&
      movement.turnRightAnimationId.isEmpty;
  VideoPetMovement _defaultMovement(
    VideoPetManifest defaults,
    List<VideoPetAnimation> migrated,
  ) {
    final movement = defaults.movement;
    if (movement.enabled &&
        migrated.any((animation) => animation.id == movement.leftAnimationId) &&
        migrated.any(
          (animation) => animation.id == movement.rightAnimationId,
        ) &&
        (movement.turnLeftAnimationId.isEmpty ||
            migrated.any(
              (animation) => animation.id == movement.turnLeftAnimationId,
            )) &&
        (movement.turnRightAnimationId.isEmpty ||
            migrated.any(
              (animation) => animation.id == movement.turnRightAnimationId,
            ))) {
      return movement.copyWith(dragAnimationId: '');
    }
    return const VideoPetMovement();
  }

  /// Cancellation returns null. Invalid or incomplete packages throw FormatException.
  Future<VideoPetPackage?> importPackage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'zip'],
      withData: true,
      dialogTitle: '导入精灵图宠物 JSON / ZIP',
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final source = picked.path == null ? null : platform.fileUri(picked.path!);
    final bytes =
        picked.bytes ??
        (source == null ? null : await platform.readFile(Uri.parse(source)));
    if (bytes == null) throw const FormatException('无法读取选择的文件');
    return importBytes(bytes, fileName: picked.name, sourceUri: source);
  }

  Future<VideoPetPackage> importBytes(
    Uint8List bytes, {
    required String fileName,
    String? sourceUri,
  }) async {
    if (fileName.toLowerCase().endsWith('.json')) {
      final manifest = _decode(utf8.decode(bytes));
      final base = sourceUri == null
          ? Uri()
          : Uri.parse(sourceUri).resolve('.');
      final mapping = <String, String>{};
      final files = <String, Uint8List>{'manifest.json': bytes};
      final copied = <String, String>{};
      for (final animation in manifest.animations) {
        final source = animation.imageSource;
        if (source == null) {
          throw const FormatException('导入包必须提供 PNG/WebP 精灵图，请先转换视频资源');
        }
        final uri = base.resolve(source);
        if (!uri.hasScheme && sourceUri == null) {
          throw const FormatException(
            '浏览器无法读取 JSON 旁的相对图片文件，请导入包含图片的 ZIP，或使用完整 HTTP(S) URL',
          );
        }
        if (uri.scheme == 'file' && !copied.containsKey(uri.toString())) {
          final data = await platform.readFile(uri);
          if (data == null || data.isEmpty) {
            throw FormatException('缺少精灵图资源: $uri');
          }
          final relative = 'media/${copied.length}.${animation.imageFormat}';
          copied[uri.toString()] = relative;
          files[relative] = data;
        }
      }
      if (copied.isNotEmpty) {
        final storedManifest = manifest.copyWith(
          animations: [
            for (final animation in manifest.animations)
              animation.copyWith(
                sources: {
                  animation.imageFormat!:
                      copied[base.resolve(animation.imageSource!).toString()] ??
                      base.resolve(animation.imageSource!).toString(),
                },
              ),
          ],
        );
        files['manifest.json'] = Uint8List.fromList(
          utf8.encode(jsonEncode(storedManifest.toJson())),
        );
        final savedBase = persistToDisk
            ? await platform.persistFiles(files, 'manifest.json')
            : null;
        for (final entry in copied.entries) {
          mapping[entry.key] = savedBase == null
              ? Uri.dataFromBytes(
                  files[entry.value]!,
                  mimeType: entry.value.endsWith('.webp')
                      ? 'image/webp'
                      : 'image/png',
                ).toString()
              : Uri.parse(savedBase).resolve(entry.value).toString();
        }
      }
      return VideoPetPackage(
        manifest: manifest,
        baseUri: base.toString(),
        resolvedSources: Map.unmodifiable(mapping),
      );
    }
    if (!fileName.toLowerCase().endsWith('.zip')) {
      throw const FormatException('请选择 JSON 或 ZIP 文件');
    }
    final decoder = ZipDecoder();
    final Archive archive;
    try {
      archive = decoder.decodeBytes(bytes, verify: true);
    } catch (error) {
      throw FormatException('无法读取 ZIP: $error');
    }
    final names = <String, String>{
      for (final header in decoder.directory.fileHeaders)
        header.file!.filename: _unicodeEntryName(header, bytes),
    };
    final files = <String, Uint8List>{};
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final name = _safePath(names[entry.name] ?? entry.name);
      if (name == null) continue;
      if (entry.isSymbolicLink) throw FormatException('ZIP 不支持符号链接: $name');
      if (files.containsKey(name)) throw FormatException('ZIP 文件名重复: $name');
      files[name] = Uint8List.fromList(entry.content);
    }
    final manifests = files.keys
        .where((name) => name.split('/').last.toLowerCase() == 'manifest.json')
        .toList();
    if (manifests.length != 1) {
      throw const FormatException('ZIP 必须包含唯一的 manifest.json');
    }
    final manifestPath = manifests.single;
    final manifest = _decode(utf8.decode(files[manifestPath]!));
    final root = Uri.parse('https://video-pet.invalid/${const Uuid().v4()}/');
    final base = root.resolve(_pathUri(manifestPath)).resolve('.');
    final resources = <String, Uint8List>{};
    final resourceFormats = <String, String>{};
    for (final animation in manifest.animations) {
      final source = animation.imageSource;
      if (source == null) {
        throw FormatException('动作 ${animation.name} 缺少 PNG/WebP 精灵图，请先转换资源包');
      }
      final uri = base.resolve(source);
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        if (uri.origin != root.origin) continue;
      } else {
        continue;
      }
      if (!uri.path.startsWith(root.path)) {
        throw FormatException('精灵图资源路径越界: $source');
      }
      final relative = Uri.decodeComponent(
        uri.path.substring(root.path.length),
      );
      final content = files[relative];
      if (content == null || content.isEmpty) {
        throw FormatException('ZIP 缺少精灵图资源: $source');
      }
      resources[uri.toString()] = content;
      resourceFormats[uri.toString()] = animation.imageFormat!;
    }
    final packageFiles = <String, Uint8List>{
      manifestPath: files[manifestPath]!,
      for (final entry in resources.entries)
        _zipRelativePath(root, entry.key): entry.value,
    };
    final savedBase = persistToDisk
        ? await platform.persistFiles(packageFiles, manifestPath)
        : null;
    if (savedBase != null) {
      return VideoPetPackage(manifest: manifest, baseUri: savedBase);
    }
    // Data URIs survive serialization/restarts, unlike object/blob URLs.
    return VideoPetPackage(
      manifest: manifest,
      baseUri: base.toString(),
      resolvedSources: Map.unmodifiable({
        for (final entry in resources.entries)
          entry.key: Uri.dataFromBytes(
            entry.value,
            mimeType: 'image/${resourceFormats[entry.key]}',
          ).toString(),
      }),
    );
  }
}

VideoPetManifest _decode(String text) {
  final decoded = jsonDecode(text.replaceFirst(RegExp(r'^\uFEFF'), ''));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('manifest 必须是 JSON 对象');
  }
  return VideoPetManifest.fromJson(decoded);
}

String _pathUri(String path) => Uri(pathSegments: path.split('/')).toString();

String _zipRelativePath(Uri root, String uri) {
  final parsed = Uri.parse(uri);
  if (!parsed.path.startsWith(root.path)) {
    throw FormatException('精灵图资源路径越界: $uri');
  }
  return Uri.decodeComponent(parsed.path.substring(root.path.length));
}

String? _safePath(String name) {
  final normalized = name.replaceAll('\\', '/');
  if (normalized.startsWith('/') ||
      RegExp(r'^[a-zA-Z]:').hasMatch(normalized)) {
    throw FormatException('ZIP 包含绝对路径: $name');
  }
  final segments = normalized
      .split('/')
      .where((s) => s.isNotEmpty && s != '.')
      .toList();
  if (segments.contains('..') || normalized.contains('\u0000')) {
    throw FormatException('ZIP 包含越界路径: $name');
  }
  if (segments.isEmpty ||
      segments.first == '__MACOSX' ||
      segments.contains('.DS_Store')) {
    return null;
  }
  return segments.join('/');
}

// Same Info-ZIP Unicode Path (0x7075) handling as existing Live2D imports.
String _unicodeEntryName(ZipFileHeader header, Uint8List bytes) {
  final extra = header.extraField;
  final offset = header.localHeaderOffset;
  if (extra == null || offset < 0 || offset + 30 > bytes.length) {
    return header.file!.filename;
  }
  final length = bytes[offset + 26] | (bytes[offset + 27] << 8);
  if (offset + 30 + length > bytes.length) return header.file!.filename;
  final crc = getCrc32(bytes.sublist(offset + 30, offset + 30 + length));
  final data = ByteData.sublistView(extra);
  for (var start = 0; start + 4 <= extra.length;) {
    final id = data.getUint16(start, Endian.little);
    final count = data.getUint16(start + 2, Endian.little);
    final payload = start + 4;
    final end = payload + count;
    if (end > extra.length) break;
    if (id == 0x7075 &&
        count >= 5 &&
        extra[payload] == 1 &&
        data.getUint32(payload + 1, Endian.little) == crc) {
      try {
        final name = utf8.decode(extra.sublist(payload + 5, end));
        if (name.isNotEmpty) return name;
      } on FormatException {
        // Optional invalid Unicode metadata falls back to the decoded name.
      }
    }
    start = end;
  }
  return header.file!.filename;
}
