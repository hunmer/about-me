/// 通用统计数据模型与计算工具
///
/// UI 层已迁移至统一手绘统计组件（`package:aboutme/widgets/stats/sketch_stats.dart`），
/// 本库仅保留数据模型与计算器，供各插件统计数据聚合使用。
///
/// - [StatisticsData] - 统计数据模型
/// - [DistributionData] / [RankingData] / [TimeSeriesPoint] - 数据条目模型
/// - [StatisticsCalculator] - 统计计算工具
library;

export 'models/statistics_models.dart';
export 'utils/statistics_calculator.dart';
