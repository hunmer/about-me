import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:aboutme/widgets/emoji_picker/index.dart';
import 'package:aboutme/plugins/chat/services/sticker_service.dart';
import 'package:aboutme/plugins/chat/screens/sticker_manager_screen.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/handlers/emoji_handler.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/message_input_actions_drawer.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/types.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/plugins/agent_chat/controllers/chat_controller.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_command.dart';
import 'package:aboutme/plugins/agent_chat/models/saved_tool_template.dart';
import 'package:aboutme/utils/file_picker_helper.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:aboutme/plugins/agent_chat/services/speech/tencent_asr_service.dart';
import 'package:aboutme/plugins/agent_chat/services/speech/voice_recognition_helper.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/models/thinking_effort.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/screens/agent_edit_screen.dart';
import 'package:aboutme/plugins/openai/services/agentlib_resource_service.dart';
import 'package:agentlib/agent_slots.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/message_input/message_input.dart' as common;
import 'suggested_questions_dialog.dart';
import 'command_selector.dart';
import 'tool_template_selector.dart';
import 'package:aboutme/plugins/agent_chat/widgets/press_to_record_button.dart';
import '../../../../../../core/services/toast_service.dart';

/// 消息输入框组件
class MessageInput extends StatefulWidget {
  final ChatController controller;

  /// 屏幕注入的附加动作（工具模板/工具管理/朋友圈/文件管理等），
  /// 与内置动作一起在"+"抽屉网格中展示
  final List<common.MessageInputQuickAction> extraQuickActions;

  /// 顶部图标工具栏快捷动作（空列表则隐藏工具栏行）
  final List<common.MessageInputQuickAction> toolbarActions;

  /// 工具栏右侧动作组（贴右缘排布）
  final List<common.MessageInputQuickAction> trailingToolbarActions;

  /// 素描面板是否画墨线描边（透传通用输入框；false = 无边框）
  final bool showPanelStroke;

  /// 素描面板描边用虚线（透传；需 showPanelStroke 为 true）
  final bool dashedPanelStroke;

  const MessageInput({
    super.key,
    required this.controller,
    this.extraQuickActions = const [],
    this.toolbarActions = const [],
    this.trailingToolbarActions = const [],
    this.showPanelStroke = true,
    this.dashedPanelStroke = false,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // 命令模式状态
  bool _isCommandMode = false;
  List<ChatCommand> _filteredCommands = [];

  // 工具模板搜索状态
  bool _isSearchingTools = false;
  List<SavedToolTemplate> _searchResults = [];
  bool _isLoadingToolResults = false;
  String? _toolSearchKeyword;
  List<SavedToolTemplate> _commandToolResults = [];
  bool _isLoadingCommandToolResults = false;
  String? _commandToolQuery;

  // 语音识别服务
  TencentASRService? _recognitionService;

  /// 快捷工具栏常驻动作 id（持久化，勾选入口见动作抽屉 header）
  static const String _quickActionIdsKey = 'agent_chat/quick_toolbar_actions';
  static const Set<String> _defaultQuickActionIds = {
    'image',
    'video',
    'skill',
    'mcp',
  };
  Set<String> _quickActionIds = _defaultQuickActionIds;

  Future<void> _loadQuickActionIds() async {
    try {
      final text = await AboutmeDataService.instance
          .readPathText(_quickActionIdsKey);
      final list = jsonDecode(text);
      if (list is List && list.every((e) => e is String)) {
        if (mounted) setState(() => _quickActionIds = {...list.cast<String>()});
      }
    } catch (_) {
      // 无配置或解析失败时保持默认集合
    }
  }

  void _setQuickActionIds(Set<String> ids) {
    setState(() => _quickActionIds = ids);
    AboutmeDataService.instance.writePath(_quickActionIdsKey, ids.toList());
  }

  @override
  void initState() {
    super.initState();
    _textController.text = widget.controller.inputText;
    _textController.addListener(_onTextChanged);
    widget.controller.addListener(_onControllerChanged);
    debugPrint(
      '[ChatClear] initState controller=#${identityHashCode(widget.controller)}',
    );
    _initializeVoiceRecognition();
    _loadQuickActionIds();
  }

  @override
  void didUpdateWidget(covariant MessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      debugPrint(
        '[ChatClear] controller replaced: #${identityHashCode(oldWidget.controller)} -> #${identityHashCode(widget.controller)}',
      );
      // controller 实例变化时重新挂监听，否则清空通知会发到旧实例上
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _textController.text = widget.controller.inputText;
    }
  }

  @override
  void dispose() {
    debugPrint(
      '[ChatClear] dispose controller=#${identityHashCode(widget.controller)}',
    );
    _textController.removeListener(_onTextChanged);
    widget.controller.removeListener(_onControllerChanged);
    _textController.dispose();
    _focusNode.dispose();
    _recognitionService?.dispose();
    super.dispose();
  }

  /// 初始化语音识别服务
  Future<void> _initializeVoiceRecognition() async {
    if (!mounted) return;

    try {
      // 使用 VoiceRecognitionHelper 创建服务（不显示错误提示）
      final service = await VoiceRecognitionHelper.createServiceSilently(
        context,
      );

      if (service != null && mounted) {
        setState(() {
          _recognitionService = service;
        });
      }
    } catch (e) {
      debugPrint('初始化语音识别服务失败: $e');
    }
  }

  void _onTextChanged() {
    final text = _textController.text;
    widget.controller.setInputText(text);

    final bool isPotentialCommand =
        text.startsWith('/') && !text.contains('\n');
    final (commandType, argument) = isPotentialCommand
        ? ChatCommand.parseInput(text)
        : (null, null);

    // 检测命令模式
    setState(() {
      if (isPotentialCommand) {
        _isCommandMode = true;
        _filteredCommands = ChatCommand.filterCommands(text);
      } else {
        _isCommandMode = false;
        _filteredCommands = [];
      }
    });

    _handleCommandInputChange(
      isPotentialCommand ? commandType : null,
      argument,
    );
  }

  void _handleCommandInputChange(
    ChatCommandType? commandType,
    String? argument,
  ) {
    if (_isCommandMode && commandType == ChatCommandType.tools) {
      final keyword = argument?.trim() ?? '';
      if (keyword.isEmpty) {
        if (_commandToolResults.isNotEmpty ||
            _isLoadingCommandToolResults ||
            _commandToolQuery != null) {
          setState(() {
            _commandToolResults = [];
            _isLoadingCommandToolResults = false;
            _commandToolQuery = null;
          });
        }
        return;
      }

      _searchToolTemplatesForCommand(keyword);
      return;
    }

    if (_commandToolResults.isNotEmpty ||
        _isLoadingCommandToolResults ||
        _commandToolQuery != null) {
      setState(() {
        _commandToolResults = [];
        _isLoadingCommandToolResults = false;
        _commandToolQuery = null;
      });
    }
  }

  void _searchToolTemplatesForCommand(String keyword) {
    if (widget.controller.templateService == null) {
      return;
    }

    if (_commandToolQuery == keyword && _isLoadingCommandToolResults) {
      return;
    }

    setState(() {
      _isLoadingCommandToolResults = true;
      _commandToolResults = [];
      _commandToolQuery = keyword;
    });

    widget.controller
        .fetchToolTemplates(keyword: keyword)
        .then((results) {
          if (!mounted || _commandToolQuery != keyword) return;
          setState(() {
            _commandToolResults = results;
            _isLoadingCommandToolResults = false;
          });
        })
        .catchError((error) {
          if (!mounted || _commandToolQuery != keyword) return;
          setState(() {
            _commandToolResults = [];
            _isLoadingCommandToolResults = false;
          });
        });
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});

      // 同步输入框文本
      if (_textController.text != widget.controller.inputText) {
        debugPrint(
          '[ChatClear] sync text: field="${_textController.text}" -> model="${widget.controller.inputText}"',
        );
        _textController.text = widget.controller.inputText;
        _textController.selection = TextSelection.collapsed(
          offset: _textController.text.length,
        );
      }
    }
  }

  /// "+"抽屉完整动作列表（原顶部工具栏快捷动作并入此处，网格展示）
  List<MessageInputAction> _buildDrawerActions() {
    final controller = widget.controller;
    final agentReady = controller.currentAgent != null;
    return [
      MessageInputAction(
        id: 'suggested',
        title: '你可以问',
        icon: DsIconKind.star,
        onTap: _showSuggestedQuestions,
      ),
      MessageInputAction(
        id: 'image',
        title: 'agent_chat_image'.tr,
        icon: DsIconKind.image,
        onTap: () => controller.pickImages(),
      ),
      MessageInputAction(
        id: 'document',
        title: 'agent_chat_document'.tr,
        icon: DsIconKind.copy,
        onTap: () => controller.pickDocuments(),
      ),
      MessageInputAction(
        id: 'video',
        title: '选择视频',
        icon: DsIconKind.video,
        onTap: _pickVideos,
      ),
      MessageInputAction(
        id: 'agent_edit',
        title: '编辑Agent',
        icon: DsIconKind.bot,
        onTap: agentReady ? _openAgentEdit : () {},
      ),
      MessageInputAction(
        id: 'skill',
        title: '选择Skill',
        icon: DsIconKind.book,
        onTap: () => _showResourceMenu(skills: true),
      ),
      MessageInputAction(
        id: 'mcp',
        title: '选择MCP',
        icon: DsIconKind.block,
        onTap: () => _showResourceMenu(skills: false),
      ),
      // 仅使用 JS 工具切换（发送中禁用）；title 含开关状态，必须用固定 id
      MessageInputAction(
        id: 'js_tools',
        title: '仅使用JS${controller.useJsTools ? '（开）' : '（关）'}',
        icon: DsIconKind.code,
        onTap: controller.isSending
            ? () {}
            : () => controller.setUseJsTools(!controller.useJsTools),
      ),
      MessageInputAction(
        id: 'clear_messages',
        title: '清空消息',
        icon: DsIconKind.trash,
        onTap: _confirmClearMessages,
      ),
      ...widget.extraQuickActions.map(
        (action) => MessageInputAction(
          title: action.tooltip,
          icon: action.icon,
          onTap: action.onPressed ?? () {},
          onLongPress: action.onLongPress,
        ),
      ),
    ];
  }

  /// 选择视频并加入待发送文件
  Future<void> _pickVideos() async {
    final files = await FilePickerHelper.pickFiles(
      allowedExtensions: const ['mp4', 'mov', 'avi', 'mkv', 'webm'],
    );
    if (files.isNotEmpty) {
      widget.controller.addFiles(files);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final agentReady = widget.controller.currentAgent != null;
    final agentId = widget.controller.currentAgent?.id;

    return common.MessageInput(
      controller: _textController,
      focusNode: _focusNode,
      enabled: agentReady,
      hintText: agentReady ? '输入消息...' : '请先选择Agent...',
      onOpenActionsDrawer: _showAttachmentMenu,
      useSketchPanel: true,
      showPanelStroke: widget.showPanelStroke,
      dashedPanelStroke: widget.dashedPanelStroke,
      // 快捷栏常驻动作：抽屉动作按持久化配置过滤（勾选入口在抽屉 header）
      quickActions: [
        for (final action in _buildDrawerActions())
          if (_quickActionIds.contains(action.id))
            common.MessageInputQuickAction(
              icon: action.icon,
              tooltip: action.title,
              onPressed: action.onTap,
              onLongPress: action.onLongPress,
            ),
        ...widget.toolbarActions,
      ],
      thinkingEffortIndex:
          widget.controller.currentAgent?.thinkingEffort.index ?? 1,
      onThinkingEffortChanged: agentReady
          ? (index) => _updateThinkingEffort(agentId!, index)
          : null,
      // 工具栏右组：表情 + 外部注入动作（"你可以问"已移入抽屉动作列表）
      trailingQuickActions: [
        common.MessageInputQuickAction(
          icon: DsIconKind.mood,
          tooltip: '表情',
          onPressed: _showEmojiPicker,
        ),
        ...widget.trailingToolbarActions,
      ],
      // 输入框上方：工具模板搜索 / 命令选择器 / 待发送状态
      header: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSearchingTools) _buildToolTemplateSearchArea(),

          // 命令选择器
          if (_isCommandMode && _filteredCommands.isNotEmpty)
            CommandSelector(
              commands: _filteredCommands,
              onCommandSelected: _handleCommandSelected,
            ),

          if (!_isSearchingTools &&
              _isCommandMode &&
              (_commandToolQuery?.isNotEmpty ?? false))
            _buildToolCommandSearchResults(),

          // 当前状态显示区域（工具模板和文件）
          if (!_isSearchingTools &&
              (widget.controller.selectedToolTemplate != null ||
                  widget.controller.selectedFiles.isNotEmpty))
            _buildCurrentStatus(),
        ],
      ),
      inputSuffix: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Token统计
            if (widget.controller.inputText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '~${widget.controller.inputTokenCount}',
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ),
            // 录音：点击开始/停止，识别结果实时写入输入框；
            // 未配置时回退为对话框输入
            if (_recognitionService != null)
              PressToRecordButton(
                textController: _textController,
                recognitionService: _recognitionService!,
                enabled: agentReady,
                size: 20,
                tooltip: '录音',
                onRecognitionComplete: (text) {
                  // 聚焦到输入框
                  _focusNode.requestFocus();
                },
                onError: (error) {
                  if (mounted) {
                    toastService.showToast('语音识别失败: $error');
                  }
                },
              )
            else
              _InlineIconAction(
                icon: DsIconKind.mic,
                color: theme.textSub,
                onPressed: agentReady ? _showVoiceInputDialog : null,
                tooltip: '语音输入（未配置）',
              ),
          ],
        ),
      ),
      // 发送/取消按钮
      sendButton: DSIconButton(
        icon: widget.controller.isSending
            ? DsIconKind
                  .close // 显示取消图标
            : DsIconKind.send,
        size: 44,
        color: widget.controller.isSending
            ? theme
                  .danger // 发送中显示红色
            : theme.primary,
        onPressed: widget.controller.isSending
            ? () => widget.controller
                  .cancelSending() // 取消发送
            : (_canSendMessage() ? _sendMessage : null),
      ),
      onSend: () {
        if (_canSendMessage()) {
          _sendMessage();
        }
      },
    );
  }

  /// 构建当前状态显示
  Widget _buildCurrentStatus() {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      padding: const EdgeInsets.all(12),
      // 面板内分区用淡色块区分层次，不画手写描边（design.md §9）
      color: theme.surfaceAlt.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 工具模板
          if (widget.controller.selectedToolTemplate != null) ...[
            Row(
              children: [
                DsIcon(DsIconKind.gear, size: 16, color: theme.warning),
                const SizedBox(width: 6),
                Text(
                  '使用工具模板',
                  style: DsTypography.caption.copyWith(
                    color: theme.textSub,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildToolTemplateChip(widget.controller.selectedToolTemplate!),
          ],

          // 分隔
          if (widget.controller.selectedToolTemplate != null &&
              widget.controller.selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: theme.textSub.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
          ],

          // 文件
          if (widget.controller.selectedFiles.isNotEmpty) ...[
            Row(
              children: [
                DsIcon(DsIconKind.copy, size: 16, color: theme.primaryText),
                const SizedBox(width: 6),
                Text(
                  '已选择 ${widget.controller.selectedFiles.length} 个文件',
                  style: DsTypography.caption.copyWith(
                    color: theme.textSub,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 文件缩略图条（横滑，图片显示缩略图，其余类型显示图标卡）
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.controller.selectedFiles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _buildFileThumb(theme, index),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建工具模板芯片
  Widget _buildToolTemplateChip(SavedToolTemplate template) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.warning.mixWhite(0.9),
        stroke: theme.warning.withValues(alpha: 0.5),
        radius: theme.radii.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIcon(DsIconKind.gear, size: 18, color: theme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: DsTypography.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${template.steps.length} 个步骤',
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onPressed: () => widget.controller.clearSelectedToolTemplate(),
            semanticLabel: '移除工具模板',
            builder: (context, states) => Container(
              padding: const EdgeInsets.all(4),
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: theme.surface,
                stroke: theme.warning.withValues(alpha: 0.6),
                circle: true,
              ),
              child: DsIcon(DsIconKind.close, size: 14, color: theme.warning),
            ),
          ),
        ],
      ),
    );
  }

  /// 单个待发送文件的缩略图：图片显示预览，其余类型显示图标卡；
  /// 点击主体用系统程序打开，右上 × 移除（样式复用 chat 插件 MetadataDisplay）
  Widget _buildFileThumb(AppThemeData theme, int index) {
    final file = widget.controller.selectedFiles[index];
    final isImage = FilePickerHelper.isImageFile(file);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _openFileWithSystem(file.path),
          child: ClipRRect(
            borderRadius: theme.radii.sm,
            child: SizedBox(
              width: 52,
              height: 52,
              child: isImage
                  ? Image(
                      image: ImageUtils.createImageProvider(file.path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _fileTypeFallback(theme, file, DsIconKind.image),
                    )
                  : _fileTypeFallback(theme, file, DsIconKind.copy),
            ),
          ),
        ),
        // 右上取消图标
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () => widget.controller.removeFile(index),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.text,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: DsIcon(DsIconKind.close, size: 10, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 非图片文件的图标卡兜底
  Widget _fileTypeFallback(AppThemeData theme, File file, DsIconKind fallback) {
    final iconData = FilePickerHelper.getFileIcon(file);
    return Container(
      color: theme.primary.mixWhite(0.85),
      child: Center(
        child: FilePickerHelper.isImageFile(file)
            ? DsIcon(fallback, size: 20, color: theme.primary)
            : Icon(iconData, size: 20, color: theme.primary),
      ),
    );
  }

  /// 用系统程序打开文件（桌面端）
  void _openFileWithSystem(String path) {
    if (path.isEmpty) return;
    if (UniversalPlatform.isWindows) {
      Process.run('explorer', [path]);
    } else if (UniversalPlatform.isMacOS) {
      Process.run('open', [path]);
    } else if (UniversalPlatform.isLinux) {
      Process.run('xdg-open', [path]);
    }
  }

  /// 清空当前会话消息（确认后执行）
  Future<void> _confirmClearMessages() async {
    final confirm = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) => DSDialog(
            title: '清空消息',
            message: '确定要清空当前会话的所有消息吗？此操作不可撤销。',
            cancelText: 'agent_chat_cancel'.tr,
            confirmText: '清空',
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () => Navigator.pop(dialogContext, true),
            onCancel: () => Navigator.pop(dialogContext, false),
          ),
        ),
      ),
    );
    if (confirm != true) return;
    try {
      await widget.controller.clearAllMessages();
      if (mounted) toastService.showToast('已清空消息');
    } catch (e) {
      if (mounted) toastService.showToast('清空失败: $e');
    }
  }

  /// 显示附件菜单（"+"按钮：完整动作列表，网格展示）
  void _showAttachmentMenu() {    SmoothBottomSheet.show(
      context: context,
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: MessageInputActionsDrawer(
              actions: _buildDrawerActions(),
              quickActionIds: _quickActionIds,
              onQuickActionIdsChanged: _setQuickActionIds,
            ),
          ),
        ),
      ),
    );
  }

  /// 打开表情选择器：Unicode 表情插入输入框光标处，
  /// 内置图片表情/贴图写入临时文件后作为附件发送
  Future<void> _showEmojiPicker() async {
    final stickerCollections = await StickerService.instance.listCollections();
    if (!mounted) return;
    final sheetHeight = math.min(
      520.0,
      MediaQuery.of(context).size.height * 0.7,
    );
    await SmoothBottomSheet.show(
      context: context,
      builder: (sheetContext) => SizedBox(
        height: sheetHeight,
        width: double.infinity,
        child: ProviderScope(
          child: Column(
            children: [
              // 顶部工具条：贴图管理入口（与 chat 插件表情抽屉保持一致）
              Align(
                alignment: Alignment.centerRight,
                child: DSButton(
                  label: 'chat_stickerManager'.tr,
                  variant: DSButtonVariant.outline,
                  size: DSButtonSize.sm,
                  icon: DsIconKind.gear,
                  onPressed:
                      () => NavigationHelper.push(
                        sheetContext,
                        const StickerManagerScreen(),
                      ),
                ),
              ),
              Expanded(
                child: EmojiPicker(
                  types: const [kEmojiPickerTypeEmoji, kEmojiPickerTypeImage],
                  appendCategories: buildStickerCategories(stickerCollections),
                  onSelection: (value, isFreeText) {
                    if (value.startsWith(kStickerPrefix)) {
                      Navigator.of(sheetContext).pop();
                      _attachSticker(value.substring(kStickerPrefix.length));
                    } else if (value.startsWith(kBuiltInEmojiPrefix)) {
                      Navigator.of(sheetContext).pop();
                      _attachEmojiAsset(
                        value.substring(kBuiltInEmojiPrefix.length),
                      );
                    } else {
                      _insertTextAtCursor(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 内置图片表情（asset）转临时文件并加入待发送文件
  Future<void> _attachEmojiAsset(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await _attachBytesAsFile(path.basename(assetPath), bytes);
    } catch (e) {
      debugPrint('表情附件添加失败: $e');
      if (mounted) {
        toastService.showToast('表情发送失败: $e');
      }
    }
  }

  /// 贴图转临时文件并加入待发送文件
  Future<void> _attachSticker(String stickerPath) async {
    try {
      final bytes = await StickerService.instance.readStickerBytes(stickerPath);
      if (bytes == null) {
        if (mounted) {
          toastService.showToast('贴图文件不存在或读取失败');
        }
        return;
      }
      await _attachBytesAsFile(path.basename(stickerPath), bytes);
    } catch (e) {
      debugPrint('贴图附件添加失败: $e');
      if (mounted) {
        toastService.showToast('贴图发送失败: $e');
      }
    }
  }

  /// 字节写入临时文件后加入待发送文件
  Future<void> _attachBytesAsFile(String fileName, List<int> bytes) async {
    final file = File(
      path.join(
        Directory.systemTemp.path,
        '${const Uuid().v4()}${path.extension(fileName)}',
      ),
    );
    await file.writeAsBytes(bytes);
    widget.controller.addFiles([file]);
  }

  /// 在光标处插入文本（Unicode 表情）
  void _insertTextAtCursor(String text) {
    final selection = _textController.selection.isValid
        ? _textController.selection
        : TextSelection.collapsed(offset: _textController.text.length);
    final newText = _textController.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    _textController.value = _textController.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + text.length),
    );
  }

  Future<void> _updateThinkingEffort(String agentId, int index) async {
    if (!mounted) return;
    try {
      final agents = AgentController();
      final agent = await agents.getAgent(agentId);
      if (agent == null) return;
      final updated = agent.copyWith(
        thinkingEffort: ThinkingEffort.values[index],
        updatedAt: DateTime.now(),
      );
      if (agents.temporaryAgents.any((entry) => entry.id == agentId)) {
        agents.addTemporaryAgent(updated);
      } else {
        await agents.updateAgent(updated);
      }
      if (!mounted) return;
      await widget.controller.reloadCurrentAgents();
    } catch (e) {
      ToastService.instance.showToast('保存思考等级失败: $e');
    }
  }

  /// 打开当前 Agent 编辑页
  void _openAgentEdit() {
    final AIAgent? agent = widget.controller.currentAgent;
    if (agent == null) return;
    NavigationHelper.push(context, AgentEditScreen(agent: agent));
  }

  /// 显示 Skills/MCP 选择菜单
  void _showResourceMenu({required bool skills}) {
    // 合并全局与当前 Agent 的同类资源，按 id 去重
    final resources = <String, AgentResourceItem>{};
    for (final item in [
      ...skills
          ? AgentLibResourceService.globalSlots.skills
          : AgentLibResourceService.globalSlots.mcpServers,
      ...?skills
          ? widget.controller.currentAgent?.resourceSlots.skills
          : widget.controller.currentAgent?.resourceSlots.mcpServers,
    ]) {
      resources[item.id] = item;
    }
    final items = resources.values.where((item) => item.enabled).toList();
    final label = skills ? 'Skill' : 'MCP';

    SmoothBottomSheet.show(
      context: context,
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SafeArea(
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          '暂无可用的 $label，可先在 Agent 编辑页添加',
                          style: DsTypography.body.copyWith(
                            color: DSThemeBridge.resolve(context).textSub,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return DSListItem(
                          leading: DsIcon(
                            skills ? DsIconKind.book : DsIconKind.block,
                            size: 22,
                            color: DSThemeBridge.resolve(context).primaryText,
                          ),
                          title: item.displayName,
                          subtitle: item.tags.isEmpty
                              ? null
                              : item.tags.join(' · '),
                          onTap: () {
                            Navigator.pop(context);
                            _insertResourceText(item, skills);
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// 在输入框插入 use [xxx] skill / mcp
  void _insertResourceText(AgentResourceItem item, bool skills) {
    final insert = 'use [${item.displayName}] ${skills ? 'skill' : 'mcp'}';
    final current = _textController.text;
    final newText = current.isEmpty ? insert : '$current\n$insert';
    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(offset: newText.length);
    widget.controller.setInputText(newText);
    _focusNode.requestFocus();
  }

  /// 显示预设问题对话框
  Future<void> _showSuggestedQuestions() async {
    final plugin = AgentChatPlugin.instance;
    final selectedQuestion = await showSuggestedQuestionsDialog(
      context,
      plugin.storage,
    );

    if (selectedQuestion != null && mounted) {
      // 将选中的问题填充到输入框
      _textController.text = selectedQuestion;
      widget.controller.setInputText(selectedQuestion);

      // 聚焦到输入框
      _focusNode.requestFocus();
    }
  }

  /// 显示语音输入对话框
  Future<void> _showVoiceInputDialog() async {
    if (!mounted) return;

    await VoiceRecognitionHelper.showVoiceInputDialog(
      context: context,
      onComplete: (text) {
        // 将识别的文本填充到输入框
        _textController.text = text;
        widget.controller.setInputText(text);

        // 聚焦到输入框
        _focusNode.requestFocus();
      },
    );
  }

  /// 构建工具模板搜索区域
  Widget _buildToolTemplateSearchArea() {
    final theme = DSThemeBridge.resolve(context);
    if (_isLoadingToolResults) {
      return DsSketchPanel(
        theme: theme,
        hachure: false,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            DSLoadingDots(size: 7),
            const SizedBox(width: 12),
            Text(
              'agent_chat_loadingToolTemplates'.tr,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && (_toolSearchKeyword?.isNotEmpty ?? false)) {
      return _buildToolSearchEmptyState();
    }

    return ToolTemplateSelector(
      templates: _searchResults,
      onTemplateSelected: _handleTemplateSelected,
      onCancel: () {
        setState(() {
          _isSearchingTools = false;
          _isLoadingToolResults = false;
          _searchResults = [];
          _toolSearchKeyword = null;
        });
      },
    );
  }

  Widget _buildToolCommandSearchResults() {
    final theme = DSThemeBridge.resolve(context);
    final keyword = _commandToolQuery ?? '';

    return DsSketchPanel(
      theme: theme,
      hachure: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                DsIcon(DsIconKind.search, size: 18, color: theme.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '匹配的工具模板：$keyword',
                    style: DsTypography.caption.copyWith(
                      color: theme.textSub,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isLoadingCommandToolResults)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: DSLoadingDots(size: 5),
                  ),
              ],
            ),
          ),
          if (_isLoadingCommandToolResults)
            const SizedBox(height: 12)
          else if (_commandToolResults.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                '找不到 "$keyword"，按 Enter 继续搜索',
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _commandToolResults.length > 5
                  ? 5
                  : _commandToolResults.length,
              itemBuilder: (context, index) {
                final template = _commandToolResults[index];
                return _buildToolCommandResultItem(template);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildToolCommandResultItem(SavedToolTemplate template) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: () => _applyToolCommandTemplate(template),
      builder: (context, states) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            DsIcon(DsIconKind.gear, size: 20, color: theme.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: DsTypography.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.text,
                    ),
                  ),
                  if (template.description != null &&
                      template.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      template.description!,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            DsIcon(DsIconKind.chevronRight, size: 16, color: theme.textSub),
          ],
        ),
      ),
    );
  }

  void _applyToolCommandTemplate(SavedToolTemplate template) {
    final newInput = '/tools ${template.name}';
    _textController.text = newInput;
    _textController.selection = TextSelection.collapsed(
      offset: newInput.length,
    );
    widget.controller.setInputText(newInput);

    setState(() {
      _commandToolResults = [];
      _isLoadingCommandToolResults = false;
      _commandToolQuery = template.name;
    });
  }

  Widget _buildToolSearchEmptyState() {
    final theme = DSThemeBridge.resolve(context);
    final keyword = _toolSearchKeyword ?? '';
    return DsSketchPanel(
      theme: theme,
      hachure: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                DsIcon(DsIconKind.search, size: 20, color: theme.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '找不到 $keyword',
                    style: DsTypography.caption.copyWith(
                      color: theme.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Pressable(
                  onPressed: () {
                    setState(() {
                      _isSearchingTools = false;
                      _isLoadingToolResults = false;
                      _searchResults = [];
                      _toolSearchKeyword = null;
                    });
                  },
                  semanticLabel: '取消',
                  builder: (context, states) => SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: DsIcon(
                        DsIconKind.close,
                        size: 20,
                        color: theme.textSub,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              '没有找到匹配的工具模板，请尝试其他关键词。',
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ),
        ],
      ),
    );
  }

  /// 处理命令选择
  void _handleCommandSelected(ChatCommand command) {
    switch (command.type) {
      case ChatCommandType.files:
        _executeFilesCommand();
        break;
      case ChatCommandType.tools:
        // 如果需要参数，填充命令模板
        if (command.requiresArgument) {
          _textController.text = '/${command.command} ';
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
          _focusNode.requestFocus();
        } else {
          _executeToolsCommand(null);
        }
        break;
    }
  }

  /// 执行 /files 命令
  void _executeFilesCommand() {
    // 清空输入框
    _textController.clear();
    widget.controller.setInputText('');

    // 显示附件菜单
    _showAttachmentMenu();
  }

  /// 执行 /tools 命令
  void _executeToolsCommand(String? searchQuery) {
    // 清空输入框
    _textController.clear();
    widget.controller.setInputText('');

    final keyword = searchQuery?.trim();
    final normalizedKeyword = (keyword == null || keyword.isEmpty)
        ? null
        : keyword;

    setState(() {
      _isSearchingTools = true;
      _isLoadingToolResults = true;
      _searchResults = [];
      _toolSearchKeyword = normalizedKeyword;
    });

    widget.controller
        .fetchToolTemplates(keyword: normalizedKeyword)
        .then((results) {
          if (!mounted) return;
          setState(() {
            _searchResults = results;
            _isLoadingToolResults = false;
          });
        })
        .catchError((error) {
          if (!mounted) return;
          setState(() {
            _isLoadingToolResults = false;
            _searchResults = [];
          });
          toastService.showToast('加载工具模板失败: $error');
        });
  }

  /// 处理模板选择
  void _handleTemplateSelected(SavedToolTemplate template) {
    // 选中模板
    widget.controller.setSelectedToolTemplate(template);

    // 关闭搜索
    setState(() {
      _isSearchingTools = false;
      _searchResults = [];
      _toolSearchKeyword = null;
    });

    // 聚焦输入框
    _focusNode.requestFocus();
  }

  /// 检查是否可以发送消息
  bool _canSendMessage() {
    // Agent 必须已选择
    if (widget.controller.currentAgent == null) return false;

    // 如果有选中的工具模板，即使输入框为空也可以发送
    if (widget.controller.selectedToolTemplate != null) return true;

    // 如果有选中的文件，即使输入框为空也可以发送
    if (widget.controller.selectedFiles.isNotEmpty) return true;

    // 否则，输入框不能为空
    return widget.controller.inputText.trim().isNotEmpty;
  }

  /// 发送消息
  Future<void> _sendMessage() async {
    // 先结束输入法组合状态（如拼音未上屏）：组合中的文本仍属于
    // inputText 会正常发出，但不提前清除 composing 标记的话，
    // 发送后清空输入框会被输入法把组合文本重新提交回来
    if (_textController.value.composing != TextRange.empty) {
      _textController.value = _textController.value.copyWith(
        composing: TextRange.empty,
      );
    }

    final text = widget.controller.inputText.trim();
    debugPrint(
      '[ChatClear] _sendMessage: field="${_textController.text}" model="${widget.controller.inputText}" controller=#${identityHashCode(widget.controller)}',
    );

    // 如果文本为空且没有工具模板和文件，则不能发送
    if (text.isEmpty &&
        widget.controller.selectedToolTemplate == null &&
        widget.controller.selectedFiles.isEmpty) {
      return;
    }

    // 检查是否是命令
    if (text.startsWith('/')) {
      final (commandType, argument) = ChatCommand.parseInput(text);

      if (commandType != null) {
        // 执行命令
        switch (commandType) {
          case ChatCommandType.files:
            _executeFilesCommand();
            return;
          case ChatCommandType.tools:
            _executeToolsCommand(argument);
            return;
        }
      } else {
        // 无效命令
        if (mounted) {
          toastService.showToast('无效的命令');
        }
        return;
      }
    }

    // 正常发送消息
    try {
      await widget.controller.sendMessage();
      _focusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        toastService.showToast('发送失败: $e');
      }
    }
  }
}

/// 输入框内嵌的无边框小图标按钮（表情/语音）
class _InlineIconAction extends StatelessWidget {
  const _InlineIconAction({
    required this.icon,
    required this.color,
    this.onPressed,
    this.tooltip,
  });

  final DsIconKind icon;
  final Color color;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Pressable(
      onPressed: onPressed,
      semanticLabel: tooltip,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedScale(
          scale: pressed && !disabled ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: DsIcon(
              icon,
              size: 18,
              color: disabled ? color.withValues(alpha: 0.4) : color,
            ),
          ),
        );
      },
    );
  }
}
