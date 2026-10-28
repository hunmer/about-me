import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_import.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('facing roundtrips and rejects invalid directions', () {
    for (final facing in ['', 'left', 'right']) {
      final animation = VideoPetAnimation(
        id: 'walk',
        name: 'walk',
        facing: facing,
        sources: const {'webm': 'walk.webm'},
      );
      animation.validate();
      expect(VideoPetAnimation.fromJson(animation.toJson()).facing, facing);
      expect(animation.copyWith(name: 'renamed').facing, facing);
    }
    expect(
      () => const VideoPetAnimation(
        id: 'walk',
        name: 'walk',
        facing: 'up',
        sources: {'webm': 'walk.webm'},
      ).validate(),
      throwsFormatException,
    );
  });
  test(
    'built-in walking faces left and refresh preserves custom facing',
    () async {
      const service = VideoPetImportService();
      final defaults = await service.loadDefault();
      expect(defaults.manifest.animation('螃蟹走路')!.facing, 'left');
      for (final original in ['', 'right']) {
        final legacy = defaults.manifest.copyWith(
          animations: [
            for (final animation in defaults.manifest.animations)
              animation.id == '螃蟹走路'
                  ? animation.copyWith(facing: original)
                  : animation,
          ],
        );
        final prepared = await service.prepareForPlayback(legacy);
        expect(
          prepared.manifest.animation('螃蟹走路')!.facing,
          original.isEmpty ? 'left' : original,
        );
      }
    },
  );
}
