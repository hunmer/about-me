import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/utils/message_options_handler.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_bubble/components/fixed_symbol.dart';
import 'package:aboutme/widgets/common/cute_notepad_editor.dart';
import 'package:aboutme/widgets/emoji_picker/emoji.dart';
import 'package:aboutme/widgets/emoji_picker/emoji_category.dart';
import 'package:aboutme/widgets/emoji_picker/emoji_picker.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

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
    return SmoothBottomSheet.showWithTitle(
      context: context,
      title: 'chat_messageOptions'.tr,
      child: MessageOptionsDialog(
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
        SmoothSheetAction(
          icon: DsIconKind.pin,
          label: 'chat_pin'.tr,
          onTap: () {
            Navigator.pop(context);
            _showFixedSymbolDialog(context);
          },
        ),
        SmoothSheetAction(
          icon: DsIconKind.edit,
          label: 'chat_edit'.tr,
          onTap: () {
            Navigator.pop(context);
            onMessageEdit(message);
          },
        ),
        SmoothSheetAction(
          icon: DsIconKind.copy,
          label: 'chat_copy'.tr,
          onTap: () {
            Navigator.pop(context);
            onMessageCopy(message);
          },
        ),
        SmoothSheetAction(
          icon: DsIconKind.share,
          label: 'chat_share'.tr,
          onTap: () {
            Navigator.pop(context);
            MessageOptionsHandler.shareMessage(context, message);
          },
        ),
        SmoothSheetAction(
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
          SmoothSheetAction(
            icon: DsIconKind.reply,
            label: 'chat_reply'.tr,
            onTap: () {
              Navigator.pop(context);
              onReply!(message);
            },
          ),
        if (onToggleFavorite != null)
          SmoothSheetAction(
            icon: DsIconKind.star,
            // 根据消息是否已收藏切换文案
            label: (isFavorite ? 'chat_unfavorite' : 'chat_favorite').tr,
            onTap: () {
              Navigator.pop(context);
              onToggleFavorite!(message);
            },
          ),
        // 危险操作放最后
        SmoothSheetAction(
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
  static Future<List<String>> _getRecentSymbols(bool useRecentSymbols) async {
    if (!useRecentSymbols) return [];
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('recentSymbols') ?? [];
  }

  // 添加新使用的符号到列表
  static Future<void> _addRecentSymbol(
    bool useRecentSymbols,
    String symbol,
  ) async {
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

  void _showFixedSymbolDialog(BuildContext context) {
    showFixedSymbolDialog(
      context,
      message: message,
      onSetFixedSymbol: onSetFixedSymbol,
      useRecentSymbols: useRecentSymbols,
    );
  }

  /// 弹出固定符号编辑弹层（EmojiPicker，文本/图像符号），
  /// 消息气泡角标等入口直接复用
  static Future<void> showFixedSymbolDialog(
    BuildContext context, {
    required Message message,
    required void Function(Message, String?) onSetFixedSymbol,
    bool useRecentSymbols = true,
  }) async {
    final List<String> recentSymbols = await _getRecentSymbols(useRecentSymbols);
    if (!context.mounted) return;

    // 最近使用分组：文本与图像符号统一为可选项
    final recentCategory = recentSymbols.isEmpty
        ? null
        : EmojiCategory(
            icon: const Text('🕘'),
            name: 'chat_recentSymbols'.tr,
            emojis: recentSymbols
                .map(
                  (value) => Emoji(
                    widget: buildFixedSymbolChild(
                      value,
                      style: const TextStyle(fontSize: 20),
                      imageSize: 24,
                    ),
                    value: value,
                    aliases: [value].lock,
                    description: value,
                    tags: const IList.empty(),
                  ),
                )
                .toIList(),
          );

    SmoothBottomSheet.showWithTitle(
      context: context,
      title: 'chat_addEmoji'.tr,
      child: Builder(
        builder: (sheetContext) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.5,
                child: ProviderScope(
                  // 开启全部内置分组：SVG 贴纸 / 方块表情 / 内置表情 / Unicode 表情
                  child: EmojiPicker(
                    prependCategories: [
                      if (recentCategory != null) recentCategory,
                    ].lock,
                    types: const [
                      kEmojiPickerTypeSvg,
                      kEmojiPickerTypeImage,
                      kEmojiPickerTypeEmoji,
                    ],
                    // 搜索框提交的自由文本也作为文本符号
                    allowFreeText: true,
                    onSelection: (value, isFreeText) {
                      final symbol = value.trim();
                      if (symbol.isEmpty) return;
                      _addRecentSymbol(useRecentSymbols, symbol);
                      onSetFixedSymbol(message, symbol);
                      Navigator.pop(sheetContext);
                    },
                  ),
                ),
              ),
              // 移除固定符号
              if (message.fixedSymbol != null)
                SmoothSheetAction(
                  icon: DsIconKind.refresh,
                  label: 'chat_removeSymbol'.tr,
                  onTap: () {
                    onSetFixedSymbol(message, null);
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
