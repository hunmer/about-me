import 'package:flutter/material.dart';

/// 启动期统一品牌壳：AppBootstrap 初始化期与 StartupGate 等待插件期间共用，
/// 避免冷启动先后出现两种样式的 loading。
class AppSplash extends StatelessWidget {
  const AppSplash({super.key, this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFFFFF8F2),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Aboutme',
                style: TextStyle(
                  color: Color(0xFF72594D),
                  fontSize: 28,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 24),
              if (failed)
                const Text(
                  '启动失败，请重启应用',
                  style: TextStyle(
                    color: Color(0xFF72594D),
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                )
              else
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFF72594D),
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 先绘制不依赖存储、翻译或插件的启动界面，再开始初始化。
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    required this.initialize,
    required this.builder,
  });

  final Future<void> Function() initialize;
  final WidgetBuilder builder;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    try {
      await widget.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'app bootstrap',
        ),
      );
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.builder(context);
    return AppSplash(failed: _failed);
  }
}
