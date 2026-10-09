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
}
