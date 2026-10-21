import 'package:aboutme/core/js_bridge/plugin_tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('统一 query 按实体、多条件过滤后再分页', () async {
    final registry = PluginToolRegistry();
    registry.register('sample', {
      'getItems': (Map<String, dynamic> params) => [
        {'id': '1', 'name': '每日阅读', 'group': '学习'},
        {'id': '2', 'name': '每周阅读', 'group': '学习'},
        {'id': '3', 'name': '每日运动', 'group': '健康'},
      ],
      'getGroups': (Map<String, dynamic> params) => [
        {'id': 'g1', 'name': '学习'},
      ],
    });

    final result = await registry.invoke('sample', 'query', {
      'entity': 'groups',
      'field': 'name',
      'value': '学',
      'fuzzy': true,
      'offset': 0,
      'count': 1,
    });

    expect(result, {
      'data': [
        {'id': 'g1', 'name': '学习'},
      ],
      'total': 1,
      'offset': 0,
      'count': 1,
      'hasMore': false,
    });
  });

  test('统一 query 默认实体选择并执行 AND 条件', () async {
    final registry = PluginToolRegistry();
    registry.register('todo', {
      'getTasks': (Map<String, dynamic> params) => [
        {'id': '1', 'title': '阅读', 'status': 'done'},
        {'id': '2', 'title': '运动', 'status': 'done'},
        {'id': '3', 'title': '阅读', 'status': 'todo'},
      ],
    });

    final result = await registry.invoke('todo', 'query', {
      'title': '阅读',
      'status': 'done',
      'findAll': false,
    });

    expect(result, {'id': '1', 'title': '阅读', 'status': 'done'});
  });
}
