import 'package:aboutme/widgets/picker/image_picker_dialog.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/picker/avatar_picker.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/events/user_events.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileEditDialog extends StatefulWidget {
  final User user;
  final ChatPlugin chatPlugin;

  const ProfileEditDialog({
    super.key,
    required this.user,
    required this.chatPlugin,
  });

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog>
    with SingleTickerProviderStateMixin {
  late TextEditingController _usernameController;
  String? _avatarPath;
  late AnimationController _animationController;
  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _avatarPath = widget.user.iconPath;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void didUpdateWidget(ProfileEditDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有当user对象确实发生变化时才更新
    if (oldWidget.user != widget.user &&
        _avatarPath == oldWidget.user.iconPath) {
      setState(() {
        _avatarPath = widget.user.iconPath;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _onAvatarChanged(String path) async {
    // 转换为相对路径
    final relativePath = await ImageUtils.toRelativePath(path);

    // 如果路径没有变化，不触发更新
    if (_avatarPath == relativePath) return;

    setState(() {
      _avatarPath = relativePath;
    });
  }

  Future<void> _save() async {
    final newUsername = _usernameController.text.trim();
    if (newUsername.isEmpty) {
      toastService.showToast('chat_usernameCannotBeEmpty'.tr);
      return;
    }

    try {
      // 创建更新后的用户对象
      final updatedUser = widget.user.copyWith(
        username: newUsername,
        iconPath: _avatarPath,
      );

      if (updatedUser.id == widget.chatPlugin.userService.currentUser.id) {
        // 当前用户资料统一写入个人主页的数据源（SharedPreferences）
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', newUsername);
        if (_avatarPath == null || _avatarPath!.isEmpty) {
          await prefs.remove('user_avatar_path');
        } else {
          await prefs.setString('user_avatar_path', _avatarPath!);
        }
      } else {
        // 非当前用户（历史消息中的其他用户）仍保存到用户列表
        await widget.chatPlugin.userService.updateUser(updatedUser);
      }

      // 广播用户资料更新，刷新聊天消息气泡头像
      EventManager.instance.broadcast(
        UserEventNames.userAvatarUpdated,
        UserAvatarUpdatedEventArgs(updatedUser),
      );

      // 强制清除图片缓存
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // 通知所有监听器（包括聊天消息气泡）更新
      widget.chatPlugin.refresh();

      if (mounted) {
        // 返回更新后的用户对象
        Navigator.of(context).pop(updatedUser);
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('${'chat_updateFailed'.tr}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // Builder 让表单在主题桥之内构建，可读取 AppTheme
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '编辑个人信息',
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.lg),

                RepaintBoundary(
                  child: AvatarPicker(
                    key: const ValueKey('avatar_picker'),
                    size: 80,
                    username: widget.user.username,
                    currentAvatarPath: _avatarPath,
                    saveDirectory: 'chat/avatars',
                    onAvatarChanged: _onAvatarChanged,
                    showPickerDialog: (
                      BuildContext context,
                      String? initialPath,
                    ) async {
                      return ImagePickerDialog.show<Map<String, dynamic>>(
                        context,
                        initialUrl: initialPath,
                        enableCrop: true,
                        cropAspectRatio: 1.0,
                      );
                    },
                  ),
                ),
                SizedBox(height: theme.spacing.lg),

                // 用户名输入框
                DSInput(
                  controller: _usernameController,
                  label: 'chat_username'.tr,
                ),
                SizedBox(height: theme.spacing.xl),

                // 按钮行
                Row(
                  children: [
                    Expanded(
                      child: DSButton(
                        label: 'app_cancel'.tr,
                        variant: DSButtonVariant.outline,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(width: theme.spacing.md),
                    Expanded(
                      child: DSButton(label: 'app_save'.tr, onPressed: _save),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
