/// 与 EffortSlider 的六个档位一一对应；请求参数由各模型适配。
enum ThinkingEffort {
  low('Low'),
  medium('Medium'),
  high('High'),
  extra('Extra'),
  max('Max'),
  galaxy('Galaxy');

  const ThinkingEffort(this.label);

  final String label;

  static ThinkingEffort fromJson(Object? value) =>
      values.firstWhere((effort) => effort.name == value, orElse: () => medium);
}
