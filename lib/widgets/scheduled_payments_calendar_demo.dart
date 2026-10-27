import 'package:flutter/material.dart';

import 'package:aboutme/widgets/photo_calendar_card.dart';

/// 定期付款日历 Demo（复刻自 scheduled_recurring_payments_ui.html）
///
/// 演示 [PhotoCalendarCard] 的回调用法：
/// - 过滤器：切换后把被过滤的日期传入 dimmedDays 变暗
/// - 点击空白日期：通过 onEmptyDayTap 弹出快捷安排面板，可指派 / 移除付款
/// - 悬停浮层：通过 previewBuilder 提供付款详情内容
class ScheduledPaymentsCalendarDemo extends StatefulWidget {
  const ScheduledPaymentsCalendarDemo({super.key});

  @override
  State<ScheduledPaymentsCalendarDemo> createState() =>
      _ScheduledPaymentsCalendarDemoState();
}

enum _Filter { all, friends, subs }

class _ScheduledPaymentsCalendarDemoState
    extends State<ScheduledPaymentsCalendarDemo> {
  late final Map<int, PhotoCalendarEntry> _schedule = _buildInitialSchedule();
  _Filter _filter = _Filter.all;
  int? _popoverDay;

  static Map<int, PhotoCalendarEntry> _buildInitialSchedule() {
    const u = 'https://images.unsplash.com/';
    return {
      3: PhotoCalendarEntry(
        isFriend: true,
        name: 'Lucas Vance',
        note: 'Split Gym & Padel',
        amount: 65.00,
        rot: 13,
        avatar: '${u}photo-1507003211169-0a1dd7228f2d?w=240&q=80',
        photos: [
          '${u}photo-1507003211169-0a1dd7228f2d?w=240&q=80',
          '${u}photo-1526506118085-60ce8714f8c5?w=240&q=80',
          '${u}photo-1554068865-24cecd4e34b8?w=240&q=80',
          '${u}photo-1517838277536-f5f99be501cd?w=240&q=80',
          '${u}photo-1534438327276-14e5300c3a48?w=240&q=80',
          '${u}photo-1476480862126-209bfaa8edc8?w=240&q=80',
        ],
      ),
      8: PhotoCalendarEntry(
        isFriend: true,
        name: 'Elena Rostova',
        note: 'Shared Family Plan',
        amount: 42.00,
        rot: -13,
        avatar: '${u}photo-1524504388940-b1c1722653e1?w=240&q=80',
        photos: [
          '${u}photo-1524504388940-b1c1722653e1?w=240&q=80',
          '${u}photo-1515886657613-9f3515b0c78f?w=240&q=80',
          '${u}photo-1507525428034-b723cf961d3e?w=240&q=80',
          '${u}photo-1529156069898-49953e39b3ac?w=240&q=80',
          '${u}photo-1516483638261-f4dbaf036963?w=240&q=80',
          '${u}photo-1513836279014-a89f7a76ae86?w=240&q=80',
        ],
      ),
      13: PhotoCalendarEntry(
        isFriend: true,
        name: 'Amara Okafor',
        note: 'Mom & Sister Gift Fund',
        amount: 85.00,
        rot: -9,
        avatar: '${u}photo-1531123897727-8f129e1688ce?w=240&q=80',
        photos: [
          '${u}photo-1531123897727-8f129e1688ce?w=240&q=80',
          '${u}photo-1534528741775-53994a69daeb?w=240&q=80',
          '${u}photo-1544005313-94ddf0286df2?w=240&q=80',
          '${u}photo-1523264766116-1e09b3145b84?w=240&q=80',
          '${u}photo-1509198397868-475647b2a1e5?w=240&q=80',
          '${u}photo-1469474968028-56623f02e42e?w=240&q=80',
        ],
      ),
      18: PhotoCalendarEntry(
        isFriend: false,
        name: 'GitHub & Spotify',
        note: '3 Dev & Media Subscriptions',
        amount: 26.99,
        items: const [
          PhotoCalendarSubItem(
            label: 'iCloud+',
            price: '\$2.99',
            bg: Color(0xFF6E6E73),
            icon: Icon(Icons.cloud, color: Colors.white70, size: 24),
            tx: 9,
            ty: -7,
            rot: 18,
            scale: 0.92,
            hoverTx: 28,
            hoverTy: -22,
            hoverRot: 22,
          ),
          PhotoCalendarSubItem(
            label: 'GitHub Copilot',
            price: '\$10.00',
            bg: Color(0xFF1B1B1D),
            icon: Icon(Icons.code, color: Colors.white, size: 28),
            tx: -10,
            ty: -9,
            hoverTx: -26,
            hoverTy: -16,
            hoverRot: -12,
          ),
          PhotoCalendarSubItem(
            label: 'Spotify Duo',
            price: '\$14.00',
            bg: Color(0xFF121212),
            icon: Icon(Icons.graphic_eq, color: Color(0xFF1ED760), size: 26),
            tx: 6,
            ty: 14,
            hoverTx: 12,
            hoverTy: 18,
            hoverRot: 8,
          ),
        ],
        photos: [
          '${u}photo-1555066931-4365d14bab8c?w=240&q=80',
          '${u}photo-1511671782779-c97d3d27a1d4?w=240&q=80',
          '${u}photo-1514525253161-7a46d19cd819?w=240&q=80',
          '${u}photo-1498050108023-c5249f4df085?w=240&q=80',
          '${u}photo-1470225620780-dba8ba36b745?w=240&q=80',
          '${u}photo-1518770660439-4636190af475?w=240&q=80',
        ],
      ),
      23: PhotoCalendarEntry(
        isFriend: false,
        name: 'Netflix & X',
        note: '2 Entertainment Subscriptions',
        amount: 23.99,
        items: const [
          PhotoCalendarSubItem(
            label: 'X Premium',
            price: '\$8.00',
            bg: Color(0xFF050505),
            icon: Text(
              'X',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            tx: 9,
            ty: -12,
            rot: 17,
            scale: 0.98,
            hoverTx: 24,
            hoverTy: -18,
            hoverRot: 18,
          ),
          PhotoCalendarSubItem(
            label: 'Netflix 4K',
            price: '\$15.99',
            bg: Color(0xFF0A0A0A),
            icon: Text(
              'N',
              style: TextStyle(
                color: Color(0xFFE50914),
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            tx: -6,
            ty: 5,
            hoverTx: -20,
            hoverTy: 10,
            hoverRot: -10,
          ),
        ],
        photos: [
          '${u}photo-1574375927938-d5a98e8ffe85?w=240&q=80',
          '${u}photo-1489599849927-2ee91cede3ba?w=240&q=80',
          '${u}photo-1536440136628-849c177e76a1?w=240&q=80',
          '${u}photo-1517604931442-7e0c8ed2963c?w=240&q=80',
          '${u}photo-1522869635100-9f4c5e86aa37?w=240&q=80',
          '${u}photo-1478720568477-152d9b164e26?w=240&q=80',
        ],
      ),
      28: PhotoCalendarEntry(
        isFriend: true,
        name: 'Mateo Silva',
        note: 'Studio Utilities Split',
        amount: 26.00,
        rot: 6,
        avatar: '${u}photo-1500648767791-00dcc994a43e?w=240&q=80',
        photos: [
          '${u}photo-1500648767791-00dcc994a43e?w=240&q=80',
          '${u}photo-1519085360753-af0119f7cbe7?w=240&q=80',
          '${u}photo-1501196354995-cbb51c65aaea?w=240&q=80',
          '${u}photo-1492562080023-ab3db95bfbce?w=240&q=80',
          '${u}photo-1504257432389-52343af06ae3?w=240&q=80',
          '${u}photo-1513836279014-a89f7a76ae86?w=240&q=80',
        ],
      ),
    };
  }

  List<PhotoCalendarEntry> get _presets => [
        PhotoCalendarEntry(
          isFriend: false,
          name: 'Claude AI',
          note: 'Claude Pro Monthly',
          amount: 20.00,
          items: const [
            PhotoCalendarSubItem(
              label: 'Claude Pro',
              price: '\$20.00',
              bg: Color(0xFFD97757),
              icon: Icon(Icons.auto_awesome, color: Colors.white, size: 24),
              rot: -8,
            ),
          ],
        ),
        PhotoCalendarEntry(
          isFriend: false,
          name: 'YouTube',
          note: 'YouTube Premium',
          amount: 13.99,
          items: const [
            PhotoCalendarSubItem(
              label: 'YouTube',
              price: '\$13.99',
              bg: Color(0xFF161616),
              icon: Icon(Icons.play_arrow, color: Color(0xFFFF0000), size: 28),
              rot: 10,
            ),
          ],
        ),
        PhotoCalendarEntry(
          isFriend: true,
          name: 'Sophia Lin',
          note: 'Coffee & Book Club',
          amount: 30.00,
          rot: -11,
          avatar:
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=240&q=80',
        ),
        PhotoCalendarEntry(
          isFriend: true,
          name: 'Marcus Chen',
          note: 'Basketball Court Split',
          amount: 35.00,
          rot: 12,
          avatar:
              'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=240&q=80',
        ),
      ];

  bool _isDimmed(PhotoCalendarEntry p) =>
      (_filter == _Filter.friends && !p.isFriend) ||
      (_filter == _Filter.subs && p.isFriend);

  Set<int> get _dimmedDays => {
        for (final e in _schedule.entries)
          if (_isDimmed(e.value)) e.key,
      };

  static String _ordinal(int n) {
    const s = ['th', 'st', 'nd', 'rd'];
    final v = n % 100;
    final i = (v - 20) % 10;
    final suffix = (i >= 0 && i < s.length)
        ? s[i]
        : (v < s.length ? s[v] : s[0]);
    return '$n$suffix';
  }

  void _assignPreset(PhotoCalendarEntry preset) {
    final day = _popoverDay;
    if (day == null) return;
    setState(() {
      _schedule[day] = preset.copy();
      _popoverDay = null;
    });
  }

  void _removePayment() {
    final day = _popoverDay;
    if (day == null) return;
    setState(() {
      _schedule.remove(day);
      _popoverDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        foregroundColor: Colors.white,
        title: const Text('定期付款日历'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 496),
            child: Column(
              children: [
                _buildFilterBar(),
                const SizedBox(height: 20),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PhotoCalendarCard(
                      entries: _schedule,
                      dimmedDays: _dimmedDays,
                      onEmptyDayTap: (day) =>
                          setState(() => _popoverDay = day),
                      onEntryTap: (day, entry) =>
                          setState(() => _popoverDay = null),
                      previewBuilder: _buildPreviewContent,
                    ),
                    // 对齐卡片内边距(32,40,32,36)+原弹出层偏移(8,0)
                    if (_popoverDay != null)
                      Positioned(
                        left: 40,
                        right: 40,
                        bottom: 36,
                        child: _buildPopover(),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final counts = _schedule.values;
    final friends = counts.where((p) => p.isFriend).length;
    final subs = counts.length - friends;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _filterChip('All (${counts.length})', _Filter.all),
          _filterChip('Friends ($friends)', _Filter.friends),
          _filterChip('Subscriptions ($subs)', _Filter.subs),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _Filter f) {
    final active = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? Colors.black : const Color(0xFF8A8A8E),
          ),
        ),
      ),
    );
  }

  /// 悬停浮层内容：好友显示头像+备注，订阅显示明细 chips
  Widget _buildPreviewContent(int day, PhotoCalendarEntry p) {
    return p.isFriend
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Dot(color: Color(0xFF34D399)),
                  const SizedBox(width: 6),
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\$${p.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${p.note} • Monthly on ${_ordinal(day)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF8A8A8E),
                ),
              ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '\$${p.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in p.items)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${item.label} ${item.price}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
  }

  Widget _buildPopover() {
    final day = _popoverDay!;
    final existing = _schedule[day];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xF2222225),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      existing != null
                          ? 'MANAGE PAYMENT'
                          : 'NEW RECURRING PAYMENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    existing != null
                        ? '${_ordinal(day)} — ${existing.name} (\$${existing.amount.toStringAsFixed(2)})'
                        : 'Schedule on the ${_ordinal(day)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _popoverDay = null),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: Icon(Icons.close,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final preset in _presets)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _buildPresetButton(preset),
                  ),
                ),
            ],
          ),
          if (existing != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _removePayment,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Remove Existing',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFCA5A5),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetButton(PhotoCalendarEntry preset) {
    return GestureDetector(
      onTap: () => _assignPreset(preset),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            if (preset.isFriend)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  preset.avatar ?? '',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 36,
                    height: 36,
                    color: const Color(0xFF2A2A2E),
                    alignment: Alignment.center,
                    child: Text(preset.name.characters.first),
                  ),
                ),
              )
            else
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: preset.items.first.bg,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: IconTheme(
                  data: const IconThemeData(size: 20),
                  child: preset.items.first.icon,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              preset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            Text(
              '\$${preset.amount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF34D399),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
