import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/wave_fill.dart';

/// 消息统计页（视觉风格同 TimerStatsView）
///
/// - Hero 卡：今日消息数 + 较昨日增量胶囊 + 总消息/频道数/连续天数
/// - 今日消息分布：0–22 点手绘墨线曲线
/// - 每日消息分布：7 天胶囊柱状图，今日高亮
/// - 类型分布 + 频道活跃排行
class ChatStatsScreen extends StatefulWidget {
  final ChatPlugin chatPlugin;

  /// 刷新令牌：变化时重新统计（bottom bar 切到统计 tab 时递增）
  final int refreshToken;

  const ChatStatsScreen({
    super.key,
    required this.chatPlugin,
    this.refreshToken = 0,
  });

  @override
  State<ChatStatsScreen> createState() => _ChatStatsScreenState();
}

class _ChatStatsScreenState extends State<ChatStatsScreen> {
  List<Message> _messages = [];
  List<Channel> _channels = [];
  bool _loading = true;
  int _selectedDay = 6; // 柱状图选中的天（默认今天，即第 7 天）

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(ChatStatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadStats();
    }
  }

  void _loadStats() {
    // 频道与消息在 dataService 内存缓存中已是全量，直接聚合
    final channels = widget.chatPlugin.dataService.channels;
    final messages = <Message>[];
    for (final channel in channels) {
      messages.addAll(channel.messages);
    }
    messages.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() {
        _channels = channels;
        _messages = messages;
        _loading = false;
      });
    }
  }

  // ===== 数据聚合 =====

  DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  List<Message> _messagesOf(DateTime day) {
    return _messages.where((m) => _dayOf(m.date) == day).toList();
  }

  /// 从今天开始往前连续有消息的天数
  int get _streakDays {
    var streak = 0;
    var day = _dayOf(DateTime.now());
    // 今天还没消息时从昨天起算，避免显示 0
    if (_messagesOf(day).isEmpty) {
      day = day.subtract(const Duration(days: 1));
    }
    while (_messagesOf(day).isNotEmpty) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// 最近 7 天（含今天）
  List<DateTime> get _last7Days => List.generate(
    7,
    (i) => _dayOf(DateTime.now()).subtract(Duration(days: 6 - i)),
  );

  static const _typeLabels = {
    MessageType.sent: '发出',
    MessageType.received: '收到',
    MessageType.file: '文件',
    MessageType.image: '图片',
    MessageType.video: '视频',
    MessageType.audio: '语音',
  };

  /// 各类型消息数（仅统计非零项用于徽章行）
  Map<MessageType, int> get _typeCounts {
    final counts = <MessageType, int>{};
    for (final m in _messages) {
      counts[m.type] = (counts[m.type] ?? 0) + 1;
    }
    return counts;
  }

  /// 频道活跃排行（按消息数倒序，取前 8）
  List<(Channel, int)> get _channelRanking {
    final ranking = [
      for (final channel in _channels) (channel, channel.messages.length),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return ranking.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    return SuperCupertinoNavigationWrapper(
      title: Text('chat_statsTab'.tr),
      largeTitle: 'chat_statsTab'.tr,
      enableSearchBar: false,
      // Tab 切换挂载时墨线描画入场（design.md §10）
      body: WiredDraw(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
          children: [
            _buildHeroCard(theme),
            const SizedBox(height: 16),
            _buildTodayLineChartCard(theme),
            const SizedBox(height: 16),
            _buildBarChartCard(theme),
            const SizedBox(height: 16),
            _buildTypeCard(theme),
            const SizedBox(height: 24),
            _buildChannelRankingSection(theme),
          ],
        ),
      ),
    );
  }

  // ===== Hero 卡：今日消息数 =====

  Widget _buildHeroCard(ThemeData theme) {
    final now = DateTime.now();
    final today = _messagesOf(_dayOf(now)).length;
    final yesterday =
        _messagesOf(_dayOf(now.subtract(const Duration(days: 1)))).length;
    final diff = today - yesterday;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'chat_todayMessages'.tr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$today',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '条',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 较昨日增量胶囊
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFFFDBCF),
                ),
                child: Row(
                  children: [
                    Icon(
                      diff >= 0 ? Icons.trending_up : Icons.trending_down,
                      size: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${diff >= 0 ? '+' : ''}$diff 较昨日',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: theme.colorScheme.surfaceContainerHighest),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFA5E1E),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '共 ${_messages.length} 条 · ${_channels.length} 个频道',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                _streakDays > 0 ? '连续记录 $_streakDays 天' : '尚未开始记录',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== 今日消息分布曲线（手绘墨线） =====

  Widget _buildTodayLineChartCard(ThemeData theme) {
    final now = DateTime.now();
    final today = _messagesOf(_dayOf(now));

    // 每 2 小时聚合一档消息数（0–22 点共 12 档）
    final buckets = List.filled(12, 0.0);
    for (final m in today) {
      buckets[m.date.hour ~/ 2] += 1;
    }
    // 全天无消息时保底 1，避免 maxValue 为 0 画不出线
    final maxBucket = buckets.fold(0.0, (a, b) => a > b ? a : b);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '今日消息分布',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${now.month}月${now.day}日 · ${today.length} 条',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 手绘墨线曲线（CustomPaint 无 child，需 tight 约束撑满）
          SizedBox(
            width: double.infinity,
            height: 170,
            child: Builder(
              builder: (context) {
                final dsTheme = DSThemeBridge.resolve(context);
                return _SketchLineChart(
                  values: buckets,
                  maxValue: maxBucket < 1 ? 1.0 : maxBucket,
                  color: theme.colorScheme.primary,
                  drawConfig: dsTheme.wired.drawConfig,
                  drawProgress: WiredDrawTransition.progressOf(context),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < buckets.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  child: Center(
                    child: Text(
                      '${i * 2}点',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ===== 每日消息分布柱状图 =====

  Widget _buildBarChartCard(ThemeData theme) {
    final days = _last7Days;
    final counts = days.map((d) => _messagesOf(d).length).toList();
    final avg = counts.fold<int>(0, (a, b) => a + b) / 7;

    final dayNames = ['一', '二', '三', '四', '五', '六', '日'];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '每日消息分布',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '日均 ${avg.toStringAsFixed(1)} 条',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 选中天的提示横幅
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.surfaceContainerLow,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _tooltipDayLabel(days[_selectedDay]),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${counts[_selectedDay]} 条消息',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 7 天胶囊柱
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _buildChartColumn(theme, i, dayNames)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _tooltipDayLabel(DateTime day) {
    final isToday = day == _dayOf(DateTime.now());
    final weekday = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][day.weekday - 1];
    return isToday ? '$weekday (今日)' : weekday;
  }

  Widget _buildChartColumn(ThemeData theme, int i, List<String> dayNames) {
    final days = _last7Days;
    final isToday = i == 6;
    final selected = _selectedDay == i;
    final counts = days.map((d) => _messagesOf(d).length).toList();
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);
    // 高度比例相对本周最多的一天；全周无消息时给最小可见高度
    final ratio = maxCount == 0 ? 0.06 : (counts[i] / maxCount).clamp(0.06, 1.0);

    final accent = theme.colorScheme.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedDay = i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${counts[i]}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? accent : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          // 胶囊轨道：波纹按比例自下而上填充。
          // SizedBox.expand 撑满轨道——WaveFill 的 CustomPaint 无 child，
          // loose 约束下会收缩为 0
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: isToday
                    ? accent.withValues(alpha: 0.25)
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
              ),
              padding: const EdgeInsets.all(2.5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox.expand(
                  child: WaveFill(
                    progress: ratio,
                    // 波体自带 0.24–0.6 渐变透明度，传不透明色避免叠加后过淡
                    color: isToday ? accent : theme.colorScheme.onSurfaceVariant,
                    // 柱体窄，收敛波幅避免波浪吞掉整根
                    amplitude: 3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dayNames[days[i].weekday - 1],
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? accent : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // 选中天底部小圆点指示
          const SizedBox(height: 3),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? accent : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 类型分布 =====

  Widget _buildTypeCard(ThemeData theme) {
    final counts = _typeCounts;
    // 按固定顺序展示非零类型
    final entries = _typeLabels.entries
        .where((e) => counts[e.key] != null && counts[e.key]! > 0)
        .toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.donut_small,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '消息类型分布',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in entries)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  child: Text(
                    '${e.value} ${counts[e.key]}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== 频道活跃排行 =====

  Widget _buildChannelRankingSection(ThemeData theme) {
    final ranking = _channelRanking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.forum,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '频道活跃排行',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                'Top ${ranking.length}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (ranking.isEmpty)
          _Card(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'chat_noMessagesYet'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          _Card(
            child: Column(
              children: [
                for (var i = 0; i < ranking.length; i++)
                  _buildRankingItem(
                    theme,
                    ranking[i].$1,
                    ranking[i].$2,
                    i < ranking.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRankingItem(
    ThemeData theme,
    Channel channel,
    int count,
    bool showLine,
  ) {
    final percent = _messages.isEmpty
        ? 0.0
        : count / _messages.length * 100;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 时间线：圆点 + 连接线
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 5),
                // 手绘圆点：频道色实底 + 墨线描边
                Container(
                  width: 12,
                  height: 12,
                  decoration: dsSketchDecoration(
                    theme: DSThemeBridge.resolve(context),
                    circle: true,
                    fillColor: channel.backgroundColor,
                    strokeWidth: 1.4,
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: theme.colorScheme.surfaceContainerHigh,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showLine ? 16 : 0),
              child: Text(
                channel.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count 条',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// 手绘墨线曲线图：skribble rough 曲线（与全局墨线风格同源）
/// + 主色淡渐变填充体 + 实底数据点，接 WiredDraw 描画入场。
/// CustomPaint 无 child，须置于 tight 约束下（SizedBox 宽高有界）
class _SketchLineChart extends StatelessWidget {
  const _SketchLineChart({
    required this.values,
    required this.maxValue,
    required this.color,
    required this.drawConfig,
    this.drawProgress,
  });

  final List<double> values;
  final double maxValue;
  final Color color;

  /// 主题墨线绘制配置（AppThemeData.wired.drawConfig）
  final DrawConfig drawConfig;

  /// 外层 WiredDraw 描画进度；null = 已画完
  final Animation<double>? drawProgress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SketchLineChartPainter(
        values: values,
        maxValue: maxValue,
        color: color,
        drawConfig: drawConfig,
        drawProgress: drawProgress,
      ),
    );
  }
}

class _SketchLineChartPainter extends CustomPainter {
  _SketchLineChartPainter({
    required this.values,
    required this.maxValue,
    required this.color,
    required this.drawConfig,
    this.drawProgress,
  }) : super(repaint: drawProgress);

  final List<double> values;
  final double maxValue;
  final Color color;
  final DrawConfig drawConfig;
  final Animation<double>? drawProgress;

  /// rough 生成缓存：尺寸不变时描画动画帧复用，不重算墨线
  Size? _builtFor;
  Path? _fillPath;
  RoughDrawing? _curve;
  List<Offset> _points = const [];

  /// 墨线先描，填充体与数据点在 30%–100% 阶段浮现（同 WaveFill 节奏）
  double get _phase => (((drawProgress?.value ?? 1) - 0.3) / 0.7).clamp(
    0.0,
    1.0,
  );

  void _build(Size size) {
    final top = 14.0; // 顶部留空给最高点数据点
    final bottom = size.height - 3;
    final chartHeight = bottom - top;
    final n = values.length;
    _points = [
      for (var i = 0; i < n; i++)
        Offset(
          i / (n - 1) * size.width,
          bottom - (values[i] / maxValue).clamp(0.0, 1.0) * chartHeight,
        ),
    ];

    // 主色淡渐变填充体（Catmull-Rom 平滑 + 闭合到底边）
    final fill = _smoothPath(_points);
    fill
      ..lineTo(_points.last.dx, bottom)
      ..lineTo(_points.first.dx, bottom)
      ..close();
    _fillPath = fill;

    // 手绘墨线曲线；reset 保证同尺寸下墨迹稳定不抖变
    drawConfig.randomizer.reset();
    final generator = Generator(drawConfig, NoFiller());
    final drawable = generator.curvePath([
      for (final p in _points) PointD(p.dx, p.dy),
    ]);
    _curve = RoughDrawing(
      drawable,
      Paint()
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.8
        ..color = color,
      Paint()..color = color, // NoFiller 下填充笔不参与绘制
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || maxValue <= 0 || size.isEmpty) return;
    if (_builtFor != size) {
      _build(size);
      _builtFor = size;
    }
    final drawValue = drawProgress?.value ?? 1;
    final phase = _phase;
    final n = values.length;

    if (phase > 0 && _fillPath != null) {
      canvas.drawPath(
        _fillPath!,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.20 * phase),
              color.withValues(alpha: 0.02 * phase),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    _curve?.paint(canvas, progress: drawValue, pressure: 0);

    // 数据点：描画推进到该点后浮现（值为 0 的贴底点不画）
    for (var i = 0; i < n; i++) {
      if (values[i] <= 0) continue;
      final appear = (drawValue * (n - 1) - i).clamp(0.0, 1.0);
      if (appear <= 0) continue;
      canvas.drawCircle(
        _points[i],
        i == n - 1 ? 5 : 3.2,
        Paint()..color = color.withValues(alpha: phase * appear),
      );
    }
  }

  /// Catmull-Rom 样条平滑路径（填充体轮廓，非手绘）
  static Path _smoothPath(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i > 0 ? i - 1 : i];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[i + 2 < pts.length ? i + 2 : i + 1];
      const segments = 16;
      for (var j = 1; j <= segments; j++) {
        final t = j / segments;
        final t2 = t * t;
        final t3 = t2 * t;
        path.lineTo(
          0.5 *
              ((2 * p1.dx) +
                  (-p0.dx + p2.dx) * t +
                  (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
                  (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3),
          0.5 *
              ((2 * p1.dy) +
                  (-p0.dy + p2.dy) * t +
                  (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
                  (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3),
        );
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _SketchLineChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.color != color ||
      oldDelegate.drawConfig != drawConfig;
}

/// 统计页通用卡：手绘纸面板（纸底 + 淡排线 + 墨线框）
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return DsSketchPanel(
      theme: DSThemeBridge.resolve(context),
      radius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }
}
