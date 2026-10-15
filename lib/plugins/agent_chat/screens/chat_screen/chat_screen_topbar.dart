part of 'chat_screen.dart';

/// 顶栏：标题 / 操作按钮 / 更多菜单
extension _ChatScreenTopBarExt on _ChatScreenState {
  /// 获取 Agent 显示文本
  String _getAgentDisplayText() {
    if (_isChainMode) {
      final chainLength = _agentChain?.length ?? 0;
      if (chainLength == 0) return '配置 Agent 链';
      return '$chainLength 个 Agent 链';
    } else {
      return _currentAgent?.name ?? 'agent_chat_selectAgent'.tr;
    }
  }

  /// 检查是否有有效的 Agent
  bool _hasValidAgent() {
    if (_isChainMode) {
      return _agentChain != null && _agentChain!.isNotEmpty;
    } else {
      return _currentAgent != null;
    }
  }

  /// 顶栏标题：会话名 + Agent/输入中状态
  Widget _buildAgentTitle() {
    final isTyping =
        _controller.isSending ||
        _controller.isThinking ||
        _controller.alivenessFlushActive;

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return ConstrainedBox(
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
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 顶栏操作按钮：工具模板/TTS/语音通话/更多菜单
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
  });

  final DsIconKind icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = theme.text;
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

// ========== 前台服务回调 ==========

/// 语音通话前台服务启动回调
///
/// 必须是顶层函数，用于前台服务启动
@pragma('vm:entry-point')
void startVoiceCallTaskCallback() {
  FlutterForegroundTask.setTaskHandler(VoiceCallTaskHandler());
}
