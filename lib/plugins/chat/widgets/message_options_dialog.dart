import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/utils/message_options_handler.dart';
import 'package:aboutme/widgets/common/cute_notepad_editor.dart';

/// 消息选项对话框组件
class MessageOptionsDialog extends StatelessWidget {
  final Message message;
  final void Function(Message) onMessageEdit;
  final Future<void> Function(Message) onMessageDelete;
  final void Function(Message) onMessageCopy;
  final void Function(Message, String?) onSetFixedSymbol;
  final void Function(Message, Color?) onSetBubbleColor;
  final void Function(Message)? onReply; // 添加回复回调函数
  final void Function(Message)? onToggleFavorite; // 添加收藏回调函数
  final bool useRecentSymbols;
  final bool initiallyShowFixedSymbolDialog;

  const MessageOptionsDialog({
    super.key,
    required this.message,
    required this.onMessageEdit,
    required this.onMessageDelete,
    required this.onMessageCopy,
    required this.onSetFixedSymbol,
    required this.onSetBubbleColor,
    this.onReply,
    this.onToggleFavorite,
    this.useRecentSymbols = true,
    this.initiallyShowFixedSymbolDialog = false,
  });

  /// 气泡颜色选项（消息气泡的自定义配色，与主题无关）
  static final List<Color> _bubbleColors = [
    Color(0xFFD6E4FF), // 默认蓝色
    Color(0xFFF8BBD0), // 粉
    Color(0xFFE1BEE7), // 紫
    Color(0xFFC8E6C9), // 绿
    Color(0xFFFFE0B2), // 橙
    Color(0xFFB2DFDB), // 青
    Color(0xFFFFECB3), // 黄
    Color(0xFFEEEEEE), // 默认灰色
  ];

  /// 显示消息选项的底部抽屉
  static Future<void> show({
    required BuildContext context,
    required Message message,
    required void Function(Message) onMessageEdit,
    required Future<void> Function(Message) onMessageDelete,
    required void Function(Message) onMessageCopy,
    required void Function(Message, String?) onSetFixedSymbol,
    required void Function(Message, Color?) onSetBubbleColor,
    void Function(Message)? onReply,
    void Function(Message)? onToggleFavorite,
    bool useRecentSymbols = true,
    bool initiallyShowFixedSymbolDialog = false,
  }) {
    return showDSBottomSheet(
      context: context,
      title: 'chat_messageOptions'.tr,
      builder:
          (context) => MessageOptionsDialog(
            message: message,
            onMessageEdit: onMessageEdit,
            onMessageDelete: onMessageDelete,
            onMessageCopy: onMessageCopy,
            onSetFixedSymbol: onSetFixedSymbol,
            onSetBubbleColor: onSetBubbleColor,
            onReply: onReply,
            onToggleFavorite: onToggleFavorite,
            useRecentSymbols: useRecentSymbols,
            initiallyShowFixedSymbolDialog: initiallyShowFixedSymbolDialog,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 如果需要直接显示固态符号对话框，在构建后使用微任务调用
    if (initiallyShowFixedSymbolDialog) {
      Future.microtask(() {
        Navigator.pop(context);
        _showFixedSymbolDialog(context);
      });
    }

    final theme = DSThemeBridge.resolve(context);
    final isFavorite =
        (message.metadata?['isFavorite'] as bool?) == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 气泡颜色选项（横向滚动）
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.xl),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 重置按钮
                _buildColorDot(context, null),
                ..._bubbleColors.map((color) => _buildColorDot(context, color)),
              ],
            ),
          ),
        ),
        SizedBox(height: theme.spacing.md),

        // 操作行
        DSSheetAction(
          icon: DsIconKind.pin,
          label: 'chat_pin'.tr,
          onTap: () {
            Navigator.pop(context);
            _showFixedSymbolDialog(context);
          },
        ),
        DSSheetAction(
          icon: DsIconKind.edit,
          label: 'chat_edit'.tr,
          onTap: () {
            Navigator.pop(context);
            onMessageEdit(message);
          },
        ),
        DSSheetAction(
          icon: DsIconKind.copy,
          label: 'chat_copy'.tr,
          onTap: () {
            Navigator.pop(context);
            onMessageCopy(message);
          },
        ),
        DSSheetAction(
          icon: DsIconKind.share,
          label: 'chat_share'.tr,
          onTap: () {
            Navigator.pop(context);
            MessageOptionsHandler.shareMessage(context, message);
          },
        ),
        DSSheetAction(
          icon: DsIconKind.palette,
          label: 'chat_makeSticker'.tr,
          onTap: () {
            Navigator.pop(context);
            CuteNotepadEditorPage.show(
              context,
              initialText: message.content,
            );
          },
        ),
        if (onReply != null)
          DSSheetAction(
            icon: DsIconKind.reply,
            label: 'chat_reply'.tr,
            onTap: () {
              Navigator.pop(context);
              onReply!(message);
            },
          ),
        if (onToggleFavorite != null)
          DSSheetAction(
            icon: DsIconKind.star,
            // 根据消息是否已收藏切换文案
            label: (isFavorite ? 'chat_unfavorite' : 'chat_favorite').tr,
            onTap: () {
              Navigator.pop(context);
              onToggleFavorite!(message);
            },
          ),
        // 危险操作放最后
        DSSheetAction(
          icon: DsIconKind.trash,
          label: 'chat_delete'.tr,
          destructive: true,
          onTap: () {
            Navigator.pop(context);
            onMessageDelete(message);
          },
        ),
      ],
    );
  }

  /// 气泡颜色圆点（null 为重置默认色），手绘墨线描边
  Widget _buildColorDot(BuildContext context, Color? color) {
    final theme = DSThemeBridge.resolve(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GestureDetector(
        onTap: () {
          onSetBubbleColor(message, color);
          Navigator.pop(context);
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: color ?? theme.surface,
            circle: true,
            seed: color?.value ?? 0,
          ),
          // Container 默认不居中子级，图标必须显式居中，否则贴左上角
          alignment: Alignment.center,
          child: color == null
              ? DsIcon(DsIconKind.refresh, size: 20, color: theme.textSub)
              : null,
        ),
      ),
    );
  }

  // 获取最近使用的符号列表
  Future<List<String>> _getRecentSymbols() async {
    if (!useRecentSymbols) return [];
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('recentSymbols') ?? [];
  }

  // 添加新使用的符号到列表
  Future<void> _addRecentSymbol(String symbol) async {
    if (!useRecentSymbols) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> recentSymbols = prefs.getStringList('recentSymbols') ?? [];

    // 如果符号已存在，先移除旧的
    recentSymbols.remove(symbol);
    // 将新使用的符号添加到列表开头
    recentSymbols.insert(0, symbol);
    // 保持列表最多20个符号
    if (recentSymbols.length > 20) {
      recentSymbols = recentSymbols.sublist(0, 20);
    }

    await prefs.setStringList('recentSymbols', recentSymbols);
  }

  void _showFixedSymbolDialog(BuildContext context) async {
    final TextEditingController symbolController = TextEditingController();
    final List<String> recentSymbols = await _getRecentSymbols();

    showDSBottomSheet(
      context: context,
      title: 'chat_addEmoji'.tr,
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.xl),
              child: DSInput(
                controller: symbolController,
                label: 'chat_tag'.tr,
                hint: 'chat_tagHint'.tr,
                maxLength: 1, // 限制只能输入一个字符
              ),
            ),
            if (useRecentSymbols && recentSymbols.isNotEmpty) ...[
              SizedBox(height: theme.spacing.md),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.xl),
                child: Text(
                  'chat_recentSymbols'.tr,
                  style: DsTypography.caption.copyWith(
                    color: theme.textSub,
                  ),
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.xl),
                child: Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.sm,
                  children: recentSymbols
                      .map(
                        (symbol) => DSChip(
                          label: symbol,
                          onSelected:
                              (_) => symbolController.text = symbol,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            SizedBox(height: theme.spacing.lg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.xl),
              child: Row(
                children: [
                  Expanded(
                    child: DSButton(
                      label: 'app_cancel'.tr,
                      variant: DSButtonVariant.outline,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  SizedBox(width: theme.spacing.md),
                  Expanded(
                    child: DSButton(
                      label: 'app_confirm'.tr,
                      onPressed: () async {
                        final symbol = symbolController.text.isEmpty
                            ? null
                            : symbolController.text;
                        if (symbol != null) {
                          await _addRecentSymbol(symbol);
                        }
                        onSetFixedSymbol(message, symbol);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: theme.spacing.md),
          ],
        );
      },
    );
  }
}
