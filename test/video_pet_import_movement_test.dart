import 'package:aboutme/plugins/live2d/video/video_pet_import.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = VideoPetImportService();

  test(
    'bundled movement is added only when all referenced actions exist',
    () async {
      final defaults = await service.loadDefault();
      final legacy = defaults.manifest.copyWith(
        movement: const VideoPetMovement(),
      );
      final upgraded = await service.prepareForPlayback(legacy);
      expect(
        upgraded.manifest.movement.toJson(),
        defaults.manifest.movement.toJson(),
      );

      final subset = legacy.copyWith(
        animations: [legacy.animation(legacy.idleAnimationId)!],
        hover: const VideoPetBinding(),
        click: const VideoPetBinding(),
        regions: const [],
      );
      final prepared = await service.prepareForPlayback(subset);
      expect(prepared.manifest.movement.enabled, isFalse);
      prepared.manifest.validate();

      final custom = legacy.copyWith(
        movement: VideoPetMovement(
          leftAnimationId: legacy.idleAnimationId,
          speed: 23,
        ),
      );
      final preserved = await service.prepareForPlayback(custom);
      expect(preserved.manifest.movement.toJson(), custom.movement.toJson());
    },
  );
}
