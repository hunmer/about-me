import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/webview_card.dart';
import '../../webview_plugin.dart';
import 'webview_add_card_sheet.dart' show buildFolderPickerSuffix;

/// 弹出编辑卡片表单（底部抽屉，标题栏自带保存按钮）
void showEditCardSheet(BuildContext context, WebViewCard card) {
  final formKey = GlobalKey<_WebViewCardEditSheetState>();

  SmoothBottomSheet.showForm(
    context: context,
    title: 'webview_edit_card'.tr,
    onSave: () => formKey.currentState?.save(),
    child: WebViewCardEditSheet(key: formKey, card: card),
  );
}

/// 编辑卡片表单
class WebViewCardEditSheet extends StatefulWidget {
  const WebViewCardEditSheet({super.key, required this.card});

  final WebViewCard card;

  @override
  State<WebViewCardEditSheet> createState() => _WebViewCardEditSheetState();
}

class _WebViewCardEditSheetState extends State<WebViewCardEditSheet> {
  late final _titleController = TextEditingController(text: widget.card.title);
  late final _urlController = TextEditingController(text: widget.card.url);
  late final _descController = TextEditingController(
    text: widget.card.description ?? '',
  );

  /// 保存中防重复提交
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (_saving) return;

    if (_titleController.text.isEmpty) {
      Toast.warning('请输入卡片标题');
      return;
    }
    if (_urlController.text.isEmpty) {
      Toast.warning('请输入 URL');
      return;
    }

    _saving = true;
    final updatedCard = widget.card.copyWith(
      title: _titleController.text,
      url: _urlController.text,
      description: _descController.text.isNotEmpty
          ? _descController.text
          : null,
    );
    await WebViewPlugin.instance.cardManager.updateCard(updatedCard);

    // 抽屉已被滑动关闭时本 State 已 unmount，不会误弹其他路由
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 选择本地文件填充 URL
  Future<void> _pickLocalFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (!mounted) return;

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      // 将文件路径转换为正确的 file:// URL
      _urlController.text = WebViewPlugin.instance.filePathToUrl(filePath);

      // 如果标题为空，使用文件名作为标题
      if (_titleController.text.isEmpty) {
        _titleController.text = result.files.single.name;
      }
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
          DSInput(
            controller: _titleController,
            label: 'webview_card_title'.tr,
          ),
          SizedBox(height: theme.spacing.md),
          DSInput(
            controller: _urlController,
            label: 'webview_card_url'.tr,
            suffix: buildFolderPickerSuffix(_pickLocalFile),
          ),
          SizedBox(height: theme.spacing.md),
          DSInput(
            controller: _descController,
            label: 'webview_card_description'.tr,
            maxLines: 2,
          ),
          SizedBox(height: theme.spacing.md),
        ],
      ),
    );
  }
}
