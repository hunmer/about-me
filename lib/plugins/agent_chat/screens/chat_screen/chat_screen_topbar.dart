part of 'chat_screen.dart';

/// 顶栏：标题 / 操作按钮 / 更多菜单
extension _ChatScreenTopBarExt on _ChatScreenState {
  /// 顶栏标题：会话名 + Agent/输入中状态，点击打开 Agent 选择器
  Widget _buildAgentTitle() {
    final isTyping =
        _controller.isSending ||
        _controller.isThinking ||
        _controller.alivenessFlushActive;

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showAgentSelector,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.text,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 正在输入状态（替代 agent 信息显示）
                      if (isTyping) ...[
                        SizedBox(
                          width: 6,
                          height: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _controller.typingStatusText ?? '正在输入中…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsTypography.caption.copyWith(
                              color: theme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ] else ...[
                        DsIcon(
                          _isChainMode ? DsIconKind.layers : DsIconKind.bot,
                          size: 12,
                          color: theme.textSub,
                        ),
                        const SizedBox(width: 4),
                        // 显示 agent 信息
                        Flexible(
                          child: Text(
                            _getAgentDisplayText(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsTypography.caption.copyWith(
                              color: _hasValidAgent()
                                  ? theme.textSub
                                  : theme.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      DsIcon(
                        DsIconKind.chevronDown,
                        size: 14,
                        color: theme.textSub,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 顶栏操作按钮：工具Agent配置/工具模板/TTS/语音通话/更多菜单
  List<Widget> _buildAgentActions() {
    // 颜色在构建期解析（按钮挂到导航壳的 actions 槽位，不依赖渲染处主题祖树）
    final theme = DSThemeBridge.resolve(context);

    // 多选模式：复制/删除选中 + 退出
    if (_isMultiSelectMode) {
      return [
        DSIconButton(
          icon: DsIconKind.copy,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          onPressed: _copySelectedMessages,
          tooltip: '复制选中消息',
        ),
        DSIconButton(
          icon: DsIconKind.trash,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: theme.danger,
          onPressed: _deleteSelectedMessages,
          tooltip: '删除选中消息',
        ),
        DSIconButton(
          icon: DsIconKind.close,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          onPressed: _toggleMultiSelectMode,
          tooltip: '退出多选模式',
        ),
      ];
    }

    return [
      DSIconButton(
        icon: DsIconKind.gear,
        size: 36,
        color: theme.surfaceAlt,
        iconColor: theme.textSub,
        onPressed: _showToolAgentsConfig,
        tooltip: '工具调用 Agent',
      ),
      DSIconButton(
        icon: DsIconKind.clipboard,
        size: 36,
        color: theme.surfaceAlt,
        iconColor: theme.textSub,
        onPressed: _openToolTemplateManagement,
        tooltip: '工具模板',
      ),
      // 语音相关按钮（仅在设置了 Agent 时显示）
      if (_currentAgent != null) ...[
        DSIconButton(
          icon: DsIconKind.bell,
          size: 36,
          color: _autoReadEnabled ? theme.primary : theme.surfaceAlt,
          iconColor: _autoReadEnabled ? theme.onPrimary : theme.textSub,
          onPressed: _openTTSSettings,
          tooltip: '语音播报设置',
        ),
        DSIconButton(
          icon: DsIconKind.mic,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          onPressed: _openVoiceCall,
          tooltip: '语音通话',
        ),
      ],
      _buildMoreMenu(theme),
    ];
  }

  /// 顶栏更多操作气泡菜单
  Widget _buildMoreMenu(AppThemeData theme) {
    return DSPopover(
      width: 190,
      contentBuilder: (popoverContext, close) {
        final popoverTheme = DSThemeBridge.resolve(popoverContext);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppBarMenuAction(
              icon: DsIconKind.list,
              label: '多选模式',
              theme: popoverTheme,
              onTap: () {
                close();
                _toggleMultiSelectMode();
              },
            ),
            _AppBarMenuAction(
              icon: DsIconKind.gear,
              label: 'agent_chat_toolManagement'.tr,
              theme: popoverTheme,
              onTap: () {
                close();
                _openToolManagement();
              },
            ),
            _AppBarMenuAction(
              icon: DsIconKind.image,
              label: '朋友圈',
              theme: popoverTheme,
              onTap: () {
                close();
                _openMoments();
              },
            ),
            _AppBarMenuAction(
              icon: DsIconKind.sort,
              label: 'agent_chat_tokenStatistics'.tr,
              theme: popoverTheme,
              onTap: () {
                close();
                _showTokenStats();
              },
            ),
            _AppBarMenuAction(
              icon: DsIconKind.trash,
              label: 'agent_chat_confirmClear'.tr,
              theme: popoverTheme,
              danger: true,
              onTap: () {
                close();
                _showClearMessagesConfirm();
              },
            ),
            _AppBarMenuAction(
              icon: DsIconKind.gear,
              label: 'agent_chat_conversationSettings'.tr,
              theme: popoverTheme,
              onTap: () {
                close();
                _showSettings();
              },
            ),
          ],
        );
      },
      child: JellyBox(
        width: 36,
        height: 36,
        radius: theme.radii.md,
        color: theme.primary,
        child: Center(
          child: DsIcon(DsIconKind.more, size: 18, color: theme.onPrimary),
        ),
      ),
    );
  }
}

class _AppBarMenuAction extends StatelessWidget {
  const _AppBarMenuAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.danger = false,
  });

  final DsIconKind icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? theme.danger : theme.text;
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: pressed ? theme.surfaceAlt : null,
            borderRadius: theme.radii.sm,
          ),
          child: Row(
            children: [
              DsIcon(icon, size: 16, color: accent),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: DsTypography.caption.copyWith(color: accent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 配置模式选择行（单 Agent / Agent 链）
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  final DsIconKind icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final effective = accent ?? theme.text;
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.all(theme.spacing.md),
          decoration: BoxDecoration(
            color: pressed ? theme.surfaceAlt : null,
            borderRadius: theme.radii.lg,
            border: Border.all(color: theme.textSub.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              DsIcon(icon, size: 24, color: effective),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DsTypography.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ========== 前台服务回调 ==========

/// 语音通话前台服务启动回调
///
/// 必须是顶层函数，用于前台服务启动
@pragma('vm:entry-point')
void startVoiceCallTaskCallback() {
  FlutterForegroundTask.setTaskHandler(VoiceCallTaskHandler());
}
