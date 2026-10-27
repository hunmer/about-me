import 'package:flutter/material.dart';

/// 定期付款日历 Demo（复刻自 scheduled_recurring_payments_ui.html）
///
/// - 31 天日历格子，好友头像徽章 / 订阅图标堆叠
/// - 悬停显示付款详情浮层，日期数字从徽章下方探出
/// - 点击徽章展开横向照片条（含语音波形卡片），其余格子变暗
/// - 点击空白日期弹出快捷安排面板，可指派 / 移除付款
class ScheduledPaymentsCalendarDemo extends StatefulWidget {
  const ScheduledPaymentsCalendarDemo({super.key});

  @override
  State<ScheduledPaymentsCalendarDemo> createState() =>
      _ScheduledPaymentsCalendarDemoState();
}

enum _Filter { all, friends, subs }

class _SubItem {
  const _SubItem({
    required this.label,
    required this.price,
    required this.bg,
    required this.icon,
    this.tx = 0,
    this.ty = 0,
    this.rot = 0,
    this.scale = 1,
    this.hoverTx = 0,
    this.hoverTy = -8,
    this.hoverRot = 0,
  });

  final String label;
  final String price;
  final Color bg;
  final Widget icon;
  final double tx;
  final double ty;
  final double rot;
  final double scale;
  final double hoverTx;
  final double hoverTy;
  final double hoverRot;
}

class _Payment {
  _Payment({
    required this.isFriend,
    required this.name,
    required this.note,
    required this.amount,
    this.rot = 0,
    this.avatar,
    this.photos = const [],
    this.items = const [],
  });

  final bool isFriend;
  final String name;
  final String note;
  final double amount;
  double rot;
  String? avatar;
  List<String> photos;
  List<_SubItem> items;

  _Payment copy() => _Payment(
        isFriend: isFriend,
        name: name,
        note: note,
        amount: amount,
        rot: rot,
        avatar: avatar,
        photos: List.of(photos),
        items: List.of(items),
      );
}

class _ScheduledPaymentsCalendarDemoState
    extends State<ScheduledPaymentsCalendarDemo>
    with SingleTickerProviderStateMixin {
  static const _spring = Cubic(0.34, 1.56, 0.64, 1);

  static const double _cellH = 62;
  static const double _rowGap = 10;
  static const int _startOffset = 2;
  static const int _totalDays = 31;

  late final Map<int, _Payment> _schedule = _buildInitialSchedule();
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  _Filter _filter = _Filter.all;
  int? _hoveredDay;
  int? _expandedDay;
  int? _popoverDay;
  bool _wavePlaying = false;

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  static Map<int, _Payment> _buildInitialSchedule() {
    const u = 'https://images.unsplash.com/';
    return {
      3: _Payment(
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
      8: _Payment(
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
      13: _Payment(
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
      18: _Payment(
        isFriend: false,
        name: 'GitHub & Spotify',
        note: '3 Dev & Media Subscriptions',
        amount: 26.99,
        items: const [
          _SubItem(
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
          _SubItem(
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
          _SubItem(
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
      23: _Payment(
        isFriend: false,
        name: 'Netflix & X',
        note: '2 Entertainment Subscriptions',
        amount: 23.99,
        items: const [
          _SubItem(
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
          _SubItem(
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
      28: _Payment(
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

  List<_Payment> get _presets => [
        _Payment(
          isFriend: false,
          name: 'Claude AI',
          note: 'Claude Pro Monthly',
          amount: 20.00,
          items: const [
            _SubItem(
              label: 'Claude Pro',
              price: '\$20.00',
              bg: Color(0xFFD97757),
              icon: Icon(Icons.auto_awesome, color: Colors.white, size: 24),
              rot: -8,
            ),
          ],
        ),
        _Payment(
          isFriend: false,
          name: 'YouTube',
          note: 'YouTube Premium',
          amount: 13.99,
          items: const [
            _SubItem(
              label: 'YouTube',
              price: '\$13.99',
              bg: Color(0xFF161616),
              icon: Icon(Icons.play_arrow, color: Color(0xFFFF0000), size: 28),
              rot: 10,
            ),
          ],
        ),
        _Payment(
          isFriend: true,
          name: 'Sophia Lin',
          note: 'Coffee & Book Club',
          amount: 30.00,
          rot: -11,
          avatar:
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=240&q=80',
        ),
        _Payment(
          isFriend: true,
          name: 'Marcus Chen',
          note: 'Basketball Court Split',
          amount: 35.00,
          rot: 12,
          avatar:
              'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=240&q=80',
        ),
      ];

  bool _isDimmed(_Payment p) =>
      (_filter == _Filter.friends && !p.isFriend) ||
      (_filter == _Filter.subs && p.isFriend);

  double get _monthlyTotal {
    var sum = 0.0;
    for (final p in _schedule.values) {
      if (_filter == _Filter.all ||
          (_filter == _Filter.friends && p.isFriend) ||
          (_filter == _Filter.subs && !p.isFriend)) {
        sum += p.amount;
      }
    }
    return sum;
  }

  static String _ordinal(int n) {
    const s = ['th', 'st', 'nd', 'rd'];
    final v = n % 100;
    final i = (v - 20) % 10;
    final suffix = (i >= 0 && i < s.length)
        ? s[i]
        : (v < s.length ? s[v] : s[0]);
    return '$n$suffix';
  }

  void _toggleStrip(int day) {
    setState(() {
      _popoverDay = null;
      _expandedDay = _expandedDay == day ? null : day;
    });
  }

  void _closeStrip() {
    if (_expandedDay != null) setState(() => _expandedDay = null);
  }

  void _openPopover(int day) {
    setState(() {
      _closeStripSilently();
      _popoverDay = day;
    });
  }

  void _closeStripSilently() => _expandedDay = null;

  void _assignPreset(_Payment preset) {
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
                _buildCard(),
                const SizedBox(height: 20),
                _buildTotalPill(),
                const SizedBox(height: 24),
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
      onTap: () => setState(() {
        _filter = f;
        _expandedDay = null;
      }),
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

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 36),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 60,
            offset: const Offset(0, 30),
            spreadRadius: -15,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scheduled Recurring Payments',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Budget your monthly expenses in advance or easily schedule recurring payments to friends and family.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.38,
                  color: Color(0xFF8A8A8E),
                ),
              ),
              const SizedBox(height: 28),
              _buildWeekHeader(),
              const SizedBox(height: 12),
              _buildCalendar(),
            ],
          ),
          if (_popoverDay != null) _buildPopover(),
        ],
      ),
    );
  }

  Widget _buildWeekHeader() {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: Center(
              child: Text(
                d,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8A8A8E),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCalendar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const totalCells = _startOffset + _totalDays;
        const rows = (totalCells + 6) ~/ 7;
        final cells = <Widget>[];
        for (var i = 0; i < totalCells; i++) {
          if (i < _startOffset) {
            cells.add(const SizedBox(height: _cellH));
          } else {
            cells.add(_buildDayCell(i - _startOffset + 1));
          }
        }

        final rowWidgets = <Widget>[];
        for (var r = 0; r < rows; r++) {
          rowWidgets.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: cells[r * 7 + c]),
              ],
            ),
          );
          if (r < rows - 1) rowWidgets.add(const SizedBox(height: _rowGap));
        }

        final expanded = _expandedDay;
        double? stripTop;
        if (expanded != null) {
          final row = ((expanded - 1) + _startOffset) ~/ 7;
          stripTop = (row * (_cellH + _rowGap) - 76).clamp(-18.0, 9999.0).toDouble();
        }

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _closeStrip,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(children: rowWidgets),
              if (expanded != null && _schedule.containsKey(expanded))
                Positioned(
                  left: -14,
                  right: -14,
                  top: stripTop,
                  height: 74,
                  child: _buildPhotoStrip(expanded, _schedule[expanded]!),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayCell(int day) {
    final payment = _schedule[day];
    final hovered = _hoveredDay == day;
    final stripOpen = _expandedDay != null;
    final isActiveStripCell = _expandedDay == day;
    final dimByStrip = stripOpen && !isActiveStripCell;
    final dimByFilter = payment != null && _isDimmed(payment);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredDay = day),
      onExit: (_) => setState(() => _hoveredDay = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isActiveStripCell) return;
          if (payment != null) {
            _toggleStrip(day);
          } else {
            _openPopover(day);
          }
        },
        child: SizedBox(
          height: _cellH,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: dimByStrip ? 0.26 : 1,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _buildDateNumber(day, payment, hovered, isActiveStripCell),
                if (payment != null)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: isActiveStripCell ? 0 : (dimByFilter ? 0.2 : 1),
                    child: IgnorePointer(
                      ignoring: isActiveStripCell,
                      child: payment.isFriend
                          ? _buildAvatarBadge(day, payment, hovered)
                          : _buildStackBadge(day, payment, hovered),
                    ),
                  ),
                if (payment != null && !isActiveStripCell)
                  _buildTooltip(day, payment, hovered),
                if (isActiveStripCell) _buildCloseButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateNumber(
      int day, _Payment? payment, bool hovered, bool hiddenByStrip) {
    final covered = payment != null;
    final peek = covered && hovered && !hiddenByStrip;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: _spring,
      width: 46,
      height: 46,
      transformAlignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(0.0, peek ? 34.0 : 0.0)
        ..scale(covered && !peek ? 0.5 : (hovered && !covered ? 1.1 : 1.0)),
      decoration: BoxDecoration(
        color: hovered && !covered
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: hiddenByStrip ? 0 : (covered && !peek ? 0 : 1),
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: covered ? 13 : 22,
            fontWeight: covered ? FontWeight.w600 : FontWeight.w400,
            color: covered
                ? Colors.white.withValues(alpha: 0.55)
                : const Color(0xFFF4F4F6),
          ),
        ),
      ),
    );
  }

  Widget _buildEntrance({required int day, required Widget child}) {
    final start = (0.15 + day * 0.02).clamp(0.0, 0.8).toDouble();
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, _) {
        final t = CurvedAnimation(
          parent: _entrance,
          curve: Interval(start, 1, curve: _spring),
        ).value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - t)),
            child: Transform.scale(scale: 0.3 + 0.7 * t, child: child),
          ),
        );
      },
    );
  }

  Widget _buildAvatarBadge(int day, _Payment p, bool hovered) {
    return _buildEntrance(
      day: day,
      child: GestureDetector(
        onTap: () => _toggleStrip(day),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: _spring,
          width: 58,
          height: 58,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(0.0, hovered ? -6.0 : -2.0)
            ..rotateZ((hovered ? 0 : p.rot) * 3.14159 / 180)
            ..scale(hovered ? 1.16 : 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: hovered
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.55),
              width: hovered ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: hovered ? 32 : 24,
                offset: Offset(0, hovered ? 18 : 10),
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13.5),
            child: Image.network(
              p.avatar ?? '',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF2A2A2E),
                alignment: Alignment.center,
                child: Text(
                  p.name.characters.first,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStackBadge(int day, _Payment p, bool hovered) {
    return _buildEntrance(
      day: day,
      child: GestureDetector(
        onTap: () => _toggleStrip(day),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < p.items.length; i++)
                _buildSubIcon(p.items[i], hovered),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubIcon(_SubItem item, bool hovered) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 550),
      curve: _spring,
      width: 50,
      height: 50,
      transformAlignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(hovered ? item.hoverTx : item.tx,
            hovered ? item.hoverTy : item.ty)
        ..rotateZ((hovered ? item.hoverRot : item.rot) * 3.14159 / 180)
        ..scale((hovered ? 1.1 : 1.0) * item.scale),
      decoration: BoxDecoration(
        color: item.bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.white.withValues(alpha: hovered ? 0.35 : 0.16),
          width: hovered ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: hovered ? 28 : 20,
            offset: Offset(0, hovered ? 16 : 8),
            spreadRadius: -2,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: item.icon,
    );
  }

  Widget _buildTooltip(int day, _Payment p, bool hovered) {
    return Positioned(
      bottom: _cellH + 8,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 280),
          opacity: hovered ? 1 : 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 380),
            curve: _spring,
            offset: hovered ? Offset.zero : const Offset(0, 0.25),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1F).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.14)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: p.isFriend
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
                                  color:
                                      Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${item.label} ${item.price}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: _closeStrip,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          Icons.close,
          size: 16,
          color: Colors.white.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  Widget _buildPhotoStrip(int day, _Payment p) {
    final cellIndex = (day - 1) + _startOffset;
    final col = cellIndex % 7;
    final photos = p.photos.take(6).toList();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: _spring,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform(
          alignment: Alignment(((col + 0.5) / 7) * 2 - 1, 1),
          transform: Matrix4.identity()
            ..translate(0.0, 24 * (1 - t))
            ..scale(0.22 + 0.78 * t, 0.5 + 0.5 * t),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF2E2C2A).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.88),
              blurRadius: 50,
              offset: const Offset(0, 26),
              spreadRadius: -10,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(child: _buildWaveformItem()),
            const SizedBox(width: 6),
            for (var i = 0; i < photos.length; i++) ...[
              Expanded(child: _buildStripPhoto(p, photos[i], i + 1)),
              if (i < photos.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformItem() {
    const heights = [14.0, 24.0, 36.0, 20.0, 40.0, 28.0, 16.0, 30.0, 22.0, 14.0];
    return GestureDetector(
      onTap: () => setState(() => _wavePlaying = !_wavePlaying),
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xF23E3A37), Color(0xF2242220)],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < heights.length; i++)
              _WaveBar(
                height: heights[i],
                delay: Duration(milliseconds: i * 75),
                playing: _wavePlaying,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStripPhoto(_Payment p, String url, int slot) {
    final isCover = p.isFriend && p.avatar == url;
    return GestureDetector(
      onTap: () {
        if (p.isFriend) {
          setState(() => p.avatar = url);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isCover
                ? const Color(0xFF38BDF8)
                : Colors.white.withValues(alpha: 0.15),
            width: isCover ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF2A2A2E),
              alignment: Alignment.center,
              child: Text('$slot',
                  style: const TextStyle(color: Colors.white54)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopover() {
    final day = _popoverDay!;
    final existing = _schedule[day];
    return Positioned(
      left: 8,
      right: 8,
      bottom: 0,
      child: Container(
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
      ),
    );
  }

  Widget _buildPresetButton(_Payment preset) {
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

  Widget _buildTotalPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Monthly Scheduled: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Text(
            '\$${_monthlyTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF34D399),
            ),
          ),
        ],
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

class _WaveBar extends StatefulWidget {
  const _WaveBar({
    required this.height,
    required this.delay,
    required this.playing,
  });

  final double height;
  final Duration delay;
  final bool playing;

  @override
  State<_WaveBar> createState() => _WaveBarState();
}

class _WaveBarState extends State<_WaveBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    reverseDuration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_WaveBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.playing) {
      Future.delayed(widget.delay, () {
        if (mounted && widget.playing) _controller.repeat(reverse: true);
      });
    } else {
      _controller.stop();
      _controller.animateTo(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 0.45 + 0.8 * _controller.value;
        return Container(
          width: 3.5,
          height: widget.height * scale,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 0.6),
          ),
        );
      },
    );
  }
}
