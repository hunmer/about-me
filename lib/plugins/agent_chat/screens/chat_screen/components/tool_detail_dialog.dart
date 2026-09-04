import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/services/message_detail_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'markdown_content.dart';
import 'tool_call_steps.dart';
import 'package:aboutme/core/services/toast_service.dart';

/// 工具调用详情对话框
///
/// 展示工具调用消息的完整详细信息，包括：
/// - 用户输入
/// - 思考过程
/// - 工具调用详情
/// - AI最终回复
class ToolDetailDialog extends StatefulWidget {
  final MessageDetail detail;
  final List<ToolCallStep>? toolCallSteps;

  const ToolDetailDialog({super.key, required this.detail, this.toolCallSteps});

  @override
  State<ToolDetailDialog> createState() => _ToolDetailDialogState();
}

class _ToolDetailDialogState extends State<ToolDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return JellyBox(
      radius: theme.radii.xxl,
      width: MediaQuery.of(context).size.width * 0.85,
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 标题栏
          Row(
            children: [
              DsIcon(DsIconKind.info, color: theme.primaryText),
              const SizedBox(width: 8),
              Text(
                '工具调用详情',
                style: DsTypography.title.copyWith(color: theme.text),
              ),
              const Spacer(),
              Pressable(
                onPressed: () => Navigator.of(context).pop(),
                semanticLabel: '关闭',
                builder:
                    (context, states) => Padding(
                      padding: const EdgeInsets.all(6),
                      child: DsIcon(
                        DsIconKind.close,
                        size: 20,
                        color: theme.textSub,
                      ),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tab栏（TabBar/TabBarView 结构性组件刻意保留 Material，配色令牌化）
          Container(
            decoration: BoxDecoration(
              color: theme.surfaceAlt,
              borderRadius: theme.radii.sm,
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: theme.primaryText,
              unselectedLabelColor: theme.textSub,
              indicator: BoxDecoration(
                color: theme.surface,
                borderRadius: theme.radii.sm,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              tabs: const [
                Tab(text: 'AI输入'),
                Tab(text: '思考过程'),
                Tab(text: '工具调用'),
                Tab(text: '最终回复'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserPromptTab(),
                _buildThinkingTab(),
                _buildToolCallTab(),
                _buildFinalReplyTab(),
              ],
            ),
          ),

          // 底部按钮
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DSButton(
                label: 'agent_chat_close'.tr,
                variant: DSButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// AI输入Tab
  Widget _buildUserPromptTab() {
    return _buildContentTab(
      content: widget.detail.userPrompt,
      icon: DsIconKind.send,
      emptyText: '无AI输入数据',
    );
  }

  /// 思考过程Tab
  Widget _buildThinkingTab() {
    return _buildContentTab(
      content: widget.detail.thinkingProcess,
      icon: DsIconKind.bot,
      emptyText: '无思考过程',
    );
  }

  /// 工具调用Tab
  Widget _buildToolCallTab() {
    if (widget.toolCallSteps == null || widget.toolCallSteps!.isEmpty) {
      return _buildEmptyState(DsIconKind.gear, '无工具调用');
    }

    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.surfaceAlt.withValues(alpha: 0.5),
            borderRadius: theme.radii.sm,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 复制按钮
                Align(
                  alignment: Alignment.topRight,
                  child: Pressable(
                    onPressed:
                        () => _copyToClipboard(
                          widget.detail.toolCallData.toString(),
                          '工具调用数据',
                        ),
                    semanticLabel: '复制工具调用数据',
                    builder:
                        (context, states) => Padding(
                          padding: const EdgeInsets.all(8),
                          child: DsIcon(
                            DsIconKind.copy,
                            size: 18,
                            color: theme.textSub,
                          ),
                        ),
                  ),
                ),
                // 工具调用步骤
                ToolCallSteps(
                  steps: widget.toolCallSteps!,
                  isGenerating: false,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 最终回复Tab
  Widget _buildFinalReplyTab() {
    return _buildContentTab(
      content: widget.detail.finalReply,
      icon: DsIconKind.chat,
      emptyText: '无最终回复',
    );
  }

  /// 通用内容Tab构建器
  Widget _buildContentTab({
    required String content,
    required DsIconKind icon,
    required String emptyText,
  }) {
    if (content.trim().isEmpty) {
      return _buildEmptyState(icon, emptyText);
    }

    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.surfaceAlt.withValues(alpha: 0.5),
            borderRadius: theme.radii.sm,
          ),
          child: Column(
            children: [
              // 复制按钮
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Pressable(
                    onPressed: () => _copyToClipboard(content, '内容'),
                    semanticLabel: '复制内容',
                    builder:
                        (context, states) => DsIcon(
                          DsIconKind.copy,
                          size: 18,
                          color: theme.textSub,
                        ),
                  ),
                ),
              ),
              // 内容
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: MarkdownContent(content: content),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 空状态展示
  Widget _buildEmptyState(DsIconKind icon, String text) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DsIcon(icon, size: 48, color: theme.textSub),
              const SizedBox(height: 16),
              Text(
                text,
                style: DsTypography.heading.copyWith(color: theme.textSub),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 复制到剪贴板
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    toastService.showToast('$label已复制到剪贴板');
  }
}
