# 通用统计数据模型 (Statistics Models)

统计数据模型与计算工具，供各插件统计数据聚合使用。

> **UI 已迁移**：统计页面/图表 UI 统一使用手绘统计组件
> `lib/widgets/stats/sketch_stats.dart`（`SketchLineChart` 墨线折线图、
> `StatsSketchCard` 统计纸卡、本地化文案辅助），
> 参考 timer / chat / todo / habits / checkin / activity 各插件的统计页实现。

## 📦 内容

- **models/statistics_models.dart** - `StatisticsData`、`DistributionData`、
  `RankingData`、`TimeSeriesPoint`、`TimeSeriesData`、`DateRangeOption`
- **utils/statistics_calculator.dart** - `StatisticsCalculator` 分布/排行/小时分布计算
