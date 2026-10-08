import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/widgets/picker/avatar_picker.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import './controllers/settings_screen_controller.dart';
import './widgets/settings_group.dart';
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

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('修改用户名'),
            content: TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(hintText: '输入用户名'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('screens_cancel'.tr),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(nameController.text),
                child: Text('app_save'.tr),
              ),
            ],
          ),
    );

    if (result != null && result.trim().isNotEmpty) {
      await _controller.setUserName(result.trim());
    }

    nameController.dispose();
  }

  // 主页菜单入口
  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget screen,
    required String routeName,
  }) {
    return DSListItem(
      title: title,
      leading: Icon(icon, size: 22),
      showChevron: true,
      onTap: () => NavigationHelper.push(context, screen, routeName: routeName),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isInitialized()) {
      return const Center(child: CircularProgressIndicator());
    }

    final ThemeData theme = Theme.of(context);

    final Widget list = DSThemeBridge(
      child: ListView(
        // 底部叠加悬浮导航栏/系统安全区高度，避免最后几项被遮挡
        padding: EdgeInsets.fromLTRB(
          16.0,
          8.0,
          16.0,
          16.0 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const SizedBox(height: 8),
          // 头像：顶部居中，点击更换
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AvatarPicker(
                  size: 96,
                  username: _controller.userName,
                  currentAvatarPath: _controller.userAvatarPath,
                  defaultAvatarAsset: 'assets/images/default_avatar.jpg',
                  onAvatarChanged:
                      (path) => _controller.setUserAvatarPath(path),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.primaryColor,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.photo_camera,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 用户名：点击修改
          Center(
            child: GestureDetector(
              onTap: _showEditNameDialog,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _controller.userName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit, size: 16, color: theme.hintColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            children: [
              _buildNavTile(
                context,
                icon: Icons.palette_outlined,
                title: '界面设置',
                screen: const InterfaceSettingsScreen(),
                routeName: '/settings/interface',
              ),
              _buildNavTile(
                context,
                icon: Icons.storage_outlined,
                title: '数据管理',
                screen: const DataSettingsScreen(),
                routeName: '/settings/data',
              ),
              _buildNavTile(
                context,
                icon: Icons.settings_outlined,
                title: '应用设置',
                screen: const AppSettingsScreen(),
                routeName: '/settings/app',
              ),
            ],
          ),
        ],
      ),
    );

    // 通过 tab 进入（无可返回的上一级路由）时直接铺满内容，不展示
    // SuperCupertino 头部；被路由 push 打开时保留头部提供返回栏
    final bool pushedAsRoute = ModalRoute.of(context)?.canPop ?? false;
    if (!pushedAsRoute) {
      return Scaffold(body: SafeArea(bottom: false, child: list));
    }

    return SuperCupertinoNavigationWrapper(
      title: Text(
        'settings_screen_settingsTitle'.tr,
        style: TextStyle(color: theme.textTheme.titleLarge?.color),
      ),
      largeTitle: 'settings_screen_settingsTitle'.tr,
      body: list,
    );
  }
}
