import 'package:aboutme/core/data_filter/field_filter_service.dart';

/// JS API 与 Agent Tool 共用的 Dart 回调，无需初始化 JavaScript 引擎。
class PluginToolRegistry {
  final Map<String, Map<String, Function>> _handlers = {};

  void register(String pluginId, Map<String, Function> handlers) {
    (_handlers[pluginId] ??= {}).addAll(handlers);
  }

  void clear() => _handlers.clear();

  Future<dynamic> invoke(
    String pluginId,
    String method,
    Map<String, dynamic> args,
  ) async {
    var handler = _handlers[pluginId]?[method];
    if (handler == null) {
      final matches = _handlers.values
          .where((methods) => methods.containsKey(method))
          .toList();
      if (matches.length != 1) {
        throw StateError(
          '插件接口不存在或路由不唯一：$pluginId.$method；'
          '该插件已注册方法：${_handlers[pluginId]?.keys.join(',') ?? '未注册'}；'
          '同名候选数：${matches.length}',
        );
      }
      handler = matches.single[method]!;
    }
    final original = Map<String, dynamic>.from(args);
    final result = await Function.apply(handler, [
      FieldFilterService.cleanParams(Map<String, dynamic>.from(args)),
    ]);
    return FieldFilterService.filterFromParams(result, original);
  }
}
