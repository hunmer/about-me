import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aboutme/plugins/openai/models/llm_models.dart';

class ModelController {
  // 单例模式
  static final ModelController _instance = ModelController._internal();
  factory ModelController() => _instance;
  ModelController._internal();

  // 内存中的模型列表
  List<LLMModelGroup> _modelGroups = [];

  // 每个分组的默认模型
  Map<String, String> _defaultModels = {};

  // 本地存储的键
  static const String _storageKey = 'openai_llm_models';
  static const String _defaultModelsKey = 'openai_default_models';

  // models.dev 的 provider id 与本地组 id 不一致时的映射
  static const Map<String, String> _providerGroupAlias = {
    'zhipuai': 'zhipu',
    'moonshotai': 'moonshot',
    'moonshotai-cn': 'moonshot',
    'alibaba': 'alibaba-qwen',
    'alibaba-cn': 'alibaba-qwen',
  };

  // models.dev 模型数据库（provider 维度）
  static const String _remoteApiUrl = 'https://models.dev/api.json';

  // 是否已初始化
  bool _initialized = false;

  // 获取所有模型组
  Future<List<LLMModelGroup>> getModels() async {
    if (!_initialized) {
      await _loadFromStorage();
    }
    return _modelGroups;
  }
  
  // 从本地存储加载模型
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? modelsJson = prefs.getString(_storageKey);

      if (modelsJson != null) {
        final List<dynamic> jsonList = jsonDecode(modelsJson);
        _modelGroups = jsonList
            .map((json) => LLMModelGroup.fromJson(json))
            .toList();

        // 智能合并：检查是否有新的默认模型组，如果有则添加
        bool hasNewGroups = false;
        for (final defaultGroup in llmModelGroups) {
          final existingGroup = _modelGroups.firstWhere(
            (g) => g.id == defaultGroup.id,
            orElse: () => LLMModelGroup(id: '', name: '', models: []),
          );

          // 如果这个组不存在，添加整个组
          if (existingGroup.id.isEmpty) {
            _modelGroups.add(defaultGroup);
            hasNewGroups = true;
          } else {
            // 如果组存在，检查是否有新的模型需要添加
            for (final defaultModel in defaultGroup.models) {
              final modelExists = existingGroup.models.any((m) => m.id == defaultModel.id);
              if (!modelExists) {
                existingGroup.models.add(defaultModel);
                hasNewGroups = true;
              }
            }
          }
        }

        // 如果有新增的组或模型，保存到本地存储
        if (hasNewGroups) {
          await _saveToStorage();
        }
      } else {
        // 首次使用，加载默认模型
        _modelGroups = List.from(llmModelGroups);
        await _saveToStorage();
      }

      await _loadDefaultModels();
      _initialized = true;
    } catch (e) {
      // 加载失败，使用默认模型
      _modelGroups = List.from(llmModelGroups);
      _initialized = true;
      // 不抛出异常，使用默认模型
      print('加载模型失败: $e');
    }
  }
  
  // 保存模型到本地存储
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _modelGroups.map((group) => group.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      print('保存模型失败: $e');
      throw Exception('保存模型失败: $e');
    }
  }

  // 添加新模型
  Future<void> addModel(LLMModel model) async {
    if (!_initialized) {
      await _loadFromStorage();
    }
    
    final groupIndex = _modelGroups.indexWhere((g) => g.id == model.group);
    if (groupIndex != -1) {
      if (_modelGroups[groupIndex].models.any((m) => m.id == model.id)) {
        throw Exception('模型ID已存在');
      }
      _modelGroups[groupIndex].models.add(model);
      await _saveToStorage();
    } else {
      throw Exception('模型组不存在');
    }
  }

  // 更新模型
  Future<void> updateModel(LLMModel model) async {
    if (!_initialized) {
      await _loadFromStorage();
    }
    
    final groupIndex = _modelGroups.indexWhere((g) => g.id == model.group);
    if (groupIndex != -1) {
      final modelIndex = _modelGroups[groupIndex].models.indexWhere((m) => m.id == model.id);
      if (modelIndex != -1) {
        _modelGroups[groupIndex].models[modelIndex] = model;
        await _saveToStorage();
      } else {
        throw Exception('模型不存在');
      }
    } else {
      throw Exception('模型组不存在');
    }
  }

  // 删除模型
  Future<void> deleteModel(String modelId) async {
    if (!_initialized) {
      await _loadFromStorage();
    }
    
    for (var group in _modelGroups) {
      final modelIndex = group.models.indexWhere((m) => m.id == modelId);
      if (modelIndex != -1) {
        group.models.removeAt(modelIndex);
        await _saveToStorage();
        return;
      }
    }
    throw Exception('模型不存在');
  }

  // 根据ID获取模型
  Future<LLMModel?> getModelById(String modelId) async {
    if (!_initialized) {
      await _loadFromStorage();
    }

    for (var group in _modelGroups) {
      try {
        final model = group.models.firstWhere(
          (m) => m.id == modelId,
        );
        return model;
      } catch (e) {
        // 在当前组中没找到，继续查找下一组
        continue;
      }
    }
    return null;
  }

  /// 模型是否支持视觉输入；模型库无记录时返回 null（能力未知）
  Future<bool?> supportsVision(String modelId) async {
    return (await getModelById(modelId))?.supportsVision;
  }
  
  // 重置为默认模型
  Future<void> resetToDefault() async {
    _modelGroups = List.from(llmModelGroups);
    await _saveToStorage();
  }

  /// 从 models.dev 拉取最新模型列表（provider 维度，跳过已废弃模型）
  /// 返回的组 id 已按 [_providerGroupAlias] 映射为本地组 id
  Future<List<LLMModelGroup>> fetchRemoteModelGroups() async {
    final response = await http.get(Uri.parse(_remoteApiUrl));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final data =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    final groups = <LLMModelGroup>[];
    data.forEach((providerId, providerRaw) {
      final provider = providerRaw as Map<String, dynamic>;
      final modelsRaw = provider['models'];
      if (modelsRaw is! Map<String, dynamic>) return;

      final groupId = _providerGroupAlias[providerId] ?? providerId;
      final models = <LLMModel>[];
      modelsRaw.forEach((modelId, modelRaw) {
        final m = modelRaw as Map<String, dynamic>;
        if (m['status'] == 'deprecated') return;
        models.add(LLMModel(
          id: modelId,
          name: (m['name'] as String?) ?? modelId,
          group: groupId,
          supportsVision: _parseSupportsVision(m),
          supportsReasoning: m['reasoning'] as bool?,
          contextLimit: ((m['limit'] as Map?)?['context'] as num?)?.toInt(),
          maxOutput: ((m['limit'] as Map?)?['output'] as num?)?.toInt(),
        ));
      });
      if (models.isEmpty) return;

      groups.add(LLMModelGroup(
        id: groupId,
        name: (provider['name'] as String?) ?? providerId,
        models: models,
      ));
    });
    return groups;
  }

  /// models.dev 新版用 modalities.input 标记输入模态，旧版用 attachment
  static bool? _parseSupportsVision(Map<String, dynamic> model) {
    final modalities = model['modalities'];
    if (modalities is Map && modalities['input'] is List) {
      return (modalities['input'] as List).contains('image');
    }
    return model['attachment'] as bool?;
  }

  /// 将远端分组合并进本地列表（只增不减：已有组补充新模型并更新能力字段，未知组整组添加）
  /// 返回统计结果
  Future<({int addedGroups, int addedModels})> mergeModelGroups(
    List<LLMModelGroup> remoteGroups,
  ) async {
    if (!_initialized) {
      await _loadFromStorage();
    }

    var addedGroups = 0;
    var addedModels = 0;
    var needsSave = false;
    for (final remote in remoteGroups) {
      LLMModelGroup? existing;
      for (final group in _modelGroups) {
        if (group.id == remote.id) {
          existing = group;
          break;
        }
      }

      if (existing == null) {
        _modelGroups.add(remote);
        addedGroups++;
        addedModels += remote.models.length;
        needsSave = true;
      } else {
        for (final model in remote.models) {
          final index = existing.models.indexWhere((m) => m.id == model.id);
          if (index == -1) {
            existing.models.add(model);
            addedModels++;
            needsSave = true;
          } else {
            // 已有模型：用远端数据补齐本地缺失的能力字段
            final current = existing.models[index];
            final merged = current.withCapabilitiesFrom(model);
            existing.models[index] = merged;
            if (merged.supportsVision != current.supportsVision ||
                merged.supportsReasoning != current.supportsReasoning ||
                merged.contextLimit != current.contextLimit ||
                merged.maxOutput != current.maxOutput) {
              needsSave = true;
            }
          }
        }
      }
    }

    if (needsSave) {
      await _saveToStorage();
    }
    return (addedGroups: addedGroups, addedModels: addedModels);
  }

  // 获取分组的默认模型
  Future<String?> getDefaultModel(String groupId) async {
    if (!_initialized) {
      await _loadFromStorage();
    }
    return _defaultModels[groupId];
  }

  // 设置分组的默认模型
  Future<void> setDefaultModel(String groupId, String modelId) async {
    if (!_initialized) {
      await _loadFromStorage();
    }
    _defaultModels[groupId] = modelId;
    await _saveDefaultModels();
  }

  // 保存默认模型到本地存储
  Future<void> _saveDefaultModels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_defaultModelsKey, jsonEncode(_defaultModels));
    } catch (e) {
      print('保存默认模型失败: $e');
    }
  }

  // 加载默认模型
  Future<void> _loadDefaultModels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? json = prefs.getString(_defaultModelsKey);
      if (json != null) {
        _defaultModels = Map<String, String>.from(jsonDecode(json));
      }
    } catch (e) {
      print('加载默认模型失败: $e');
    }
  }
}