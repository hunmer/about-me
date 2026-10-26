import 'dart:io';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

import '../../models/webview_card.dart';
import '../../webview_plugin.dart';

/// 弹出添加卡片表单（底部抽屉，标题栏自带保存按钮）
///
/// 在线 URL / 本地项目目录复制，由宿主页底部导航圆钮调用
void showAddCardSheet(BuildContext context) {
  final formKey = GlobalKey<_WebViewAddCardFormState>();

  SmoothBottomSheet.showForm(
    context: context,
    title: 'webview_add_card'.tr,
    onSave: () => formKey.currentState?.save(),
    child: WebViewAddCardForm(key: formKey),
  );
}

/// 添加卡片表单
class WebViewAddCardForm extends StatefulWidget {
  const WebViewAddCardForm({super.key});

  @override
  State<WebViewAddCardForm> createState() => _WebViewAddCardFormState();
}

class _WebViewAddCardFormState extends State<WebViewAddCardForm> {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _descController = TextEditingController();
  final _projectNameController = TextEditingController();
  CardType _selectedType = CardType.url;

  /// 保存中防重复提交（复制文件可能耗时）
  bool _saving = false;

  bool get _isLocalFileMode => _selectedType == CardType.localFile;

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _descController.dispose();
    _projectNameController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (_saving) return;

    if (_titleController.text.isEmpty) {
      Toast.warning('请输入卡片标题');
      return;
    }

    if (_isLocalFileMode) {
      // 本地文件模式：复制文件并生成 ./ 路径
      if (_projectNameController.text.isEmpty) {
        Toast.warning('请输入项目名称');
        return;
      }

      _saving = true;
      try {
        final sourcePath = _urlController.text;
        final projectName = _projectNameController.text;

        // 复制文件到 HTTP 服务器目录
        final relativePath = await WebViewPlugin.instance.copyToHttpServer(
          sourcePath: sourcePath,
          projectName: projectName,
        );

        // 添加卡片（使用 ./ 相对路径，同时保存原始路径）
        await WebViewPlugin.instance.cardManager.addCard(
          title: _titleController.text,
          url: relativePath,
          type: _selectedType,
          description: _descController.text.isNotEmpty
              ? _descController.text
              : null,
          sourcePath: sourcePath, // 保存原始路径用于同步
        );

        if (mounted) {
          Navigator.of(context).pop();
          Toast.success('本地项目已添加');
        }
      } catch (e) {
        Toast.error('添加失败: $e');
      }
    } else {
      // 在线 URL 模式
      if (_urlController.text.isEmpty) {
        Toast.warning('请输入 URL');
        return;
      }

      _saving = true;
      try {
        await WebViewPlugin.instance.cardManager.addCard(
          title: _titleController.text,
          url: _urlController.text,
          type: _selectedType,
          description: _descController.text.isNotEmpty
              ? _descController.text
              : null,
        );

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        Toast.error('添加失败: $e');
      }
    }
  }

  /// 选择本地项目：macOS 选目录，其他平台多选文件，需包含 index.html
  Future<void> _pickLocalProject() async {
    String? directoryPath;
    List<String>? filesToCopy;

    // macOS 使用目录选择，其他平台使用多文件选择
    if (Theme.of(context).platform == TargetPlatform.macOS) {
      directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择项目目录（需包含 index.html）',
      );
    } else {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择项目中的所有文件（包括 index.html）',
        allowMultiple: true,
        type: FileType.any,
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      // 找到包含 index.html 的目录
      String? indexHtmlPath;
      for (final file in result.files) {
        if (file.path != null && file.name == 'index.html') {
          indexHtmlPath = file.path;
          break;
        }
      }

      if (indexHtmlPath == null) {
        Toast.error('错误：所选文件中未找到 index.html');
        return;
      }

      // 获取目录路径和文件列表
      directoryPath = path.dirname(indexHtmlPath);
      filesToCopy = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
    }

    if (directoryPath == null) {
      return;
    }

    // 检查目录中是否存在 index.html
    final indexHtmlFile = File(path.join(directoryPath, 'index.html'));
    if (!await indexHtmlFile.exists()) {
      Toast.error('错误：所选目录中未找到 index.html');
      return;
    }

    final directoryName = path.basename(directoryPath);

    // 将选中的文件列表保存到 WebViewPlugin 中以备后用
    if (filesToCopy != null) {
      WebViewPlugin.instance.pendingFilesToCopy = filesToCopy;
    } else {
      // macOS: 扫描目录下所有文件
      final dir = Directory(directoryPath);
      WebViewPlugin.instance.pendingFilesToCopy = await dir
          .list(recursive: true)
          .where((entity) => entity is File)
          .map((entity) => entity.path)
          .toList();
    }

    if (!mounted) return;
    setState(() => _selectedType = CardType.localFile);

    // 如果标题为空，使用目录名作为标题
    if (_titleController.text.isEmpty) {
      _titleController.text = directoryName;
    }

    // 如果项目名称为空，生成默认名称
    if (_projectNameController.text.isEmpty) {
      final projectName = directoryName
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
          .replaceAll(RegExp('_+'), '_');
      _projectNameController.text = projectName;
    }

    // 存储目录路径
    _urlController.text = directoryPath;
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DSInput(
            controller: _titleController,
            label: 'webview_card_title'.tr,
          ),
          SizedBox(height: theme.spacing.md),

          // 项目名称输入（本地文件模式）
          if (_isLocalFileMode) ...[
            DSInput(
              controller: _projectNameController,
              label: '项目名称（英文/数字/下划线）',
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              '文件将复制到 http_server/项目名称/ 目录',
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
            SizedBox(height: theme.spacing.md),
          ],

          DSInput(
            controller: _urlController,
            label: 'webview_card_url'.tr,
            // 本地文件模式下 URL 自动生成,只读展示
            enabled: !_isLocalFileMode,
            suffix: buildFolderPickerSuffix(_pickLocalProject),
          ),
          if (_isLocalFileMode) ...[
            SizedBox(height: theme.spacing.xs),
            Text(
              'URL 将自动生成为 ./项目名称/...',
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
          SizedBox(height: theme.spacing.md),
          DSInput(
            controller: _descController,
            label: 'webview_card_description'.tr,
            maxLines: 2,
          ),
          SizedBox(height: theme.spacing.md),
          DSSegmentedControl(
            options: [
              'webview_card_type_url'.tr,
              'webview_card_type_local'.tr,
            ],
            selected: _selectedType == CardType.url ? 0 : 1,
            onChanged: (value) {
              setState(() {
                _selectedType = value == 0 ? CardType.url : CardType.localFile;
                if (!_isLocalFileMode) {
                  _projectNameController.clear();
                }
              });
            },
          ),
          SizedBox(height: theme.spacing.md),
        ],
      ),
    );
  }
}

/// 本地文件/目录选择按钮(DS 暂无文件夹图标,保留 Material IconButton)
Widget buildFolderPickerSuffix(VoidCallback onPressed) {
  return Builder(
    builder: (context) {
      final theme = DSThemeBridge.resolve(context);
      return Material(
        type: MaterialType.transparency,
        child: IconButton(
          icon: Icon(Icons.folder_open, color: theme.primary),
          tooltip: 'webview_select_local_file'.tr,
          onPressed: onPressed,
        ),
      );
    },
  );
}
