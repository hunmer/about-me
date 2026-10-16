import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/theme_controller.dart';
import 'package:aboutme/core/services/app_background_controller.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/hand_drawn_style_controller.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/settings_screen/screens/theme_background_settings_screen.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import '../controllers/settings_screen_controller.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_tile.dart';

/// 界面设置：语言、深色模式、主题背景
class InterfaceSettingsScreen extends StatefulWidget {
  const InterfaceSettingsScreen({super.key});

  @override
  State<InterfaceSettingsScreen> createState() =>
      _InterfaceSettingsScreenState();
}

class _InterfaceSettingsScreenState extends State<InterfaceSettingsScreen> {
  late SettingsScreenController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SettingsScreenController();
    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

  @override
  Widget build(BuildContext context) {
    if (!_controller.isInitialized()) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return SuperCupertinoNavigationWrapper(
      title: Text('settings_screen_interfaceSettings'.tr),
      largeTitle: 'settings_screen_interfaceSettings'.tr,
      enableLargeTitle: false,
      body: DSThemeBridge(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16.0,
            16.0,
            16.0,
            16.0 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: DsIconKind.language,
                  iconColor: DsAccentColors.blue,
                  title: 'settings_screen_languageTitle'.tr,
                  subtitle: 'settings_screen_languageSubtitle'.tr,
                  onTap: () => _controller.toggleLanguage(context),
                ),
                SettingsTile(
                  icon: DsIconKind.moon,
                  iconColor: DsAccentColors.indigo,
                  title: 'settings_screen_darkModeTitle'.tr,
                  subtitle: 'settings_screen_darkModeSubtitle'.tr,
                  showChevron: false,
                  trailing: DSSwitch(
                    value: ThemeController.isDarkTheme(context),
                    onChanged: (value) => _controller.setTheme(context, value),
                  ),
                ),
                // 主题设置：全局背景图，应用于所有界面
                ListenableBuilder(
                  listenable: AppBackgroundController(),
                  builder: (context, _) {
                    return SettingsTile(
                      icon: DsIconKind.image,
                      iconColor: DsAccentColors.emerald,
                      title: 'screens_themeSettings'.tr,
                      subtitle:
                          AppBackgroundController().hasBackground
                              ? 'screens_backgroundImageSet'.tr
                              : AppBackgroundController().backgroundColor != null
                              ? 'screens_solidBackgroundSet'.tr
                              : 'screens_backgroundImageNotSet'.tr,
                      onTap: () {
                        NavigationHelper.push(
                          context,
                          const ThemeBackgroundSettingsScreen(),
                          routeName: '/settings/theme_background',
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            // 手绘便签效果：全局控制贴条与倾斜姿态
            ListenableBuilder(
              listenable: HandDrawnStyleController(),
              builder: (context, _) {
                final style = HandDrawnStyleController();
                return SettingsGroup(
                  title: 'settings_screen_handDrawnGroupTitle'.tr,
                  children: [
                    SettingsTile(
                      icon: DsIconKind.stickyNote,
                      iconColor: DsAccentColors.amber,
                      title: 'settings_screen_handDrawnTapeTitle'.tr,
                      subtitle: 'settings_screen_handDrawnTapeSubtitle'.tr,
                      showChevron: false,
                      trailing: DSSwitch(
                        value: style.tapeEnabled,
                        onChanged: style.setTapeEnabled,
                      ),
                    ),
                    SettingsTile(
                      icon: DsIconKind.rotateRight,
                      iconColor: DsAccentColors.pink,
                      title: 'settings_screen_handDrawnTiltTitle'.tr,
                      subtitle: 'settings_screen_handDrawnTiltSubtitle'.tr,
                      showChevron: false,
                      trailing: DSSwitch(
                        value: style.tiltEnabled,
                        onChanged: style.setTiltEnabled,
                      ),
                    ),
                    SettingsTile(
                      icon: DsIconKind.animation,
                      iconColor: DsAccentColors.sky,
                      title: 'settings_screen_handDrawnEntranceTitle'.tr,
                      subtitle: 'settings_screen_handDrawnEntranceSubtitle'.tr,
                      showChevron: false,
                      trailing: DSSwitch(
                        value: style.entranceEnabled,
                        onChanged: style.setEntranceEnabled,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
