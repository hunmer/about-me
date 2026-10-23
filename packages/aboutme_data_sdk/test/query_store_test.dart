import 'dart:async';
import 'dart:io';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:test/test.dart';

Map<String, dynamic> _result(int value) => {'success': true, 'data': value};

void main() {
  test('同目录另一 SDK 实例提交也会使本地 watch 更新', () async {
    final root = await Directory.systemTemp.createTemp('sdk_watch_');
    final first = AboutmeData.local(root.path);
    final second = AboutmeData.local(root.path);
    final received = <QuerySnapshot>[];
    final initial = Completer<void>();
    final changed = Completer<void>();
    final sub = first.watch('chat', 'getList').listen((snapshot) {
      received.add(snapshot);
      if (snapshot.status != QueryStatus.data) return;
      final count = snapshot.result!['data']['total'];
      if (count == 0 && !initial.isCompleted) initial.complete();
      if (count == 1 && !changed.isCompleted) changed.complete();
    });
    await initial.future;
    await second.call('chat', 'create', {'id': 'other-instance'});
    await changed.future;
    expect(received.last.result!['data']['total'], 1);
    await sub.cancel();
    await first.dispose();
    await second.dispose();
    await root.delete(recursive: true);
  });
  test('失效期间返回的旧响应不发布，同查询请求合并', () async {
    final events = StreamController<DataChangeEvent>.broadcast();
    final calls = <Completer<Map<String, dynamic>>>[];
    final store = QueryStore((plugin, action, params) {
      final call = Completer<Map<String, dynamic>>();
      calls.add(call);
      return call.future;
    }, events.stream);
    final first = store.query('chat', 'getList', {});
    final second = store.query('chat', 'getList', {});
    expect(calls.length, 1);
    store.invalidate('chat');
    calls.first.complete(_result(1));
    await Future<void>.delayed(Duration.zero);
    expect(calls.length, 2);
    calls.last.complete(_result(2));
    expect(await first, _result(2));
    expect(await second, _result(2));
    final cached = await store.query('chat', 'getList', {}, cacheOnly: true);
    cached['data'] = -1;
    expect(
      await store.query('chat', 'getList', {}, cacheOnly: true),
      _result(2),
    );
    await store.close();
    await events.close();
  });

  test('取消一个订阅不影响另一个；重连强制查询；错误保留旧快照', () async {
    final events = StreamController<DataChangeEvent>.broadcast();
    var value = 0;
    var fail = false;
    final store = QueryStore((plugin, action, params) async {
      if (fail)
        throw const StorageException(StorageErrorKind.offline, 'offline');
      return _result(value);
    }, events.stream);
    final received = <QuerySnapshot>[];
    final first = store.watch('chat', 'getList', {}).listen((_) {});
    final second = store.watch('chat', 'getList', {}).listen(received.add);
    await Future<void>.delayed(Duration.zero);
    expect(received.last.result, _result(0));
    await first.cancel();
    value = 1;
    events.add(
      const DataChangeEvent(
        pluginId: 'chat',
        filePattern: '*',
        source: 'remote',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(received.last.result, _result(1));
    value = 2;
    store.invalidate();
    await Future<void>.delayed(Duration.zero);
    expect(received.last.result, _result(2));
    fail = true;
    store.invalidate();
    await Future<void>.delayed(Duration.zero);
    expect(received.last.status, QueryStatus.error);
    expect(received.last.result, _result(2));
    await second.cancel();
    await store.close();
    await events.close();
  });

  test('销毁实例后在途请求不能更新缓存；新账号实例独立', () async {
    final pending = Completer<Map<String, dynamic>>();
    final old = QueryStore(
      (plugin, action, params) => pending.future,
      const Stream.empty(),
    );
    final request = old.query('chat', 'getList', {});
    final rejected = expectLater(request, throwsStateError);
    await old.close();
    final next = QueryStore(
      (plugin, action, params) async => _result(2),
      const Stream.empty(),
    );
    pending.complete(_result(1));
    await rejected;
    expect(await next.query('chat', 'getList', {}), _result(2));
    await next.close();
  });
}
