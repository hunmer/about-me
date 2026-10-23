import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/scripts_center/models/script_info.dart';
import 'package:aboutme/plugins/scripts_center/models/script_folder.dart';

/// 脚本加载器服务
///
/// 负责加载JS代码和JSON元数据。数据统一存于 scripts_center 分区，
/// 全部经 SDK 命令（AboutmeDataService.call）读写，不再直接操作文件系统。
class ScriptLoader {
  final StorageManager storage;

  /// 内置脚本 ID 列表（assets/scripts/{id}/ 下的脚本）
  static const List<String> builtInScriptIds = [
    'line_sticker',
  ];

  /// 已下线的内置脚本（2026-10 迁入工具箱插件成为原生小工具）：
  /// 本地残留脚本在 syncBuiltInScripts 时清理，用户配置迁移由工具箱服务负责
  static const List<String> _retiredBuiltInScriptIds = [
    'ai_image',
    'image_search',
  ];

  /// 旧分区顶层键（迁移用）
  static const String _legacySourcesKey =
      'configs/scripts_center_script_sources.json';
  static const String _legacyInstalledKey =
      'configs/scripts_center_installed_scripts';

  ScriptLoader(this.storage);

  /// 获取默认scripts目录路径（仅作文件夹展示标识，数据实际在 SDK 分区）
  Future<String> getScriptsDirectory() async {
    return 'scripts_center/scripts';
  }

  /// 调用 scripts_center 域命令，失败抛异常（调用方自行兜底）
  Future<dynamic> call(String action, Map<String, dynamic> params) async {
    final result = await AboutmeDataService.instance.call(
      'scripts_center',
      action,
      params,
    );
    if (result['success'] != true) {
      throw Exception('scripts_center.$action 失败: ${result['error']}');
    }
    return result['data'];
  }

  /// 同步内置脚本（在 loadScripts 之前调用，先执行旧分区迁移）
  ///
  /// 内置脚本随应用 assets 打包（assets/scripts/{id}/）：
  /// - 本地不存在：从 assets 恢复
  /// - assets 版本更高：自动升级覆盖（代码与元数据），用户配置不受影响
  /// - 版本相同：跳过（保留用户对内置脚本代码的本地修改）
  Future<void> syncBuiltInScripts() async {
    // 一次性幂等迁移：旧 scripts/ 与 configs/scripts_center* → scripts_center 分区
    await migrateLegacyPartition();

    final items = <Map<String, dynamic>>[];
    for (final scriptId in builtInScriptIds) {
      try {
        final assetsMetaJson = await rootBundle.loadString(
          'assets/scripts/$scriptId/metadata.json',
        );
        final assetsMeta =
            jsonDecode(assetsMetaJson) as Map<String, dynamic>;
        final code = await rootBundle.loadString(
          'assets/scripts/$scriptId/script.js',
        );
        items.add({'id': scriptId, 'metadata': assetsMeta, 'code': code});
      } catch (e) {
        print('❌ 同步内置脚本失败: $scriptId, 错误: $e');
      }
    }

    if (items.isNotEmpty) {
      try {
        final result = await call('syncBuiltin', {'items': items}) as Map;
        for (final id in (result['synced'] as List)) {
          print('✅ 内置脚本已恢复/升级: $id');
        }
        // skipped：本地版本不低于 assets，保留本地修改

        // 兜底：元数据在而代码缺失（如手动删除过 script.js）时强制恢复代码
        for (final item in items) {
          final id = item['id'] as String;
          final code = await call('getCode', {'id': id}) as String?;
          if (code == null || code.isEmpty) {
            await call('saveCode', {'id': id, 'code': item['code']});
          }
        }
      } catch (e) {
        print('❌ 同步内置脚本命令失败: $e');
      }
    }

    // 清理已下线内置脚本的本地残留（其配置已由工具箱服务迁移，
    // 本地被用户改过的脚本也一并移除——功能已由原生小工具替代）
    for (final scriptId in _retiredBuiltInScriptIds) {
      try {
        final exists = await call('existsScript', {'id': scriptId}) as bool;
        if (!exists) continue;
        final metadata = await call('getMeta', {'id': scriptId});
        // 仅删除带 builtIn 标记的（用户自建同名脚本不受影响）
        if (metadata is Map && metadata['builtIn'] == true) {
          await call('deleteScript', {'id': scriptId});
          print('🧹 已清理下线内置脚本: $scriptId');
        }
      } catch (e) {
        print('⚠️ 清理下线内置脚本失败: $scriptId, 错误: $e');
      }
    }
  }

  /// 旧分区数据一次性迁移（幂等）：
  /// - scripts/{id}/metadata.json + script.js → 分区 createScript
  /// - scripts/index.json → 废弃直接删
  /// - configs/scripts_center/{id}_config.json → 分区 setConfig
  ///   （ai_image/image_search 两个已下线工具的配置留给工具箱服务迁移）
  /// - configs/scripts_center/execution_log.json → recordExecution 回放
  /// - configs/scripts_center_script_sources.json → store/sources.json
  /// - configs/scripts_center_installed_scripts → store/installed.json
  ///
  /// 触发条件：分区内无任何脚本且旧分区存在数据；迁移后删除旧文件，
  /// 之后启动条件不再成立。
  Future<void> migrateLegacyPartition() async {
    final svc = AboutmeDataService.instance;
    try {
      final existing = await call('listScripts', {}) as List;
      if (existing.isNotEmpty) return;

      final legacyScriptKeys = await svc.listPathKeys('scripts/');
      final legacyConfigKeys = await svc.listPathKeys('configs/scripts_center');
      final legacySourcesExists = await svc.existsPath(_legacySourcesKey);
      final legacyInstalledExists = await svc.existsPath(_legacyInstalledKey);
      if (legacyScriptKeys.isEmpty &&
          legacyConfigKeys.isEmpty &&
          !legacySourcesExists &&
          !legacyInstalledExists) {
        return;
      }

      // 1) 脚本：metadata + code → 分区（分区当前为空，不会 CONFLICT）
      final ids = <String>{};
      for (final key in legacyScriptKeys) {
        final parts = key.split('/'); // scripts/{id}/{file}
        if (parts.length == 3) ids.add(parts[1]);
      }
      for (final id in ids) {
        try {
          final metadata = await svc.readPath('scripts/$id/metadata.json');
          final code = await svc.readPathText('scripts/$id/script.js');
          if (metadata is Map && metadata.isNotEmpty) {
            await call('createScript', {
              'id': id,
              'metadata': metadata,
              'code': code,
            });
          }
        } catch (e) {
          print('⚠️ 迁移脚本失败: $id, 错误: $e');
        }
      }

      // 2) 脚本配置（跳过已下线工具箱工具，其配置由工具箱兜底迁移）
      for (final key in legacyConfigKeys) {
        final name = key.split('/').last;
        if (name == 'execution_log.json' || !name.endsWith('_config.json')) {
          continue;
        }
        final scriptId = name.substring(0, name.length - '_config.json'.length);
        if (_retiredBuiltInScriptIds.contains(scriptId)) continue;
        try {
          final config = await svc.readPath(key);
          if (config is Map && config.isNotEmpty) {
            await call('setConfig', {'scriptId': scriptId, 'config': config});
          }
          await svc.deletePath(key);
        } catch (e) {
          print('⚠️ 迁移脚本配置失败: $scriptId, 错误: $e');
        }
      }

      // 3) 执行记录：倒序回放（recordExecution 头部插入，最终顺序与旧文件一致）
      const legacyLogKey = 'configs/scripts_center/execution_log.json';
      if (legacyConfigKeys.contains(legacyLogKey)) {
        try {
          final entries = await svc.readPath(legacyLogKey);
          if (entries is List && entries.isNotEmpty) {
            for (final entry in entries.reversed.whereType<Map>()) {
              await call('recordExecution', {
                'entry': Map<String, dynamic>.from(entry),
              });
            }
          }
          await svc.deletePath(legacyLogKey);
        } catch (e) {
          print('⚠️ 迁移执行记录失败: $e');
        }
      }

      // 4) 商场源配置与已安装脚本
      try {
        if (legacySourcesExists) {
          final sources = await svc.readPath(_legacySourcesKey);
          if (sources is List && sources.isNotEmpty) {
            await call('saveSources', {'sources': sources});
          }
          await svc.deletePath(_legacySourcesKey);
        }
        if (legacyInstalledExists) {
          final installed = await svc.readPath(_legacyInstalledKey);
          if (installed is List && installed.isNotEmpty) {
            await call('saveInstalled', {'installed': installed});
          }
          await svc.deletePath(_legacyInstalledKey);
        }
      } catch (e) {
        print('⚠️ 迁移商场数据失败: $e');
      }

      // 5) 删除旧 scripts/ 文件（含废弃的 index.json）
      for (final key in legacyScriptKeys) {
        try {
          await svc.deletePath(key);
        } catch (_) {}
      }
      print('✅ scripts_center 旧分区迁移完成（${ids.length} 个脚本）');
    } catch (e) {
      print('❌ scripts_center 旧分区迁移失败: $e');
    }
  }

  /// 扫描指定文件夹，返回该文件夹下的所有脚本信息
  ///
  /// 数据统一存于 SDK 分区，文件夹参数仅保留兼容签名
  Future<List<ScriptInfo>> scanScriptsInFolder(ScriptFolder folder) async {
    return listScripts();
  }

  /// 扫描scripts目录，返回所有脚本信息（已废弃，建议使用 scanScriptsInFolder）
  @Deprecated('使用 scanScriptsInFolder 代替')
  Future<List<ScriptInfo>> scanScripts() => listScripts();

  /// 列出分区内的全部脚本
  Future<List<ScriptInfo>> listScripts() async {
    try {
      final rows = await call('listScripts', {}) as List;
      final scripts = <ScriptInfo>[];
      for (final row in rows) {
        try {
          final map = row as Map;
          final id = map['id'] as String;
          scripts.add(ScriptInfo.fromJson(
            Map<String, dynamic>.from(map['metadata'] as Map),
            id: id,
            path: 'scripts_center/scripts/$id',
          ));
        } catch (e) {
          print('⚠️ 加载脚本失败: ${(row as Map)['id']}, 错误: $e');
        }
      }
      return scripts;
    } catch (e) {
      print('❌ 扫描脚本失败: $e');
      return [];
    }
  }

  /// 加载单个脚本的元数据
  Future<ScriptInfo?> loadScriptMetadata(
    String scriptId, [
    String? basePath,
  ]) async {
    try {
      final jsonData = await call('getMeta', {'id': scriptId});
      if (jsonData == null || jsonData is! Map) {
        print('⚠️ 元数据不存在: $scriptId');
        return null;
      }

      return ScriptInfo.fromJson(
        Map<String, dynamic>.from(jsonData),
        id: scriptId,
        path: 'scripts_center/scripts/$scriptId',
      );
    } catch (e) {
      print('❌ 加载脚本元数据失败: $scriptId, 错误: $e');
      return null;
    }
  }

  /// 读取脚本代码
  Future<String?> loadScriptCode(String scriptId) async {
    try {
      final code = await call('getCode', {'id': scriptId}) as String?;
      if (code == null) {
        print('⚠️ 脚本文件不存在: $scriptId');
      }
      return code;
    } catch (e) {
      print('❌ 加载脚本代码失败: $scriptId, 错误: $e');
      return null;
    }
  }

  /// 保存脚本元数据
  Future<void> saveScriptMetadata(String scriptId, ScriptInfo info) async {
    try {
      // 更新修改时间
      final updatedInfo = info.copyWith(updatedAt: DateTime.now());
      await call('saveMeta', {
        'id': scriptId,
        'metadata': updatedInfo.toJson(),
      });
      print('✅ 保存脚本元数据成功: $scriptId');
    } catch (e) {
      print('❌ 保存脚本元数据失败: $scriptId, 错误: $e');
      rethrow;
    }
  }

  /// 保存脚本代码
  Future<void> saveScriptCode(String scriptId, String code) async {
    try {
      await call('saveCode', {'id': scriptId, 'code': code});
      print('✅ 保存脚本代码成功: $scriptId');
    } catch (e) {
      print('❌ 保存脚本代码失败: $scriptId, 错误: $e');
      rethrow;
    }
  }

  /// 删除脚本（分区级联删除：元数据、代码、运行配置）
  Future<void> deleteScript(String scriptId) async {
    // 内置脚本不可删除（兜底，UI 与 Manager 层已有拦截）
    if (builtInScriptIds.contains(scriptId)) {
      throw Exception('内置脚本不可删除: $scriptId');
    }

    try {
      await call('deleteScript', {'id': scriptId});
      print('✅ 删除脚本成功: $scriptId');
    } catch (e) {
      print('❌ 删除脚本失败: $scriptId, 错误: $e');
      rethrow;
    }
  }

  /// 创建新脚本
  Future<ScriptInfo> createScript({
    required String scriptId,
    required String name,
    String version = '1.0.0',
    String description = '',
    String icon = 'code',
    String author = 'Unknown',
  }) async {
    try {
      final scriptInfo = ScriptInfo(
        id: scriptId,
        path: 'scripts_center/scripts/$scriptId',
        name: name,
        version: version,
        description: description,
        icon: icon,
        author: author,
        enabled: true,
        type: 'module',
        triggers: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 命令内校验 id 重复（CONFLICT）
      await call('createScript', {
        'id': scriptId,
        'metadata': scriptInfo.toJson(),
        'code': _getDefaultScriptTemplate(name),
      });

      print('✅ 创建脚本成功: $scriptId');
      return scriptInfo;
    } catch (e) {
      print('❌ 创建脚本失败: $scriptId, 错误: $e');
      rethrow;
    }
  }

  /// 获取默认脚本模板
  String _getDefaultScriptTemplate(String name) {
    return '''// $name
// 创建时间: ${DateTime.now().toIso8601String()}

(async function() {
  // 获取传入参数
  const params = typeof args !== 'undefined' ? args : {};

  log('脚本开始执行: $name', 'info');

  try {
    // 在这里编写你的脚本逻辑

    // 示例：访问存储
    // const data = await storage.get('my_key');
    // await storage.set('my_key', { value: 'Hello' });

    // 示例：触发事件
    // emit('my_custom_event', { message: 'Hello from script' });

    // 示例：调用其他脚本
    // const result = await runScript('other_script', { param1: 'value' });

    log('脚本执行完成', 'info');
    return { success: true, message: '执行成功' };
  } catch (error) {
    log('脚本执行失败: ' + error, 'error');
    return { success: false, error: error.toString() };
  }
})();
''';
  }
}
