import 'package:flutter/material.dart';
import 'storage/storage_manager.dart';
import 'plugin_manager.dart';
import 'config_manager.dart';

/// 插件数据刷新参数
class PluginRefreshDataArgs {
  /// 触发刷新的文件路径
  final String filePath;

  /// 触发源（websocket, manual, etc）
  final String source;

  /// 时间戳
  final DateTime timestamp;

  PluginRefreshDataArgs({
    required this.filePath,
    this.source = 'sync',
  }) : timestamp = DateTime.now();
}

/// 插件首次打开引导的单个步骤
///
/// 默认渲染为「图标 + 标题 + 说明」的介绍页；
/// 需要交互内容（如配置表单）时通过 [builder] 提供自定义视图，
/// 并在交互时把收集到的数据写入 [values]（整个引导共享一个 Map）。
class PluginOnboardingStep {
  const PluginOnboardingStep({
    this.icon,
    required this.title,
    required this.description,
    this.builder,
  });

  /// 步骤图标（介绍页插图占位，为空时回退到插件图标）
  final IconData? icon;

  final String title;
  final String description;

  /// 自定义内容构建器，返回 null 的插件使用默认图标+说明布局
  final Widget Function(BuildContext context, Map<String, dynamic> values)?
  builder;
}

/// 插件基类，所有插件必须继承此类
abstract class PluginBase {
  /// 插件唯一标识符
  String get id;

  /// 插件存储目录
  String get storageDir => getPluginStoragePath();

  /// 插件图标
  IconData? get icon => Icons.extension;

  /// 插件颜色
  Color? get color => Colors.blue;

  /// 存储管理器实例
  StorageManager? _storage;

  /// 诊断用：存储管理器是否已注入
  bool get hasStorage => _storage != null;

  /// 获取存储管理器
  /// 如果未设置存储管理器会抛出详细异常
  StorageManager get storage {
    final value = _storage;
    if (value == null) {
      throw StateError(
        '插件($id#$hashCode) 在 setStorageManager 之前访问了 storage',
      );
    }
    return value;
  }

  /// 插件配置
  Map<String, dynamic> _settings = {};

  /// 获取插件配置
  Map<String, dynamic> get settings => _settings;

  /// 设置存储管理器
  void setStorageManager(StorageManager storageManager) {
    _storage = storageManager;
  }

  String getPluginSettingPath() => ConfigManager.getPluginConfigPath(id);

  /// 加载插件配置
  Future<void> loadSettings(Map<String, dynamic> defaultSettings) async {
    try {
      final storedSettings = await storage.read(getPluginSettingPath());
      if (storedSettings.isNotEmpty) {
        _settings = Map<String, dynamic>.from(storedSettings);
        // 确保所有默认配置项都存在
        bool needsUpdate = false;
        for (var entry in defaultSettings.entries) {
          if (!_settings.containsKey(entry.key)) {
            _settings[entry.key] = entry.value;
            needsUpdate = true;
          }
        }
        if (needsUpdate) {
          await saveSettings();
        }
      } else {
        _settings = Map<String, dynamic>.from(defaultSettings);
        await saveSettings();
      }
    } catch (e) {
      _settings = Map<String, dynamic>.from(defaultSettings);
      try {
        await saveSettings();
      } catch (e) {
        print('Warning: Failed to save plugin settings: $e');
      }
    }
  }

  /// 保存插件配置
  Future<void> saveSettings() async {
    try {
      await storage.write(getPluginSettingPath(), _settings);
    } catch (e) {
      print('Warning: Failed to save plugin settings: $e');
    }
  }

  /// 更新插件配置
  Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    _settings.addAll(newSettings);
    await saveSettings();
  }

  /// 初始化插件
  Future<void> initialize();

  /// 注册到应用程序
  /// 用于在插件初始化后进行额外的设置，如注册服务、设置监听器等
  Future<void> registerToApp(
    PluginManager pluginManager,
    ConfigManager configManager,
  ) async {}

  /// 构建插件主视图
  Widget buildMainView(BuildContext context);

  /// 构建插件卡片视图
  /// 如果插件需要自定义卡片显示样式，可以重写此方法
  Widget? buildCardView(BuildContext context) => null;

  /// 是否提供设置页面
  ///
  /// 重写 [buildSettingsView] 的插件应同时重写此 getter 返回 true，
  /// 用于决定是否展示插件设置入口
  bool get hasSettingsView => false;

  /// 构建插件设置视图
  Widget buildSettingsView(BuildContext context) {
    return Column(children: [
      
      ],
    );
  }

  /// 获取插件存储路径
  String getPluginStoragePath() {
    return storage.getPluginStoragePath(id);
  }

  String? getPluginName(context) {
    return null;
  }

  /// 刷新插件数据（可选实现）
  ///
  /// 当数据通过同步服务更新时调用，插件应重写此方法以重新加载内存中的数据。
  /// 默认实现返回 false 表示未实现刷新功能。
  ///
  /// 参数:
  /// - [args] 刷新参数，包含触发源和文件路径
  ///
  /// 返回值:
  /// - true: 刷新成功
  /// - false: 未实现刷新或刷新失败
  Future<bool> refreshData([PluginRefreshDataArgs? args]) async {
    return false;
  }

  /// 是否支持指定文件的刷新（可选实现）
  ///
  /// 子类可重写以实现更精细的文件级别刷新控制
  bool supportsFileRefresh(String filePath) => true;

  /// 首次打开引导步骤（可选实现）
  ///
  /// 返回非空列表时，插件第一次通过 PluginManager.openPlugin 打开会弹出
  /// 引导页；默认返回空列表表示无引导
  List<PluginOnboardingStep> getOnboardingSteps(BuildContext context) =>
      const [];

  /// 引导完成回调（可选实现）
  ///
  /// [values] 为引导过程中各自定义步骤收集的数据
  Future<void> onOnboardingComplete(
    BuildContext context,
    Map<String, dynamic> values,
  ) async {}
}
