import 'package:aboutme/core/services/speech_recognition_config_service.dart';

import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/settings_screen/widgets/speech_recognition_settings_dialog.dart';
import 'package:aboutme/core/floating_ball/settings_screen.dart';
import 'package:aboutme/core/floating_ball/floating_ball_manager.dart';
import 'package:aboutme/screens/settings_screen/controllers/permission_controller.dart';
import 'package:aboutme/screens/settings_screen/widgets/permission_request_dialog.dart';
import 'package:aboutme/screens/about_screen/about_screen.dart';
import 'package:get/get.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/widgets/route_viewer_dialog.dart';
import 'package:aboutme/screens/route.dart';
import 'package:aboutme/plugins/reminder/screens/reminder_list_screen.dart';
import '../controllers/settings_screen_controller.dart';
import '../widgets/settings_group.dart';

/// 应用设置：悬浮球、插件、剪切板、权限、更新、开发者测试、关于
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late SettingsScreenController _controller;
  bool _isSpeechRecognitionConfigured = false;

  @override
  void initState() {
    super.initState();
    _controller = SettingsScreenController();

    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    // 初始化语音识别配置服务
    _initSpeechRecognitionConfig();
  }

  // 初始化语音识别配置服务
  Future<void> _initSpeechRecognitionConfig() async {
    await SpeechRecognitionConfigService.instance.initialize();
    if (mounted) {
      setState(() {
        _isSpeechRecognitionConfigured =
            SpeechRecognitionConfigService.instance.isConfigured;
      });
    }
  }

  // 显示语音识别设置对话框
  Future<void> _showSpeechRecognitionSettings() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const SpeechRecognitionSettingsDialog(),
    );

    if (result == true && mounted) {
      setState(() {
        _isSpeechRecognitionConfigured =
            SpeechRecognitionConfigService.instance.isConfigured;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 异步初始化控制器
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    await _controller.initializeControllers(context);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 显示定位 API Key 设置对话框
  Future<void> _showLocationApiKeyDialog() async {
    final TextEditingController apiKeyController = TextEditingController(
      text: _controller.locationApiKey,
    );

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('screens_setLocationApiKey'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'screens_locationApiKeyHint'.tr,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: apiKeyController,
                  decoration: InputDecoration(
                    labelText: 'screens_apiKeyLabel'.tr,
                    hintText: 'screens_apiKeyInputHint'.tr,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 12),
                Text(
                  'screens_locationApiKeyGuide'.tr,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('screens_cancel'.tr),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(apiKeyController.text);
                },
                child: Text('app_save'.tr),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      await _controller.setLocationApiKey(result);
      if (mounted) {
        setState(() {});
      }
    }

    apiKeyController.dispose();
  }

  Future<void> _showPluginManagementSheet() async {
    await SmoothBottomSheet.show(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final double sheetHeight = MediaQuery.of(context).size.height * 0.75;
        return SizedBox(
          height: sheetHeight,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final List<PluginBase> plugins = List<PluginBase>.from(
                _controller.availablePlugins,
              )..sort(
                (a, b) => (a.getPluginName(context) ?? a.id).compareTo(
                  b.getPluginName(context) ?? b.id,
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'settings_screen_pluginManagementTip'.tr,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: plugins.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final plugin = plugins[index];
                        final pluginName =
                            plugin.getPluginName(context) ?? plugin.id;
                        final isEnabled = _controller.isPluginEnabled(
                          plugin.id,
                        );
                        return SwitchListTile(
                          title: Text(pluginName),
                          subtitle: Text(plugin.id),
                          value: isEnabled,
                          onChanged: (value) async {
                            await _controller.setPluginEnabled(
                              plugin.id,
                              value,
                            );
                            setModalState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showPermissionEntry =
        UniversalPlatform.isAndroid || UniversalPlatform.isIOS;
    if (!_controller.isInitialized()) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('应用设置')),
      body: DSThemeBridge(
        child: ListView(
        // 底部叠加系统安全区高度，避免最后几项被遮挡
        padding: EdgeInsets.fromLTRB(
          16.0,
          16.0,
          16.0,
          16.0 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          // 通用
          SettingsGroup(
            title: '通用',
            children: [
              FutureBuilder<bool>(
                future: FloatingBallManager().isEnabled(),
                builder: (context, snapshot) {
                  final bool isEnabled = snapshot.data ?? true;
                  return DSListItem(
                    title: 'settings_screen_floatingBallTitle'.tr,
                    subtitle: isEnabled
                        ? 'settings_screen_floatingBallEnabled'.tr
                        : 'settings_screen_floatingBallDisabled'.tr,
                    leading: const Icon(Icons.touch_app, size: 22),
                    showChevron: true,
                    onTap: () {
                      NavigationHelper.push(
                        context,
                        const FloatingBallSettingsScreen(),
                        routeName: '/settings/floating_ball_settings',
                      );
                    },
                  );
                },
              ),
              if (UniversalPlatform.isAndroid)
                DSListItem(
                  title: 'screens_floatingBallSettings'.tr,
                  subtitle: 'screens_manageSystemFloatingBall'.tr,
                  leading: const Icon(Icons.touch_app, size: 22),
                  showChevron: true,
                  onTap: () {
                    Navigator.pushNamed(context, '/floating_ball');
                  },
                ),
              DSListItem(
                title: '定时提醒',
                subtitle: '管理定时提醒任务',
                leading: const Icon(Icons.alarm, size: 22),
                showChevron: true,
                onTap: () {
                  NavigationHelper.push(
                    context,
                    const ReminderListScreen(),
                    routeName: '/settings/reminder',
                  );
                },
              ),
              DSListItem(
                title: 'settings_screen_pluginManagementTitle'.tr,
                subtitle: 'settings_screen_pluginManagementSubtitle'.tr,
                leading: const Icon(Icons.extension, size: 22),
                showChevron: true,
                onTap: _showPluginManagementSheet,
              ),
              DSListItem(
                title: 'settings_screen_autoOpenLastPluginTitle'.tr,
                subtitle: 'settings_screen_autoOpenLastPluginSubtitle'.tr,
                leading: const Icon(Icons.play_circle, size: 22),
                trailing: DSSwitch(
                  value: _controller.autoOpenLastPlugin,
                  onChanged:
                      (value) => setState(() {
                        _controller.autoOpenLastPlugin = value;
                      }),
                ),
              ),
              DSListItem(
                title: 'screens_locationApiKey'.tr,
                subtitle: _controller.locationApiKey.isEmpty
                    ? 'screens_locationApiKeyNotSet'.tr
                    : 'screens_locationApiKeyPartial'.trParams({
                      'key': _controller.locationApiKey.substring(0, 8),
                    }),
                leading: const Icon(Icons.location_on, size: 22),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () => _showLocationApiKeyDialog(),
              ),
              DSListItem(
                title: '语音识别设置',
                subtitle: _isSpeechRecognitionConfigured
                    ? '已配置腾讯云语音识别'
                    : '配置语音识别服务',
                leading: const Icon(Icons.mic, size: 22),
                trailing: _isSpeechRecognitionConfigured
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showSpeechRecognitionSettings,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 剪切板设置
          SettingsGroup(
            title: '剪切板设置',
            children: [
              DSListItem(
                title: '自动读取剪切板',
                subtitle: '启用后将自动识别剪切板中的数据',
                leading: const Icon(Icons.content_paste, size: 22),
                trailing: DSSwitch(
                  value: _controller.clipboardAutoRead,
                  onChanged:
                      (value) => setState(() {
                        _controller.clipboardAutoRead = value;
                      }),
                ),
              ),
              DSListItem(
                title: '读取并识别剪切板',
                subtitle: '手动读取剪切板中的数据并识别处理',
                leading: const Icon(Icons.content_paste_go, size: 22),
                showChevron: true,
                onTap: () async {
                  final result = await _controller.readAndProcessClipboard();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result ? '剪切板识别成功' : '剪切板中没有可识别的数据'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              if (showPermissionEntry)
                DSListItem(
                  title: 'app_permissionsTitle'.tr,
                  subtitle: 'app_permissionsManageDescription'.tr,
                  leading: const Icon(Icons.privacy_tip, size: 22),
                  showChevron: true,
                  onTap: () async {
                    await showPermissionRequestDialog(
                      context: context,
                      controller: PermissionController(),
                      barrierDismissible: true,
                      showSkipButton: false,
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 更新
          SettingsGroup(
            title: '更新',
            children: [
              DSListItem(
                title: 'settings_screen_autoCheckUpdateTitle'.tr,
                subtitle: 'settings_screen_autoCheckUpdateSubtitle'.tr,
                leading: const Icon(Icons.system_update, size: 22),
                trailing: DSSwitch(
                  value: _controller.autoCheckUpdate,
                  onChanged:
                      (value) => setState(() {
                        _controller.autoCheckUpdate = value;
                      }),
                ),
              ),
              DSListItem(
                title: 'settings_screen_checkUpdateTitle'.tr,
                subtitle: 'settings_screen_checkUpdateSubtitle'.tr,
                leading: const Icon(Icons.update, size: 22),
                showChevron: true,
                onTap: _controller.checkForUpdates,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 开发者测试
          SettingsGroup(
            title: '开发者测试',
            children: [
              DSListItem(
                title: 'Toast 测试',
                subtitle: '测试 Toast 显示、动画和自定义 Widget',
                leading: const Icon(Icons.notifications_active, size: 22),
                showChevron: true,
                onTap: () {
                  Navigator.pushNamed(context, '/toast_test');
                },
              ),
              DSListItem(
                title: '后台播报测试',
                subtitle: '测试 TTS 后台定时播报功能',
                leading: const Icon(Icons.record_voice_over, size: 22),
                showChevron: true,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.backgroundAnnouncementTest,
                  );
                },
              ),
              DSListItem(
                title: '数据选择器测试',
                subtitle: '测试插件数据选择器系统',
                leading: const Icon(Icons.account_tree, size: 22),
                showChevron: true,
                onTap: () {
                  Navigator.pushNamed(context, '/data_selector_test');
                },
              ),
              DSListItem(
                title: '路由查看器',
                subtitle: '查看所有可用路由',
                leading: const Icon(Icons.route, size: 22),
                showChevron: true,
                onTap: () {
                  RouteViewerDialog.show(context);
                },
              ),
              DSListItem(
                title: 'SwipeAction 测试',
                subtitle: '测试滑动操作组件',
                leading: const Icon(Icons.swipe, size: 22),
                showChevron: true,
                onTap: () {
                  Navigator.pushNamed(context, '/swipe_action_test');
                },
              ),
              DSListItem(
                title: 'screens_jsonDynamicWidgetTest'.tr,
                subtitle: 'screens_testAndPreviewDynamicUI'.tr,
                leading: const Icon(Icons.widgets, size: 22),
                showChevron: true,
                onTap: () {
                  Navigator.pushNamed(context, '/json_dynamic_test');
                },
              ),
              DSListItem(
                title: 'screens_notificationTest'.tr,
                leading: const Icon(Icons.notifications, size: 22),
                showChevron: true,
                onTap: () {
                  Navigator.pushNamed(context, '/notification_test');
                },
              ),
              DSListItem(
                title: 'screens_intentTest'.tr,
                subtitle: 'screens_testDynamicIntentAndDeepLink'.tr,
                leading: const Icon(Icons.link, size: 22),
                showChevron: true,
                onTap: () {
                  Navigator.pushNamed(context, '/intent_test');
                },
              ),
              if (UniversalPlatform.isIOS)
                DSListItem(
                  title: 'Live Activities 测试',
                  subtitle: '测试实时活动通知',
                  leading: const Icon(Icons.notifications_active, size: 22),
                  showChevron: true,
                  onTap: () {
                    Navigator.pushNamed(context, '/live_activities_test');
                  },
                ),
              DSListItem(
                title: '通用组件示例',
                subtitle: '查看 widgets 目录下的通用组件示例',
                leading: const Icon(Icons.category, size: 22),
                showChevron: true,
                onTap: () {
                  Navigator.pushNamed(context, '/widgets_gallery');
                },
              ),
              DSListItem(
                title: '日志系统',
                subtitle: '查看和管理应用日志',
                leading: const Icon(Icons.description, size: 22),
                showChevron: true,
                onTap: () {
                  Navigator.pushNamed(context, '/log');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 关于
          SettingsGroup(
            title: '关于',
            children: [
              DSListItem(
                title: 'app_aboutTitle'.tr,
                leading: const Icon(Icons.info, size: 22),
                showChevron: true,
                onTap: () {
                  NavigationHelper.push(
                    context,
                    const AboutScreen(),
                    routeName: '/settings/about',
                  );
                },
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}
