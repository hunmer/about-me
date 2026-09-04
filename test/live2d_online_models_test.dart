import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog parser keeps model3 files and builds encoded CDN URLs', () {
    final models = Live2DOnlineCatalog.parseModels({
      'models': {
        'name': 'repo',
        'children': [
          {
            'name': '游戏 模型',
            'children': [
              {
                'name': '角色 A',
                'files': [
                  'normal/model.model3.json',
                  'legacy/model.model.json',
                  'normal/model.moc3',
                ],
              },
            ],
          },
        ],
      },
    });

    expect(models, hasLength(1));
    expect(models.single.category, '游戏 模型');
    expect(models.single.name, 'model (角色 A)');
    expect(
      models.single.url,
      contains(
        '/%E6%B8%B8%E6%88%8F%20%E6%A8%A1%E5%9E%8B/'
        '%E8%A7%92%E8%89%B2%20A/normal/model.model3.json',
      ),
    );
  });

  test('motion parser exposes sound metadata and stable group indexes', () {
    final motions = Live2DOnlineCatalog.parseMotions({
      'FileReferences': {
        'Motions': {
          'TapHead': [
            {'Name': 'Hello', 'File': 'hello.motion3.json', 'Sound': 'a.wav'},
            {'File': 'nod.motion3.json'},
          ],
        },
      },
    });

    expect(motions, hasLength(2));
    expect(motions.first.group, 'TapHead');
    expect(motions.first.index, 0);
    expect(motions.first.label, 'Hello');
    expect(motions.first.hasSound, isTrue);
    expect(motions.last.index, 1);
    expect(motions.last.hasSound, isFalse);
  });

  test('online motion list is capped and prioritizes voiced motions', () {
    final ordinary = List.generate(
      30,
      (index) => {'File': 'motion_$index.motion3.json'},
    );
    final motions = Live2DOnlineCatalog.parseMotions({
      'FileReferences': {
        'Motions': {
          'Action': ordinary,
          'Voice': [
            {'File': 'voice.motion3.json', 'Sound': 'voice.wav'},
          ],
        },
      },
    });

    expect(motions, hasLength(Live2DOnlineCatalog.maxPreloadedMotions));
    expect(motions.any((motion) => motion.hasSound), isTrue);
  });
}
