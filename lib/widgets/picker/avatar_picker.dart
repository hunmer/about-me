import 'dart:io';
import 'dart:math';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'image_picker_dialog.dart';
import 'package:path/path.dart' as path;
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/adaptive_image.dart';

class AvatarPicker extends StatefulWidget {
  final double size;
  final String username;
  final String? currentAvatarPath;
  final String saveDirectory;
  final String? defaultAvatarAsset;
  final Function(String path)? onAvatarChanged;
  final Future<Map<String, dynamic>?> Function(
    BuildContext context,
    String? initialPath,
  )?
  showPickerDialog;

  const AvatarPicker({
    super.key,
    this.size = 80.0,
    required this.username,
    this.currentAvatarPath,
    this.saveDirectory = 'avatars',
    this.defaultAvatarAsset,
    this.onAvatarChanged,
    this.showPickerDialog,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _avatarPath = widget.currentAvatarPath;
  }

  @override
  void didUpdateWidget(AvatarPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只在路径确实发生变化，且不是当前选择的路径时更新
    if (oldWidget.currentAvatarPath != widget.currentAvatarPath &&
        _avatarPath != widget.currentAvatarPath) {
      // 清除可能的缓存
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      setState(() {
        _avatarPath = widget.currentAvatarPath;
      });
    }
  }

  Future<void> _pickImage(BuildContext context) async {
    // 使用外部提供的对话框打开方法或默认方法
    final result =
        widget.showPickerDialog != null
            ? await widget.showPickerDialog!(context, _avatarPath)
            : await ImagePickerDialog.show<Map<String, dynamic>>(
              context,
              initialUrl: _avatarPath,
              saveDirectory: widget.saveDirectory,
              enableCrop: true,
              cropAspectRatio: 1.0, // 强制使用1:1的裁剪比例
            );

    if (result != null) {
      final sourcePath = result['url'] as String;

      // 清除图片缓存
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      setState(() {
        _avatarPath = sourcePath;
      });

      // 重命名文件为随机文件名
      if (_avatarPath != null) {
        try {
          // 获取源文件的绝对路径
          final sourceAbsolutePath = await ImageUtils.getAbsolutePath(
            _avatarPath!,
          );
          final sourceFile = File(sourceAbsolutePath);

          // 确保文件存在
          if (await sourceFile.exists()) {
            // 获取应用文档目录
            final appDir =
                await StorageManager.getApplicationDocumentsDirectory();
            final avatarDir = Directory(
              path.join(appDir.path, 'app_data', widget.saveDirectory),
            );
            if (!await avatarDir.exists()) {
              await avatarDir.create(recursive: true);
            }

            // 生成随机文件名
            final random = Random();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final randomString =
                List.generate(
                  8,
                  (_) => random.nextInt(16).toRadixString(16),
                ).join();
            final newFileName = '$timestamp-$randomString.jpg';
            final newPath = path.join(avatarDir.path, newFileName);

            // 如果目标文件已存在，先删除
            final newFile = File(newPath);
            if (await newFile.exists()) {
              await newFile.delete();
            }

            // 复制文件到新位置
            await sourceFile.copy(newPath);

            // 转换为相对路径并更新状态
            final relativePath = await ImageUtils.toRelativePath(newPath);
            setState(() {
              _avatarPath = relativePath;
            });

            // 通知父组件头像已更新
            widget.onAvatarChanged?.call(relativePath);

            debugPrint('Avatar saved successfully to: $newPath');
          } else {
            debugPrint(
              'Source avatar file does not exist: $sourceAbsolutePath',
            );
          }
        } catch (e) {
          debugPrint('Error processing avatar file: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return GestureDetector(
      onTap: () => _pickImage(context),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.primary.mixWhite(0.85),
          border: Border.all(color: theme.primary.withValues(alpha: 0.35)),
        ),
        child:
            _avatarPath != null
                ? AdaptiveImage(
                  key: ValueKey(_avatarPath),
                  imagePath: _avatarPath,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  shape: BoxShape.circle,
                )
                : _buildDefaultAvatar(theme),
      ),
    );
  }

  Widget _buildDefaultAvatar(AppThemeData theme) {
    // 支持指定默认头像资产图片，未指定时回退为用户名首字
    if (widget.defaultAvatarAsset != null) {
      return ClipOval(
        child: Image.asset(
          widget.defaultAvatarAsset!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) => _buildLetterAvatar(theme),
        ),
      );
    }
    return _buildLetterAvatar(theme);
  }

  Widget _buildLetterAvatar(AppThemeData theme) {
    return Center(
      child: Text(
        widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?',
        style: DsTypography.title.copyWith(
          fontSize: widget.size * 0.5,
          color: theme.primaryText,
        ),
      ),
    );
  }
}
