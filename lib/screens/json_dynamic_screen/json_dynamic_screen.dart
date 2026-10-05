import 'dart:convert';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';

/// JSON 动态 UI 展示页面
///
/// 接收 json_dynamic_widget 格式的 JSON 并全屏渲染。
/// 由脚本通过 Aboutme.plugins.ui.showJsonScreen(json, {title}) 打开。
class JsonDynamicScreen extends StatefulWidget {
  /// 页面标题
  final String title;

  /// json_dynamic_widget 组件 JSON（顶层为 {type: ..., args: ...}）
  final Map<String, dynamic> widgetJson;

  const JsonDynamicScreen({
    super.key,
    required this.title,
    required this.widgetJson,
  });

  @override
  State<JsonDynamicScreen> createState() => _JsonDynamicScreenState();
}

class _JsonDynamicScreenState extends State<JsonDynamicScreen> {
  JsonWidgetData? _widgetData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _buildWidget();
  }

  void _buildWidget() {
    try {
      final data = JsonWidgetData.fromDynamic(
        widget.widgetJson,
        registry: JsonWidgetRegistry.instance,
      );
      setState(() {
        _widgetData = data;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'JSON 构建失败: $e\n\n${JsonEncoder.withIndent('  ').convert(widget.widgetJson)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _errorMessage != null
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Text(
                        '渲染失败',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          : _widgetData != null
              ? _widgetData!.build(context: context)
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
