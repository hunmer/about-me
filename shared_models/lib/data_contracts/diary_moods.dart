/// 日记心情数据契约
library;

/// 心情常量列表（单一数据源，顺序即编辑器展示顺序）
///
/// 日记 mood 字段存储此处的 id（如 'happy'），不是 emoji；
/// emoji 仅是 UI 展示回退，外观定义在 app 侧 kDiaryMoods。
const List<String> kDiaryMoodIds = [
  // 基础十款
  'happy', 'excited', 'loved', 'surprised', 'tired', 'sick', 'thinking',
  'cool', 'sad', 'angry',
  // 开心组
  'winking', 'blushing', 'drooly', 'tasty', 'tongueOut',
  // 兴奋组
  'starEyes', 'hysterical', 'playful',
  // 心动组
  'blowingKiss', 'kissy',
  // 惊讶组
  'baffled', 'gaping', 'flushed',
  // 难过组
  'puppyEyes', 'bawling', 'wailing',
  // 困倦组
  'knockedOut', 'sweating',
  // 生气组
  'mad',
  // 思考组
  'skeptical', 'sly', 'annoyed', 'nervous', 'gritting',
  // 平静组
  'unamused', 'deadpan',
];
