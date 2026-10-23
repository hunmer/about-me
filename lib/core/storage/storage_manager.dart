import 'dart:io';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path_provider;

import 'device_identity.dart';
import 'mobile_storage.dart';
import 'storage_backend_config.dart';
import 'web_storage.dart' as web_storage;

/// 存储管理器：在数据 SDK 的 [DataStore] 之上做 Flutter 宿主胶水 ——
/// 默认后端选择（本地/Web/远端 HTTP）、远端配置加载与回退、应用目录解析。
/// 数据操作语义全部复用 SDK，与服务端（aboutme_server）共享同一数据核心。
class StorageManager extends DataStore {
  StorageManager({
    StorageInterface? storage,
    StorageBackendConfigStore? configStore,
  }) : _storageWasInjected = storage != null,
       _configStore = configStore ?? LocalStorageBackendConfigStore(),
       super(storage: storage ?? _defaultStorage());

  final bool _storageWasInjected;
  final StorageBackendConfigStore _configStore;

  /// 远端存储初始化失败回退本地的原因；null 表示未发生回退
  String? remoteFallbackReason;

  static StorageInterface _defaultStorage() =>
      kIsWeb ? web_storage.WebStorage.instance : MobileStorage.instance;

  static StorageInterface get localBackend => _defaultStorage();

  /// 将共享文件物化到本地临时目录，供只接受真实路径的系统 API 使用。
  Future<File?> materializeToTemporaryFile(String storagePath) async {
    if (!isRemote) {
      final appData = await getApplicationDataDirectory();
      final file = File(path.join(appData.path, storagePath));
      return await file.exists() ? file : null;
    }
    final bytes = await readBytes(storagePath);
    if (bytes == null) return null;
    final tempRoot = await path_provider.getTemporaryDirectory();
    final safePath = storagePath.replaceAll('\\', '/');
    final target = File(
      path.join(tempRoot.path, 'aboutme_remote_cache', safePath),
    );
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
    return target;
  }

  /// 初始化存储管理器
  Future<void> initialize() async {
    if (_storageWasInjected) return;
    remoteFallbackReason = null;
    final config = await _configStore.load();
    if (config.isHttpEnabled) {
      // 配置无效时中止初始化，不能继续向默认本地后端写入。
      final httpStorage = HttpStorage.fromConfig(
        config,
        deviceId: DeviceIdentity.id,
      );
      setBackend(httpStorage);
      try {
        await httpStorage.testConnection();
      } catch (e) {
        remoteFallbackReason = e.toString();
        debugPrint('[StorageManager] 远端存储不可用，保持 HTTP 模式: $e');
      }
    } else {
      setBackend(_defaultStorage());
    }
    clearCache();
  }

  /// 获取应用文档目录
  /// 如果是浏览器环境返回'aboutme_app'，其他环境返回正常的应用文档目录
  static Future<Directory> getApplicationDocumentsDirectory() async {
    if (kIsWeb) {
      // 在web环境中创建虚拟目录对象
      return Directory('aboutme_app');
    }
    return await path_provider.getApplicationDocumentsDirectory();
  }

  /// 静态获取应用数据目录（包含 app_data 前缀）
  /// 桌面端(如Windows)的文档目录是用户公共目录，应用数据都在其 app_data 子目录下
  static Future<Directory> appDataDirectory() async {
    if (kIsWeb) {
      // Web 平台返回虚拟目录
      return Directory('aboutme_app');
    }
    final appDir = await getApplicationDocumentsDirectory();
    return Directory(path.join(appDir.path, 'app_data'));
  }

  /// 获取应用数据目录（包含 app_data 前缀）
  /// 所有插件数据都存储在这个目录下
  Future<Directory> getApplicationDataDirectory() => appDataDirectory();
}
