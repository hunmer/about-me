import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/lazy_indexed_stack.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 复现 live2d 主界面结构：nav actions 里 DSMenu（JellyBox 触发器）
/// 菜单项切换底部 LazyIndexedStack tab。
/// 用户曾反馈真机点「Live2D 商店」无反应，此测试锁住该交互链路。
void main() {
  for (final withSearchBar in [false, true]) {
    testWidgets(
      'DSMenu 菜单项可切换 LazyIndexedStack tab（搜索栏=$withSearchBar）',
      (tester) async {
        var tab = 0;
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
                  searchBody: withSearchBar ? _buildBody(tab) : null,
                  body: _buildBody(tab),
                  actions: [
                    DSThemeBridge(
                      child: Builder(
                        builder: (context) {
                          final theme = DSThemeBridge.resolve(context);
                          return DSMenu(
                            align: DSMenuAlign.end,
                            width: 190,
                            items: [
                              DSMenuItem(
                                label: 'Live2D 商店',
                                icon: DsIconKind.store,
                                trailing: tab == 1 ? '✓' : null,
                                onTap: () => setState(() => tab = 1),
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

        // 打开菜单并点击「Live2D 商店」菜单项
        await tester.tap(find.byKey(const ValueKey('menuTrigger')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Live2D 商店'));
        await tester.pumpAndSettle();

        expect(tab, 1);
        expect(find.byKey(const ValueKey('store')), findsOneWidget);
        expect(find.byKey(const ValueKey('archives')), findsNothing);
      },
    );
  }
}

Widget _buildBody(int tab) => LazyIndexedStack(
  index: tab,
  children: const [
    Text('ARCHIVES', key: ValueKey('archives')),
    Text('STORE', key: ValueKey('store')),
  ],
);
