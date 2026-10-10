import 'package:flutter/material.dart';
import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/plugin_manager.dart';
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
    if (!mounted || _navigated || !AppStartupState.instance.pluginsReady) {
      return;
    }

    _navigated = true;
    final manager = PluginManager.instance;
    final lastId = manager.getLastOpenedPluginId;
    final lastPlugin = lastId == null ? null : manager.getPlugin(lastId);

    if (manager.autoOpenLastPlugin && lastPlugin != null) {
      debugPrint('[StartupGate] 直接恢复插件 ${lastPlugin.id}，跳过主页构建');
      manager.recordPluginOpen(lastPlugin);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: RouteSettings(name: '/plugin/${lastPlugin.id}'),
          builder: (_) => lastPlugin.buildMainView(context),
        ),
      );
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.jellyHome);
    }
  }

  @override
  void dispose() {
    AppStartupState.instance.removeListener(_onStartupChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
