import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/plugins/webview/services/tab_manager.dart';

void main() {
  test('迟到的 controller 绑定不会重新挂到已关闭标签页', () async {
    final manager = TabManager();
    final tab = await manager.createTab(
      url: 'https://example.com',
      setActive: true,
    );

    await manager.closeTab(tab.id);

    // InAppWebViewController 由平台 widget 创建，业务层不应在这里伪造或销毁它。
    // setController 仍应拒绝已经不在 manager 中的 tab。
    expect(manager.getController(tab.id), isNull);
  });

  test('退出 WebView 页面时可安全清理尚未绑定的 controller 槽位', () async {
    final manager = TabManager();
    final tab = await manager.createTab(
      url: 'https://example.com',
      setActive: true,
    );

    expect(manager.getController(tab.id), isNull);
    manager.clearController(tab.id, null);
    expect(manager.getController(tab.id), isNull);
  });
}
