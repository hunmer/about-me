import 'dart:ui';

import 'package:aboutme/screens/jelly_home/widgets/jelly_status_panel_config.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_status_panel_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('status panel styles expose a stable id and preview asset', () {
    expect(JellyStatusPanelSettings.maxDisplayHeight, 150);
    expect(JellyStatusPanelSettings.builtInStyles, isNotEmpty);
    expect(JellyStatusPanelSettings.builtInStyles.map((style) => style.id), [
      'rabbit_a1',
      'rabbit_a2',
      'rabbit_a3',
    ]);
    expect(JellyStatusPanelSettings.builtInStyles.first.id, 'rabbit_a1');
    expect(
      JellyStatusPanelSettings.builtInStyles.first.asset,
      'assets/images/jelly_status_panel.png',
    );
    expect(
      JellyStatusPanelSettings.builtInStyles.first.mapToVisible(
        JellyStatusPanelSettings.builtInStyles.first.visibleBounds,
      ),
      const Rect.fromLTWH(0, 0, 1, 1),
    );
  });

  test('status panel config round-trips through preferences', () {
    final config = JellyStatusPanelConfig.defaults.copyWith(
      items: const [
        JellyStatusItemConfig(
          type: JellyStatusItemType.mood,
          iconRegion: Rect.fromLTWH(0.1, 0.2, 0.1, 0.1),
          valueRegion: Rect.fromLTWH(0.2, 0.2, 0.2, 0.1),
        ),
      ],
    );

    final restored = JellyStatusPanelConfig.parse(config.encode());

    expect(restored.avatarRegion, config.avatarRegion);
    expect(restored.experienceRegion, config.experienceRegion);
    expect(restored.items, config.items);
  });

  test('invalid persisted config falls back to defaults', () {
    expect(
      JellyStatusPanelConfig.parse('bad'),
      JellyStatusPanelConfig.defaults,
    );
  });

  test('rectangles outside the image are rejected', () {
    final invalid = JellyStatusPanelConfig.defaults.copyWith(
      avatarRegion: const Rect.fromLTRB(-0.1, 0, 0.2, 0.2),
    );

    expect(
      JellyStatusPanelConfig.parse(invalid.encode()),
      JellyStatusPanelConfig.defaults,
    );
  });
}
