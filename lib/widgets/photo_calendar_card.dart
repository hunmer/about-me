import 'package:flutter/material.dart';

/// 图片日历卡片 —— 图片 + 日历结合的展示组件
///
/// - 31 天日历格子，有内容的日期展示头像徽章 / 图标堆叠
/// - 点击徽章展开横向照片条（含语音波形卡片），其余格子变暗
/// - 悬停浮层内容由 [previewBuilder] 提供，点击空白日期交给 [onEmptyDayTap] 处理
class PhotoCalendarCard extends StatefulWidget {
  const PhotoCalendarCard({
    super.key,
    required this.entries,
    this.dimmedDays = const {},
    this.onEmptyDayTap,
    this.onEntryTap,
    this.previewBuilder,
  });

  /// key 为日期（1-31），有内容的日期显示徽章
  final Map<int, PhotoCalendarEntry> entries;

  /// 需要变暗的日期（如被过滤器排除的条目）
  final Set<int> dimmedDays;

  /// 点击空白日期回调，由外部弹出添加菜单
  final void Function(int day)? onEmptyDayTap;

  /// 点击有内容的日期回调（组件内部会同时展开/收起照片条）
  final void Function(int day, PhotoCalendarEntry entry)? onEntryTap;

  /// 悬停某日期时浮层内展示的内容
  final Widget Function(int day, PhotoCalendarEntry entry)? previewBuilder;

  @override
  State<PhotoCalendarCard> createState() => _PhotoCalendarCardState();
}

/// 日历上一天的展示条目：好友头像或订阅图标堆叠
class PhotoCalendarEntry {
  PhotoCalendarEntry({
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
  final double rot;
  String? avatar;
  List<String> photos;
  List<PhotoCalendarSubItem> items;

  PhotoCalendarEntry copy() => PhotoCalendarEntry(
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

/// 订阅堆叠徽章中的单个图标
class PhotoCalendarSubItem {
  const PhotoCalendarSubItem({
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

class _PhotoCalendarCardState extends State<PhotoCalendarCard>
    with SingleTickerProviderStateMixin {
  static const _spring = Cubic(0.34, 1.56, 0.64, 1);

  static const double _cellH = 62;
  static const double _rowGap = 10;
  static const int _startOffset = 2;
  static const int _totalDays = 31;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  int? _hoveredDay;
  int? _expandedDay;
  bool _wavePlaying = false;

  @override
  void didUpdateWidget(covariant PhotoCalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 过滤集变化（切换过滤器）时收起照片条
    final old = oldWidget.dimmedDays;
    final cur = widget.dimmedDays;
    if (_expandedDay != null &&
        (old.length != cur.length || !cur.containsAll(old))) {
      _expandedDay = null;
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _toggleStrip(int day) {
    final entry = widget.entries[day];
    if (entry == null) return;
    setState(() => _expandedDay = _expandedDay == day ? null : day);
    widget.onEntryTap?.call(day, entry);
  }

  void _closeStrip() {
    if (_expandedDay != null) setState(() => _expandedDay = null);
  }

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWeekHeader(),
          const SizedBox(height: 12),
          _buildCalendar(),
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
                  Expanded(
                    child: r * 7 + c < cells.length
                        ? cells[r * 7 + c]
                        : const SizedBox(height: _cellH),
                  ),
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
              if (expanded != null && widget.entries.containsKey(expanded))
                Positioned(
                  left: -14,
                  right: -14,
                  top: stripTop,
                  height: 74,
                  child: _buildPhotoStrip(expanded, widget.entries[expanded]!),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayCell(int day) {
    final payment = widget.entries[day];
    final hovered = _hoveredDay == day;
    final stripOpen = _expandedDay != null;
    final isActiveStripCell = _expandedDay == day;
    final dimByStrip = stripOpen && !isActiveStripCell;
    final dimByFilter = widget.dimmedDays.contains(day);
    final preview = widget.previewBuilder;

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
            setState(() => _expandedDay = null);
            widget.onEmptyDayTap?.call(day);
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
                if (payment != null && !isActiveStripCell && preview != null)
                  _buildTooltip(day, payment, hovered, preview),
                if (isActiveStripCell) _buildCloseButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateNumber(
      int day, PhotoCalendarEntry? payment, bool hovered, bool hiddenByStrip) {
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

  Widget _buildAvatarBadge(int day, PhotoCalendarEntry p, bool hovered) {
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

  Widget _buildStackBadge(int day, PhotoCalendarEntry p, bool hovered) {
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

  Widget _buildSubIcon(PhotoCalendarSubItem item, bool hovered) {
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

  Widget _buildTooltip(
      int day,
      PhotoCalendarEntry p,
      bool hovered,
      Widget Function(int day, PhotoCalendarEntry entry) preview) {
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
              child: preview(day, p),
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

  Widget _buildPhotoStrip(int day, PhotoCalendarEntry p) {
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

  Widget _buildStripPhoto(PhotoCalendarEntry p, String url, int slot) {
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
