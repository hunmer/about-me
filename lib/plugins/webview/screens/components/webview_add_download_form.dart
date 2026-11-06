import 'dart:io' as io;

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/download_flow.dart';
import '../../webview_plugin.dart';

/// 弹出手动添加下载表单（底部抽屉，标题栏自带保存按钮）
///
/// 由下载管理页签的「添加」入口调用；提交后直接进入后台下载，
/// 进度在下载列表中查看，不弹进度对话框
void showAddDownloadSheet(BuildContext context) {
  final formKey = GlobalKey<_DownloadAddFormState>();

  SmoothBottomSheet.showForm(
    context: context,
    title: 'webview_download_add'.tr,
    onSave: () => formKey.currentState?.save(),
    child: DownloadAddForm(key: formKey),
  );
}

/// 手动添加下载表单：URL 必填（http/https）、文件名留空自动从链接提取、
/// 保存目录必选；提交后经 BrowserDownloadManager 后台下载
class DownloadAddForm extends StatefulWidget {
  const DownloadAddForm({super.key});

  @override
  State<DownloadAddForm> createState() => _DownloadAddFormState();
}

class _DownloadAddFormState extends State<DownloadAddForm> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  final _dirController = TextEditingController();

  /// 提交中防重复（保存目录选择可能耗时）
  bool _saving = false;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _dirController.dispose();
    super.dispose();
  }

  /// 校验 http/https 链接（带主机名）
  bool _isValidHttpUrl(String text) {
    final uri = Uri.tryParse(text);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// 选择保存目录（FilePicker 原生目录选择器）
  Future<void> _pickDirectory() async {
    if (_saving) return;
    final directory = await FilePicker.platform.getDirectoryPath(
      lockParentWindow: true,
    );
    if (directory == null || !mounted) return;
    setState(() => _dirController.text = directory);
  }

  Future<void> save() async {
    if (_saving) return;

    final url = _urlController.text.trim();
    if (!_isValidHttpUrl(url)) {
      Toast.warning('webview_download_invalid_url'.tr);
      return;
    }
    if (_dirController.text.trim().isEmpty) {
      Toast.warning('webview_download_dir_required'.tr);
      return;
    }

    _saving = true;
    // 文件名留空时按下载流程的规则从链接自动提取
    final rawName = _nameController.text.trim();
    final fileName = rawName.isNotEmpty
        ? rawName
        : extractDownloadFileName(url: url);

    WebViewPlugin.instance.browserDownloadManager.startDownload(
      url: url,
      fileName: fileName,
      savePath:
          '${_dirController.text.trim()}${io.Platform.pathSeparator}$fileName',
    );

    if (mounted) {
      Navigator.of(context).pop();
      Toast.success('webview_download_added'.tr);
    }
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
          // 下载链接（必填，仅支持 http/https）
          DSInput(
            controller: _urlController,
            label: 'webview_download_url'.tr,
            hint: 'https://example.com/file.zip',
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
          ),
          SizedBox(height: theme.spacing.md),

          // 文件名（留空自动从链接提取）
          DSInput(
            controller: _nameController,
            label: 'webview_download_file_name'.tr,
            hint: 'webview_download_file_name_hint'.tr,
          ),
          SizedBox(height: theme.spacing.md),

          // 保存目录（只读，经右侧按钮选择）
          DSInput(
            controller: _dirController,
            label: 'webview_download_save_dir'.tr,
            enabled: false,
            suffix: DSIconButton(
              icon: DsIconKind.folder,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.primary,
              tooltip: 'webview_download_pick_dir'.tr,
              onPressed: _pickDirectory,
            ),
          ),
          SizedBox(height: theme.spacing.md),
        ],
      ),
    );
  }
}
