import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/widgets/picker/circle_icon_picker.dart';
import '../../../../../../../core/services/toast_service.dart';

class ChatChannelForm extends StatefulWidget {
  // 用于区分是添加还是编辑模式
  final bool isEditMode;
  // 编辑模式时传入的频道
  final Channel? channel;
  // 添加频道的回调
  final Future<void> Function(Channel)? onAddChannel;
  // 更新频道的回调
  final Function(Channel)? onUpdateChannel;
  // 默认的频道分组
  final String? defaultGroup;
  // 是否作为底部弹层内容展示（去掉对话框卡片外壳，由 sheet 提供容器）
  final bool asSheet;

  const ChatChannelForm({
    super.key,
    this.isEditMode = false,
    this.channel,
    this.onAddChannel,
    this.onUpdateChannel,
    this.defaultGroup,
    this.asSheet = false,
  }) : assert(
         (isEditMode && channel != null && onUpdateChannel != null) ||
             (!isEditMode && onAddChannel != null),
         '编辑模式需要提供channel和onUpdateChannel，添加模式需要提供onAddChannel',
       );

  @override
  State<ChatChannelForm> createState() => _ChatChannelFormState();
}

class _ChatChannelFormState extends State<ChatChannelForm> {
  late TextEditingController _titleController;
  late TextEditingController _groupController;
  late IconData _selectedIcon;

  /// 用户选择的颜色；null 表示未设置，展示与保存时按标题自动计算
  Color? _selectedColor;

  /// 频道名称校验错误（DSInput 通过 errorText 展示）
  String? _titleError;

  /// 提交状态，避免异步创建期间重复提交或误关闭其他路由
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode && widget.channel != null) {
      // 编辑模式，初始化为现有频道数据
      _titleController = TextEditingController(text: widget.channel!.title);
      _groupController = TextEditingController(
        text: widget.channel!.groups.isNotEmpty
            ? widget.channel!.groups.join(', ')
            : '',
      );
      _selectedIcon = widget.channel!.icon;
      _selectedColor = widget.channel!.backgroundColor;
    } else {
      // 添加模式，使用默认值；颜色未设置，按标题自动计算
      _titleController = TextEditingController();
      _groupController = TextEditingController(text: widget.defaultGroup ?? '');
      _selectedIcon = Icons.chat;
      _selectedColor = null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    // DSInput 无内建 Form 校验，提交时手动校验
    if (_titleController.text.trim().isEmpty) {
      setState(() => _titleError = '请输入频道名称');
      return;
    }
    setState(() {
      _titleError = null;
      _isSubmitting = !widget.isEditMode;
    });

    final List<String> groups = _groupController.text.isEmpty
        ? []
        : _groupController.text
              .replaceAll('，', ',')
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

    if (widget.isEditMode && widget.channel != null) {
      // 编辑模式
      final updatedChannel = Channel(
        id: widget.channel!.id,
        title: _titleController.text,
        groups: groups,
        icon: _selectedIcon,
        backgroundColor: _selectedColor,
        priority: widget.channel!.priority,
        lastMessage: widget.channel!.lastMessage,
        draft: widget.channel!.draft,
        messages: widget.channel!.messages,
        backgroundPath: widget.channel!.backgroundPath, // 保留背景图片路径
      );

      widget.onUpdateChannel!(updatedChannel);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    try {
      final newChannel = Channel(
        id: const Uuid().v4(),
        title: _titleController.text,
        groups: groups,
        icon: _selectedIcon,
        backgroundColor: _selectedColor,
        priority: 0,
        messages: [], // 添加空的消息列表
      );
      final formRoute = ModalRoute.of(context);
      final navigator = Navigator.of(context);

      // 异步调用添加频道。提交状态由表单按钮承载，避免额外 Dialog 抢占导航栈。
      await widget.onAddChannel!(newChannel);

      if (mounted && formRoute != null && formRoute.isActive) {
        // 创建事件可能同步打开成就弹窗，直接移除表单路由避免误关成就弹窗。
        navigator.removeRoute(formRoute);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        toastService.showToast('${'chat_channelCreationFailed'.tr}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditMode ? '编辑频道' : ('chat_newChannel'.tr);

    return DSThemeBridge(
      // Builder 让表单在主题桥之内构建，可读取 AppTheme
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final form = SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.lg),
                CircleIconPicker(
                  currentIcon: _selectedIcon,
                  backgroundColor:
                      _selectedColor ??
                      Channel.colorFromTitle(_titleController.text),
                  onIconSelected: (icon) {
                    setState(() {
                      _selectedIcon = icon;
                    });
                  },
                  onColorSelected: (color) {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                ),
                SizedBox(height: theme.spacing.lg),
                DSInput(
                  controller: _titleController,
                  label: 'chat_channelName'.tr,
                  errorText: _titleError,
                  onChanged: (_) {
                    // 输入后清除错误提示；未手动选色时预览颜色随标题联动
                    if (_titleError != null || _selectedColor == null) {
                      setState(() => _titleError = null);
                    }
                  },
                ),
                SizedBox(height: theme.spacing.md),
                DSInput(
                  controller: _groupController,
                  label: 'chat_channelGroupLabel'.tr,
                  hint: 'chat_channelGroupHint'.tr,
                ),
                SizedBox(height: theme.spacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: DSButton(
                        label: 'chat_cancel'.tr,
                        variant: DSButtonVariant.outline,
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(width: theme.spacing.md),
                    Expanded(
                      child: DSButton(
                        label: widget.isEditMode
                            ? 'core_save'.tr
                            : 'chat_create'.tr,
                        loading: _isSubmitting,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (widget.asSheet) {
            return Padding(
              // sheet 顶部已有拖拽指示条，标题侧仅留小间距
              padding: EdgeInsets.fromLTRB(
                theme.spacing.xl,
                theme.spacing.sm,
                theme.spacing.xl,
                theme.spacing.xl,
              ),
              child: form,
            );
          }
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 360),
            child: form,
          );
        },
      ),
    );
  }
}
