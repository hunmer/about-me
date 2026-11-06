import 'package:flutter/material.dart';
import 'package:grok_icon_study/grok_icon_study.dart';
import 'package:get/get.dart' hide Value;

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/controllers/chat_controller.dart';
import 'package:aboutme/plugins/agent_chat/screens/conversation_list_screen/test_conversation_list_screen.dart';
import 'package:aboutme/plugins/personal_assistant/services/grok_bot_instance_service.dart';
import 'package:aboutme/plugins/personal_assistant/widgets/static_grok_avatar.dart';

/// 个人助手顶栏：标题 + grokbot 实例切换条（中部）+
/// 新增/删除实例按钮 + 最右侧 dots 菜单（测试/查看测试会话记录/完整聊天）；
/// 从 [PersonalAssistantScreen] 按功能拆出，仅做视图装配，
/// 状态与实例管理仍留在 Screen
class AssistantHeader extends StatelessWidget {
  const AssistantHeader({
    super.key,
    required this.theme,
    required this.scheme,
    required this.bots,
    required this.activeBotId,
    required this.controller,
    required this.sending,
    required this.questionTestOpen,
    required this.botStripController,
    required this.headerCharacters,
    required this.onSwitchBot,
    required this.onAddBot,
    required this.onRemoveBot,
    required this.onOpenQuestionTest,
    required this.onOpenFullChat,
  });

  final AppThemeData theme;
  final String scheme;

  /// grokbot 实例列表
  final List<GrokBotInstance> bots;

  /// 当前展示的实例 id
  final String? activeBotId;

  /// 当前活动实例的会话控制器（未加载完成时为 null）
  final ChatController? controller;

  /// 当前是否发送中
  final bool sending;

  /// 测试弹窗是否已打开（打开期间禁止再开新测试）
  final bool questionTestOpen;

  /// 顶栏图标横滚控制器（新增实例后滚到最右）
  final ScrollController botStripController;

  /// 顶栏切换条中各实例的独立小角色（多个视图不能共享一个 character）
  final Map<String, GrokCharacter> headerCharacters;

  /// 切换活动实例
  final ValueChanged<GrokBotInstance> onSwitchBot;

  /// 新增实例
  final VoidCallback onAddBot;

  /// 删除当前活动实例（首个实例不可删，Screen 侧拦截）
  final VoidCallback onRemoveBot;

  /// 打开「选择测试」弹窗
  final ValueChanged<ChatController> onOpenQuestionTest;

  /// 打开完整聊天页（顶栏菜单按钮）
  final ValueChanged<ChatController?> onOpenFullChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.lg,
        vertical: theme.spacing.sm,
      ),
      child: DSTopBar(
        // 中部展示 grokbot 实例切换条（title 仅保留语义/无障碍）
        title: 'screens_assistantTitle'.tr,
        center: _buildBotSwitcher(),
        actions: [
          _buildAddBotButton(),
          _buildRemoveBotButton(),
          // 最右侧固定：dots 菜单（测试/查看测试会话记录）
          _buildDotsMenu(context),
        ],
      ),
    );
  }

  /// 顶栏中部 grokbot 切换条：横滚图标列表，点击切换会话
  Widget _buildBotSwitcher() {
    if (bots.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      controller: botStripController,
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final bot in bots) _buildBotChip(bot)],
      ),
    );
  }

  /// 顶栏单个 grokbot 图标：34px 手绘圆框 + 28px 动态小角色，
  /// 活动实例以主题色描边加底
  Widget _buildBotChip(GrokBotInstance bot) {
    final active = bot.id == activeBotId;
    // 非活动图标静态化：N 个动态角色每帧全量自绘会拖低帧率，
    // 弹簧动画（转一圈等）因 dt 钳制被慢放；仅活动 bot 保留动态视图。
    Widget avatar;
    if (active) {
      final character = _headerCharacterFor(bot);
      // setColor 不触发重建，角色每帧自绘，可在 build 中安全同步明暗
      if (character.scheme != scheme) {
        character.setColor(bot.colorId, scheme);
      }
      avatar = GrokCharacterView(character: character, sizePx: 28);
    } else {
      avatar = StaticGrokAvatar(
        shapeId: bot.shapeId,
        colorId: bot.colorId,
        scheme: scheme,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: () => onSwitchBot(bot),
        child: Container(
          width: 34,
          height: 34,
          decoration: dsSketchDecoration(
            theme: theme,
            circle: true,
            fillColor: active ? theme.primary.withValues(alpha: 0.14) : null,
            stroke: active ? theme.primary : null,
            strokeWidth: active ? 2.2 : 1.6,
            seed: bot.id.hashCode,
          ),
          child: Padding(padding: const EdgeInsets.all(2), child: avatar),
        ),
      ),
    );
  }

  /// 顶栏小角色按实例 id 懒创建（多视图不能共享 character）
  GrokCharacter _headerCharacterFor(GrokBotInstance bot) {
    return headerCharacters.putIfAbsent(
      bot.id,
      () => GrokCharacter(
        mode: 'hold',
        state: 'idle',
        shapeName: bot.shapeId,
        colorId: bot.colorId,
      )..updateRenderWidth(30),
    );
  }

  /// 新增实例按钮：与顶栏图标钮同尺寸的手绘按压圆钮
  Widget _buildAddBotButton() {
    return Pressable(
      onPressed: onAddBot,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pressed
                ? theme.surfaceAlt
                : hovered
                ? theme.surfaceAlt.withValues(alpha: 0.6)
                : null,
          ),
          child: DsIcon(DsIconKind.plus, size: 20, color: theme.text),
        );
      },
    );
  }

  /// 删除当前实例按钮：首个实例固定保留（沿用聊天助手原会话），置灰禁用
  Widget _buildRemoveBotButton() {
    // 仅当活动实例存在且不是首个实例时可删
    final removable = bots.isNotEmpty && activeBotId != null
        ? activeBotId != bots.first.id
        : false;
    return Pressable(
      onPressed: removable ? onRemoveBot : null,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pressed
                ? theme.surfaceAlt
                : hovered && removable
                ? theme.surfaceAlt.withValues(alpha: 0.6)
                : null,
          ),
          child: DsIcon(
            DsIconKind.trash,
            size: 20,
            color: removable ? theme.text : theme.textSub,
          ),
        );
      },
    );
  }

  /// 最右侧 dots 菜单：弹出「测试/查看测试会话记录/完整聊天」下拉气泡
  Widget _buildDotsMenu(BuildContext context) {
    return DSPopover(
      width: 190,
      contentBuilder: (popoverContext, close) {
        final popoverTheme = DSThemeBridge.resolve(popoverContext);
        final chatController = controller;
        // 发送中/思考中/测试运行中不可开启新测试
        final testDisabled =
            chatController == null ||
            sending ||
            chatController.isThinking ||
            questionTestOpen;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TestMenuAction(
              icon: DsIconKind.science,
              label: '测试',
              theme: popoverTheme,
              enabled: !testDisabled,
              onTap: () {
                close();
                onOpenQuestionTest(chatController!);
              },
            ),
            _TestMenuAction(
              icon: DsIconKind.list,
              label: '查看测试会话记录',
              theme: popoverTheme,
              onTap: () {
                close();
                NavigationHelper.push(
                  context,
                  const TestConversationListScreen(),
                );
              },
            ),
            _TestMenuAction(
              icon: DsIconKind.chat,
              label: '完整聊天',
              theme: popoverTheme,
              onTap: () {
                close();
                onOpenFullChat(controller);
              },
            ),
          ],
        );
      },
      // DSPopover 接管点击，child 不能用会吞手势的按钮
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: DsIcon(DsIconKind.dots, size: 20, color: theme.text),
      ),
    );
  }
}

/// 测试弹出气泡的菜单项（结构与工具管理页 _ToolMenuAction 一致，支持禁用态）
class _TestMenuAction extends StatelessWidget {
  const _TestMenuAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.enabled = true,
  });

  final DsIconKind icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = enabled ? theme.text : theme.textSub;
    return Pressable(
      onPressed: enabled ? onTap : null,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: pressed && enabled ? theme.surfaceAlt : null,
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
