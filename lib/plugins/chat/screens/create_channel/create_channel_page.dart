import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/core/services/toast_service.dart';

/// 创建频道 Sheet 内容
///
/// 使用 smooth_sheets 的 modal sheet 展示
class CreateChannelSheet extends StatefulWidget {
  final ChatPlugin plugin;

  const CreateChannelSheet({super.key, required this.plugin});

  @override
  State<CreateChannelSheet> createState() => _CreateChannelSheetState();
}

class _CreateChannelSheetState extends State<CreateChannelSheet> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  bool _isCreating = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    // 对应原 TextFormField 的 autofocus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// 创建频道
  Future<void> _createChannel() async {
    final channelName = _nameController.text.trim();
    if (channelName.isEmpty) {
      setState(() => _nameError = '请输入频道名称');
      return;
    }

    setState(() {
      _isCreating = true;
      _nameError = null;
    });

    try {
      // 创建频道对象（icon 为持久化的 Material IconData）
      final channel = Channel(
        id: const Uuid().v4(),
        title: channelName,
        icon: Icons.chat,
        backgroundColor: widget.plugin.color,
        messages: [],
      );

      await widget.plugin.channelService.createChannel(channel);

      if (mounted) {
        toastService.showToast('chat_channelCreated'.tr);
        // 返回 true 表示创建成功
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('${'chat_createChannelFailed'.tr}: $e');
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          // 使用简单的 Column 布局，不使用 SheetContentScaffold
          return Material(
            color: theme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min, // 关键：让 Column 根据内容收缩
              children: [
                // 顶部栏
                SheetTopBar(
                  leading: DSIconButton(
                    icon: DsIconKind.close,
                    size: 40,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: Text('chat_createChannel'.tr),
                  actions: [
                    if (_isCreating)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: DSLoadingDots(color: theme.textSub),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: DSButton(
                          label: 'chat_create'.tr,
                          variant: DSButtonVariant.ghost,
                          size: DSButtonSize.sm,
                          onPressed: _createChannel,
                        ),
                      ),
                  ],
                ),
                // 内容区域
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 频道名称输入
                      DSInput(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        label: 'chat_channelName'.tr,
                        hint: '例如：工作、学习、随笔...',
                        errorText: _nameError,
                        enabled: !_isCreating,
                        prefix: DsIcon(
                          DsIconKind.tag,
                          size: 18,
                          color: theme.textSub,
                        ),
                        onSubmitted: (_) => _createChannel(),
                      ),
                      const SizedBox(height: 16),

                      // 创建按钮
                      DSButton(
                        label: _isCreating ? '创建中...' : 'chat_create'.tr,
                        icon: DsIconKind.plus,
                        expand: true,
                        onPressed: _isCreating ? null : _createChannel,
                      ),
                      // 底部安全区域
                      SizedBox(
                        height: MediaQuery.of(context).viewPadding.bottom + 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// SheetTopBar 组件
///
/// 用于 SheetContentScaffold 的顶部栏
class SheetTopBar extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final List<Widget>? actions;

  const SheetTopBar({super.key, this.leading, this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.stroke, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            children: [
              // 标题居中
              if (title != null)
                Center(
                  child: DefaultTextStyle(
                    style: DsTypography.title.copyWith(color: theme.text),
                    textAlign: TextAlign.center,
                    child: title!,
                  ),
                ),
              // 左侧和右侧按钮
              Row(
                children: [
                  if (leading != null)
                    leading!
                  else
                    const SizedBox(width: 48), // 占位，保持对称
                  const Spacer(),
                  if (actions != null) ...actions!,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
