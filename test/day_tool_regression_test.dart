import 'dart:convert';
import 'dart:io';

import 'package:aboutme/plugins/day/day_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final configs = jsonDecode(
    File('lib/plugins/agent_chat/tools/day.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('day 工具描述方法名与 JS API 注册名一致', () {
    final methods = DayPlugin().defineJSAPI();
    // 描述文件（LLM 可见的 schema）与 defineJSAPI 注册（实际路由）名字
    // 不一致时，模型按 schema 调用必失败且按错误提示换名也被校验层拒绝
    for (final key in configs.keys) {
      expect(methods.containsKey(key), isTrue, reason: key);
    }
    for (final key in methods.keys) {
      expect(configs.containsKey(key), isTrue, reason: key);
    }
  });

  test('废弃旧命名不再出现在描述文件中', () {
    const obsolete = [
      'getMemorialDays',
      'createMemorialDay',
      'updateMemorialDay',
      'deleteMemorialDay',
      'getUpcomingDays',
      'findMemorialDayBy',
      'findMemorialDayById',
      'findMemorialDayByName',
    ];
    for (final method in obsolete) {
      expect(configs.containsKey(method), isFalse, reason: method);
      expect(configs.containsKey('day_$method'), isFalse, reason: method);
    }
  });
}
