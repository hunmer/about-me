import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:aboutme/plugins/openai/moments/models/agent_asset.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';

/// Agent 资产图服务
///
/// 数据：`openai/moments/<agentId>/assets.json`
/// 图片文件：`openai/moments/assets/<agentId>/`（经 ImageUtils 保存，相对路径 './...'）
class AgentAssetsService extends ChangeNotifier {
  AgentAssetsService._();

  static final AgentAssetsService instance = AgentAssetsService._();

  static const assetsDir = 'openai/moments/assets';

  /// 预置占位：名称 → 生成提示词模板
  static const defaultPlaceholders = {
    '三视图':
        '角色全身三视图设定图，正面、侧面、背面三个视角并排站立，全身可见，纯白背景，角色设定插画风格，服装发型细节清晰',
    '房间照片':
        '角色居住的温馨卧室室内照片，自然光透过窗帘，生活感真实，整洁有序，有个人喜好的装饰细节',
  };

  final Map<String, List<AgentAsset>> _cache = {};

  String _path(String agentId) => 'openai/moments/$agentId/assets.json';

  List<AgentAsset>? cached(String agentId) => _cache[agentId];

  Future<List<AgentAsset>> getAssets(String agentId) async {
    if (_cache.containsKey(agentId)) return _cache[agentId]!;
    try {
      final data = await OpenAIPlugin.instance.storage.read(_path(agentId));
      final list =
          (data is Map ? data['assets'] : null) as List<dynamic>? ?? [];
      _cache[agentId] = list
          .map(
            (e) => AgentAsset.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('[Moments] 读取资产失败 ($agentId): $e');
      _cache[agentId] = [];
    }
    return _cache[agentId]!;
  }

  /// 首次访问时初始化预置占位（三视图/房间照片）
  Future<List<AgentAsset>> ensureDefaults(String agentId) async {
    final assets = await getAssets(agentId);
    if (assets.isNotEmpty) return assets;
    for (final entry in defaultPlaceholders.entries) {
      assets.add(
        AgentAsset(
          id: const Uuid().v4(),
          name: entry.key,
          prompt: entry.value,
          path: null,
          createdAt: DateTime.now(),
        ),
      );
    }
    await _save(agentId);
    return assets;
  }

  Future<AgentAsset> addAsset({
    required String agentId,
    required String name,
    String prompt = '',
    String? path,
  }) async {
    final assets = await getAssets(agentId);
    final asset = AgentAsset(
      id: const Uuid().v4(),
      name: name,
      prompt: prompt,
      path: path,
      createdAt: DateTime.now(),
    );
    assets.add(asset);
    await _save(agentId);
    return asset;
  }

  Future<AgentAsset?> updateAsset({
    required String agentId,
    required String assetId,
    String? name,
    String? prompt,
    String? path,
  }) async {
    final assets = await getAssets(agentId);
    final index = assets.indexWhere((a) => a.id == assetId);
    if (index < 0) return null;
    final updated = assets[index].copyWith(name: name, prompt: prompt, path: path);
    assets[index] = updated;
    await _save(agentId);
    return updated;
  }

  Future<bool> deleteAsset({
    required String agentId,
    required String assetId,
  }) async {
    final assets = await getAssets(agentId);
    final before = assets.length;
    assets.removeWhere((a) => a.id == assetId);
    final removed = before != assets.length;
    if (removed) await _save(agentId);
    return removed;
  }

  /// 工具用：按名称查找资产（先全等，再包含匹配），只返回已生成图片的
  List<AgentAsset> findByName(String agentId, String name) {
    final assets = _cache[agentId] ?? const <AgentAsset>[];
    final exact = assets
        .where((a) => a.hasImage && a.name == name)
        .toList();
    if (exact.isNotEmpty) return exact;
    return assets
        .where((a) => a.hasImage && a.name.contains(name))
        .toList();
  }

  Future<void> _save(String agentId) async {
    final assets = _cache[agentId] ?? [];
    await OpenAIPlugin.instance.storage.write(_path(agentId), {
      'assets': assets.map((a) => a.toJson()).toList(),
    });
    notifyListeners();
  }
}
