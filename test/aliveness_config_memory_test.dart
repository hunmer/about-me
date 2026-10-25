import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';

void main() {
  group('AlivenessConfig memory libraries', () {
    test('old config does not enable memory by following enabled', () {
      final config = AlivenessConfig.fromJson(const {'enabled': true});

      expect(config.enabled, isTrue);
      expect(config.memoryEnabled, isFalse);
      expect(config.memoryIds, isEmpty);
      expect(config.hasMemory, isFalse);
    });

    test('memory ids and hasMemory round trip', () {
      const config = AlivenessConfig(
        enabled: true,
        memoryEnabled: true,
        memoryIds: ['library-a', 'library-b'],
      );
      final restored = AlivenessConfig.fromJson(config.toJson());

      expect(restored.memoryEnabled, isTrue);
      expect(restored.memoryIds, ['library-a', 'library-b']);
      expect(restored.hasMemory, isTrue);
      expect(config.copyWith(memoryIds: const ['library-c']).memoryIds, [
        'library-c',
      ]);
      expect(config.copyWith(memoryEnabled: false).hasMemory, isFalse);
    });
  });
}
