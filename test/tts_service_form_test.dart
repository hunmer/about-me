import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/tts/models/tts_service_config.dart';
import 'package:aboutme/plugins/tts/models/tts_service_type.dart';
import 'package:aboutme/plugins/tts/widgets/tts_service_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final useWheel in [false, true]) {
    testWidgets('切换服务类型后可滚动到 MiniMax 最后一个字段 wheel=$useWheel', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => TtsServiceForm.show(
                  context,
                  service: TTSServiceConfig(
                    name: 'test',
                    type: TTSServiceType.http,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final select = tester.widget<DSSelect<TTSServiceType>>(
        find.byType(DSSelect<TTSServiceType>),
      );
      select.onChanged!(TTSServiceType.minimax);
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byType(TtsServiceForm),
            matching: find.byType(SingleChildScrollView),
          )
          .first;
      for (var i = 0; i < 6; i++) {
        if (useWheel) {
          await tester.sendEventToBinding(
            PointerScrollEvent(
              position: tester.getCenter(scroll),
              scrollDelta: const Offset(0, 600),
            ),
          );
        } else {
          await tester.drag(scroll, const Offset(0, -600));
        }
        await tester.pumpAndSettle();
      }
      final lastField = find.byType(DSSelect<String>).last;
      final save = find.text('tts_save');
      expect(
        tester.getRect(lastField).bottom,
        lessThanOrEqualTo(tester.getRect(save).top),
      );
      expect(lastField.hitTestable(), findsOneWidget);
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getRect(lastField).bottom, lessThanOrEqualTo(800));
      expect(tester.takeException(), isNull);
    });
  }
}
