import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d_interaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transparent taps are not treated as character hits', () {
    expect(hasJellyLive2DHitArea(null, null), isFalse);
    expect(hasJellyLive2DHitArea(null, '  '), isFalse);
  });

  test('a declared hit area enables character interaction', () {
    expect(hasJellyLive2DHitArea('HitAreaBody', null), isTrue);
    expect(hasJellyLive2DHitArea(null, 'Head'), isTrue);
  });

  test('native view coordinates map to normalized top-left coordinates', () {
    expect(normalizeJellyLive2DViewPoint(-1, 1), (x: 0.0, y: 0.0));
    expect(normalizeJellyLive2DViewPoint(1, -1), (x: 1.0, y: 1.0));
    expect(normalizeJellyLive2DViewPoint(0, 0), (x: 0.5, y: 0.5));
  });

  test('archive regions serialize native metadata and custom bounds', () {
    final archive = Live2DArchive.fromJson({
      'id': 'archive',
      'name': 'Mao',
      'modelLabel': 'Mao',
      'modelDir': 'assets/models/mao/',
      'modelFile': 'mao.model3.json',
      'tapMessagesEnabled': true,
      'tapRegions': [
        {
          'id': 'HitAreaHead',
          'name': 'Head',
          'source': 'model',
          'messages': ['hello', 'welcome'],
        },
        {
          'id': 'custom-head',
          'name': 'Custom head',
          'source': 'custom',
          'left': 0.2,
          'top': 0.1,
          'right': 0.4,
          'bottom': 0.3,
          'messages': ['custom line'],
        },
      ],
    });

    expect(archive.tapRegionForHitArea('hitareahead', null)?.name, 'Head');
    expect(archive.tapRegionForHitArea(null, ' head ')?.id, 'HitAreaHead');
    expect(archive.tapRegionAt(0.3, 0.2)?.messages, ['custom line']);
    expect(archive.tapRegionAt(0.4, 0.2), isNull);
    expect(archive.toJson()['tapRegions'], hasLength(2));
  });

  test(
    'legacy archive without regions keeps tap messages and empty regions',
    () {
      final archive = Live2DArchive.fromJson({
        'id': 'legacy',
        'name': 'Mao',
        'tapMessages': {'head': 'old line'},
      });

      expect(archive.tapRegions, isEmpty);
      expect(archive.tapMessageList('head'), ['old line']);
      expect(archive.toJson()['tapRegions'], isEmpty);
    },
  );
}
