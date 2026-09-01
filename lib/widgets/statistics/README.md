# 通用统计组件 (Statistics Components)

一套可复用的统计图表和屏幕组件，为所有插件提供统一的统计界面和交互体验。

## 🚀 特性

- ✅ **统一视觉风格** - 所有插件使用相同的图表样式和交互
- ✅ **灵活配置** - 支持多种图表类型和自定义选项
- ✅ **高效开发** - 减少重复代码，快速实现统计功能
- ✅ **类型安全** - 完整的类型定义和 Dart 分析支持
- ✅ **易于扩展** - 支持自定义图表和业务逻辑

## 📦 组件列表

### 核心组件

- **[StatisticsScreen](#statisticsscreen)** - 通用统计屏幕
- **[StatisticsConfig](#statisticsconfig)** - 统计屏幕配置
- **[StatisticsData](#statisticsdata)** - 统计数据模型

### 图表组件

- **[DistributionPieChart](#distributionpiechart)** - 分布饼图
- **[RankingList](#rankinglist)** - 排行榜列表
- **[TimeSeriesChart](#timeserieschart)** - 时间序列趋势图
- **[HourlyDistributionBar](#hourlydistributionbar)** - 24小时分布条形图

### 辅助组件

- **[DateRangeSelector](#daterangeselector)** - 日期范围选择器
- **[StatisticsCalculator](#statisticscalculator)** - 统计计算工具

## 🛠️ 快速开始

### 基本使用

```dart
import 'package:aboutme/widgets/statistics/statistics.dart';

class MyStatisticsScreen extends StatelessWidget {
  final MyDataService dataService;

  const MyStatisticsScreen({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return StatisticsScreen(
      config: const StatisticsConfig(
        type: StatisticsType.custom,
        title: 'My Statistics',
        showDateRange: true,
        defaultRange: DateRangeOption.thisWeek,
      ),
      dataLoader: _loadData,
    );
  }

  Future<StatisticsData> _loadData(
    DateRangeOption range,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    // 加载并计算统计数据
    final data = await dataService.getData(startDate!, endDate!);

    return StatisticsData(
      title: 'My Statistics',
      startDate: startDate,
      endDate: endDate,
      totalValue: data.totalValue,
      totalValueLabel: 'items',
      distributionData: data.distributionData,
      rankingData: data.rankingData,
    );
  }
}
```

### 高级配置

```dart
StatisticsScreen(
  config: const StatisticsConfig(
    type: StatisticsType.custom,
    title: 'Advanced Statistics',
    subtitle: 'Custom subtitle',
    showDateRange: true,
    availableRanges: [
      DateRangeOption.today,
      DateRangeOption.thisWeek,
      DateRangeOption.thisMonth,
      DateRangeOption.custom,
    ],
    defaultRange: DateRangeOption.thisWeek,
    chartColors: [
      Color(0xFF60A5FA), // blue
      Color(0xFF4ADE80), // green
      Color(0xFF818CF8), // indigo
    ],
    show24hDistribution: true,
  ),
  dataLoader: _loadData,
  onRankingItemTap: (data) {
    // 处理排行榜项点击
    print('Clicked: ${data.label}');
  },
  customSections: (context, statsData) {
    // 添加自定义部分
    return [
      buildStatisticsCard(
        context: context,
        title: 'Custom Section',
        child: Text('Custom content'),
      ),
    ];
  },
)
```

## 📖 详细文档

### StatisticsScreen

通用统计屏幕组件，整合了所有统计功能。

#### 参数

- `config` - 统计配置
- `dataLoader` - 数据加载回调
- `onDateRangeChanged` - 日期范围变化回调（可选）
- `onRankingItemTap` - 排行榜项点击回调（可选）
- `customSections` - 自定义内容部分（可选）

#### 数据加载回调

```dart
Future<StatisticsData> _loadData(
  DateRangeOption range,
  DateTime? startDate,
  DateTime? endDate,
) async {
  // 从数据源加载数据
  final rawData = await fetchData(startDate!, endDate!);

  // 计算统计指标
  final distributionData = StatisticsCalculator.calculateDistributionByTag(
    rawData,
    tagField: 'category',
    valueField: 'value',
  );

  final rankingData = StatisticsCalculator.calculateRanking(
    rawData,
    labelField: 'name',
    valueField: 'score',
  );

  // 返回统计数据
  return StatisticsData(
    title: 'Statistics',
    startDate: startDate,
    endDate: endDate,
    totalValue: rawData.length.toDouble(),
    distributionData: distributionData,
    rankingData: rankingData,
  );
}
```

### StatisticsConfig

统计屏幕配置类。

#### 属性

- `type` - 统计类型 (StatisticsType)
- `title` - 标题
- `subtitle` - 副标题（可选）
- `showDateRange` - 是否显示日期选择器（默认true）
- `availableRanges` - 可用的日期范围选项
- `defaultRange` - 默认日期范围
- `chartColors` - 图表颜色主题
- `show24hDistribution` - 是否显示24小时分布（默认false）
- `loadingWidget` - 加载状态组件（可选）
- `emptyWidget` - 空数据组件（可选）

### StatisticsData

统计数据模型。

#### 属性

- `title` - 标题
- `subtitle` - 副标题
- `startDate` - 开始日期
- `endDate` - 结束日期
- `totalValue` - 总值（可选）
- `totalValueLabel` - 总值标签（可选）
- `distributionData` - 分布数据（饼图用）
- `rankingData` - 排行榜数据
- `timeSeriesData` - 时间序列数据（趋势图用）
- `hourlyDistribution` - 24小时分布数据
- `extraData` - 额外数据

### DistributionPieChart

分布饼图组件。

#### 使用示例

```dart
DistributionPieChart(
  data: [
    DistributionData(
      label: 'Category A',
      value: 30.0,
      color: Colors.blue,
    ),
    DistributionData(
      label: 'Category B',
      value: 45.0,
      color: Colors.green,
    ),
  ],
  colorPalette: [Colors.blue, Colors.green, Colors.orange],
  centerText: '75',
  centerSubtext: 'total',
  onSectionSelected: (index) {
    print('Selected section: $index');
  },
)
```

### RankingList

排行榜列表组件。

#### 使用示例

```dart
RankingList(
  data: [
    RankingData(
      label: 'Item 1',
      value: 100.0,
      color: Colors.blue,
      icon: Icons.star.codePoint.toString(),
    ),
    RankingData(
      label: 'Item 2',
      value: 85.0,
      color: Colors.green,
    ),
  ],
  colorPalette: [Colors.blue, Colors.green],
  onItemTap: (data) {
    print('Tapped: ${data.label}');
  },
  valueLabel: 'score',
)
```

### TimeSeriesChart

时间序列趋势图组件。

#### 使用示例

```dart
TimeSeriesChart(
  series: [
    TimeSeriesData(
      label: 'Series 1',
      points: [
        TimeSeriesPoint(date: DateTime(2024, 1, 1), value: 10.0),
        TimeSeriesPoint(date: DateTime(2024, 1, 2), value: 15.0),
        TimeSeriesPoint(date: DateTime(2024, 1, 3), value: 12.0),
      ],
      color: Colors.blue,
    ),
  ],
  colorPalette: [Colors.blue],
  showDots: true,
  showLines: true,
)
```

### StatisticsCalculator

统计计算工具类，提供常用的统计计算方法。

#### 常用方法

- `calculateDistributionByTag()` - 按标签计算分布数据
- `calculateRanking()` - 计算排行榜数据
- `calculateTimeSeries()` - 计算时间序列数据
- `calculateHourlyDistribution()` - 计算24小时分布
- `assignColorsToDistribution()` - 为分布数据分配颜色
- `assignColorsToRanking()` - 为排行榜数据分配颜色
- `filterByDateRange()` - 按日期范围过滤数据
- `calculateTotalValue()` - 计算总值

#### 使用示例

```dart
// 计算分布数据
final distributionData = StatisticsCalculator.calculateDistributionByTag(
  records,
  tagField: 'category',
  valueField: 'amount',
);

// 分配颜色
final coloredData = StatisticsCalculator.assignColorsToDistribution(
  distributionData,
  [Colors.blue, Colors.green, Colors.orange],
);

// 计算排行榜
final rankingData = StatisticsCalculator.calculateRanking(
  records,
  labelField: 'name',
  valueField: 'score',
);

// 分配颜色
final coloredRanking = StatisticsCalculator.assignColorsToRanking(
  rankingData,
  [Colors.blue, Colors.green, Colors.orange],
);
```

## 🎨 自定义样式

### 自定义颜色主题

```dart
const StatisticsConfig(
  chartColors: [
    Color(0xFF3B82F6), // 自定义蓝色
    Color(0xFF10B981), // 自定义绿色
    Color(0xFF8B5CF6), // 自定义紫色
    Color(0xFFF59E0B), // 自定义橙色
    Color(0xFFEF4444), // 自定义红色
    Color(0xFF6B7280), // 自定义灰色
  ],
)
```

### 自定义卡片样式

```dart
Widget buildCustomCard(BuildContext context, String title, Widget child) {
  return Card(
    elevation: 4,
    shadowColor: Colors.black26,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}
```

## 📝 最佳实践

### 1. 数据加载优化

```dart
Future<StatisticsData> _loadData(
  DateRangeOption range,
  DateTime? startDate,
  DateTime? endDate,
) async {
  try {
    // 使用缓存减少重复请求
    final cachedData = _getCachedData(startDate!, endDate!);
    if (cachedData != null) {
      return cachedData;
    }

    // 加载新数据
    final data = await _fetchData(startDate, endDate);

    // 缓存数据
    _cacheData(startDate, endDate, data);

    return data;
  } catch (e) {
    throw Exception('Failed to load data: $e');
  }
}
```

### 2. 错误处理

```dart
StatisticsScreen(
  config: StatisticsConfig(
    // ... 配置
  ),
  dataLoader: _loadData,
  onDateRangeChanged: (state) {
    if (state.isLoading) {
      // 显示加载指示器
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loading data...')),
      );
    }
  },
)
```

### 3. 性能优化

```dart
// 使用 const 构造函数优化性能
const StatisticsConfig(
  type: StatisticsType.custom,
  title: 'Statistics',
  chartColors: [
    Color(0xFF60A5FA),
    Color(0xFF4ADE80),
    // ...
  ],
)

// 缓存计算结果
final _cache = <String, StatisticsData>{};

String _getCacheKey(DateTime startDate, DateTime endDate) {
  return '${startDate.toIso8601String()}_${endDate.toIso8601String()}';
}
```

## 🔧 故障排除

### 常见问题

**Q: 图表不显示数据**
A: 检查 `StatisticsData` 中的数据是否为 `null`，确保数据格式正确。

**Q: 日期选择器不工作**
A: 确保 `showDateRange` 设置为 `true`，并正确实现 `dataLoader` 方法。

**Q: 颜色不匹配**
A: 使用 `StatisticsCalculator` 的 `assignColorsTo*` 方法为数据分配颜色。

**Q: 性能问题**
A: 使用数据缓存，避免重复计算，考虑使用 `const` 构造函数。

### 调试技巧

```dart
// 启用详细日志
final data = await _loadData(range, startDate, endDate);
print('Loaded data: ${data.distributionData?.length} distribution items');
print('Ranking items: ${data.rankingData?.length}');
```

## 📄 许可证

本组件库遵循项目的整体许可证。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个组件库！

---

**最后更新**: 2025-12-04
