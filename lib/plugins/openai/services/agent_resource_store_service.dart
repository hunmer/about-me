import 'dart:convert';

import 'package:agentlib/agent_slots.dart';
import 'package:aboutme/plugins/openai/screens/agent_resource_list_screen.dart';
import 'package:http/http.dart' as http;

class AgentResourceStoreItem {
  const AgentResourceStoreItem({
    required this.id,
    required this.name,
    required this.description,
    required this.tags,
    required this.contentUrl,
    this.updatedAt,
    this.needsEnv = const [],
  });

  final String id;
  final String name;
  final String description;
  final List<String> tags;
  final String contentUrl;
  final String? updatedAt;
  final List<String> needsEnv;

  AgentResourceItem toResource(String content) =>
      AgentResourceItem(id: id, name: name, tags: tags, content: content);
}

class AgentResourceStoreService {
  static const defaultBaseUrl =
      'https://gh-proxy.org/https://github.com/hunmer/agent-spaces/raw/refs/heads/main/packages/templates/';
  static final Map<String, List<AgentResourceStoreItem>> _cache = {};

  static Future<List<AgentResourceStoreItem>> load(
    AgentResourceType type, {
    String baseUrl = defaultBaseUrl,
    bool forceRefresh = false,
  }) async {
    final root = _normalize(baseUrl);
    final cacheKey = '${type.name}:$root';
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      return List.unmodifiable(_cache[cacheKey]!);
    }
    final indexPath =
        type == AgentResourceType.skills
            ? 'skills/index.json'
            : 'mcps/index.json';
    final response = await _get(Uri.parse('$root$indexPath'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('商店索引加载失败: HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    final items =
        data.map((raw) {
          final json = Map<String, dynamic>.from(raw as Map);
          final isSkill = type == AgentResourceType.skills;
          final path =
              isSkill ? '${json['path']}/SKILL.md' : 'mcps/${json['filename']}';
          return AgentResourceStoreItem(
            id: json['id'] as String,
            name: json['name'] as String? ?? json['id'] as String,
            description:
                json['description'] as String? ??
                json['summary'] as String? ??
                '',
            tags: [
              if (json['group'] is String &&
                  (json['group'] as String).isNotEmpty)
                json['group'] as String,
              ...(json['tags'] as List<dynamic>? ?? const []).cast<String>(),
            ],
            contentUrl: '$root$path',
            updatedAt: json['updatedAt'] as String?,
            needsEnv:
                (json['needsEnv'] as List<dynamic>? ?? const []).cast<String>(),
          );
        }).toList();
    _cache[cacheKey] = items;
    return List.unmodifiable(items);
  }

  static void clearCache() => _cache.clear();

  static Future<String> fetchContent(AgentResourceStoreItem item) async {
    final response = await _get(Uri.parse(item.contentUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('资源下载失败: HTTP ${response.statusCode}');
    }
    return response.body;
  }

  static Future<http.Response> _get(Uri uri) async {
    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'text/plain, application/json, */*',
        'User-Agent': 'Aboutme-AgentStore/1.0',
      },
    );
    if (response.statusCode != 403 || uri.host != 'gh-proxy.org') {
      return response;
    }
    final fallback = _rawGithubUri(uri);
    return http.get(
      fallback,
      headers: const {
        'Accept': 'text/plain, application/json, */*',
        'User-Agent': 'Aboutme-AgentStore/1.0',
      },
    );
  }

  static Uri _rawGithubUri(Uri proxyUri) {
    final path = proxyUri.toString().substring('https://gh-proxy.org/'.length);
    final rawPath = path
        .replaceFirst(
          'https://github.com/',
          'https://raw.githubusercontent.com/',
        )
        .replaceFirst('/raw/refs/heads/', '/refs/heads/');
    return Uri.parse(rawPath);
  }

  static String _normalize(String value) =>
      value.endsWith('/') ? value : '$value/';
}
