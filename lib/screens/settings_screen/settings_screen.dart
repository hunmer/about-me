import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import './controllers/settings_screen_controller.dart';
import './widgets/settings_group.dart';
import './widgets/settings_tile.dart';
import './screens/interface_settings_screen.dart';
import './screens/data_settings_screen.dart';
import './screens/app_settings_screen.dart';
import 'package:aboutme/core/floating_ball/settings_screen.dart';
import 'package:aboutme/core/floating_ball/floating_ball_manager.dart';

/// 设置页：通用/应用设置分组入口
///
/// 玩家信息（头像/用户名/使用统计）已抽离至 ProfileScreen（/profile）
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  // 主页菜单入口
  Widget _buildNavTile(
    BuildContext context, {
    required DsIconKind icon,
    required Color iconColor,
    required String title,
    required Widget screen,
    required String routeName,
  }) {
    return SettingsTile(
      icon: icon,
      iconColor: iconColor,
      title: title,
      onTap: () => NavigationHelper.push(context, screen, routeName: routeName),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isInitialized()) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final Widget list = DSThemeBridge(
      child: Builder(
        builder: (bridgeContext) {
          return ListView(
            // 底部叠加系统安全区高度，避免最后几项被遮挡
            padding: EdgeInsets.fromLTRB(
              20.0,
              8.0,
              20.0,
              16.0 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              const SizedBox(height: 8),
              SettingsGroup(
                title: 'settings_screen_generalSection'.tr,
                children: [
                  _buildNavTile(
                    context,
                    icon: DsIconKind.palette,
                    iconColor: DsAccentColors.pink,
                    title: 'settings_screen_interfaceSettings'.tr,
                    screen: const InterfaceSettingsScreen(),
                    routeName: '/settings/interface',
                  ),
                  _buildNavTile(
                    context,
                    icon: DsIconKind.storage,
                    iconColor: DsAccentColors.blue,
                    title: 'settings_screen_dataSettings'.tr,
                    screen: const DataSettingsScreen(),
                    routeName: '/settings/data',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SettingsGroup(
                title: 'settings_screen_appSection'.tr,
                children: [
                  _buildNavTile(
                    context,
                    icon: DsIconKind.tune,
                    iconColor: DsAccentColors.violet,
                    title: 'settings_screen_appSettings'.tr,
                    screen: const AppSettingsScreen(),
                    routeName: '/settings/app',
                  ),
                  FutureBuilder<bool>(
                    future: FloatingBallManager().isEnabled(),
                    builder: (context, snapshot) {
                      final bool isEnabled = snapshot.data ?? true;
                      return SettingsTile(
                        icon: DsIconKind.touchApp,
                        iconColor: DsAccentColors.pink,
                        title: 'settings_screen_floatingBallTitle'.tr,
                        subtitle: isEnabled
                            ? 'settings_screen_floatingBallEnabled'.tr
                            : 'settings_screen_floatingBallDisabled'.tr,
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
                  SettingsTile(
                    icon: DsIconKind.update,
                    iconColor: DsAccentColors.blue,
                    title: 'settings_screen_checkUpdateTitle'.tr,
                    subtitle: 'settings_screen_checkUpdateSubtitle'.tr,
                    onTap: _controller.checkForUpdates,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // SuperCupertinoNavigationWrapper：路由可返回时自动显示返回按钮
    return SuperCupertinoNavigationWrapper(
      title: Text('settings_screen_settingsTitle'.tr),
      largeTitle: 'settings_screen_settingsTitle'.tr,
      enableLargeTitle: false,
      body: SafeArea(bottom: false, child: list),
    );
  }
}
