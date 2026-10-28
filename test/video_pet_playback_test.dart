import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_player_state.dart';

const manifest = VideoPetManifest(
  id: 'test',
  name: 'test',
  idleAnimationId: 'idle',
  animations: [
    VideoPetAnimation(id: 'idle', name: 'idle'),
    VideoPetAnimation(id: 'hover', name: 'hover'),
    VideoPetAnimation(id: 'click', name: 'click'),
    VideoPetAnimation(id: 'manual', name: 'manual'),
  ],
);

void main() {
  test('once priority, hover continuity and latest completion', () {
    final state = VideoPetPlaybackState(manifest);
    expect(state.current!.animationId, 'idle');
    expect(state.setHover('hover')!.loop, isTrue);
    final click = state.playClick(
      const VideoPetBinding(animationIds: ['click']),
    )!;
    expect(click.kind, VideoPetPlaybackKind.click);
    expect(click.loop, isFalse);
    expect(state.setHover(null)!.generation, click.generation);
    final manual = state.playManual('manual')!;
    expect(state.ended(click.generation), isNull);
    state.setHover('hover');
    expect(state.current!.animationId, 'manual');
    expect(state.ended(manual.generation)!.animationId, 'hover');
    expect(state.setHover(null)!.animationId, 'idle');
  });
  test('same source replay and empty binding/unknown manual are no-ops', () {
    final state = VideoPetPlaybackState(manifest);
    final a = state.playManual('click')!;
    final b = state.playManual('click')!;
    expect(b.generation, greaterThan(a.generation));
    expect(state.playClick(const VideoPetBinding())!.generation, b.generation);
    expect(state.playManual('missing')!.generation, b.generation);
  });
  test('sequence bindings are independent, pause retains generation', () {
    final state = VideoPetPlaybackState(manifest);
    const binding = VideoPetBinding(
      animationIds: ['click', 'manual'],
      strategy: 'sequence',
    );
    expect(state.playClick(binding)!.animationId, 'click');
    expect(state.playClick(binding)!.animationId, 'manual');
    final generation = state.generation;
    expect(state.setLifecycle(paused: true)!.generation, generation);
    expect(state.playing, isFalse);
    expect(state.ended(generation), isNull);
    state.setLifecycle(paused: false);
    expect(state.ended(generation)!.animationId, 'idle');
  });
  test('contain coordinates ignore letterbox and invalid dimensions', () {
    ({double x, double y})? point(double x, double y) => videoPetContainPoint(
      x: x,
      y: y,
      width: 200,
      height: 100,
      canvasWidth: 100,
      canvasHeight: 100,
    );
    expect(point(10, 50), isNull);
    expect(point(100, 50), (x: 0.5, y: 0.5));
    expect(point(50, 0), (x: 0.0, y: 0.0));
    expect(
      videoPetContainPoint(
        x: 0,
        y: 0,
        width: 0,
        height: 0,
        canvasWidth: 1,
        canvasHeight: 1,
      ),
      isNull,
    );
  });
}
