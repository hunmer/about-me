import 'package:aboutme/core/services/speech_recognition_config_service.dart';

import 'package:flutter/material.dart';
import 'package:aboutme/widgets/adaptive_switch.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
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
      body: ListView(
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
                  return ListTile(
                    leading: const Icon(Icons.touch_app),
                    title: Text('settings_screen_floatingBallTitle'.tr),
                    subtitle: Text(
                      isEnabled
                          ? 'settings_screen_floatingBallEnabled'.tr
                          : 'settings_screen_floatingBallDisabled'.tr,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
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
                ListTile(
                  leading: const Icon(Icons.touch_app),
                  title: Text('screens_floatingBallSettings'.tr),
                  subtitle: Text('screens_manageSystemFloatingBall'.tr),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.pushNamed(context, '/floating_ball');
                  },
                ),
              ListTile(
                leading: const Icon(Icons.alarm),
                title: const Text('定时提醒'),
                subtitle: const Text('管理定时提醒任务'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  NavigationHelper.push(
                    context,
                    const ReminderListScreen(),
                    routeName: '/settings/reminder',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.extension),
                title: Text('settings_screen_pluginManagementTitle'.tr),
                subtitle: Text('settings_screen_pluginManagementSubtitle'.tr),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _showPluginManagementSheet,
              ),
              ListTile(
                leading: const Icon(Icons.play_circle),
                title: Text('settings_screen_autoOpenLastPluginTitle'.tr),
                subtitle: Text('settings_screen_autoOpenLastPluginSubtitle'.tr),
                trailing: AdaptiveSwitch(
                  value: _controller.autoOpenLastPlugin,
                  onChanged:
                      (value) => setState(() {
                        _controller.autoOpenLastPlugin = value;
                      }),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: Text('screens_locationApiKey'.tr),
                subtitle: Text(
                  _controller.locationApiKey.isEmpty
                      ? 'screens_locationApiKeyNotSet'.tr
                      : 'screens_locationApiKeyPartial'.trParams({
                        'key': _controller.locationApiKey.substring(0, 8),
                      }),
                ),
                trailing: const Icon(Icons.edit),
                onTap: () => _showLocationApiKeyDialog(),
              ),
              ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('语音识别设置'),
                subtitle: Text(
                  _isSpeechRecognitionConfigured ? '已配置腾讯云语音识别' : '配置语音识别服务',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSpeechRecognitionConfigured)
                      const Icon(Icons.check_circle, color: Colors.green),
                    const Icon(Icons.arrow_forward_ios),
                  ],
                ),
                onTap: _showSpeechRecognitionSettings,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 剪切板设置
          SettingsGroup(
            title: '剪切板设置',
            children: [
              ListTile(
                leading: const Icon(Icons.content_paste),
                title: const Text('自动读取剪切板'),
                subtitle: const Text('启用后将自动识别剪切板中的数据'),
                trailing: AdaptiveSwitch(
                  value: _controller.clipboardAutoRead,
                  onChanged:
                      (value) => setState(() {
                        _controller.clipboardAutoRead = value;
                      }),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.content_paste_go),
                title: const Text('读取并识别剪切板'),
                subtitle: const Text('手动读取剪切板中的数据并识别处理'),
                trailing: const Icon(Icons.arrow_forward_ios),
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
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: Text('app_permissionsTitle'.tr),
                  subtitle: Text('app_permissionsManageDescription'.tr),
                  trailing: const Icon(Icons.arrow_forward_ios),
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
              ListTile(
                leading: const Icon(Icons.system_update),
                title: Text('settings_screen_autoCheckUpdateTitle'.tr),
                subtitle: Text('settings_screen_autoCheckUpdateSubtitle'.tr),
                trailing: AdaptiveSwitch(
                  value: _controller.autoCheckUpdate,
                  onChanged:
                      (value) => setState(() {
                        _controller.autoCheckUpdate = value;
                      }),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.update),
                title: Text('settings_screen_checkUpdateTitle'.tr),
                subtitle: Text('settings_screen_checkUpdateSubtitle'.tr),
                onTap: _controller.checkForUpdates,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 开发者测试
          SettingsGroup(
            title: '开发者测试',
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active),
                title: const Text('Toast 测试'),
                subtitle: const Text('测试 Toast 显示、动画和自定义 Widget'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, '/toast_test');
                },
              ),
              ListTile(
                leading: const Icon(Icons.record_voice_over),
                title: const Text('后台播报测试'),
                subtitle: const Text('测试 TTS 后台定时播报功能'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.backgroundAnnouncementTest,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_tree),
                title: const Text('数据选择器测试'),
                subtitle: const Text('测试插件数据选择器系统'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, '/data_selector_test');
                },
              ),
              ListTile(
                leading: const Icon(Icons.route),
                title: const Text('路由查看器'),
                subtitle: const Text('查看所有可用路由'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  RouteViewerDialog.show(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swipe),
                title: const Text('SwipeAction 测试'),
                subtitle: const Text('测试滑动操作组件'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, '/swipe_action_test');
                },
              ),
              ListTile(
                leading: const Icon(Icons.widgets),
                title: Text('screens_jsonDynamicWidgetTest'.tr),
                subtitle: Text('screens_testAndPreviewDynamicUI'.tr),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, '/json_dynamic_test');
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: Text('screens_notificationTest'.tr),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, '/notification_test');
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: Text('screens_intentTest'.tr),
                subtitle: Text('screens_testDynamicIntentAndDeepLink'.tr),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, '/intent_test');
                },
              ),
              if (UniversalPlatform.isIOS)
                ListTile(
                  leading: const Icon(Icons.notifications_active),
                  title: const Text('Live Activities 测试'),
                  subtitle: const Text('测试实时活动通知'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.pushNamed(context, '/live_activities_test');
                  },
                ),
              ListTile(
                leading: const Icon(Icons.category),
                title: const Text('通用组件示例'),
                subtitle: const Text('查看 widgets 目录下的通用组件示例'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, '/widgets_gallery');
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('日志系统'),
                subtitle: const Text('查看和管理应用日志'),
                trailing: const Icon(Icons.arrow_forward_ios),
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
              ListTile(
                leading: const Icon(Icons.info),
                title: Text('app_aboutTitle'.tr),
                trailing: const Icon(Icons.arrow_forward_ios),
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
    );
  }
}
