import 'dart:convert';

import 'package:http/http.dart' as http;

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
  });

  final String label;
  final String modelDir;
  final String modelFile;
  final List<Live2DMotionDefinition> motions;
  final String? category;
  final bool isOnline;
}

class Live2DOnlineModelItem {
  const Live2DOnlineModelItem({
    required this.name,
    required this.url,
    required this.category,
  });

  final String name;
  final String url;
  final String category;
}

class Live2DOnlineCatalog {
  const Live2DOnlineCatalog._();

  static const int maxPreloadedMotions = 24;

  static Future<List<Live2DOnlineModelItem>> fetchModels() async {
    final response = await http
        .get(Uri.parse(live2DOnlineCatalogUrl))
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw Exception('模型仓库返回 HTTP ${response.statusCode}');
    }
    return parseModels(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  static List<Live2DOnlineModelItem> parseModels(Object? data) {
    if (data is! Map<String, dynamic>) return const [];
    final root = data['models'];
    if (root is! Map<String, dynamic>) return const [];

    final items = <Live2DOnlineModelItem>[];

    void traverse(Map<String, dynamic> node, List<String> ancestors) {
      final nodeName = node['name']?.toString() ?? '';
      final children = node['children'];
      if (children is List) {
        for (final child in children) {
          if (child is Map) {
            traverse(
              child.map((key, value) => MapEntry(key.toString(), value)),
              [...ancestors, nodeName],
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
        final category =
            ancestors.length > 1 && ancestors[1].isNotEmpty
                ? ancestors[1]
                : (nodeName.isEmpty ? '未分类' : nodeName);
        final url =
            '$_live2DModelCdnBase${pathParts.map(Uri.encodeComponent).join('/')}';

        items.add(
          Live2DOnlineModelItem(
            name: '${baseName.isEmpty ? nodeName : baseName} ($nodeName)',
            url: url,
            category: category,
          ),
        );
      }
    }

    traverse(root, const []);
    return items;
  }

  static Future<Live2DModelDefinition> loadDefinition(
    Live2DOnlineModelItem item,
  ) async {
    final modelUri = Uri.parse(item.url);
    final response = await http
        .get(modelUri)
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw Exception('模型配置返回 HTTP ${response.statusCode}');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('模型配置不是 JSON 对象');
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
            label:
                name == null || name.isEmpty
                    ? '${group.isEmpty ? '动作' : group} ${index + 1}'
                    : name,
            hasSound: sound != null && sound.isNotEmpty,
          ),
        );
      }
    }
    if (result.length <= maxPreloadedMotions) return result;

    final selected =
        result
            .where((motion) {
              final group = motion.group.toLowerCase();
              return motion.hasSound ||
                  group == 'idle' ||
                  group.startsWith('tap');
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
