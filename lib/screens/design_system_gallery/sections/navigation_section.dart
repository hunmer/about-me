import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

import 'gallery_section.dart';

/// 07 导航
class NavigationSection extends StatefulWidget {
  const NavigationSection({super.key});

  @override
  State<NavigationSection> createState() => _NavigationSectionState();
}

class _NavigationSectionState extends State<NavigationSection> {
  int _navIndex = 0;
  int _pageIndex = 1;
  final _listController = ScrollController();

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  static const _navItems = [
    DSNavItem(icon: DsIconKind.home, label: '小屋'),
    DSNavItem(icon: DsIconKind.calendar, label: '日历'),
    DSNavItem(icon: DsIconKind.chat, label: '对话'),
    DSNavItem(icon: DsIconKind.store, label: '商店', showBadge: true),
    DSNavItem(icon: DsIconKind.user, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SectionCard(
      index: '07',
      title: '导航',
      children: [
        const DemoSubHeader('底部导航栏（Bottom Navigation）'),
        DSBottomNavigation(
          items: _navItems,
          currentIndex: _navIndex,
          onTap: (i) => setState(() => _navIndex = i),
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('顶部导航栏（Top Bar）'),
        DSTopBar(title: '我的小屋'),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('页面指示器（Page Indicator，点击切换）'),
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _pageIndex = (_pageIndex + 1) % 4),
            child: DSPageIndicator(count: 4, index: _pageIndex),
          ),
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('回到顶部（滚动下方列表）'),
        SizedBox(
          height: 200,
          child: DsBackTop(
            controller: _listController,
            child: ListView.builder(
              controller: _listController,
              itemCount: 40,
              itemBuilder:
                  (context, i) => DSListItem(
                    title: '列表项 ${i + 1}',
                    subtitle: '滚过 400px 后右下角出现回顶浮钮',
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
