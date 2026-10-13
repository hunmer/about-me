import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/widgets/picker/avatar_picker.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import './controllers/settings_screen_controller.dart';
import './widgets/settings_group.dart';
import './widgets/settings_tile.dart';
import './screens/interface_settings_screen.dart';
import './screens/data_settings_screen.dart';
import './screens/app_settings_screen.dart';

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

  // 修改用户名
  Future<void> _showEditNameDialog() async {
    final TextEditingController nameController = TextEditingController(
      text: _controller.userName,
    );
    final FocusNode focusNode = FocusNode();
    // DSInput 无 autofocus 参数，弹窗挂载后手动聚焦弹出键盘
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => focusNode.requestFocus(),
    );

    final result = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSDialog(
            title: 'settings_screen_changeUsername'.tr,
            content: DSInput(
              controller: nameController,
              focusNode: focusNode,
              hint: 'settings_screen_enterUsernameHint'.tr,
            ),
            confirmText: 'app_save'.tr,
            cancelText: 'screens_cancel'.tr,
          ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await _controller.setUserName(nameController.text.trim());
    }

    nameController.dispose();
    focusNode.dispose();
  }

  // 主页菜单入口
  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
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
      return const Center(child: CircularProgressIndicator());
    }

    final Widget list = DSThemeBridge(
      child: Builder(
        builder: (bridgeContext) {
          final ds = DSThemeBridge.resolve(bridgeContext);
          return ListView(
            // 底部叠加悬浮导航栏/系统安全区高度，避免最后几项被遮挡
            padding: EdgeInsets.fromLTRB(
              20.0,
              8.0,
              20.0,
              16.0 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              const SizedBox(height: 8),
              // 头部：头像（左，右上角铅笔徽标）+ 用户名（大号粗体），参考稿样式
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AvatarPicker(
                        size: 84,
                        username: _controller.userName,
                        currentAvatarPath: _controller.userAvatarPath,
                        defaultAvatarAsset: 'assets/images/default_avatar.jpg',
                        onAvatarChanged:
                            (path) => _controller.setUserAvatarPath(path),
                      ),
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 28,
                          height: 28,
                          // 手绘墨线描边圆徽标（禁手写 Border.all）
                          decoration: dsSketchDecoration(
                            theme: ds,
                            circle: true,
                            fillColor: ds.surface,
                            stroke: ds.textSub.withValues(alpha: 0.4),
                          ),
                          child: Center(
                            child: DsIcon(
                              DsIconKind.edit,
                              size: 14,
                              color: ds.text,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  // 用户名：点击修改
                  Expanded(
                    child: GestureDetector(
                      onTap: _showEditNameDialog,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        _controller.userName,
                        style: DsTypography.display.copyWith(
                          fontSize: 28,
                          color: ds.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SettingsGroup(
                title: 'settings_screen_generalSection'.tr,
                children: [
                  _buildNavTile(
                    context,
                    icon: Icons.palette_outlined,
                    iconColor: DsAccentColors.pink,
                    title: 'settings_screen_interfaceSettings'.tr,
                    screen: const InterfaceSettingsScreen(),
                    routeName: '/settings/interface',
                  ),
                  _buildNavTile(
                    context,
                    icon: Icons.storage_outlined,
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
                    icon: Icons.tune,
                    iconColor: DsAccentColors.violet,
                    title: 'settings_screen_appSettings'.tr,
                    screen: const AppSettingsScreen(),
                    routeName: '/settings/app',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return Scaffold(
      body: SafeArea(bottom: false, child: list),
    );
  }
}
