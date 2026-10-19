import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/widgets/picker/avatar_picker.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/app_usage_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/settings_screen/settings_screen.dart';
import 'package:aboutme/screens/settings_screen/controllers/settings_screen_controller.dart';
import 'package:aboutme/screens/settings_screen/widgets/settings_group.dart';
import 'package:aboutme/screens/settings_screen/widgets/settings_tile.dart';

/// 个人主页：玩家信息（头像/用户名/使用统计）+ 设置入口
///
/// 路由：/profile；同时作为果冻小屋底部导航「我的」页签内容
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late SettingsScreenController _controller;
  // 使用时长信息栏的实时刷新（累计时长含当前会话）
  Timer? _usageTicker;

  @override
  void initState() {
    super.initState();
    _controller = SettingsScreenController();

    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    _usageTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
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
    _usageTicker?.cancel();
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

  // 头部迷你统计（值 + 小标签，参考稿 GENDER/AGE/BIRTHDAY 样式）
  Widget _buildStat(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: DsTypography.heading.copyWith(
              fontSize: 15,
              color: DSThemeBridge.resolve(context).text,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: DsTypography.caption.copyWith(
              fontSize: 10,
              color: DSThemeBridge.resolve(context).textSub,
            ),
          ),
        ],
      ),
    );
  }

  // 使用时长格式化：天 → 小时 → 分钟逐级降档
  String _formatUsageDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    if (days > 0) {
      return 'settings_screen_durationDays'.trParams({
        'days': '$days',
        'hours': '$hours',
      });
    }
    if (duration.inHours > 0) {
      return 'settings_screen_durationHours'.trParams({
        'hours': '${duration.inHours}',
        'minutes': '$minutes',
      });
    }
    return 'settings_screen_durationMinutes'.trParams({
      'minutes': '${duration.inMinutes}',
    });
  }

  // 信息栏：药丸横幅展示累计使用时长（参考稿 ID 条位置）
  Widget _buildUsageBanner(AppThemeData ds) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: dsSketchDecoration(
        theme: ds,
        fillColor: ds.hatch,
        radius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          DsIcon(DsIconKind.clock, size: 18, color: ds.text),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _formatUsageDuration(AppUsageService.instance.totalSeconds),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsTypography.heading.copyWith(color: ds.text),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'settings_screen_usageDuration'.tr,
            style: DsTypography.caption.copyWith(color: ds.textSub),
          ),
        ],
      ),
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
          final usage = AppUsageService.instance;
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
              // 头部：头像（左，右上角铅笔徽标）+ 用户名/迷你统计（右），参考稿样式
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
                  // 用户名：点击修改；下方三格迷你统计
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _showEditNameDialog,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            _controller.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsTypography.display.copyWith(
                              fontSize: 28,
                              color: ds.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildStat(
                              '${usage.usageDays}',
                              'settings_screen_statDaysUsed'.tr,
                            ),
                            _buildStat(
                              '${_controller.availablePlugins.length}',
                              'settings_screen_statPlugins'.tr,
                            ),
                            if (_controller.appVersion.isNotEmpty)
                              _buildStat(
                                _controller.appVersion,
                                'settings_screen_statVersion'.tr,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildUsageBanner(ds),
              const SizedBox(height: 24),
              SettingsGroup(
                children: [
                  SettingsTile(
                    icon: DsIconKind.gear,
                    iconColor: DsAccentColors.violet,
                    title: 'settings_screen_settingsTitle'.tr,
                    onTap:
                        () => NavigationHelper.push(
                          context,
                          const SettingsScreen(),
                          routeName: '/settings',
                        ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return Scaffold(body: SafeArea(bottom: false, child: list));
  }
}
