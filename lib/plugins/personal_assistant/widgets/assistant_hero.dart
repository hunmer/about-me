import 'package:flutter/material.dart';
import 'package:grok_icon_study/grok_icon_study.dart';
import 'package:skribble/skribble.dart';
import 'package:get/get.dart' hide Value;

import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/controllers/chat_controller.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/marquee_button_list_card.dart';

/// 个人助手首页空态（无消息时）：176px 大角色（右上角外观设置入口）+
/// 状态徽章 + 问候语 + 灵感速记跑马灯入口；
/// 从 [PersonalAssistantScreen] 按功能拆出，仅做视图装配
class AssistantHero extends StatelessWidget {
  const AssistantHero({
    super.key,
    required this.theme,
    required this.controller,
    required this.heroCharacter,
    required this.onOpenStyleSheet,
  });

  final AppThemeData theme;
  final ChatController controller;

  /// 首页大角色（与消息流头像各自独立实例，避免宽度切换串扰）
  final GrokCharacter heroCharacter;

  /// 打开角色外观设置弹层（身形/墨色）
  final VoidCallback onOpenStyleSheet;

  @override
  Widget build(BuildContext context) {
    // 同头像：预置渲染宽度，避免挂载首帧几何错位
    heroCharacter.updateRenderWidth(176);
    return WiredDraw(
      // 视口最小高度撑满可用区：内容整体垂直居中，空间不足时仍可滚动
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.lg,
            vertical: theme.spacing.md,
          ),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: SizedBox(
                        width: 176,
                        height: 176,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: heroCharacter.bounceOnce,
                                child: GrokCharacterView(
                                  character: heroCharacter,
                                  sizePx: 176,
                                  pointerFollow: true,
                                ),
                              ),
                            ),
                            // 右上角外观设置入口（身形/墨色）
                            Positioned(
                              top: -2,
                              right: -2,
                              child: GestureDetector(
                                onTap: onOpenStyleSheet,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: dsSketchDecoration(
                                    theme: theme,
                                    fillColor: theme.surface,
                                    circle: true,
                                  ),
                                  child: Center(
                                    child: DsIcon(
                                      DsIconKind.gear,
                                      size: 15,
                                      color: theme.textSub,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(child: _buildBadge()),
                    const SizedBox(height: 16),
                    Text(
                      'screens_assistantGreeting'.tr,
                      style: DsTypography.heading.copyWith(color: theme.text),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'screens_assistantIdeas'.tr,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                    ),
                    MarqueeButtonListCardWidget(
                      inline: true,
                      rows: 3,
                      // 手绘风：纸底 + 主题文字，去柔影（design.md §9.3）
                      cardColor: theme.surface,
                      textColor: theme.text,
                      showShadow: false,
                      items:
                          [
                                (
                                  Icons.schedule,
                                  'screens_assistantIdeaTodo'.tr,
                                  theme.primary,
                                ),
                                (
                                  Icons.savings,
                                  'screens_assistantIdeaBill'.tr,
                                  theme.warning,
                                ),
                                (
                                  Icons.menu_book,
                                  'screens_assistantIdeaDiary'.tr,
                                  theme.success,
                                ),
                                (
                                  Icons.water_drop,
                                  'screens_assistantIdeaCheckin'.tr,
                                  theme.danger,
                                ),
                                (
                                  Icons.event,
                                  'screens_assistantIdeaEvent'.tr,
                                  theme.primary,
                                ),
                                (
                                  Icons.alarm,
                                  'screens_assistantIdeaTimer'.tr,
                                  theme.warning,
                                ),
                              ]
                              .map(
                                (e) => MarqueeButtonItemData(
                                  label: e.$2,
                                  icon: e.$1,
                                  color: e.$3,
                                  payload: e.$2,
                                ),
                              )
                              .toList(),
                      onItemTap: (item, _) =>
                          controller.setInputText(item.label),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 状态徽章：处理中/待机文案 + sparkle 图标
  Widget _buildBadge() {
    final working = controller.isSending;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        radius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIcon(
            DsIconKind.sparkle,
            size: 14,
            color: working ? theme.primary : theme.textSub,
          ),
          const SizedBox(width: 6),
          Text(
            working
                ? 'screens_assistantWorking'.tr
                : 'screens_assistantBadgeIdle'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ],
      ),
    );
  }
}
