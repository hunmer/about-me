// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/widgets.dart';

import 'package:live2d_flutter/live2d_flutter.dart';

const bool _runMacOSRuntimeTest = bool.fromEnvironment(
  'LIVE2D_MACOS_RUNTIME_TEST',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getPlatformVersion test', (WidgetTester tester) async {
    final String? version = await Live2D.getPlatformVersion();
    // The version string depends on the host platform running the test, so
    // just assert that some non-empty string is returned.
    expect(version?.isNotEmpty, true);
  });

  testWidgets(
    'macOS loads a model and accepts controller commands',
    (WidgetTester tester) async {
      final controller = Live2DViewController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 600,
            height: 600,
            child: Live2DView(controller: controller),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await controller.whenAttached.timeout(const Duration(seconds: 10));

      final loaded = await controller
          .loadModel(
            modelDir: 'assets/models/mao/',
            modelFileName: 'mao_pro.model3.json',
          )
          .timeout(const Duration(seconds: 90));
      expect(loaded, isTrue);
      expect(controller.value.isLoaded, isTrue);

      await controller.startMotion(group: 'Idle');
      await controller.setExpression(0);
      await controller.setParameter('ParamAngleX', 10);
      await controller.setMotionSpeed(1.5);
      await controller.setRenderingPaused(true);
      expect(controller.value.isRenderingPaused, isTrue);
      await controller.setRenderingPaused(false);
      await controller.unloadModel();
      expect(controller.value.isLoaded, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      controller.dispose();
    },
    skip:
        defaultTargetPlatform != TargetPlatform.macOS || !_runMacOSRuntimeTest,
  );
}
