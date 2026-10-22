import 'dart:convert';
import 'dart:io';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:aboutme/plugins/bill/bill_plugin.dart';
import 'package:aboutme/plugins/bill/screens/account_edit_screen.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/tool_call_steps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TemporaryPaths extends PathProviderPlatform {
  _TemporaryPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _TemporaryStorage implements StorageInterface {
  _TemporaryStorage(this.directory);
  final Directory directory;

  Future<File> _file(String key) async {
    final file = File('${directory.path}/$key');
    await file.parent.create(recursive: true);
    return file;
  }

  @override
  Future<String> readString(String path) async {
    final file = await _file(path);
    return await file.exists() ? file.readAsString() : '';
  }

  @override
  Future<void> writeString(String path, String value) async =>
      (await _file(path)).writeAsString(value);

  @override
  Future<void> saveData(String path, String value) => writeString(path, value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late BillPlugin plugin;
  late PathProviderPlatform originalPaths;

  Future<Map<String, dynamic>> invoke(
    String method,
    Map<String, dynamic> args,
  ) async {
    final result = await JSBridgeManager.instance.pluginTools.invoke(
      'bill',
      method,
      args,
    );
    return jsonDecode(result as String) as Map<String, dynamic>;
  }

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('aboutme-bill-tools-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TemporaryPaths(temporary.path);
    SharedPreferences.setMockInitialValues({});
    globalStorage = StorageManager(storage: _TemporaryStorage(temporary));
    await AboutmeDataService.instance.initialize();
    await PluginManager.instance.setStorageManager(globalStorage);
    plugin = BillPlugin();
    await PluginManager.instance.registerPlugin(plugin);
  });

  tearDownAll(() async {
    plugin.controller.dispose();
    plugin.dispose();
    PathProviderPlatform.instance = originalPaths;
    await temporary.delete(recursive: true);
  });

  test('按 schema 参数名(title/iconCodePoint/backgroundColor)创建账户', () async {
    // 复现测试报告 42c352d3 中失败的参数
    final result = await invoke('createAccount', {
      'title': '支付宝',
      'iconCodePoint': 8997,
      'backgroundColor': 4288425,
    });
    expect(result['error'], isNull, reason: jsonEncode(result));
    expect(result['name'], '支付宝');
    expect(result['color'], '4288425');

    // 清理，避免影响后续用例的账户选择
    expect((await invoke('deleteAccount', {'accountId': result['id']}))['success'], isTrue);
  });

  testWidgets('点击创建账户步骤打开已有账户表单，失败结果不显示入口', (tester) async {
    late Map<String, dynamic> created;
    await tester.runAsync(() async {
      created = await invoke('createAccount', {'title': '弹层回归账户'});
    });
    final step = ToolCallStep(
      method: 'plugin_tool',
      title: '创建账户',
      desc: '创建失败或暂不支持详情',
      data: jsonEncode({'pluginId': 'bill', 'method': 'createAccount', 'args': {}}),
      status: ToolCallStatus.success,
      result: jsonEncode(created),
    );
    Future<void> pumpStep() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DSThemeBridge(child: ToolCallSteps(steps: [step]))),
      ),
    );
    await pumpStep();
    await tester.tap(find.text('agent_chat_viewCreatedDetail'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountEditScreen), findsOneWidget);
    expect(find.text('弹层回归账户'), findsOneWidget);
    Navigator.of(tester.element(find.byType(AccountEditScreen))).pop();
    await tester.pumpAndSettle();

    for (final result in [
      {'success': false, 'id': created['id']},
      {'error': '创建失败', 'id': created['id']},
    ]) {
      step.result = jsonEncode(result);
      await pumpStep();
      expect(find.text('agent_chat_viewCreatedDetail'), findsNothing);
    }
    step.result = jsonEncode(created);
    step.status = ToolCallStatus.failed;
    await pumpStep();
    expect(find.text('agent_chat_viewCreatedDetail'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await invoke('deleteAccount', {'accountId': created['id']});
    });
  });

  test('UseCase 原生参数名(name)同样可用', () async {
    final result = await invoke('createAccount', {'name': '微信钱包'});
    expect(result['error'], isNull);
    expect(result['name'], '微信钱包');
    expect(
      (await invoke('deleteAccount', {'accountId': result['id']}))['success'],
      isTrue,
    );
  });

  test('updateAccount/deleteAccount 接受 accountId+title', () async {
    final created = await invoke('createAccount', {'title': '储蓄卡'});
    expect(created['error'], isNull);

    final updated = await invoke('updateAccount', {
      'accountId': created['id'],
      'title': '储蓄卡-常用',
    });
    expect(updated['error'], isNull, reason: jsonEncode(updated));
    expect(updated['name'], '储蓄卡-常用');

    final deleted = await invoke('deleteAccount', {'accountId': created['id']});
    expect(deleted['success'], isTrue);
    expect(deleted['accountId'], created['id']);
  });

  test('updateBill/deleteBill 接受 billId，note 映射到 description', () async {
    final created = await invoke('createAccount', {'title': '回归账户'});
    expect(created['error'], isNull);

    final bill = await invoke('createBill', {
      'accountId': created['id'],
      'type': 'expense',
      'amount': -50,
      'category': '餐饮',
      'description': '午餐',
    });
    expect(bill['error'], isNull, reason: jsonEncode(bill));

    final updated = await invoke('updateBill', {
      'billId': bill['id'],
      'note': '午餐-加购',
    });
    expect(updated['error'], isNull, reason: jsonEncode(updated));
    expect(updated['description'], '午餐-加购');

    final deleted = await invoke('deleteBill', {'billId': bill['id']});
    expect(deleted['success'], isTrue);
    expect(deleted['billId'], bill['id']);

    await invoke('deleteAccount', {'accountId': created['id']});
  });
}
