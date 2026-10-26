import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

class _RouteListener with RouteAware {
  int covered = 0;
  int restored = 0;

  @override
  void didPushNext() => covered++;

  @override
  void didPopNext() => restored++;
}

void main() {
  test('smooth sheet 不触发模型路由生命周期，普通页面仍触发', () {
    final observer = RouteHistoryManager.instance;
    final listener = _RouteListener();
    final home = MaterialPageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );
    final sheet = ModalSheetRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );
    final page = MaterialPageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );
    observer.subscribe(listener, home);
    addTearDown(() {
      observer.unsubscribe(listener);
      home.dispose();
      sheet.dispose();
      page.dispose();
    });

    // ModalSheetRoute 同样属于 PageRoute，必须按 opaque 区分。
    expect(sheet, isA<PageRoute<void>>());
    expect(sheet.opaque, isFalse);
    observer.didPush(sheet, home);
    observer.didPop(sheet, home);
    expect(listener.covered, 0);
    expect(listener.restored, 0);

    observer.didPush(page, home);
    observer.didPop(page, home);
    expect(listener.covered, 1);
    expect(listener.restored, 1);
  });
}
