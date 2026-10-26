import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeJellyLive2DDisplaySize', () {
    test('fitContainer fills the usable height above the bottom reserve', () {
      expect(
        computeJellyLive2DDisplaySize(
          savedSize: 360,
          containerWidth: 515,
          containerHeight: 1008,
          bottomReserve: 157,
          fill: false,
          fitContainer: true,
          modelViewportAspectRatio: 0.5,
        ),
        851,
      );
    });

    test('fitContainer also shrinks to fit a narrow window', () {
      expect(
        computeJellyLive2DDisplaySize(
          savedSize: 360,
          containerWidth: 410,
          containerHeight: 1008,
          bottomReserve: 157,
          fill: false,
          fitContainer: true,
          modelViewportAspectRatio: 0.5,
        ),
        820,
      );
    });

    test('regular mode keeps the persisted model size', () {
      expect(
        computeJellyLive2DDisplaySize(
          savedSize: 320,
          containerWidth: 515,
          containerHeight: 1008,
          bottomReserve: 157,
          fill: false,
          fitContainer: false,
          modelViewportAspectRatio: 0.5,
        ),
        320,
      );
    });
  });

  group('computeJellyLive2DViewportLayout', () {
    test('Windows resizes its native viewport without composited scaling', () {
      expect(
        computeJellyLive2DViewportLayout(
          displaySize: 851,
          baseViewportHeight: 360,
          useResizableViewport: true,
        ),
        (viewportHeight: 851, scale: 1.0),
      );
    });

    test('other platforms retain the fixed viewport scaling path', () {
      expect(
        computeJellyLive2DViewportLayout(
          displaySize: 851,
          baseViewportHeight: 360,
          useResizableViewport: false,
        ),
        (viewportHeight: 360, scale: 851 / 360),
      );
    });
  });

  group('computeJellyLive2DModelBottomInset', () {
    test('uses the navigation boundary as the model horizontal baseline', () {
      expect(
        computeJellyLive2DModelBottomInset(
          layoutHeight: 1008,
          navigationPadding: 129,
          fitContainer: true,
        ),
        129,
      );
    });

    test('regular mode keeps the model at the bottom of its own box', () {
      expect(
        computeJellyLive2DModelBottomInset(
          layoutHeight: 360,
          navigationPadding: 129,
          fitContainer: false,
        ),
        0,
      );
    });
  });
}
