import 'package:flutter/material.dart';
import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/startup_trace.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/app_bootstrap.dart';
import 'package:aboutme/screens/route.dart';

/// 启动分流页：插件恢复前不创建主页，避免先初始化 Live2D 再跳转。
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    AppStartupState.instance.addListener(_onStartupChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeWhenReady());
  }

  void _onStartupChanged() => _routeWhenReady();

  void _routeWhenReady() {
    if (!mounted ||
        _navigated ||
        !AppStartupState.instance.criticalPluginsReady ||
        AppStartupState.instance.isHandlingInitialUri) {
      return;
    }

    _navigated = true;
    StartupTrace.mark('startup_route_ready');
    final manager = PluginManager.instance;
    final lastId = manager.getLastOpenedPluginId;
    final lastPlugin = lastId == null ? null : manager.getPlugin(lastId);

    if (manager.autoOpenLastPlugin && lastPlugin != null) {
      debugPrint('[StartupGate] 直接恢复插件 ${lastPlugin.id}，跳过主页构建');
      // 保留 StartupGate 作为底层路由，让插件页具备系统左滑返回的栈条件。
      // 返回完成后再把启动闸门替换为主页，避免重新触发插件恢复。
      manager.recordPluginOpen(lastPlugin);
      final navigator = Navigator.of(context);
      NavigationHelper.push(
        context,
        _RestoredPluginPage(
          page: lastPlugin.buildMainView(context),
          onPopped: () {
            // smartBack() 也可能在 pop 后负责切换主页；延迟一帧并检查
            // 当前路由，避免两条返回路径重复推入主页。
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (RouteHistoryManager.getCurrentContext()?.pageId ==
                  '/startup') {
                navigator.pushReplacementNamed(AppRoutes.jellyHome);
              }
            });
          },
        ),
        routeName: '/plugin/${lastPlugin.id}',
      );
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.jellyHome);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupTrace.mark('destination_frame');
    });
  }

  @override
  void dispose() {
    AppStartupState.instance.removeListener(_onStartupChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const AppSplash();
}

/// 启动时恢复的插件页：系统左滑完成 pop 后，将底层启动闸门切换为主页。
class _RestoredPluginPage extends StatelessWidget {
  const _RestoredPluginPage({required this.page, required this.onPopped});

  final Widget page;
  final VoidCallback onPopped;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) onPopped();
      },
      child: page,
    );
  }
}
