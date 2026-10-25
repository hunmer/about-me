import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/theme_controller.dart';
import 'package:aboutme/core/builtin_plugins.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/services/clipboard_service.dart';
import 'package:aboutme/plugins/chat/events/user_events.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base_settings_controller.dart';
import 'export_controller.dart';
import 'import_controller.dart';
import 'full_backup_controller.dart';
import 'auto_update_controller.dart';

class SettingsScreenController extends ChangeNotifier {
  final BaseSettingsController _baseController;
  late ExportController _exportController;
  late ImportController _importController;
  late FullBackupController _fullBackupController;
  late AutoUpdateController _autoUpdateController;
  late SharedPreferences _prefs;
  BuildContext? _context;
  bool _initialized = false;
  final Map<String, bool> _pluginEnabledStates = {};

  bool isInitialized() => _initialized;

  SettingsScreenController() : _baseController = BaseSettingsController();

  Future<void> initializeControllers(BuildContext context) async {
    _context = context;
    await initPrefs(); // 确保等待初始化完成
    _exportController = ExportController(context);
    _importController = ImportController(context);
    _fullBackupController = FullBackupController(context);
    _autoUpdateController = AutoUpdateController(context);
    await _loadPluginStates();
    await _loadAppVersion();
    _initialized = true;
    notifyListeners();
  }

  // 应用版本号（头部统计展示）
  String _appVersion = '';
  String get appVersion => _appVersion;

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
    } catch (_) {
      _appVersion = '';
    }
  }

  Future<void> initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    enableLogging = _prefs.getBool('enable_logging') ?? false;
    _locationApiKey = _prefs.getString('location_api_key') ?? '';

    // 加载剪切板自动读取配置（默认关闭）
    _clipboardAutoRead = _prefs.getBool('clipboard_auto_read') ?? false;
    ClipboardService.instance.autoReadEnabled = _clipboardAutoRead;

    // 加载用户资料（设置页顶部头像/用户名）
    _userName = _prefs.getString('user_name') ?? '';
    _userAvatarPath = _prefs.getString('user_avatar_path');
  }

  // 用户资料（设置页顶部头像/用户名），聊天插件等从此数据源读取
  String _userName = '';
  String get userName => _userName.trim().isEmpty ? '用户' : _userName.trim();
  Future<void> setUserName(String value) async {
    _userName = value;
    await _prefs.setString('user_name', value);
    notifyListeners();
    _broadcastProfileUpdated();
  }

  String? _userAvatarPath;
  String? get userAvatarPath => _userAvatarPath;
  Future<void> setUserAvatarPath(String? value) async {
    _userAvatarPath = value;
    if (value == null || value.isEmpty) {
      await _prefs.remove('user_avatar_path');
    } else {
      await _prefs.setString('user_avatar_path', value);
    }
    notifyListeners();
    _broadcastProfileUpdated();
  }

  /// 广播用户资料更新（id 与聊天当前用户一致），刷新聊天消息气泡头像
  void _broadcastProfileUpdated() {
    EventManager.instance.broadcast(
      UserEventNames.userAvatarUpdated,
      UserAvatarUpdatedEventArgs(User(id: 'default_user', username: userName)),
    );
  }

  void toggleTheme(context) => ThemeController.toggleTheme(context);

  /// 直接设置主题，避免 toggleThemeMode 在三种模式间循环导致需要点击两次
  void setTheme(BuildContext context, bool isDark) {
    if (isDark) {
      ThemeController.setDarkTheme(context);
    } else {
      ThemeController.setLightTheme(context);
    }
  }

  // 语言相关
  Future<void> toggleLanguage(context) async {
    await _baseController.showLanguageSelectionDialog(context);
  }

  // 数据导出
  Future<void> exportData([BuildContext? context]) =>
      _exportController.exportData(context ?? _context);

  // 数据导入
  Future<void> importData() => _importController.importData();

  // 全量数据备份与恢复
  Future<void> exportAllData() => _fullBackupController.exportAllData();
  Future<void> importAllData() => _fullBackupController.importAllData();

  // 自动打开最后使用的插件设置
  bool get autoOpenLastPlugin => globalPluginManager.autoOpenLastPlugin;
  set autoOpenLastPlugin(bool value) {
    globalPluginManager.autoOpenLastPlugin = value;
    notifyListeners();
  }

  // 自动更新相关
  bool get autoCheckUpdate => _autoUpdateController.autoCheckUpdate;
  set autoCheckUpdate(bool value) {
    _autoUpdateController.autoCheckUpdate = value;
  }

  bool _enableLogging = false;
  bool get enableLogging => _enableLogging;
  set enableLogging(bool value) {
    _enableLogging = value;
    _prefs.setBool('enable_logging', value);
    notifyListeners();
  }

  // 定位 API Key 设置
  String _locationApiKey = '';
  String get locationApiKey => _locationApiKey;
  Future<void> setLocationApiKey(String value) async {
    _locationApiKey = value;
    await _prefs.setString('location_api_key', value);
    notifyListeners();
  }

  // 剪切板配置
  bool _clipboardAutoRead = false;
  bool get clipboardAutoRead => _clipboardAutoRead;
  set clipboardAutoRead(bool value) {
    _clipboardAutoRead = value;
    ClipboardService.instance.autoReadEnabled = value;
    _prefs.setBool('clipboard_auto_read', value);
    notifyListeners();
  }

  /// 手动读取并识别剪切板
  Future<bool> readAndProcessClipboard() async {
    return await ClipboardService.instance.processClipboard();
  }

  Future<void> checkForUpdates() => _autoUpdateController.showUpdateDialog();

  List<PluginBase> get availablePlugins {
    final installed = globalPluginManager.allPlugins;
    final installedIds = installed.map((plugin) => plugin.id).toSet();
    final builtin = BuiltinPlugins.createAll();
    final additional =
        builtin.where((plugin) => !installedIds.contains(plugin.id)).toList();
    return [...installed, ...additional];
  }

  bool isPluginEnabled(String pluginId) {
    return _pluginEnabledStates[pluginId] ?? true;
  }

  Future<void> setPluginEnabled(String pluginId, bool enabled) async {
    _pluginEnabledStates[pluginId] = enabled;
    notifyListeners();
    await globalConfigManager.setPluginEnabledState(pluginId, enabled);
  }

  Future<void> _loadPluginStates() async {
    final storedStates = globalConfigManager.getPluginEnabledStates();
    _pluginEnabledStates
      ..clear()
      ..addAll(storedStates);

    final Set<String> knownPluginIds = {};
    for (final plugin in globalPluginManager.allPlugins) {
      knownPluginIds.add(plugin.id);
    }
    for (final plugin in BuiltinPlugins.createAll()) {
      knownPluginIds.add(plugin.id);
    }
    for (final pluginId in knownPluginIds) {
      _pluginEnabledStates.putIfAbsent(pluginId, () => true);
    }
  }
}
