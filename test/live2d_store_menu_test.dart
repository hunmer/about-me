import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 复现 live2d 主界面结构：nav actions 里 DSMenu（JellyBox 触发器），
/// 菜单项直接 push 新页面（Live2D 商店→在线模型页 / 宠物商店→宠物商店）。
/// 用户曾反馈真机点菜单项无反应，此测试锁住该交互链路。
void main() {
  for (final withSearchBar in [false, true]) {
    testWidgets(
      'DSMenu 菜单项可 push 新页面（搜索栏=$withSearchBar）',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DSThemeBridge(
              child: StatefulBuilder(
                builder: (context, setState) =>
                    SuperCupertinoNavigationWrapper(
                  title: const Text('T'),
                  largeTitle: 'T',
                  enableSearchBar: withSearchBar,
                  searchPlaceholder: 'search',
                  searchBody: withSearchBar
                      ? const Scaffold(body: Text('SEARCH'))
                      : null,
                  body: const Scaffold(body: Text('ARCHIVES')),
                  actions: [
                    DSThemeBridge(
                      child: Builder(
                        builder: (context) {
                          final theme = DSThemeBridge.resolve(context);
                          return DSMenu(
                            align: DSMenuAlign.end,
                            width: 190,
                            items: [
                              // 与真机同构：菜单项直接 push 新页面
                              DSMenuItem(
                                label: 'Live2D 商店',
                                icon: DsIconKind.store,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const Text('ONLINE_MODELS'),
                                  ),
                                ),
                              ),
                              DSMenuItem(
                                label: '宠物商店',
                                icon: DsIconKind.mood,
                                onTap: () {},
                              ),
                            ],
                            // 与真机同款 JellyBox 触发器（墨线描边质感）
                            child: JellyBox(
                              key: const ValueKey('menuTrigger'),
                              width: 36,
                              height: 36,
                              radius: theme.radii.circle,
                              color: theme.surfaceAlt,
                              raised: true,
                              alignment: Alignment.center,
                              child: DsIcon(
                                DsIconKind.store,
                                size: 20,
                                color: theme.textSub,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // 打开菜单并点击「Live2D 商店」菜单项 → 应 push 在线模型页
        await tester.tap(find.byKey(const ValueKey('menuTrigger')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Live2D 商店'));
        await tester.pumpAndSettle();

        expect(find.text('ONLINE_MODELS'), findsOneWidget);
      },
    );
  }
}
