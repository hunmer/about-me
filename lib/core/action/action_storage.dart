/// 动作存储管理
/// 负责动作配置的持久化存储（基于 globalStorage，桌面/移动/Web 通用）
library;

import 'dart:convert';
import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/floating_ball/models/floating_ball_gesture.dart';
import 'package:flutter/material.dart';
import 'models/action_instance.dart';
import 'models/action_group.dart';

/// 动作存储配置文件名（globalStorage 存储 key，位于 app_data 根目录）
const String CONFIG_FILE_NAME = 'action_config.json';

/// 备份文件所在目录（app_data 下的子目录）
const String _backupDir = 'action_config_backups';

/// 动作存储管理类
class ActionStorage {
  // 单例
  static final ActionStorage _instance = ActionStorage._internal();
  factory ActionStorage() => _instance;
  ActionStorage._internal();

  /// 检查配置文件是否存在
  Future<bool> hasConfig() => globalStorage.exists(CONFIG_FILE_NAME);

  /// 加载配置
  Future<ActionStorageData> loadConfig() async {
    try {
      final raw = await globalStorage.readJson(CONFIG_FILE_NAME);
      if (raw is! Map || raw.isEmpty) {
        return _emptyConfig();
      }
      final json = _toStringKeyMap(raw);

      // 解析手势动作
      final gestureActions = <FloatingBallGesture, GestureActionConfig>{};
      final gestureJson = _toMapOrNull(json['gestureActions']);
      if (gestureJson != null) {
        gestureJson.forEach((key, value) {
          final gesture = FloatingBallGesture.values.firstWhere(
            (g) => g.name == key,
            orElse: () => FloatingBallGesture.tap,
          );
          gestureActions[gesture] = GestureActionConfig.fromJson(
            _toStringKeyMap(value),
          );
        });
      }

      // 解析自定义动作实例
      final customActions = <String, ActionInstance>{};
      final customActionsJson = _toMapOrNull(json['customActions']);
      if (customActionsJson != null) {
        customActionsJson.forEach((key, value) {
          customActions[key] = ActionInstance.fromJson(_toStringKeyMap(value));
        });
      }

      // 解析动作组
      final actionGroups = <String, ActionGroup>{};
      final actionGroupsJson = _toMapOrNull(json['actionGroups']);
      if (actionGroupsJson != null) {
        actionGroupsJson.forEach((key, value) {
          actionGroups[key] = ActionGroup.fromJson(_toStringKeyMap(value));
        });
      }

      return ActionStorageData(
        lastModified:
            DateTime.tryParse(json['lastModified'] as String? ?? '') ??
            DateTime.now(),
        gestureActions: gestureActions,
        customActions: customActions,
        actionGroups: actionGroups,
        settings: _toMapOrNull(json['settings']) ?? {},
      );
    } catch (e) {
      debugPrint('Failed to load config: $e');
      // 出错时返回空配置
      return _emptyConfig();
    }
  }

  ActionStorageData _emptyConfig() => ActionStorageData(
        lastModified: DateTime.now(),
        gestureActions: {},
        customActions: {},
        actionGroups: {},
        settings: {},
      );

  /// 保存配置
  Future<void> saveConfig(ActionStorageData data) async {
    await globalStorage.writeJson(CONFIG_FILE_NAME, data.toJson());
  }

  /// 备份配置，返回备份文件的存储 key
  Future<String> backupConfig() async {
    final content = await globalStorage.readFile(CONFIG_FILE_NAME);
    if (content.isEmpty) {
      throw StateError('Config file does not exist');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupKey = '$_backupDir/action_config_backup_$timestamp.json';
    await globalStorage.writeFile(backupKey, content);

    return backupKey;
  }

  /// 恢复配置
  Future<void> restoreConfig(String backupPath) async {
    final content = await globalStorage.readFile(backupPath);
    if (content.isEmpty) {
      throw StateError('Backup file does not exist');
    }

    await globalStorage.writeFile(CONFIG_FILE_NAME, content);
  }

  /// 删除配置
  Future<void> deleteConfig() async {
    await globalStorage.deleteFile(CONFIG_FILE_NAME);
  }

  /// 获取配置信息
  Future<ConfigInfo> getConfigInfo() async {
    final content = await globalStorage.readFile(CONFIG_FILE_NAME);

    return ConfigInfo(
      exists: content.isNotEmpty,
      size: content.length,
      lastModified: null,
    );
  }

  /// 列出所有备份文件
  Future<List<BackupFileInfo>> listBackups() async {
    final keys = await globalStorage.getKeysWithPrefix(_backupDir);
    final backups = <BackupFileInfo>[];

    for (final key in keys) {
      if (!key.contains('backup')) continue;

      final content = await globalStorage.readFile(key);
      final match = RegExp(r'backup_(\d+)\.json$').firstMatch(key);
      backups.add(
        BackupFileInfo(
          path: key,
          name: key.split('/').last,
          size: content.length,
          createdAt: match != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  int.parse(match.group(1)!),
                )
              : DateTime.now(),
        ),
      );
    }

    // 按创建时间排序
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return backups;
  }

  /// 清理旧备份（保留最新 N 个）
  Future<void> cleanOldBackups({int keepCount = 5}) async {
    final backups = await listBackups();

    if (backups.length <= keepCount) return;

    // 删除多余的备份
    for (int i = keepCount; i < backups.length; i++) {
      await globalStorage.deleteFile(backups[i].path);
    }
  }

  /// 验证配置文件
  Future<ConfigValidationResult> validateConfig() async {
    try {
      final raw = await globalStorage.readJson(CONFIG_FILE_NAME);
      if (raw is! Map || raw.isEmpty) {
        return ConfigValidationResult(
          isValid: false,
          errors: ['Config file does not exist'],
          warnings: [],
        );
      }
      final json = _toStringKeyMap(raw);

      final errors = <String>[];
      final warnings = <String>[];

      // 检查必需字段
      final requiredFields = ['lastModified'];
      for (final field in requiredFields) {
        if (!json.containsKey(field)) {
          errors.add('Missing required field: $field');
        }
      }

      // 检查手势动作格式
      final gestureJson = _toMapOrNull(json['gestureActions']);
      if (gestureJson != null) {
        for (final entry in gestureJson.entries) {
          final gestureName = entry.key;
          final config = _toMapOrNull(entry.value);

          if (config == null) {
            errors.add('Invalid gesture config for $gestureName');
            continue;
          }

          FloatingBallGesture.values.firstWhere(
            (g) => g.name == gestureName,
            orElse: () => FloatingBallGesture.tap,
          );

          // 验证配置结构
          try {
            GestureActionConfig.fromJson(config);
          } catch (e) {
            errors.add('Invalid gesture config for $gestureName: $e');
          }
        }
      }

      // 检查自定义动作实例格式
      final customActionsJson = _toMapOrNull(json['customActions']);
      if (customActionsJson != null) {
        for (final entry in customActionsJson.entries) {
          final id = entry.key;
          final instanceJson = _toMapOrNull(entry.value);

          if (instanceJson == null) {
            errors.add('Invalid custom action instance: $id');
            continue;
          }

          try {
            ActionInstance.fromJson(instanceJson);
          } catch (e) {
            errors.add('Invalid custom action instance $id: $e');
          }
        }
      }

      // 检查动作组格式
      final actionGroupsJson = _toMapOrNull(json['actionGroups']);
      if (actionGroupsJson != null) {
        for (final entry in actionGroupsJson.entries) {
          final id = entry.key;
          final groupJson = _toMapOrNull(entry.value);

          if (groupJson == null) {
            errors.add('Invalid action group: $id');
            continue;
          }

          try {
            ActionGroup.fromJson(groupJson);
          } catch (e) {
            errors.add('Invalid action group $id: $e');
          }
        }
      }

      return ConfigValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        warnings: warnings,
      );
    } catch (e) {
      return ConfigValidationResult(
        isValid: false,
        errors: ['Failed to parse config: $e'],
        warnings: [],
      );
    }
  }

  /// 导出配置为 JSON 字符串
  Future<String> exportConfigAsJson() async {
    final data = await loadConfig();

    final exportData = {
      'exportTime': DateTime.now().toIso8601String(),
      'data': data.toJson(),
    };

    return JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// 从 JSON 字符串导入配置
  Future<void> importConfigFromJson(String jsonString) async {
    // 备份当前配置
    final backup = await backupConfig();

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final dataJson = _toMapOrNull(json['data']) ?? json;

      // 解析手势动作
      final gestureActions = <FloatingBallGesture, GestureActionConfig>{};
      final gestureJson = _toMapOrNull(dataJson['gestureActions']);
      if (gestureJson != null) {
        gestureJson.forEach((key, value) {
          final gesture = FloatingBallGesture.values.firstWhere(
            (g) => g.name == key,
            orElse: () => FloatingBallGesture.tap,
          );
          gestureActions[gesture] = GestureActionConfig.fromJson(
            _toStringKeyMap(value),
          );
        });
      }

      // 解析自定义动作实例
      final customActions = <String, ActionInstance>{};
      final customActionsJson = _toMapOrNull(dataJson['customActions']);
      if (customActionsJson != null) {
        customActionsJson.forEach((key, value) {
          customActions[key] = ActionInstance.fromJson(_toStringKeyMap(value));
        });
      }

      // 解析动作组
      final actionGroups = <String, ActionGroup>{};
      final actionGroupsJson = _toMapOrNull(dataJson['actionGroups']);
      if (actionGroupsJson != null) {
        actionGroupsJson.forEach((key, value) {
          actionGroups[key] = ActionGroup.fromJson(_toStringKeyMap(value));
        });
      }

      final data = ActionStorageData(
        lastModified: DateTime.now(),
        gestureActions: gestureActions,
        customActions: customActions,
        actionGroups: actionGroups,
        settings: _toMapOrNull(dataJson['settings']) ?? {},
      );

      await saveConfig(data);
    } catch (e) {
      // 导入失败，恢复备份
      await restoreConfig(backup);
      rethrow;
    }
  }

  // Web 端解码结果可能是 Map<dynamic, dynamic>，统一转成 Map<String, dynamic>
  Map<String, dynamic> _toStringKeyMap(dynamic value) {
    return (value as Map).map((k, v) => MapEntry(k.toString(), v));
  }

  Map<String, dynamic>? _toMapOrNull(dynamic value) {
    return value is Map ? _toStringKeyMap(value) : null;
  }
}

/// 存储数据类
class ActionStorageData {
  final DateTime lastModified;
  final Map<FloatingBallGesture, GestureActionConfig> gestureActions;
  final Map<String, ActionInstance> customActions;
  final Map<String, ActionGroup> actionGroups;
  final Map<String, dynamic> settings;

  ActionStorageData({
    required this.lastModified,
    required this.gestureActions,
    required this.customActions,
    required this.actionGroups,
    required this.settings,
  });

  Map<String, dynamic> toJson() {
    return {
      'lastModified': lastModified.toIso8601String(),
      'gestureActions': gestureActions.map(
        (gesture, config) => MapEntry(gesture.name, config.toJson()),
      ),
      'customActions': customActions.map(
        (id, instance) => MapEntry(id, instance.toJson()),
      ),
      'actionGroups': actionGroups.map(
        (id, group) => MapEntry(id, group.toJson()),
      ),
      'settings': settings,
    };
  }
}

/// 配置信息
class ConfigInfo {
  final bool exists;
  final int size;
  final DateTime? lastModified;

  const ConfigInfo({
    required this.exists,
    required this.size,
    this.lastModified,
  });
}

/// 备份文件信息
class BackupFileInfo {
  final String path;
  final String name;
  final int size;
  final DateTime createdAt;

  const BackupFileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.createdAt,
  });
}

/// 配置验证结果
class ConfigValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ConfigValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  bool get hasWarnings => warnings.isNotEmpty;
}
