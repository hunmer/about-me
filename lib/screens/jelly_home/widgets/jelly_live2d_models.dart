import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';

import '../live2d_online_models.dart';

/// 内置模型清单；改这里要同步根 pubspec.yaml 的 assets 声明
const List<Live2DModelDefinition> _models = [
  Live2DModelDefinition(
    label: 'Mao',
    modelDir: 'assets/models/mao/',
    modelFile: 'mao_pro.model3.json',
    motions: [
      // label 存翻译 key，显示处需 .tr 解析
      Live2DMotionDefinition(
        group: 'Idle',
        index: 0,
        label: 'screens_jellyLive2dMotionIdle',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 0,
        label: 'screens_jellyLive2dMotion1',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 1,
        label: 'screens_jellyLive2dMotion2',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 2,
        label: 'screens_jellyLive2dMotion3',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 3,
        label: 'screens_jellyLive2dSpecialMotion1',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 4,
        label: 'screens_jellyLive2dSpecialMotion2',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 5,
        label: 'screens_jellyLive2dSpecialMotion3',
      ),
    ],
  ),
  Live2DModelDefinition(
    label: 'IceGirl',
    modelDir: 'assets/models/icegirl/',
    modelFile: 'IceGirl.model3.json',
    motions: [],
  ),
  Live2DModelDefinition(
    label: 'Ren',
    modelDir: 'assets/models/ren/',
    modelFile: 'ren.model3.json',
    motions: [
      Live2DMotionDefinition(
        group: 'Idle',
        index: 0,
        label: 'screens_jellyLive2dMotionIdle',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 0,
        label: 'screens_jellyLive2dMotion1',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 1,
        label: 'screens_jellyLive2dMotion2',
      ),
    ],
  ),
];

List<Live2DModelDefinition> get availableJellyLive2DModels =>
    List.unmodifiable(_models);

/// 把 Live2D 存档转换为视图层模型定义（小屋页签与设置页共用）：
/// 优先匹配内置模型（带动作列表），否则按存档路径构造在线模型定义
Live2DModelDefinition? modelDefinitionForArchive(Live2DArchive? value) {
  if (value == null || value.modelLabel.isEmpty) return null;
  return availableJellyLive2DModels
          .where((model) => model.label == value.modelLabel)
          .firstOrNull ??
      Live2DModelDefinition(
        label: value.modelLabel,
        modelDir: value.modelDir,
        modelFile: value.modelFile,
        motions: const [],
        isOnline: value.modelDir.startsWith('http'),
      );
}
