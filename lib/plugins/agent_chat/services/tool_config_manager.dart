/// 工具配置管理器
///
/// 负责管理 AI 工具的配置数据，包括加载、保存、CRUD 操作等
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';
import 'package:aboutme/plugins/agent_chat/services/native_tool_agent_service.dart';

/// 工具配置管理器（单例）
class ToolConfigManager {
  // 单例模式
  static final ToolConfigManager instance = ToolConfigManager._();
  ToolConfigManager._();

  // 存储管理器（跨平台: 本地文件/HTTP 远端/Web IndexedDB）
  StorageManager? _storage;

  // 工具配置在存储中的路径前缀
  static const String _toolsPrefix = 'agent_chat/tools';

  StorageManager get _manager => _storage ??= StorageManager();

  // 内存缓存
  List<List<String>> _toolIndex = [];
  final Map<String, PluginToolSet> _pluginTools = {};

  // 配置文件列表
  static const List<String> _pluginIds = [
    'system', // 系统级工具（时间、设备信息等）
    'activity',
    'bill',
    'openai',
    'calendar',
    'calendar_album',
    'chat',
    'checkin',
    'contact',
    'database',
    'day',
    'diary',
    'goods',
    'habits',
    'memory', // 活人感记忆查询
    'moments', // 朋友圈 / 资产图 / 生图（描述 openai 插件的方法）
    'nodes',
    'notes',
    'store',
    'timer',
    'todo',
    'tracker',
    'ui',
  ];

  // 插件别名映射（用于帮助AI识别用户的自然语言描述）
  static const Map<String, List<String>> _pluginAliases = {
    'bill': ['账单', '记账', '账本', '财务', '消费', '支出', '收入', '花销'],
    'chat': ['聊天', '频道', '消息', '对话', '会话'],
    'diary': ['日记', '日志', '记录'],
    'todo': ['任务', '待办', '清单', '事项', '计划'],
    'notes': ['笔记', '备忘', '记事'],
    'activity': ['活动', '事件', '记录活动'],
    'checkin': ['签到', '打卡', '考勤'],
    'calendar': ['日历', '日程', '日程表'],
    'day': ['纪念日', '倒计时', '正计时', '重要日子'],
    'goods': ['物品', '商品', '东西', '物件'],
    'habits': ['习惯', '习惯养成', '习惯追踪'],
    'tracker': ['追踪', '目标', '目标追踪', '统计'],
    'timer': ['计时', '计时器', '定时', '定时器'],
    'contact': ['联系人', '通讯录', '人脉'],
    'store': ['商店', '兑换', '积分商城'],
    'nodes': ['节点', '树形笔记'],
    'calendar_album': ['相册', '照片', '图片日记'],
    'database': ['数据库', '自定义数据'],
    'moments': [
      '朋友圈',
      '动态',
      '生图',
      '生成图片',
      '画图',
      '资产图',
      '照片',
      '自拍',
      '拍照',
      '画一张',
    ],
  };

  // 是否已初始化
  bool _initialized = false;

  /// 检查是否已初始化
  bool get isInitialized => _initialized;

  /// 初始化配置管理器
  ///
  /// 首次启动时会从 assets 复制配置到存储
  Future<void> initialize({StorageManager? storage}) async {
    if (_initialized) return;
    if (storage != null) _storage = storage;

    try {
      // 以索引文件是否存在判断是否已初始化过（与旧版本地文件位置兼容）
      if (!await _manager.fileExists('$_toolsPrefix/index.json')) {
        await _copyAssetsToStorage();
      } else {
        // 增量同步：新版本新增的工具描述文件补拷给老安装（不覆盖已有文件，
        // 用户对描述的本地自定义不受影响），有变化时重建索引
        await _syncMissingToolFiles();
      }

      // 加载工具索引和配置
      await _loadAllConfigs();

      _initialized = true;
    } catch (e) {
      print('❌ ToolConfigManager 初始化失败: $e');
      rethrow;
    }
  }

  /// 补拷缺失的工具描述文件（版本升级新增工具时分发给老安装）
  Future<void> _syncMissingToolFiles() async {
    var copied = false;
    for (final pluginId in _pluginIds) {
      final path = '$_toolsPrefix/$pluginId.json';
      if (await _manager.fileExists(path)) continue;
      try {
        final configData = await rootBundle.loadString(
          'lib/plugins/agent_chat/tools/$pluginId.json',
        );
        await _manager.writeString(path, configData);
        copied = true;
        print('✅ 增量补拷 $pluginId.json');
      } catch (_) {
        // assets 中无此文件则跳过
      }
    }
    if (copied) {
      await _regenerateToolIndex();
    }
  }

  /// 从 assets 复制配置文件到存储
  Future<void> _copyAssetsToStorage() async {
    print('🔄 首次启动：复制工具配置到存储...');

    // 复制各插件配置文件
    for (final pluginId in _pluginIds) {
      try {
        final configData = await rootBundle.loadString(
          'lib/plugins/agent_chat/tools/$pluginId.json',
        );
        await _manager.writeString(
          '$_toolsPrefix/$pluginId.json',
          configData,
        );
        print('✅ 复制 $pluginId.json');
      } catch (e) {
        print('⚠️ 复制 $pluginId.json 失败: $e');
      }
    }

    // 重新生成 index.json（基于实际的工具配置）
    await _regenerateToolIndex();

    print('✅ 工具配置复制完成');
  }

  /// 重新生成工具索引
  Future<void> _regenerateToolIndex() async {
    print('🔄 重新生成工具索引...');

    final newIndex = <List<String>>[];

    // 遍历所有插件配置文件
    for (final pluginId in _pluginIds) {
      try {
        final jsonData = await _manager.readJson(
          '$_toolsPrefix/$pluginId.json',
        );
        if (jsonData is! Map<String, dynamic>) continue;

        // 为每个工具创建索引条目
        jsonData.forEach((methodName, toolData) {
          if (toolData is Map<String, dynamic>) {
            final title = toolData['title'] as String?;
            final description = toolData['description'] as String?;

            // 生成完整的工具 ID (pluginId_methodName 格式)
            // 如果 methodName 已经包含插件前缀，则不重复添加
            String fullToolId;
            if (methodName.startsWith('${pluginId}_')) {
              fullToolId = methodName;
            } else {
              fullToolId = '${pluginId}_$methodName';
            }

            // 使用简要描述（优先使用 title，其次是 description 的第一句话）
            String brief = title ?? '';
            if (brief.isEmpty && description != null) {
              final sentences = description.split(RegExp(r'[。\.]\s*'));
              brief = sentences.isNotEmpty ? sentences.first : description;
              if (brief.length > 50) {
                brief = '${brief.substring(0, 50)}...';
              }
            }

            newIndex.add([fullToolId, brief]);
          }
        });

        print('✅ 生成 $pluginId 的索引 (${jsonData.length} 个工具)');
      } catch (e) {
        print('⚠️ 生成 $pluginId 索引失败: $e');
      }
    }

    // 保存新的索引文件
    try {
      final content = const JsonEncoder.withIndent('  ').convert(newIndex);
      await _manager.writeString('$_toolsPrefix/index.json', content);
      print('✅ 工具索引已生成 (共 ${newIndex.length} 个工具)');
      _invalidateNativeToolCache();
    } catch (e) {
      print('❌ 保存工具索引失败: $e');
    }
  }

  /// 加载所有配置
  Future<void> _loadAllConfigs() async {
    await _loadToolIndexFromFile();

    for (final pluginId in _pluginIds) {
      await _loadPluginConfig(pluginId);
    }
  }

  /// 从存储加载工具索引
  Future<void> _loadToolIndexFromFile() async {
    try {
      final jsonData = await _manager.readJson('$_toolsPrefix/index.json');

      if (jsonData is List && jsonData.isNotEmpty) {
        _toolIndex =
            jsonData
                .map(
                  (item) =>
                      (item as List<dynamic>).map((e) => e.toString()).toList(),
                )
                .toList();
      } else {
        print('⚠️ index.json 不存在');
        _toolIndex = [];
      }
    } catch (e) {
      print('❌ 加载工具索引失败: $e');
      _toolIndex = [];
    }
  }

  /// 加载插件配置
  Future<void> _loadPluginConfig(String pluginId) async {
    try {
      final jsonData = await _manager.readJson(
        '$_toolsPrefix/$pluginId.json',
      );

      if (jsonData is Map<String, dynamic>) {
        _pluginTools[pluginId] = PluginToolSet.fromJson(pluginId, jsonData);
      } else {
        print('⚠️ $pluginId.json 不存在');
      }
    } catch (e) {
      print('❌ 加载 $pluginId 配置失败: $e');
    }
  }

  /// 保存插件配置到存储
  Future<void> _savePluginConfig(String pluginId) async {
    try {
      final toolSet = _pluginTools[pluginId];
      if (toolSet == null) {
        print('⚠️ 插件 $pluginId 不存在');
        return;
      }

      final jsonData = toolSet.toJson();
      final content = const JsonEncoder.withIndent('  ').convert(jsonData);
      await _manager.writeString('$_toolsPrefix/$pluginId.json', content);
      _invalidateNativeToolCache();
    } catch (e) {
      print('❌ 保存 $pluginId 配置失败: $e');
      rethrow;
    }
  }

  /// 保存工具索引到存储
  Future<void> _saveToolIndex() async {
    try {
      final content = const JsonEncoder.withIndent('  ').convert(_toolIndex);
      await _manager.writeString('$_toolsPrefix/index.json', content);
    } catch (e) {
      print('❌ 保存工具索引失败: $e');
    }
  }

  /// 工具配置发生变化后失效原生 FC 工具集缓存
  void _invalidateNativeToolCache() {
    try {
      NativeToolAgentService.instance.invalidateCache();
    } catch (_) {}
  }

  /// 获取全部启用工具及其所属插件（原生 function calling 注入用）
  ///
  /// 返回 (toolId, pluginId, ToolConfig) 列表；toolId 为完整 ID（含插件前缀）
  List<(String, String, ToolConfig)> getEnabledToolsWithPlugin() {
    final result = <(String, String, ToolConfig)>[];
    for (final entry in _pluginTools.entries) {
      final pluginId = entry.key;
      for (final toolEntry in entry.value.tools.entries) {
        if (toolEntry.value.enabled) {
          result.add((toolEntry.key, pluginId, toolEntry.value));
        }
      }
    }
    return result;
  }

  /// 获取工具简要索引（用于第一阶段 AI 请求）
  List<List<String>> getToolIndex({bool enabledOnly = true}) {
    if (!enabledOnly) {
      return List.from(_toolIndex);
    }

    // 过滤已禁用的工具
    return _toolIndex.where((item) {
      final toolId = item[0];

      // 遍历所有插件查找工具（支持任意 toolId 格式）
      for (final entry in _pluginTools.entries) {
        final toolSet = entry.value;
        final tool = toolSet.tools[toolId];
        if (tool != null) {
          return tool.enabled;
        }
      }

      // 如果在 _pluginTools 中找不到，尝试旧的格式匹配（向后兼容）
      final parts = toolId.split('_');
      if (parts.length >= 2) {
        final pluginId = parts[0];
        final toolSet = _pluginTools[pluginId];
        if (toolSet != null) {
          final tool = toolSet.tools[toolId];
          return tool?.enabled ?? false;
        }
      }

      return false;
    }).toList();
  }

  /// 获取指定工具的详细信息
  Future<ToolConfig?> getToolDetails(String toolId) async {
    // 遍历所有插件查找工具（支持任意 toolId 格式）
    for (final entry in _pluginTools.entries) {
      final toolSet = entry.value;
      final tool = toolSet.tools[toolId];
      if (tool != null) {
        return tool;
      }
    }

    // 如果在 _pluginTools 中找不到，尝试旧的格式匹配（向后兼容）
    final parts = toolId.split('_');
    if (parts.length >= 2) {
      final pluginId = parts[0];
      final toolSet = _pluginTools[pluginId];
      return toolSet?.tools[toolId];
    }

    return null;
  }

  /// 获取多个工具的详细信息
  Future<Map<String, ToolConfig>> getToolsDetails(List<String> toolIds) async {
    final result = <String, ToolConfig>{};

    for (final toolId in toolIds) {
      final tool = await getToolDetails(toolId);
      if (tool != null) {
        result[toolId] = tool;
      }
    }

    return result;
  }

  /// 获取所有插件工具集
  Map<String, PluginToolSet> getAllPluginTools() {
    return Map.from(_pluginTools);
  }

  /// 获取指定插件的工具集
  PluginToolSet? getPluginTools(String pluginId) {
    return _pluginTools[pluginId];
  }

  /// 添加工具
  Future<void> addTool(
    String pluginId,
    String toolId,
    ToolConfig config,
  ) async {
    var toolSet = _pluginTools[pluginId];

    // 如果插件不存在，创建新的工具集
    if (toolSet == null) {
      toolSet = PluginToolSet(pluginId: pluginId, tools: {toolId: config});
      _pluginTools[pluginId] = toolSet;
    } else {
      // 添加工具到现有工具集
      toolSet.tools[toolId] = config;
    }

    // 添加到索引
    _toolIndex.add([toolId, config.getBriefDescription()]);

    // 保存到文件
    await _savePluginConfig(pluginId);
    await _saveToolIndex();
  }

  /// 更新工具
  Future<void> updateTool(
    String pluginId,
    String toolId,
    ToolConfig config,
  ) async {
    final toolSet = _pluginTools[pluginId];
    if (toolSet == null) {
      throw Exception('插件 $pluginId 不存在');
    }

    if (!toolSet.tools.containsKey(toolId)) {
      throw Exception('工具 $toolId 不存在');
    }

    // 更新工具配置
    toolSet.tools[toolId] = config;

    // 更新索引
    final indexItem = _toolIndex.firstWhere(
      (item) => item[0] == toolId,
      orElse: () => [],
    );
    if (indexItem.isNotEmpty) {
      indexItem[1] = config.getBriefDescription();
    }

    // 保存到文件
    await _savePluginConfig(pluginId);
    await _saveToolIndex();
  }

  /// 删除工具
  Future<void> deleteTool(String pluginId, String toolId) async {
    final toolSet = _pluginTools[pluginId];
    if (toolSet == null) {
      throw Exception('插件 $pluginId 不存在');
    }

    // 从工具集中删除
    toolSet.tools.remove(toolId);

    // 从索引中删除
    _toolIndex.removeWhere((item) => item[0] == toolId);

    // 保存到文件
    await _savePluginConfig(pluginId);
    await _saveToolIndex();
  }

  /// 切换工具启用状态
  Future<void> toggleToolEnabled(
    String pluginId,
    String toolId,
    bool enabled,
  ) async {
    final toolSet = _pluginTools[pluginId];
    if (toolSet == null) {
      throw Exception('插件 $pluginId 不存在');
    }

    final tool = toolSet.tools[toolId];
    if (tool == null) {
      throw Exception('工具 $toolId 不存在');
    }

    // 更新启用状态
    toolSet.tools[toolId] = tool.copyWith(enabled: enabled);

    // 保存到文件
    await _savePluginConfig(pluginId);
  }

  /// 导出配置到指定文件
  Future<void> exportConfig(String filePath) async {
    try {
      final exportData = {
        'index': _toolIndex,
        'plugins': _pluginTools.map(
          (pluginId, toolSet) => MapEntry(pluginId, toolSet.toJson()),
        ),
      };

      final content = const JsonEncoder.withIndent('  ').convert(exportData);
      final file = File(filePath);
      await file.writeAsString(content);
    } catch (e) {
      print('❌ 导出配置失败: $e');
      rethrow;
    }
  }

  /// 从文件导入配置
  Future<void> importConfig(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $filePath');
      }

      final content = await file.readAsString();
      final Map<String, dynamic> importData = json.decode(content);

      // 验证数据格式
      if (!importData.containsKey('index') ||
          !importData.containsKey('plugins')) {
        throw Exception('无效的配置文件格式');
      }

      // 导入索引
      final List<dynamic> indexData = importData['index'];
      _toolIndex =
          indexData
              .map(
                (item) =>
                    (item as List<dynamic>).map((e) => e.toString()).toList(),
              )
              .toList();

      // 导入插件配置
      _pluginTools.clear();
      final Map<String, dynamic> pluginsData = importData['plugins'];
      pluginsData.forEach((pluginId, toolsData) {
        _pluginTools[pluginId] = PluginToolSet.fromJson(
          pluginId,
          toolsData as Map<String, dynamic>,
        );
      });

      // 保存到文件
      await _saveToolIndex();
      for (final pluginId in _pluginTools.keys) {
        await _savePluginConfig(pluginId);
      }
    } catch (e) {
      print('❌ 导入配置失败: $e');
      rethrow;
    }
  }

  /// 恢复默认配置
  Future<void> resetToDefault() async {
    try {
      // 清空存储中的现有工具配置
      await _manager.clearPrefix(_toolsPrefix);

      // 重新从 assets 复制
      await _copyAssetsToStorage();

      // 重新加载配置
      await _loadAllConfigs();
    } catch (e) {
      print('❌ 恢复默认配置失败: $e');
      rethrow;
    }
  }

  /// 搜索工具
  List<String> searchTools(String keyword) {
    if (keyword.isEmpty) {
      return _toolIndex.map((item) => item[0]).toList();
    }

    final lowerKeyword = keyword.toLowerCase();
    return _toolIndex
        .where(
          (item) =>
              item[0].toLowerCase().contains(lowerKeyword) ||
              item[1].toLowerCase().contains(lowerKeyword),
        )
        .map((item) => item[0])
        .toList();
  }

  /// 获取统计信息
  Map<String, dynamic> getStatistics() {
    final pluginsStats = <String, Map<String, int>>{};

    _pluginTools.forEach((pluginId, toolSet) {
      pluginsStats[pluginId] = {
        'total': toolSet.toolCount,
        'enabled': toolSet.enabledToolCount,
      };
    });

    return {
      'total_tools': _toolIndex.length,
      'enabled_tools': getToolIndex(enabledOnly: true).length,
      'plugins': pluginsStats,
    };
  }

  /// 获取插件别名映射（用于生成AI Prompt）
  static Map<String, List<String>> getPluginAliases() {
    return Map.from(_pluginAliases);
  }

  /// 生成插件别名的 Prompt 描述
  static String generatePluginAliasesPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('### 🏷️ 插件别名映射\n');
    buffer.writeln('当用户使用以下自然语言描述时，请识别对应的插件ID：\n');

    _pluginAliases.forEach((pluginId, aliases) {
      buffer.writeln('- **$pluginId**: ${aliases.join('、')}');
    });

    buffer.writeln('\n**示例**：');
    buffer.writeln('- 用户说"帮我记一笔账" → 使用 `bill` 插件');
    buffer.writeln('- 用户说"查看今天的任务" → 使用 `todo` 插件');
    buffer.writeln('- 用户说"给频道发消息" → 使用 `chat` 插件\n');

    return buffer.toString();
  }
}
