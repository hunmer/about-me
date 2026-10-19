import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'jelly_live2d_panel.dart';

/// 果冻小屋主导航的五个页签
enum JellyTab { cottage, assistant, schedule, board, mine }

/// 果冻小屋底部导航（小屋 / 聊天助手 / 日程 / 看板 / 我的）
///
/// 漂浮式：[child]（页面内容）铺满全屏并延伸到导航栏下方，
/// 导航栏悬浮在内容之上，不占用布局高度。点击页签通过 [onTap]
/// 通知宿主切换内容，不涉及路由跳转。
///
/// 通过 Scaffold.extendBody 把导航栏高度注入 body 的
/// MediaQuery.padding.bottom，页内 SafeArea、网格滚动区等内容
/// 可读取该内边距避让导航栏；同时同步到 viewPadding.bottom，
/// 让页内悬浮 FAB（按 viewPadding 定位）也上浮避让。
class JellyBottomNav extends StatelessWidget {
  const JellyBottomNav({
    super.key,
    required this.current,
    required this.child,
    this.onTap,
    this.onToggleChat,
    this.chatActive = false,
    this.live2dPanel,
  });

  /// 当前所在页签
  final JellyTab current;

  /// 沉在导航栏下方的页面内容（铺满全屏）
  final Widget child;

  final ValueChanged<int>? onTap;

  /// 切换小屋 Live2D 聊天表单显示（仅小屋页签显示该按钮）
  final VoidCallback? onToggleChat;

  /// 聊天表单当前是否显示（按钮高亮态）
  final bool chatActive;

  /// Live2D 底部资源面板开关（仅小屋页签显示对应的子栏图标）
  final ValueNotifier<JellyLive2dPanel?>? live2dPanel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: _buildBar(context),
      body: Builder(
        builder: (context) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              viewPadding: mq.viewPadding.copyWith(
                bottom: mq.padding.bottom,
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    final theme = AppTheme.of(context);

    Widget buildNavigation(JellyLive2dPanel? activePanel) {
      return DSBottomNavigation(
        items: const [
          DSNavItem(icon: DsIconKind.home, label: '小屋'),
          DSNavItem(icon: DsIconKind.bot, label: '聊天助手'),
          DSNavItem(icon: DsIconKind.calendar, label: '日程'),
          DSNavItem(icon: DsIconKind.grid, label: '看板'),
          DSNavItem(icon: DsIconKind.user, label: '我的', showBadge: true),
        ],
        currentIndex: current.index,
        onTap: onTap,
        // 子栏元素常驻（不随页签增删），由 subBarVisible 控制显隐：
        // 显隐切换经弹簧折叠动画过渡，画布全高恒定不跳动。
        // 子栏仅小屋页签可见（其它页签没有可切换的聊天表单/面板）
        subBarBehavior: RadialSubBarBehavior.always,
        subBarVisible: current == JellyTab.cottage,
        // 子栏左侧：切换 Live2D 聊天表单
        leadingAction:
            onToggleChat != null
                ? Builder(
                  builder: (context) {
                    final navTheme = AppTheme.of(context);
                    return DsIcon(
                      DsIconKind.chat,
                      size: 16,
                      color: chatActive
                          ? navTheme.primary
                          : navTheme.textSub,
                    );
                  },
                )
                : null,
        onLeadingTap: onToggleChat,
        // 子栏最右侧：切换 Live2D 档案（与面板同款 激活高亮/再点收起）
        trailingAction:
            live2dPanel != null
                ? DsIcon(
                    DsIconKind.switchAccount,
                    size: 16,
                    color:
                        activePanel == JellyLive2dPanel.archive
                            ? theme.onPrimary
                            : theme.textSub,
                  )
                : null,
        onTrailingTap:
            live2dPanel != null
                ? () => _toggleLive2dPanel(live2dPanel!, JellyLive2dPanel.archive)
                : null,
        trailingSelected: activePanel == JellyLive2dPanel.archive,
        // 小屋子栏：气泡/背景/状态面板资源入口，
        // 激活（面板打开）时圆钮以主题色实底高亮
        subActions:
            live2dPanel != null
                ? [
                  _live2dPanelAction(
                    live2dPanel!,
                    JellyLive2dPanel.bubble,
                    '气泡样式',
                    DsIconKind.bubble,
                    activePanel,
                    theme,
                  ),
                  _live2dPanelAction(
                    live2dPanel!,
                    JellyLive2dPanel.background,
                    '背景图片',
                    DsIconKind.image,
                    activePanel,
                    theme,
                  ),
                ]
                : null,
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          theme.spacing.lg,
          theme.spacing.sm,
          theme.spacing.lg,
          theme.spacing.lg,
        ),
        // 面板开关变化时重建子栏图标的激活态。
        // 结构需恒定（仅按构造期固定的 live2dPanel 判空）：
        // 若随页签切换在 ValueListenableBuilder 与裸 DSBottomNavigation
        // 之间切换，子树会被整体卸载重建，子栏折叠的弹簧 State 丢失，
        // 显隐只剩瞬时跳变
        child: live2dPanel != null
            ? ValueListenableBuilder<JellyLive2dPanel?>(
                valueListenable: live2dPanel!,
                builder: (context, activePanel, _) =>
                    buildNavigation(activePanel),
              )
            : buildNavigation(null),
      ),
    );
  }

  /// 切换资源面板：再次点击同面板收起；打开面板时收起聊天表单
  /// （两者都悬浮在页面底部）
  void _toggleLive2dPanel(
    ValueNotifier<JellyLive2dPanel?> panel,
    JellyLive2dPanel value,
  ) {
    if (panel.value != value && chatActive) onToggleChat?.call();
    panel.value = panel.value == value ? null : value;
  }

  /// 子栏资源面板图标：点按在 打开/收起 间切换（再次点击同图标收起）
  RadialSubAction _live2dPanelAction(
    ValueNotifier<JellyLive2dPanel?> panel,
    JellyLive2dPanel value,
    String label,
    DsIconKind icon,
    JellyLive2dPanel? active,
    AppThemeData theme,
  ) {
    final selected = active == value;
    return RadialSubAction(
      label: label,
      selected: selected,
      icon: DsIcon(
        icon,
        size: 16,
        color: selected ? theme.onPrimary : theme.textSub,
      ),
      onTap: () => _toggleLive2dPanel(panel, value),
    );
  }
}
