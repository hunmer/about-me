import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'pet_store_catalog.dart';
import 'video_pet_import.dart';
import 'video_pet_import_stub.dart'
    if (dart.library.io) 'video_pet_import_io.dart'
    as platform;
import 'video_pet_manifest.dart';

/// 宠物商店服务：目录浏览、整包安装、动作列表获取与单个动作下载。
///
/// 所有请求都限定在 [baseUrl] 同源范围内；下载的图片/音频在非 Web 平台
/// 真实落盘（复用导入服务的持久化目录结构），Web 平台退化为 data URI。
/// 失败统一抛 [FormatException]（中文错误信息），且只有全部下载成功后
/// 才会修改/返回新的 manifest 状态。
class PetStoreService {
  /// 创建商店服务。
  ///
  /// [baseUrl] 默认取 `PET_STORE_URL` dart-define（便于真机连局域网商店），
  /// 回落到 `http://127.0.0.1:8765/`；[client] 可注入用于测试打桩，
  /// 未注入时懒创建并由本实例持有（[close] 时释放）。
  PetStoreService({
    String? baseUrl,
    http.Client? client,
    this.persistToDisk = true,
    this.requestTimeout = const Duration(seconds: 30),
  }) : baseUrl = normalizeStoreBaseUrl(
         baseUrl ??
             const String.fromEnvironment(
               'PET_STORE_URL',
               defaultValue: kDefaultPetStoreBaseUrl,
             ),
       ),
       _injectedClient = client;

  /// 商店根地址（规范化为带尾斜杠的 http(s) URL）。
  final Uri baseUrl;

  /// False keeps downloaded media in memory as data URIs (also used on Web).
  final bool persistToDisk;

  /// 单个商店请求的超时上限，避免 UI 卡在"安装中"。
  final Duration requestTimeout;

  final http.Client? _injectedClient;
  http.Client? _ownedClient;

  http.Client get _http =>
      _injectedClient ?? (_ownedClient ??= http.Client());

  /// 释放自建的 HTTP 客户端；注入的客户端由调用方自行管理。
  void close() {
    _ownedClient?.close();
    _ownedClient = null;
  }

  /// 拉取并解析商店目录（`<baseUrl>pets.json`）。
  Future<List<PetStoreEntry>> fetchPets() async {
    final uri = baseUrl.resolve('pets.json');
    return parsePetStoreCatalog(await _getJson(uri), uri);
  }

  /// 安装宠物：下载基础动作包的图片与音频并持久化。
  ///
  /// 返回的 package：
  /// - manifest 的 metadata 写入 `storePetId` / `storeActionsUrl`；
  /// - 持久化成功时源为绝对 `file:` URI（manifest 自包含，可经
  ///   toJson/fromJson 往返后继续播放），`baseUri` 为包目录；
  /// - Web 或未持久化时源为 `data:` URI，`baseUri` 为商店 manifest URL。
  Future<VideoPetPackage> installPet(PetStoreEntry pet) async {
    final manifestUri = _requireStoreHttp(
      Uri.parse(pet.manifestUrl),
      'manifest',
    );
    _requireStoreHttp(Uri.parse(pet.actionsUrl), '动作列表');
    final decoded = await _getJson(manifestUri);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('商店 manifest 必须是 JSON 对象');
    }
    final manifest = VideoPetManifest.fromJson(decoded);
    if (manifest.id != pet.id) {
      // 防止目录条目与 manifest 内容不一致（例如商店数据配错或被篡改）。
      throw FormatException(
        '商店 manifest 与目录条目身份不一致：期望 ${pet.id}，实际 ${manifest.id}',
      );
    }

    // 第一遍：下载全部图源/音频到内存（相对路径存为 media/N.ext）。
    // 任何一步失败都直接抛出，不会修改本地状态。
    final files = <String, Uint8List>{};
    final downloaded = <String, String>{};
    final storedAnimations = <VideoPetAnimation>[];
    final sourceKeyById = <String, String>{};
    final audioKeyById = <String, String>{};
    for (final animation in manifest.animations) {
      final source = animation.imageSource;
      if (source == null || animation.spritesheet == null) {
        throw FormatException('动作 ${animation.name} 缺少精灵图，无法安装');
      }
      final sourceUri = _resolveResource(
        source,
        manifestUri,
        '${animation.name} 精灵图',
      );
      final sourceKey = await _downloadTo(
        sourceUri,
        files,
        downloaded,
        animation.imageFormat!,
      );
      final audio = animation.audio;
      final audioKey = audio == null
          ? null
          : await _downloadTo(
              _resolveResource(audio, manifestUri, '${animation.name} 音频'),
              files,
              downloaded,
              audioExtension(audio),
            );
      sourceKeyById[animation.id] = sourceKey;
      if (audioKey != null) audioKeyById[animation.id] = audioKey;
      storedAnimations.add(
        animation.copyWith(
          sources: {animation.imageFormat!: sourceKey},
          audio: audioKey,
        ),
      );
    }

    // 第二遍：持久化（含相对路径版 manifest.json，便于离线重装/检查）。
    final metadata = {
      ...manifest.metadata,
      kPetStoreMetadataPetId: pet.id,
      kPetStoreMetadataActionsUrl: pet.actionsUrl,
    };
    files['manifest.json'] = Uint8List.fromList(
      utf8.encode(
        jsonEncode(
          manifest
              .copyWith(animations: storedAnimations, metadata: metadata)
              .toJson(),
        ),
      ),
    );
    final savedBase = persistToDisk
        ? await platform.persistFiles(files, 'manifest.json')
        : null;

    // 第三遍：构造运行时 manifest——源一律为绝对 URI（file: 或 data:），
    // 使 manifest 自包含，存档后无需依赖商店或包目录之外的资源。
    String resolveKey(String key, String reference) => savedBase == null
        ? _dataUri(files[key]!, reference)
        : Uri.parse(savedBase).resolve(key).toString();
    final liveAnimations = <VideoPetAnimation>[
      for (final animation in manifest.animations)
        animation.copyWith(
          sources: {
            animation.imageFormat!: resolveKey(
              sourceKeyById[animation.id]!,
              animation.imageSource!,
            ),
          },
          audio: audioKeyById[animation.id] == null
              ? null
              : resolveKey(
                  audioKeyById[animation.id]!,
                  animation.audio!,
                ),
        ),
    ];
    final liveManifest = manifest.copyWith(
      animations: liveAnimations,
      metadata: metadata,
    );
    liveManifest.validate();
    return VideoPetPackage(
      manifest: liveManifest,
      baseUri: savedBase ?? pet.manifestUrl,
    );
  }

  /// 获取动作列表（actions.json），返回源已解析为绝对 URL 的动画元数据。
  ///
  /// 动画不会被下载；配合 [downloadAction] 按需落单个动作。
  Future<List<VideoPetAnimation>> fetchActions(VideoPetManifest manifest) async {
    final actionsUri = _requireStoreHttp(
      _effectiveActionsUri(manifest),
      '动作列表',
    );
    final decoded = await _getJson(actionsUri);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('商店动作列表必须是 JSON 对象');
    }
    if (decoded['schemaVersion'] != 1) {
      throw FormatException(
        '商店动作列表 schemaVersion 不支持：${decoded['schemaVersion']}',
      );
    }
    final expected = _storePetIdOf(manifest);
    if (decoded['petId'] != expected) {
      throw FormatException(
        '动作列表与当前宠物不匹配：期望 $expected，实际 ${decoded['petId']}',
      );
    }
    final animations = decoded['animations'];
    if (animations is! List) {
      throw const FormatException('商店动作列表缺少 animations 数组');
    }
    final results = <VideoPetAnimation>[];
    for (final (index, item) in animations.indexed) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('动作列表 animations[$index] 必须是对象');
      }
      final animation = VideoPetAnimation.fromJson(item);
      final source = animation.imageSource;
      if (source == null || animation.spritesheet == null) {
        throw FormatException('动作 ${animation.name} 缺少精灵图信息');
      }
      final audio = animation.audio;
      results.add(
        animation.copyWith(
          sources: {
            animation.imageFormat!: _resolveResource(
              source,
              actionsUri,
              '${animation.name} 精灵图',
            ).toString(),
          },
          audio: audio == null
              ? null
              : _resolveResource(
                  audio,
                  actionsUri,
                  '${animation.name} 音频',
                ).toString(),
        ),
      );
    }
    return results;
  }

  /// 下载单个动作并加入 manifest，返回可继续持久化的新 package。
  ///
  /// - 幂等：manifest 已含同 id 动作时直接返回原 package（不发起请求）；
  /// - 动作源按 metadata 中的 actionsUrl 解析并做同源校验；
  /// - 落盘文件写入包目录 `store/` 前缀下（绝对 file URI 源），
  ///   Web / 未持久化 / 非 file 包目录时退化为 data URI 源；
  /// - 只有文件全部写入成功后才返回追加了动作的新 manifest。
  Future<VideoPetPackage> downloadAction({
    required VideoPetPackage package,
    required VideoPetAnimation animation,
  }) async {
    final manifest = package.manifest;
    if (manifest.animations.any((a) => a.id == animation.id)) {
      return package;
    }
    final source = animation.imageSource;
    if (source == null || animation.spritesheet == null) {
      throw FormatException('动作 ${animation.name} 缺少精灵图，无法下载');
    }
    final actionsUri = _requireStoreHttp(
      _effectiveActionsUri(manifest),
      '动作列表',
    );
    final files = <String, Uint8List>{};
    final downloaded = <String, String>{};
    // 每次下载使用独立的 UUID 子目录：downloaded 计数在每次调用间重置，
    // 若共用扁平 store/ 前缀，第二次下载会覆盖第一次已解锁动作的文件。
    final batch = const Uuid().v4();
    final sourceKey = await _downloadTo(
      _resolveResource(source, actionsUri, '${animation.name} 精灵图'),
      files,
      downloaded,
      animation.imageFormat!,
      prefix: 'store/$batch',
    );
    final audio = animation.audio;
    final audioKey = audio == null
        ? null
        : await _downloadTo(
            _resolveResource(audio, actionsUri, '${animation.name} 音频'),
            files,
            downloaded,
            audioExtension(audio),
            prefix: 'store/$batch',
          );

    final appendedBase = persistToDisk
        ? await platform.appendFiles(package.baseUri, files)
        : null;
    final storeDirectory = appendedBase ?? package.baseUri;
    final live = animation.copyWith(
      sources: {
        animation.imageFormat!: appendedBase == null
            ? _dataUri(files[sourceKey]!, source)
            : Uri.parse(storeDirectory).resolve(sourceKey).toString(),
      },
      audio: audioKey == null
          ? null
          : (appendedBase == null
                ? _dataUri(files[audioKey]!, audio!)
                : Uri.parse(storeDirectory).resolve(audioKey).toString()),
    );
    final updated = manifest.copyWith(
      animations: [...manifest.animations, live],
    );
    updated.validate();
    return VideoPetPackage(
      manifest: updated,
      baseUri: package.baseUri,
      resolvedSources: package.resolvedSources,
    );
  }

  String _dataUri(Uint8List bytes, String reference) =>
      Uri.dataFromBytes(bytes, mimeType: mediaMimeType(reference)).toString();

  /// 校验 URL 为 http(s) 且与商店同源，返回原 URI。
  Uri _requireStoreHttp(Uri uri, String label) {
    if (!uri.isScheme('HTTP') && !uri.isScheme('HTTPS')) {
      throw FormatException('宠物商店 $label 不支持的协议：$uri');
    }
    if (uri.scheme != baseUrl.scheme ||
        uri.host != baseUrl.host ||
        uri.port != baseUrl.port) {
      throw FormatException('宠物商店 $label 指向了商店以外的服务器：$uri');
    }
    return uri;
  }

  /// 解析动作资源地址：data: 原样保留；相对路径按 [base]（manifest 或
  /// actions.json 地址）解析；绝对 http(s) 须与商店同源。
  Uri _resolveResource(String raw, Uri base, String label) {
    final parsed = Uri.tryParse(raw);
    if (parsed == null) {
      throw FormatException('$label 地址无效：$raw');
    }
    if (parsed.isScheme('data')) return parsed;
    final resolved = base.resolve(raw);
    return _requireStoreHttp(resolved, label);
  }

  /// 下载资源字节到 [files]（同 URL 复用同一文件），返回相对文件名。
  Future<String> _downloadTo(
    Uri uri,
    Map<String, Uint8List> files,
    Map<String, String> downloaded,
    String extension, {
    String prefix = 'media',
  }) async {
    final existing = downloaded[uri.toString()];
    if (existing != null) return existing;
    final Uint8List bytes;
    if (uri.isScheme('data')) {
      bytes = Uint8List.fromList(UriData.fromUri(uri).contentAsBytes());
    } else {
      final response = await _get(uri, '$prefix 资源');
      bytes = response.bodyBytes;
    }
    if (bytes.isEmpty) {
      throw FormatException('商店资源内容为空：$uri');
    }
    final relative = '$prefix/${downloaded.length}.$extension';
    downloaded[uri.toString()] = relative;
    files[relative] = bytes;
    return relative;
  }

  Future<Object?> _getJson(Uri uri) async {
    final response = await _get(uri, '目录');
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw FormatException('商店返回了无效 JSON：$uri');
    }
  }

  Future<http.Response> _get(Uri uri, String label) async {
    final http.Response response;
    try {
      response = await _http.get(uri).timeout(requestTimeout);
    } on TimeoutException {
      throw FormatException('商店请求超时（${requestTimeout.inSeconds}s）：$uri');
    } catch (error) {
      throw FormatException('无法访问宠物商店（$label）：$error');
    }
    if (response.statusCode != 200) {
      throw FormatException(
        '商店请求失败（HTTP ${response.statusCode}）：$uri',
      );
    }
    return response;
  }

  /// 解析并校验动作列表地址。
  ///
  /// 内置 manifest 携带的默认商店地址（[kDefaultPetStoreBaseUrl]，即
  /// 127.0.0.1）在 `PET_STORE_URL` 切到局域网地址时会因同源校验被拒。
  /// 这里只对这一**已知的内置默认 origin** 把地址重基到当前商店——
  /// 不放宽任意跨源 URL；重基后仍走常规同源校验。
  Uri _effectiveActionsUri(VideoPetManifest manifest) {
    final raw = Uri.tryParse(_actionsUrlOf(manifest));
    if (raw == null) {
      throw FormatException('动作列表地址无效：${_actionsUrlOf(manifest)}');
    }
    bool sameOrigin(Uri a, Uri b) =>
        a.hasAuthority &&
        a.scheme == b.scheme &&
        a.host == b.host &&
        a.port == b.port;
    if (sameOrigin(raw, Uri.parse(kDefaultPetStoreBaseUrl)) &&
        !sameOrigin(raw, baseUrl)) {
      return baseUrl.resolve(
        '${raw.path}${raw.query.isEmpty ? '' : '?${raw.query}'}',
      );
    }
    return raw;
  }

  String _actionsUrlOf(VideoPetManifest manifest) {
    final raw = manifest.metadata[kPetStoreMetadataActionsUrl];
    if (raw is! String || raw.isEmpty) {
      throw const FormatException('该宠物未关联动作商店，无法获取动作');
    }
    return raw;
  }

  String _storePetIdOf(VideoPetManifest manifest) {
    final raw = manifest.metadata[kPetStoreMetadataPetId];
    return raw is String && raw.isNotEmpty ? raw : manifest.id;
  }
}
