import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'pet_store_catalog.dart';
import 'video_pet_manifest.dart';
import 'video_pet_import_stub.dart'
    if (dart.library.io) 'video_pet_import_io.dart'
    as platform;

/// 该 manifest 是否来自宠物商店安装（metadata 携带 storePetId）。
///
/// 商店包与内置包可能共用 id（如 `dsh-pet`），但资源已各自持久化，
/// 播放准备时绝不能按内置 assets 刷新或裁剪商店包。
bool isStorePetManifest(VideoPetManifest manifest) {
  final value = manifest.metadata[kPetStoreMetadataPetId];
  return value is String && value.isNotEmpty;
}

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
    // 商店安装包不做内置刷新：其源已是绝对 file/data URI（自包含），
    // 且动作集合与内置 assets 不再一一对应。注意内置 assets manifest 本身
    // 也带 storePetId 元数据（标记商店身份供动作下载用），但其源是相对
    // 路径，仍应按内置包刷新。
    final isStoreInstall =
        isStorePetManifest(manifest) &&
        manifest.animations.any((animation) {
          final source = animation.imageSource;
          return source != null &&
              (Uri.tryParse(source)?.hasScheme ?? false);
        });
    final isBuiltIn = manifest.id == 'dsh-pet' && !isStoreInstall;
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
          // 内置包已不再附带该动作（如资源迁往商店）。降级策略：
          // 1) 自带绝对源（file:/data:/http:）且精灵图完整的动作原样保留
          //    （商店下载、编辑器导入的扩展动作不受内置裁剪影响）；
          // 2) 仍引用内置相对源的动作，仅当 assets 中文件仍存在时保留；
          // 3) 其余丢弃，稍后统一清理绑定引用。
          final source = animation.imageSource;
          final selfContained =
              source != null &&
              animation.spritesheet != null &&
              (Uri.tryParse(source)?.hasScheme ?? false);
          if (selfContained) {
            migrated.add(animation);
            continue;
          }
          if (source != null &&
              animation.spritesheet != null &&
              await _bundledAssetExists(source)) {
            migrated.add(animation);
            continue;
          }
          continue;
        }
        migrated.add(
          animation.copyWith(
            sources: replacement.sources,
            spritesheet: replacement.spritesheet,
            audio: replacement.audio,
            facing: animation.facing.isEmpty
                ? replacement.facing
                : animation.facing,
          ),
        );
      }
      if (migrated.isEmpty) {
        throw const FormatException('内置动作全部缺少 PNG/WebP 精灵图，无法降级播放');
      }
      // 仅追加明确发布的新动作；已同步过的存档不会恢复用户删除的动作。
      final additions = defaults.manifest.metadata['bundledAdditions'];
      final knownAdditions = manifest.metadata['bundledAdditions'];
      final migratedAdditions = <String>{
        if (knownAdditions is List) ...knownAdditions.whereType<String>(),
      };
      if (additions is List) {
        for (final id in additions.whereType<String>()) {
          final addition = defaultById[id];
          if (!migratedAdditions.contains(id) &&
              addition != null &&
              !migrated.any((animation) => animation.id == id)) {
            migrated.add(addition);
          }
          migratedAdditions.add(id);
        }
      }
      // 降级丢弃动作后清理所有引用，保证 validate 通过且绑定始终有效。
      final keptIds = {for (final animation in migrated) animation.id};
      final idleId = keptIds.contains(manifest.idleAnimationId)
          ? manifest.idleAnimationId
          : migrated.first.id;
      VideoPetBinding? pruneBinding(VideoPetBinding? binding) => binding?.copyWith(
              animationIds: binding.animationIds
                  .where(keptIds.contains)
                  .toList(),
            );
      final prunedMovement = _pruneMovementReferences(
        manifest.movement,
        keptIds,
      );
      var movement = _shouldFillDefaultMovement(prunedMovement)
          ? _defaultMovement(
              defaults.manifest,
              migrated,
            ).copyWith(dragAnimationId: prunedMovement.dragAnimationId)
          : prunedMovement;
      // Refresh the old built-in wait range without overriding custom ranges.
      if (movement.minIdleSeconds == 5 && movement.maxIdleSeconds == 15) {
        movement = movement.copyWith(minIdleSeconds: 10, maxIdleSeconds: 10);
      }
      final dragId = defaults.manifest.movement.dragAnimationId;
      if (movement.dragAnimationId.isEmpty &&
          dragId.isNotEmpty &&
          migrated.any((a) => a.id == dragId)) {
        movement = movement.copyWith(dragAnimationId: dragId);
      }
      // 迁移时补齐内置默认的商店关联：旧存档没有 storeActionsUrl 的话
      // 将无法解锁动作下载。只补缺失字段，用户已有的值不覆盖。
      bool missingMetadata(String key) {
        final value = manifest.metadata[key];
        return value is! String || value.isEmpty;
      }

      final defaultsMetadata = defaults.manifest.metadata;
      final migratedManifest = manifest.copyWith(
        animations: migrated,
        idleAnimationId: idleId,
        hover: pruneBinding(manifest.hover),
        click: pruneBinding(manifest.click),
        movement: movement,
        regions: [
          for (final region in manifest.regions)
            region.copyWith(
              hover: pruneBinding(region.hover),
              click: pruneBinding(region.click),
            ),
        ],
        metadata: {
          ...manifest.metadata,
          if (missingMetadata(kPetStoreMetadataPetId) &&
              defaultsMetadata[kPetStoreMetadataPetId] != null)
            kPetStoreMetadataPetId: defaultsMetadata[kPetStoreMetadataPetId],
          if (missingMetadata(kPetStoreMetadataActionsUrl) &&
              defaultsMetadata[kPetStoreMetadataActionsUrl] != null)
            kPetStoreMetadataActionsUrl:
                defaultsMetadata[kPetStoreMetadataActionsUrl],
          if (migratedAdditions.isNotEmpty)
            'bundledAdditions': migratedAdditions.toList(),
        },
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

  /// 降级丢弃动作后，清空 movement 中指向缺失动作的引用（空串=禁用）。
  VideoPetMovement _pruneMovementReferences(
    VideoPetMovement movement,
    Set<String> keptIds,
  ) {
    String clearIfMissing(String id) =>
        id.isEmpty || keptIds.contains(id) ? id : '';
    final wallBumpId = clearIfMissing(movement.wallBumpAnimationId);
    var result = movement.copyWith(
      leftAnimationId: clearIfMissing(movement.leftAnimationId),
      rightAnimationId: clearIfMissing(movement.rightAnimationId),
      turnLeftAnimationId: clearIfMissing(movement.turnLeftAnimationId),
      turnRightAnimationId: clearIfMissing(movement.turnRightAnimationId),
      dragAnimationId: clearIfMissing(movement.dragAnimationId),
      wallBumpAnimationId: wallBumpId,
    );
    if (wallBumpId.isEmpty) {
      // 撞墙动画被清空时同步清空帧区间（显式传 null 表示清除）。
      result = result.copyWith(
        wallBumpStartFrame: null,
        wallBumpEndFrame: null,
      );
    }
    return result;
  }

  /// 内置 assets 中是否仍存在 [source] 指向的资源文件。
  Future<bool> _bundledAssetExists(String source) async {
    try {
      final key = Uri.decodeFull(
        Uri.parse(kDefaultVideoPetManifestAsset)
            .resolve('.')
            .resolve(source)
            .toString(),
      );
      final data = await rootBundle.load(key);
      return data.lengthInBytes > 0;
    } catch (_) {
      return false;
    }
  }

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
        for (final resource in [source, ?animation.audio]) {
          final uri = base.resolve(resource);
          if (!uri.hasScheme && sourceUri == null) {
            throw const FormatException(
              '浏览器无法读取 JSON 旁的相对资源，请导入包含资源的 ZIP，或使用完整 HTTP(S) URL',
            );
          }
          if (uri.scheme == 'file' && !copied.containsKey(uri.toString())) {
            final data = await platform.readFile(uri);
            if (data == null || data.isEmpty) {
              throw FormatException('缺少动作资源: $uri');
            }
            final extension = resource == source
                ? animation.imageFormat!
                : audioExtension(resource);
            final relative = 'media/${copied.length}.$extension';
            copied[uri.toString()] = relative;
            files[relative] = data;
          }
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
                audio: animation.audio == null
                    ? null
                    : copied[base.resolve(animation.audio!).toString()] ??
                          base.resolve(animation.audio!).toString(),
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
                  mimeType: mediaMimeType(entry.value),
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
      for (final resource in [source, ?animation.audio]) {
        final uri = base.resolve(resource);
        if (uri.scheme == 'http' || uri.scheme == 'https') {
          if (uri.origin != root.origin) continue;
        } else {
          continue;
        }
        final label = resource == source ? '精灵图' : '音频';
        if (!uri.path.startsWith(root.path)) {
          throw FormatException('$label资源路径越界: $resource');
        }
        final relative = Uri.decodeComponent(
          uri.path.substring(root.path.length),
        );
        final content = files[relative];
        if (content == null || content.isEmpty) {
          throw FormatException('ZIP 缺少$label资源: $resource');
        }
        resources[uri.toString()] = content;
        resourceFormats[uri.toString()] = mediaMimeType(resource);
      }
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
            mimeType: resourceFormats[entry.key]!,
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

/// 从资源地址推断音频扩展名（未知扩展统一回落到 m4a）。
String audioExtension(String source) {
  final extension = Uri.parse(source).path.split('.').last.toLowerCase();
  return const {
        'm4a',
        'mp4',
        'aac',
        'mp3',
        'wav',
        'ogg',
        'opus',
        'flac',
        'webm',
      }.contains(extension)
      ? extension
      : 'm4a';
}

/// 从资源地址推断 MIME 类型（图/音频，未知回落 application/octet-stream）。
String mediaMimeType(String source) =>
    switch (Uri.parse(source).path.split('.').last.toLowerCase()) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'm4a' || 'mp4' => 'audio/mp4',
      'aac' => 'audio/aac',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'ogg' || 'opus' => 'audio/ogg',
      'flac' => 'audio/flac',
      'webm' => 'audio/webm',
      _ => 'application/octet-stream',
    };

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
