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

class _StartupGateState extends State<StartupGate> with RouteAware {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    AppStartupState.instance.addListener(_onStartupChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeWhenReady());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      RouteHistoryManager.instance.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // 插件切换会移除最初恢复的插件页，返回兜底必须由栈底启动页负责。
    // 延迟一帧，让 smartBack 等返回逻辑先完成，避免重复创建首页。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      _navigated = true;
      Navigator.of(context).pushReplacementNamed(AppRoutes.jellyHome);
    });
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
      // 返回完成后由 didPopNext 把启动闸门替换为主页。
      manager.recordPluginOpen(lastPlugin);
      NavigationHelper.push(
        context,
        lastPlugin.buildMainView(context),
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
    RouteHistoryManager.instance.unsubscribe(this);
    AppStartupState.instance.removeListener(_onStartupChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const AppSplash();
}
