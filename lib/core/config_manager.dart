import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'data/aboutme_data_service.dart';
import 'storage/storage_manager.dart';

/// 配置管理器，负责管理插件配置
///
/// 全部读写走 system 域 config 命令（configs/ 前缀统一通道），
/// 原始文件层写已封闭（426）。
class ConfigManager {
  final StorageManager _storage;
  final Map<String, dynamic> _configs = {};
  final Map<String, dynamic> _appConfig = {};
  static const String _appConfigKey = 'app_config';

  ConfigManager(this._storage);

  /// 初始化配置管理器
  Future<void> initialize() async {
    // Web平台不需要创建目录，只需要确保存储管理器已初始化
    if (!kIsWeb) {
      await _storage.createDirectory('configs');
    }

    // 加载应用级配置
    await _loadAppConfig();
  }

  /// 加载应用级配置
  Future<void> _loadAppConfig() async {
    try {
      final config = await AboutmeDataService.instance.getConfig(
        '$_appConfigKey.json',
      );
      if (config is Map<String, dynamic>) {
        _appConfig.addAll(config);
      } else {
        throw StateError('app_config 形态异常: $config');
      }
    } catch (e) {
      _appConfig.addAll(_getDefaultConfig());
      await saveAppConfig(); // 保存默认配置到文件
    }
  }

  /// 获取默认配置
  Map<String, dynamic> _getDefaultConfig() {
    return {
      'themeMode': 'system',
      'locale': 'zh_CN',
      'permissionsOnboardingCompleted': false,
      'pluginStates': <String, dynamic>{},
    };
  }

  /// 保存应用级配置
  Future<void> saveAppConfig() async {
    await AboutmeDataService.instance.setConfig(
      '$_appConfigKey.json',
      _appConfig,
    );
  }

  /// 获取语言设置
  Locale getLocale() {
    final localeStr = _appConfig['locale'] as String;
    final parts = localeStr.split('_');
    if (parts.length == 1) {
      return Locale(parts[0]);
    } else if (parts.length > 1) {
      return Locale(parts[0], parts[1]);
    }
    // ignore: deprecated_member_use
    return WidgetsBinding.instance.window.locale;
  }

  /// 设置语言
  Future<void> setLocale(Locale locale) async {
    String localeStr = locale.languageCode;
    if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
      localeStr += '_${locale.countryCode}';
    }

    _appConfig['locale'] = localeStr;
    await saveAppConfig();
  }

  /// èŽ·å–åº”ç”¨çº§é…ç½®å€¼ï¼Œå¦‚æžœä¸å­˜åœ¨åˆ™è¿”å›žé»˜è®¤å€¼
  T getAppConfigValue<T>(String key, T defaultValue) {
    final value = _appConfig[key];
    if (value is T) {
      return value;
    }
    return defaultValue;
  }

  /// è®¾ç½®åº”ç”¨çº§é…ç½®å¹¶ç«‹å³ä¿å­˜
  Future<void> setAppConfigValue<T>(String key, T value) async {
    _appConfig[key] = value;
    await saveAppConfig();
  }

  /// 批量设置应用级配置并立即保存（只写一次文件）
  Future<void> setAppConfigValues(Map<String, dynamic> values) async {
    _appConfig.addAll(values);
    await saveAppConfig();
  }

  Map<String, bool> getPluginEnabledStates() {
    final states = _appConfig['pluginStates'];
    if (states is Map) {
      final Map<String, bool> result = {};
      states.forEach((key, value) {
        result[key.toString()] = value is bool ? value : value == true;
      });
      return result;
    }
    return {};
  }

  bool isPluginEnabled(String pluginId) {
    final states = getPluginEnabledStates();
    return states[pluginId] ?? true;
  }

  Future<void> setPluginEnabledState(String pluginId, bool enabled) async {
    final Map<String, dynamic> states = Map<String, dynamic>.from(
      (_appConfig['pluginStates'] as Map?) ?? {},
    );
    states[pluginId] = enabled;
    _appConfig['pluginStates'] = states;
    await saveAppConfig();
  }

  /// 配置键（configs/ 下相对路径）
  static String getPluginConfigKey(
    String pluginId, [
    String? fileName = 'settings',
  ]) {
    return '$pluginId/$fileName.json';
  }

  static String getPluginConfigPath(
    String pluginId, [
    String? fileName = 'settings',
  ]) {
    return 'configs/${getPluginConfigKey(pluginId, fileName)}';
  }

  /// 保存插件配置
  Future<void> savePluginConfig(
    String pluginId,
    Map<String, dynamic> config,
  ) async {
    _configs[pluginId] = config;
    await AboutmeDataService.instance.setConfig(
      getPluginConfigKey(pluginId),
      config,
    );
  }

  /// 获取插件配置
  Future<Map<String, dynamic>?> getPluginConfig(String pluginId) async {
    if (_configs.containsKey(pluginId)) {
      return _configs[pluginId] as Map<String, dynamic>?;
    }

    try {
      final config = await AboutmeDataService.instance.getConfig(
        getPluginConfigKey(pluginId),
      );
      if (config is! Map) return null;

      // 确保所有键都是String类型
      final result = <String, dynamic>{};
      for (final key in config.keys) {
        if (key is String) {
          result[key] = config[key];
        }
      }

      _configs[pluginId] = result;
      return result;
    } catch (e) {
      return null;
    }
  }

  /// 删除插件配置
  Future<void> deletePluginConfig(String pluginId) async {
    _configs.remove(pluginId);
    await AboutmeDataService.instance.deleteConfig(
      getPluginConfigKey(pluginId),
    );
  }
}
