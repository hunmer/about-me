import 'dart:ui';

import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d_crop_region.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('crop region round-trips through preferences', () {
    final region = JellyLive2DCropRegion.fromImageRect(
      const Rect.fromLTWH(40, 80, 120, 240),
      const Size(200, 400),
    );

    final restored = JellyLive2DCropRegion.parse(region.encode());

    expect(restored.rect, const Rect.fromLTWH(0.2, 0.2, 0.6, 0.6));
  });

  test('crop transform maps selected area to the full source viewport', () {
    final region = JellyLive2DCropRegion.fromImageRect(
      const Rect.fromLTWH(40, 80, 120, 240),
      const Size(200, 400),
    );
    const sourceSize = Size(180, 360);
    final translation = region.sourceTranslation(sourceSize);

    expect(region.zoom, closeTo(5 / 3, 0.0001));
    final mappedTopLeft =
        region.rect.topLeft.scale(
          sourceSize.width * region.zoom,
          sourceSize.height * region.zoom,
        ) +
        translation;
    expect(mappedTopLeft.dx, closeTo(0, 0.0001));
    expect(mappedTopLeft.dy, closeTo(0, 0.0001));
    expect(
      region.rect.size.width * sourceSize.width * region.zoom,
      sourceSize.width,
    );
    expect(
      region.rect.size.height * sourceSize.height * region.zoom,
      sourceSize.height,
    );
  });

  test('invalid persisted region falls back to full image', () {
    expect(JellyLive2DCropRegion.parse('bad').isFull, isTrue);
    expect(JellyLive2DCropRegion.parse('-1,0,1,1').isFull, isTrue);
    expect(JellyLive2DCropRegion.parse('0,0,2,1').isFull, isTrue);
  });
}
