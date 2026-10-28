import 'package:aboutme/plugins/live2d/video/video_pet_import.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = VideoPetImportService();

  test(
    'drag migration preserves walking, explicit binding and subset safety',
    () async {
      final defaults = (await service.loadDefault()).manifest;
      expect(defaults.movement.dragAnimationId, '被鼠标拖拽悬空反馈');
      final old = defaults.copyWith(
        movement: defaults.movement.copyWith(dragAnimationId: ''),
      );
      final upgraded = await service.prepareForPlayback(old);
      expect(upgraded.manifest.movement.toJson(), defaults.movement.toJson());
      final explicit = defaults.copyWith(
        movement: defaults.movement.copyWith(
          dragAnimationId: defaults.idleAnimationId,
        ),
      );
      expect(
        (await service.prepareForPlayback(
          explicit,
        )).manifest.movement.dragAnimationId,
        defaults.idleAnimationId,
      );
      final dragOnly = defaults.copyWith(
        movement: VideoPetMovement(dragAnimationId: defaults.idleAnimationId),
      );
      final filled = (await service.prepareForPlayback(
        dragOnly,
      )).manifest.movement;
      expect(filled.enabled, true);
      expect(filled.dragAnimationId, defaults.idleAnimationId);
      final subset = old.copyWith(
        animations: old.animations
            .where((a) => a.id != defaults.movement.dragAnimationId)
            .toList(),
      );
      final safe = await service.prepareForPlayback(subset);
      expect(safe.manifest.movement.enabled, true);
      expect(safe.manifest.movement.dragAnimationId, isEmpty);
      safe.manifest.validate();
    },
  );

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
      expect(
        preserved.manifest.movement.toJson(),
        custom.movement
            .copyWith(
              dragAnimationId: defaults.manifest.movement.dragAnimationId,
            )
            .toJson(),
      );
    },
  );
}
