import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:aboutme/core/utils/network.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String live2DOnlineCatalogUrl =
    'https://guansss.github.io/live2d-viewer-web/eikanyalive2d-model.json';
const String _live2DModelCdnBase =
    'https://cdn.jsdelivr.net/gh/Eikanya/Live2d-model@master/';

class Live2DMotionDefinition {
  const Live2DMotionDefinition({
    required this.group,
    required this.index,
    required this.label,
    this.hasSound = false,
  });

  final String group;
  final int index;
  final String label;
  final bool hasSound;
}

class Live2DModelDefinition {
  const Live2DModelDefinition({
    required this.label,
    required this.modelDir,
    required this.modelFile,
    required this.motions,
    this.category,
    this.isOnline = false,
    this.thumbPath,
  });

  final String label;
  final String modelDir;
  final String modelFile;
  final List<Live2DMotionDefinition> motions;
  final String? category;
  final bool isOnline;

  /// 缩略图路径：本地导入记录的用户上传图片（http/file 均可），
  /// 在线模型与内置模型为空
  final String? thumbPath;
}

class Live2DOnlineModelItem {
  const Live2DOnlineModelItem({
    required this.name,
    required this.url,
    required this.category,
    this.thumbUrl,
  });

  final String name;
  final String url;
  final String category;

  /// 目录 JSON 节点的 thumbUrl 字段（可继承祖先节点），列表缩略图用
  final String? thumbUrl;
}

class Live2DOnlineCatalog {
  const Live2DOnlineCatalog._();

  static const int maxPreloadedMotions = 24;
  static final Map<String, Future<Live2DModelDefinition>> _cacheTasks = {};

  static Future<http.Response> _get(Uri uri) async {
    // Re-detect the proxy on retries and retain normal TLS verification.
    final proxy = await detectSystemProxyUrl();
    final transport = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    if (proxy != null) transport.findProxy = (_) => 'PROXY $proxy';
    final client = IOClient(transport);
    try {
      final candidates = <Uri>[
        uri,
        // The model repository is also available over GitHub's HTTPS origin.
        if (uri.host == 'cdn.jsdelivr.net' &&
            uri.path.startsWith('/gh/Eikanya/Live2d-model@master/'))
          uri.replace(
            host: 'raw.githubusercontent.com',
            pathSegments: [
              'Eikanya',
              'Live2d-model',
              'master',
              ...uri.pathSegments.skip(3),
            ],
          ),
      ];
      for (var index = 0; index < candidates.length; index++) {
        final candidate = candidates[index];
        debugPrint('[Live2DOnline] GET $candidate proxy=${proxy ?? 'DIRECT'}');
        try {
          final response = await client
              .get(candidate)
              .timeout(const Duration(seconds: 10));
          debugPrint(
            '[Live2DOnline] HTTP ${response.statusCode} $candidate '
            'bytes=${response.bodyBytes.length}',
          );
          if (response.statusCode >= 500 && index < candidates.length - 1) {
            continue;
          }
          return response;
        } catch (error) {
          debugPrint('[Live2DOnline] ${error.runtimeType} $candidate: $error');
          if (index == candidates.length - 1) rethrow;
        }
      }
      throw StateError('No Live2D download source available');
    } finally {
      client.close();
    }
  }

  static Future<List<Live2DOnlineModelItem>> fetchModels() async {
    final response = await _get(
      Uri.parse(live2DOnlineCatalogUrl),
    ).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw Exception(
        'screens_jellyLive2dRepoHttpError'.trParams({
          'code': response.statusCode.toString(),
        }),
      );
    }
    return parseModels(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  static List<Live2DOnlineModelItem> parseModels(Object? data) {
    if (data is! Map<String, dynamic>) return const [];
    final root = data['models'];
    if (root is! Map<String, dynamic>) return const [];

    final items = <Live2DOnlineModelItem>[];

    // thumbUrl 规范化：绝对 URL 原样使用，相对路径拼模型仓库 CDN
    String? resolveThumbUrl(Object? value, String? inherited) {
      final raw = value?.toString().trim();
      if (raw == null || raw.isEmpty) return inherited;
      if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
      final segments = raw
          .replaceAll('\\', '/')
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .map(Uri.encodeComponent)
          .join('/');
      return '$_live2DModelCdnBase$segments';
    }

    void traverse(
      Map<String, dynamic> node,
      List<String> ancestors,
      String? inheritedThumb,
    ) {
      final nodeName = node['name']?.toString() ?? '';
      final thumbUrl = resolveThumbUrl(node['thumbUrl'], inheritedThumb);
      final children = node['children'];
      if (children is List) {
        for (final child in children) {
          if (child is Map) {
            traverse(
              child.map((key, value) => MapEntry(key.toString(), value)),
              [...ancestors, nodeName],
              thumbUrl,
            );
          }
        }
      }

      final files = node['files'];
      if (files is! List) return;
      for (final rawFile in files) {
        final file = rawFile.toString();
        // The current runtime uses moc3/CubismModelSettingJson and cannot load
        // legacy Cubism 2 `.model.json` files.
        if (!file.toLowerCase().endsWith('.model3.json')) continue;

        final fileParts = file.split('/').where((part) => part.isNotEmpty);
        final pathParts = <String>[
          ...ancestors.skip(1).where((part) => part.isNotEmpty),
          if (nodeName.isNotEmpty) nodeName,
          ...fileParts,
        ];
        if (pathParts.isEmpty) continue;

        final fileName = pathParts.last;
        final baseName = fileName.replaceFirst(
          RegExp(r'\.model3\.json$', caseSensitive: false),
          '',
        );
        final category = ancestors.length > 1 && ancestors[1].isNotEmpty
            ? ancestors[1]
            : (nodeName.isEmpty
                  ? 'screens_jellyLive2dUncategorized'.tr
                  : nodeName);
        final url =
            '$_live2DModelCdnBase${pathParts.map(Uri.encodeComponent).join('/')}';

        items.add(
          Live2DOnlineModelItem(
            name: '${baseName.isEmpty ? nodeName : baseName} ($nodeName)',
            url: url,
            category: category,
            thumbUrl: thumbUrl,
          ),
        );
      }
    }

    traverse(root, const [], null);
    return items;
  }

  static Future<Live2DModelDefinition> loadDefinition(
    Live2DOnlineModelItem item,
  ) async {
    final modelUri = Uri.parse(item.url);
    final response = await _get(modelUri).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw Exception(
        'screens_jellyLive2dConfigHttpError'.trParams({
          'code': response.statusCode.toString(),
        }),
      );
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic>) {
      throw FormatException('screens_jellyLive2dConfigNotJson'.tr);
    }

    return Live2DModelDefinition(
      label: item.name,
      modelDir: modelUri.resolve('.').toString(),
      modelFile: modelUri.pathSegments.last,
      motions: parseMotions(data),
      category: item.category,
      isOnline: true,
    );
  }

  /// Downloads only the files referenced by [model], grouped in a dedicated
  /// cache directory for that model. The catalog itself is never preloaded.
  static Future<Live2DModelDefinition> cacheDefinition(
    Live2DModelDefinition model,
  ) {
    if (!model.isOnline || !model.modelDir.startsWith('http')) {
      return Future.value(model);
    }
    return _cacheTasks.putIfAbsent(
      '${model.modelDir}${model.modelFile}',
      () async {
        try {
          return await _cacheDefinition(model);
        } catch (_) {
          // A failed download must not poison subsequent attempts.
          _cacheTasks.remove('${model.modelDir}${model.modelFile}');
          rethrow;
        }
      },
    );
  }

  static Future<Live2DModelDefinition> _cacheDefinition(
    Live2DModelDefinition model,
  ) async {
    final sourceUri = Uri.parse('${model.modelDir}${model.modelFile}');
    final root = await getApplicationSupportDirectory();
    final key = sha1.convert(utf8.encode(sourceUri.toString())).toString();
    final cacheDir = Directory(p.join(root.path, 'live2d_models', key));
    final completeFile = File(p.join(cacheDir.path, '.complete'));
    final localModelFile = File(p.join(cacheDir.path, model.modelFile));
    if (!await completeFile.exists()) {
      await cacheDir.create(recursive: true);
      final response = await _get(
        sourceUri,
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('在线 Live2D 模型下载失败: HTTP ${response.statusCode}');
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) {
        throw const FormatException('在线 Live2D 模型配置不是 JSON 对象');
      }
      final references = _referencedFiles(json);
      references.add(model.modelFile);
      for (final relativePath in references) {
        final normalized = _normalizeRelativePath(relativePath);
        if (normalized == null) continue;
        final target = File(p.join(cacheDir.path, normalized));
        await target.parent.create(recursive: true);
        final uri = sourceUri.resolve(relativePath);
        final asset = await _get(uri).timeout(const Duration(seconds: 30));
        if (asset.statusCode != 200) {
          throw Exception('在线 Live2D 资源下载失败: ${uri.toString()}');
        }
        await target.writeAsBytes(asset.bodyBytes, flush: true);
      }
      await completeFile.writeAsString('1', flush: true);
    }
    if (!await localModelFile.exists()) {
      throw StateError('Live2D 缓存不完整: ${sourceUri.toString()}');
    }
    return Live2DModelDefinition(
      label: model.label,
      modelDir: '${cacheDir.path}${Platform.pathSeparator}',
      modelFile: model.modelFile,
      motions: model.motions,
      category: model.category,
    );
  }

  static Set<String> _referencedFiles(Map<String, dynamic> modelJson) {
    final result = <String>{};
    final refs = modelJson['FileReferences'];
    if (refs is! Map) return result;
    void add(Object? value) {
      final path = value?.toString().trim();
      if (path != null && path.isNotEmpty) result.add(path);
    }

    add(refs['Moc']);
    add(refs['Physics']);
    add(refs['Pose']);
    add(refs['UserData']);
    add(refs['DisplayInfo']);
    final textures = refs['Textures'];
    if (textures is List) textures.forEach(add);
    final expressions = refs['Expressions'];
    if (expressions is List) {
      for (final expression in expressions) {
        if (expression is Map) add(expression['File']);
      }
    }
    final motions = refs['Motions'];
    if (motions is Map) {
      for (final group in motions.values) {
        if (group is! List) continue;
        for (final motion in group) {
          if (motion is Map) {
            add(motion['File']);
            add(motion['Sound']);
          }
        }
      }
    }
    return result;
  }

  static String? _normalizeRelativePath(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return null;
    }
    final normalized = p.normalize(value.replaceAll('\\', '/'));
    if (normalized == '.' ||
        p.isAbsolute(normalized) ||
        normalized.startsWith('..')) {
      return null;
    }
    return normalized;
  }

  static List<Live2DMotionDefinition> parseMotions(
    Map<String, dynamic> modelJson,
  ) {
    final fileReferences = modelJson['FileReferences'];
    if (fileReferences is! Map) return const [];
    final motions = fileReferences['Motions'];
    if (motions is! Map) return const [];

    final result = <Live2DMotionDefinition>[];
    for (final entry in motions.entries) {
      final group = entry.key.toString();
      final definitions = entry.value;
      if (definitions is! List) continue;
      for (var index = 0; index < definitions.length; index++) {
        final definition = definitions[index];
        if (definition is! Map) continue;
        final name = definition['Name']?.toString().trim();
        final sound = definition['Sound']?.toString().trim();
        result.add(
          Live2DMotionDefinition(
            group: group,
            index: index,
            label: name == null || name.isEmpty
                ? '${group.isEmpty ? 'screens_jellyLive2dMotionGeneric'.tr : group} ${index + 1}'
                : name,
            hasSound: sound != null && sound.isNotEmpty,
          ),
        );
      }
    }
    if (result.length <= maxPreloadedMotions) return result;

    final selected = result
        .where((motion) {
          final group = motion.group.toLowerCase();
          return motion.hasSound || group == 'idle' || group.startsWith('tap');
        })
        .take(maxPreloadedMotions)
        .toList();
    for (final motion in result) {
      if (selected.length >= maxPreloadedMotions) break;
      if (!selected.contains(motion)) selected.add(motion);
    }
    return selected;
  }
}
