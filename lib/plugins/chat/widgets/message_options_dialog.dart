import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/utils/message_options_handler.dart';

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

  /// 显示消息选项对话框的静态方法
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
    return showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
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

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'chat_messageOptions'.tr,
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),

                // 设置气泡颜色选项
                Padding(
                  padding: EdgeInsets.only(top: theme.spacing.lg),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 重置按钮
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: GestureDetector(
                            onTap: () {
                              onSetBubbleColor(message, null);
                              Navigator.pop(context);
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.stroke,
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: DsIcon(
                                  DsIconKind.refresh,
                                  size: 20,
                                  color: theme.textSub,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 颜色选项
                        ..._bubbleColors.map(
                          (color) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: GestureDetector(
                              onTap: () {
                                onSetBubbleColor(message, color);
                                Navigator.pop(context);
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.stroke,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 分隔线
                Container(
                  height: 1,
                  margin: EdgeInsets.symmetric(vertical: theme.spacing.md),
                  color: theme.stroke.withValues(alpha: 0.5),
                ),

                // 功能按钮区域 - 使用Wrap实现自动换行，每行最多5个
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12.0, // 水平间距
                  runSpacing: 12.0, // 垂直间距
                  children: [
                    // 设置固定标记
                    _buildIconButton(
                      context,
                      DsIconKind.pin,
                      theme.primary,
                      () {
                        Navigator.pop(context);
                        _showFixedSymbolDialog(context);
                      },
                    ),
                    // 编辑
                    _buildIconButton(
                      context,
                      DsIconKind.edit,
                      theme.success,
                      () {
                        Navigator.pop(context);
                        onMessageEdit(message);
                      },
                    ),
                    // 复制
                    _buildIconButton(
                      context,
                      DsIconKind.copy,
                      theme.warning,
                      () {
                        Navigator.pop(context);
                        onMessageCopy(message);
                      },
                    ),
                    // 删除
                    _buildIconButton(
                      context,
                      DsIconKind.trash,
                      theme.danger,
                      () {
                        Navigator.pop(context);
                        onMessageDelete(message);
                      },
                    ),
                    // 分享
                    _buildIconButton(
                      context,
                      DsIconKind.share,
                      theme.secondary,
                      () {
                        Navigator.pop(context);
                        MessageOptionsHandler.shareMessage(context, message);
                      },
                    ),
                    // 回复
                    if (onReply != null)
                      _buildIconButton(
                        context,
                        DsIconKind.reply,
                        theme.primary,
                        () {
                          Navigator.pop(context);
                          onReply!(message);
                        },
                      ),
                    // 收藏
                    if (onToggleFavorite != null)
                      _buildIconButton(
                        context,
                        // 根据消息是否已收藏显示实心/空心星星
                        DsIconKind.star,
                        theme.warning,
                        isFilled:
                            (message.metadata?['isFavorite'] as bool?) == true,
                        () {
                          Navigator.pop(context);
                          onToggleFavorite!(message);
                        },
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

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
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
                        'chat_addEmoji'.tr,
                        textAlign: TextAlign.center,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      DSInput(
                        controller: symbolController,
                        label: 'chat_tag'.tr,
                        hint: 'chat_tagHint'.tr,
                        maxLength: 1, // 限制只能输入一个字符
                      ),
                      if (useRecentSymbols && recentSymbols.isNotEmpty) ...[
                        SizedBox(height: theme.spacing.md),
                        Text(
                          '最近使用',
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                        ),
                        SizedBox(height: theme.spacing.sm),
                        Wrap(
                          spacing: theme.spacing.sm,
                          runSpacing: theme.spacing.sm,
                          children:
                              recentSymbols
                                  .map(
                                    (symbol) => DSChip(
                                      label: symbol,
                                      onSelected:
                                          (_) => symbolController.text = symbol,
                                    ),
                                  )
                                  .toList(),
                        ),
                      ],
                      SizedBox(height: theme.spacing.lg),
                      Row(
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
                              label: 'chat_settings'.tr,
                              onPressed: () async {
                                final symbol =
                                    symbolController.text.isEmpty
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
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }

  // 构建图标按钮
  Widget _buildIconButton(
    BuildContext context,
    DsIconKind icon,
    Color color,
    VoidCallback onPressed, {
    bool isFilled = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: DsIcon(icon, color: color, size: 24, fill: isFilled),
      ),
    );
  }
}
