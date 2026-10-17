import 'package:flutter/material.dart';
import 'package:get/get.dart';
// WiredDrawTransition 由 skribble 包提供
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/chat_screen.dart';
import 'package:aboutme/widgets/stats/sketch_stats.dart';
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

  static const _typeKeys = {
    MessageType.sent: 'chat_typeSent',
    MessageType.received: 'chat_typeReceived',
    MessageType.file: 'chat_file',
    MessageType.image: 'chat_photo',
    MessageType.video: 'chat_video',
    MessageType.audio: 'chat_typeAudio',
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

    return StatsSketchCard(
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
                            'chat_statsUnit'.tr,
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
                      'chat_statsVsYesterday'.trParams({
                        'diff': '${diff >= 0 ? '+' : ''}$diff',
                      }),
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
                  'chat_statsTotalSummary'.trParams({
                    'messages': '${_messages.length}',
                    'channels': '${_channels.length}',
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                _streakDays > 0
                    ? 'chat_statsStreak'.trParams({'count': '$_streakDays'})
                    : 'chat_statsNotStarted'.tr,
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

    return StatsSketchCard(
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
                  'chat_statsTodayChart'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${statsDateLabel(now)} · ${today.length} ${'chat_statsUnit'.tr}',
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
                return SketchLineChart(
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
                      statsHourLabel(i * 2),
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

    // 按 weekday 索引（周一 = 0）
    final dayNames = List.generate(7, (i) => statsWeekdayShort(i + 1));

    return StatsSketchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'chat_statsDailyChart'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                'chat_statsDailyAvg'.trParams({
                  'count': avg.toStringAsFixed(1),
                }),
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
                  'chat_messageCount'.trParams({
                    'count': '${counts[_selectedDay]}',
                  }),
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
    final label = statsWeekdayLabel(day.weekday);
    return isToday ? '$label (${'chat_today'.tr})' : label;
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
    final entries = _typeKeys.entries
        .where((e) => counts[e.key] != null && counts[e.key]! > 0)
        .toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return StatsSketchCard(
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
                  'chat_statsTypeChart'.tr,
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
                    '${e.value.tr} ${counts[e.key]}',
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
                  'chat_statsRanking'.tr,
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
          StatsSketchCard(
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
          StatsSketchCard(
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 点击进入对应频道聊天页（与频道列表入口一致）
        onTap: () => NavigationHelper.openContainerWithHero(
          context,
          (context) => ChatScreen(channel: channel),
          transitionDuration: const Duration(milliseconds: 400),
        ),
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
              '$count ${'chat_statsUnit'.tr}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
