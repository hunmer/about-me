import 'package:aboutme/core/services/speech_recognition_config_service.dart';

import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/settings_screen/widgets/speech_recognition_settings_dialog.dart';
import 'package:aboutme/screens/settings_screen/controllers/permission_controller.dart';
import 'package:aboutme/screens/settings_screen/widgets/permission_request_dialog.dart';
import 'package:aboutme/screens/about_screen/about_screen.dart';
import 'package:get/get.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/widgets/route_viewer_dialog.dart';
import 'package:aboutme/plugins/reminder/screens/reminder_list_screen.dart';
import 'package:grok_icon_study/grok_icon_study.dart';
import '../controllers/settings_screen_controller.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_tile.dart';

/// 应用设置：插件、剪切板、权限、更新、开发者测试、关于
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
    final result = await SpeechRecognitionSettingsDialog.show(context);

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

    final result = await showDSDialog<String>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSDialog(
                title: 'screens_setLocationApiKey'.tr,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'screens_locationApiKeyHint'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                    SizedBox(height: theme.spacing.md),
                    DSInput(
                      controller: apiKeyController,
                      hint: 'screens_apiKeyInputHint'.tr,
                    ),
                    SizedBox(height: theme.spacing.sm),
                    Text(
                      'screens_locationApiKeyGuide'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ),
                confirmText: 'app_save'.tr,
                cancelText: 'screens_cancel'.tr,
                onConfirm: () =>
                    Navigator.pop(context, apiKeyController.text),
              );
            },
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
      builder: (context) {
        final double sheetHeight = MediaQuery.of(context).size.height * 0.75;
        return SizedBox(
          height: sheetHeight,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final theme = DSThemeBridge.resolve(context);
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
                      style: DsTypography.body.copyWith(color: theme.textSub),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: plugins.length,
                      separatorBuilder:
                          (_, __) => SizedBox(height: theme.spacing.sm),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemBuilder: (context, index) {
                        final plugin = plugins[index];
                        final pluginName =
                            plugin.getPluginName(context) ?? plugin.id;
                        final isEnabled = _controller.isPluginEnabled(
                          plugin.id,
                        );
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    pluginName,
                                    style: DsTypography.heading.copyWith(
                                      color: theme.text,
                                    ),
                                  ),
                                  Text(
                                    plugin.id,
                                    style: DsTypography.caption.copyWith(
                                      color: theme.textSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DSSwitch(
                              value: isEnabled,
                              onChanged: (value) async {
                                await _controller.setPluginEnabled(
                                  plugin.id,
                                  value,
                                );
                                setModalState(() {});
                              },
                            ),
                          ],
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

    return SuperCupertinoNavigationWrapper(
      title: Text('settings_screen_appSettings'.tr),
      largeTitle: 'settings_screen_appSettings'.tr,
      enableLargeTitle: false,
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final ds = DSThemeBridge.resolve(context);
            return ListView(
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
                  title: 'settings_screen_generalGroup'.tr,
                  children: [
                    if (UniversalPlatform.isAndroid)
                      SettingsTile(
                        icon: DsIconKind.radioButton,
                        iconColor: DsAccentColors.orange,
                        title: 'screens_floatingBallSettings'.tr,
                        subtitle: 'screens_manageSystemFloatingBall'.tr,
                        onTap: () {
                          NavigationHelper.pushNamed(context, '/floating_ball');
                        },
                      ),
                    SettingsTile(
                      icon: DsIconKind.alarm,
                      iconColor: DsAccentColors.red,
                      title: 'settings_screen_reminderTitle'.tr,
                      subtitle: 'settings_screen_reminderSubtitle'.tr,
                      onTap: () {
                        NavigationHelper.push(
                          context,
                          const ReminderListScreen(),
                          routeName: '/settings/reminder',
                        );
                      },
                    ),
                    SettingsTile(
                      icon: DsIconKind.extension,
                      iconColor: DsAccentColors.indigo,
                      title: 'settings_screen_pluginManagementTitle'.tr,
                      subtitle: 'settings_screen_pluginManagementSubtitle'.tr,
                      onTap: _showPluginManagementSheet,
                    ),
                    SettingsTile(
                      icon: DsIconKind.video,
                      iconColor: DsAccentColors.emerald,
                      title: 'settings_screen_autoOpenLastPluginTitle'.tr,
                      subtitle: 'settings_screen_autoOpenLastPluginSubtitle'.tr,
                      showChevron: false,
                      trailing: DSSwitch(
                        value: _controller.autoOpenLastPlugin,
                        onChanged:
                            (value) => setState(() {
                              _controller.autoOpenLastPlugin = value;
                            }),
                      ),
                    ),
                    SettingsTile(
                      icon: DsIconKind.locationOn,
                      iconColor: DsAccentColors.amber,
                      title: 'screens_locationApiKey'.tr,
                      subtitle: _controller.locationApiKey.isEmpty
                          ? 'screens_locationApiKeyNotSet'.tr
                          : 'screens_locationApiKeyPartial'.trParams({
                              'key': _controller.locationApiKey.substring(0, 8),
                            }),
                      onTap: () => _showLocationApiKeyDialog(),
                    ),
                    SettingsTile(
                      icon: DsIconKind.mic,
                      iconColor: DsAccentColors.teal,
                      title: 'settings_screen_speechSettingsTitle'.tr,
                      subtitle: _isSpeechRecognitionConfigured
                          ? 'settings_screen_speechConfigured'.tr
                          : 'settings_screen_speechNotConfigured'.tr,
                      showChevron: !_isSpeechRecognitionConfigured,
                      trailing: _isSpeechRecognitionConfigured
                          ? DsIcon(
                              DsIconKind.check,
                              size: 20,
                              color: ds.primary,
                            )
                          : null,
                      onTap: _showSpeechRecognitionSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 剪切板设置
                SettingsGroup(
                  title: 'settings_screen_clipboardGroup'.tr,
                  children: [
                    SettingsTile(
                      icon: DsIconKind.clipboard,
                      iconColor: DsAccentColors.blue,
                      title: 'settings_screen_clipboardAutoReadTitle'.tr,
                      subtitle: 'settings_screen_clipboardAutoReadSubtitle'.tr,
                      showChevron: false,
                      trailing: DSSwitch(
                        value: _controller.clipboardAutoRead,
                        onChanged:
                            (value) => setState(() {
                              _controller.clipboardAutoRead = value;
                            }),
                      ),
                    ),
                    SettingsTile(
                      icon: DsIconKind.contentPasteGo,
                      iconColor: DsAccentColors.cyan,
                      title: 'settings_screen_clipboardReadTitle'.tr,
                      subtitle: 'settings_screen_clipboardReadSubtitle'.tr,
                      onTap: () async {
                        final result = await _controller.readAndProcessClipboard();
                        if (mounted) {
                          Toast.show(
                            result
                                ? 'settings_screen_clipboardReadSuccess'.tr
                                : 'settings_screen_clipboardReadEmpty'.tr,
                          );
                        }
                      },
                    ),
                    if (showPermissionEntry)
                      SettingsTile(
                        icon: DsIconKind.privacyTip,
                        iconColor: DsAccentColors.violet,
                        title: 'app_permissionsTitle'.tr,
                        subtitle: 'app_permissionsManageDescription'.tr,
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
                  title: 'settings_screen_updateGroup'.tr,
                  children: [
                    SettingsTile(
                      icon: DsIconKind.systemUpdate,
                      iconColor: DsAccentColors.emerald,
                      title: 'settings_screen_autoCheckUpdateTitle'.tr,
                      subtitle: 'settings_screen_autoCheckUpdateSubtitle'.tr,
                      showChevron: false,
                      trailing: DSSwitch(
                        value: _controller.autoCheckUpdate,
                        onChanged:
                            (value) => setState(() {
                              _controller.autoCheckUpdate = value;
                            }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 开发者测试
                SettingsGroup(
                  title: 'settings_screen_devTestGroup'.tr,
                  children: [
                    SettingsTile(
                      icon: DsIconKind.route,
                      iconColor: DsAccentColors.slate,
                      title: 'settings_screen_routeViewerTitle'.tr,
                      subtitle: 'settings_screen_routeViewerSubtitle'.tr,
                      onTap: () {
                        RouteViewerDialog.show(context);
                      },
                    ),
                    SettingsTile(
                      icon: DsIconKind.widgets,
                      iconColor: DsAccentColors.slate,
                      title: 'screens_jsonDynamicWidgetTest'.tr,
                      subtitle: 'screens_testAndPreviewDynamicUI'.tr,
                      onTap: () {
                        NavigationHelper.pushNamed(
                          context,
                          '/json_dynamic_test',
                        );
                      },
                    ),
                    SettingsTile(
                      icon: DsIconKind.link,
                      iconColor: DsAccentColors.slate,
                      title: 'screens_intentTest'.tr,
                      subtitle: 'screens_testDynamicIntentAndDeepLink'.tr,
                      onTap: () {
                        NavigationHelper.pushNamed(context, '/intent_test');
                      },
                    ),
                    if (UniversalPlatform.isIOS)
                      SettingsTile(
                        icon: DsIconKind.notificationsActive,
                        iconColor: DsAccentColors.slate,
                        title: 'settings_screen_liveActivitiesTestTitle'.tr,
                        subtitle:
                            'settings_screen_liveActivitiesTestSubtitle'.tr,
                        onTap: () {
                          NavigationHelper.pushNamed(
                            context,
                            '/live_activities_test',
                          );
                        },
                      ),
                    SettingsTile(
                      icon: DsIconKind.animation,
                      iconColor: DsAccentColors.slate,
                      title: 'screens_grokCharacterStudyTitle'.tr,
                      subtitle: 'screens_grokCharacterStudySubtitle'.tr,
                      onTap: () {
                        NavigationHelper.push(
                          context,
                          const GrokStudyScreen(),
                          routeName: '/settings/grok_study',
                        );
                      },
                    ),
                    SettingsTile(
                      icon: DsIconKind.category,
                      iconColor: DsAccentColors.slate,
                      title: 'settings_screen_widgetsGalleryTitle'.tr,
                      subtitle: 'settings_screen_widgetsGallerySubtitle'.tr,
                      onTap: () {
                        NavigationHelper.pushNamed(context, '/widgets_gallery');
                      },
                    ),
                    SettingsTile(
                      icon: DsIconKind.description,
                      iconColor: DsAccentColors.slate,
                      title: 'settings_screen_logSystemTitle'.tr,
                      subtitle: 'settings_screen_logSystemSubtitle'.tr,
                      onTap: () {
                        NavigationHelper.pushNamed(context, '/log');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 关于
                SettingsGroup(
                  title: 'settings_screen_aboutGroup'.tr,
                  children: [
                    SettingsTile(
                      icon: DsIconKind.info,
                      iconColor: DsAccentColors.sky,
                      title: 'app_aboutTitle'.tr,
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
            );
          },
        ),
      ),
    );
  }
}
