import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/core/widgets/custom_bottom_bar.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_folder_item.dart';
import 'package:aboutme/screens/home_screen/widgets/home_card.dart';
import 'package:aboutme/screens/home_screen/widgets/home_grid.dart';

/// CustomBottomBar 冒烟载体:TabController + DS 导航 + TabBarView
class _BottomBarHarness extends StatefulWidget {
  const _BottomBarHarness();

  @override
  State<_BottomBarHarness> createState() => _BottomBarHarnessState();
}

class _BottomBarHarnessState extends State<_BottomBarHarness>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomBottomBar(
      items: const [
        DSNavItem(icon: DsIconKind.check, label: '待办'),
        DSNavItem(icon: DsIconKind.clock, label: '历史'),
      ],
      currentIndex: _tabController.index,
      tabController: _tabController,
      body:
          (context, controller) => TabBarView(
            controller: _tabController,
            children: const [
              Center(child: Text('page0')),
              Center(child: Text('page1')),
            ],
          ),
    );
  }
}

void main() {
  HomeFolderItem makeFolder() => HomeFolderItem(
    id: 'f',
    name: 'folder',
    icon: Icons.folder,
    color: const Color(0xFF885CF6),
  );

  // 验证 DSThemeBridge 在普通 Material 页面中让 DS 组件可读取主题，
  // 以及 HomeGrid 各渲染路径（空态/骨架/普通卡片）不因缺少 AppTheme 崩溃。
  group('DSThemeBridge + DS 组件冒烟', () {
    testWidgets('桥接后 DS 组件可读取 AppTheme 令牌', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: DSThemeBridge(child: const DSButton(label: '测试'))),
      );
      await tester.pump();
      expect(find.text('测试'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HomeGrid 空状态不崩溃', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeGrid(items: [makeFolder()])),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('HomeGrid 骨架屏不崩溃', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 800,
            child: HomeGrid(items: [makeFolder()], showSkeleton: true),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('暗色模式下桥接到 AppThemeData.dark', (tester) async {
      AppThemeData? captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: DSThemeBridge(
            child: Builder(
              builder: (context) {
                captured = AppTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(captured?.isDark, isTrue);
    });

    // 回归：第三方导航栏（SuperAppBar）会把 actions 经 Overlay/Hero flight
    // 重建到页面主题树之外，DS 按钮必须自带 DSThemeBridge 才能取到主题
    testWidgets('自带桥的 DSIconButton 挂到 Overlay 不崩溃', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      final overlay = Overlay.of(tester.element(find.byType(Scaffold)));
      overlay.insert(
        OverlayEntry(
          builder:
              (_) => const Align(
                alignment: Alignment.topRight,
                child: DSThemeBridge(
                  child: DSIconButton(icon: DsIconKind.grid, size: 36),
                ),
              ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    // 表单/对话框迁移：showDSDialog 支持显式传 theme，
    // 独立路由（无 AppTheme 祖先）的调用点用 DSThemeBridge.resolve 解析
    testWidgets('showDSDialog 在无 AppTheme 调用点传 theme 不崩溃', (tester) async {
      bool confirmed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DSThemeBridge(
              child: Builder(
                builder:
                    (context) => Center(
                      child: DSButton(
                        label: 'open',
                        onPressed:
                            () => showDSDialog(
                              context: context,
                              theme: DSThemeBridge.resolve(context),
                              builder:
                                  (_) => DSDialog(
                                    title: '确认删除',
                                    message: '此操作不可撤销',
                                    confirmText: '删除',
                                    cancelText: '取消',
                                    confirmVariant: DSButtonVariant.destructive,
                                    onConfirm: () {
                                      confirmed = true;
                                      Navigator.of(context).pop();
                                    },
                                  ),
                            ),
                      ),
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('删除'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });

    // 注：不能在同一测试内连续 pumpWidget 替换根 MaterialApp 来切换明暗
    // （测试框架原地更新时不会应用新的 themeMode），故拆成两个独立用例
    testWidgets('DSThemeBridge.resolve 亮色模式解析', (tester) async {
      AppThemeData? light;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () => light = DSThemeBridge.resolve(context),
                  child: const Text('light'),
                ),
          ),
        ),
      );
      await tester.tap(find.text('light'));
      await tester.pump();
      expect(light?.isDark, isFalse);
    });

    testWidgets('DSThemeBridge.resolve 暗色模式解析', (tester) async {
      AppThemeData? dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () => dark = DSThemeBridge.resolve(context),
                  child: const Text('dark'),
                ),
          ),
        ),
      );
      await tester.tap(find.text('dark'));
      await tester.pump();
      expect(dark?.isDark, isTrue);
    });

    testWidgets('HomeGrid 渲染文件夹卡片（含批量选中态）不崩溃', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 800,
            child: HomeGrid(
              items: [makeFolder()],
              isBatchMode: true,
              selectedItemIds: const {'f'},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      // 选中态勾选圆内的对勾图标（CustomPaint，验证存在画布）
      expect(find.byType(HomeCard), findsOneWidget);
    });

    // CustomBottomBar 骨架替换回归:外壳(floating bottom bar)+ DSBottomNavigation
    // 在无 DSThemeBridge 宿主下渲染、点按切页都不崩溃(外壳根部自包桥)
    testWidgets('CustomBottomBar DS 导航渲染与切页不崩溃', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _BottomBarHarness()));
      // 入场有 300ms 浮动条动画,先等动画完成再断言/点按
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(DSBottomNavigation), findsOneWidget);
      expect(find.text('待办'), findsOneWidget);
      expect(find.text('历史'), findsOneWidget);

      await tester.tap(find.text('历史'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('page1'), findsOneWidget);
    });

    // 自绘图标回归：每个 DsIconKind 的画布绘制都不抛错
    testWidgets('全部自绘图标渲染不崩溃', (tester) async {
      const kinds = [
        DsIconKind.check,
        DsIconKind.minus,
        DsIconKind.plus,
        DsIconKind.close,
        DsIconKind.heart,
        DsIconKind.gear,
        DsIconKind.search,
        DsIconKind.chevronLeft,
        DsIconKind.chevronRight,
        DsIconKind.chevronDown,
        DsIconKind.chevronUp,
        DsIconKind.star,
        DsIconKind.bell,
        DsIconKind.home,
        DsIconKind.chat,
        DsIconKind.store,
        DsIconKind.user,
        DsIconKind.calendar,
        DsIconKind.trash,
        DsIconKind.share,
        DsIconKind.download,
        DsIconKind.more,
        DsIconKind.moon,
        DsIconKind.sun,
        DsIconKind.book,
        DsIconKind.calendarCheck,
        DsIconKind.piggy,
        DsIconKind.gift,
        DsIconKind.drop,
        DsIconKind.clipboard,
        DsIconKind.sprout,
        DsIconKind.cart,
        DsIconKind.drag,
        DsIconKind.layers,
        DsIconKind.block,
        DsIconKind.edit,
        DsIconKind.tag,
        DsIconKind.clock,
        DsIconKind.refresh,
        DsIconKind.sort,
        DsIconKind.hash,
        DsIconKind.grid,
        DsIconKind.list,
        DsIconKind.video,
        DsIconKind.columns,
        DsIconKind.rows,
        DsIconKind.image,
        DsIconKind.palette,
        DsIconKind.info,
        DsIconKind.copy,
        DsIconKind.send,
        DsIconKind.mic,
        DsIconKind.bot,
        DsIconKind.camera,
        DsIconKind.pin,
        DsIconKind.reply,
        DsIconKind.stop,
        DsIconKind.play,
        DsIconKind.pause,
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: DSThemeBridge(
            child: Wrap(
              children: [
                for (final kind in kinds)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: DsIcon(kind, size: 24),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(DsIcon), findsNWidgets(kinds.length));
    });
  });
}
