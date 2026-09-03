// DSSwitch カチッ动画的独立预览入口（仅开发调试用，不入库核心代码）
// 运行：flutter run -d web-server --web-port=5599 -t tool/switch_preview.dart
import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';

void main() {
  runApp(const _SwitchPreviewApp());
}

class _SwitchPreviewApp extends StatefulWidget {
  const _SwitchPreviewApp();

  @override
  State<_SwitchPreviewApp> createState() => _SwitchPreviewAppState();
}

class _SwitchPreviewAppState extends State<_SwitchPreviewApp> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.light();
    return WidgetsApp(
      color: theme.primary,
      builder: (context, _) => AppTheme(
        data: theme,
        child: Container(
          color: theme.background,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 灰底参照块，检验越界绘制是否可见
                Container(
                  color: const Color(0x11000000),
                  child: DSSwitch(
                    value: _on,
                    onChanged: (v) => setState(() => _on = v),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _on ? 'ON' : 'OFF',
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
