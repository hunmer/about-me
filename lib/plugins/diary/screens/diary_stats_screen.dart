import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/plugins/diary/models/diary_entry.dart';
import 'package:aboutme/plugins/diary/utils/diary_utils.dart';
import 'package:aboutme/plugins/diary/widgets/diary_mood_face.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 心情罐分类（对应 HTML 设计稿的 Perfect / Good / Nice）
enum JarMood { perfect, good, nice }

class _JarMoodSpec {
  final JarMood type;
  final String name;
  final Color barColor;
  final Color pillBg;
  final Color pillText;
  final List<({String cn, String en})> quotes;

  const _JarMoodSpec({
    required this.type,
    required this.name,
    required this.barColor,
    required this.pillBg,
    required this.pillText,
    required this.quotes,
  });
}

const Map<JarMood, _JarMoodSpec> _jarMoodSpecs = {
  JarMood.perfect: _JarMoodSpec(
    type: JarMood.perfect,
    name: 'Perfect Day',
    barColor: Color(0xFFEBB142),
    pillBg: Color(0x33EBB142),
    pillText: Color(0xFFF9C859),
    quotes: [
      (cn: '“今天所有的美好都如约而至，连微风都带着甜味。”', en: '"Every little sparkle today made my heart dance with joy."'),
      (cn: '“眼里有星辰，心中有暖阳，今天是满分闪耀的一天！”', en: '"Sunlight in my pocket and stardust in my eyes—what a perfect day."'),
      (cn: '“把今天积攒的灿烂笑脸装进玻璃罐，留给未来的自己发光。”', en: '"Bottling up today\'s golden laughter to brighten every tomorrow."'),
    ],
  ),
  JarMood.good: _JarMoodSpec(
    type: JarMood.good,
    name: 'Good Day',
    barColor: Color(0xFF6C99C3),
    pillBg: Color(0x386C99C3),
    pillText: Color(0xFF8EC5FC),
    quotes: [
      (cn: '“平静而充实的时光，像冰川蓝的湖面一样温柔清澈。”', en: '"Calm, clear, and gentle—like a quiet breeze across a blue lake."'),
      (cn: '“不必事事完美，步履不停且内心安宁就是最好的日子。”', en: '"Peace in the heart and steady steps make for a truly good day."'),
      (cn: '“抬头看见好看的云朵，耳机里恰好播放着最喜欢的歌。”', en: '"Pretty clouds overhead and my favorite song playing right on cue."'),
    ],
  ),
  JarMood.nice: _JarMoodSpec(
    type: JarMood.nice,
    name: 'Nice Day',
    barColor: Color(0xFFC3895D),
    pillBg: Color(0x38C3895D),
    pillText: Color(0xFFF0B284),
    quotes: [
      (cn: '“生活藏着许多蜜桃味的小确幸，慢下来就能撞个满怀。”', en: '"Life hides sweet little peach-colored surprises around every corner."'),
      (cn: '“一杯热饮，一个微笑，平凡日子里的温暖最抚凡人心。”', en: '"A warm drink and a gentle smile—simple joys that warm the soul."'),
      (cn: '“给努力生活的自己比个耶，每一个温柔的瞬间都算数。”', en: '"Cheers to myself for showing up today; every gentle moment counts."'),
    ],
  ),
};

const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// 日记心情 emoji -> 罐子分类
JarMood _jarMoodOf(String mood) {
  switch (diaryMoodSpecOf(mood).kind) {
    case DiaryMoodFaceKind.happy:
    case DiaryMoodFaceKind.excited:
    case DiaryMoodFaceKind.loved:
      return JarMood.perfect;
    case DiaryMoodFaceKind.tired:
    case DiaryMoodFaceKind.sad:
    case DiaryMoodFaceKind.angry:
      return JarMood.nice;
    case DiaryMoodFaceKind.surprised:
    case DiaryMoodFaceKind.thinking:
    case DiaryMoodFaceKind.neutral:
      return JarMood.good;
  }
}

// ==================== 物理常量（与 HTML 版一致，逻辑坐标 340x368） ====================
const double _kJarW = 340;
const double _kJarH = 368;
const double _kGravity = 0.45;
const double _kRestitution = 0.72;
const double _kFriction = 0.992;
const double _kAngularDamping = 0.96;
const int _kSubSteps = 6;

const double _kLeftWall = 50;
const double _kRightWall = 290;
const double _kTopCeiling = 64;
const double _kBottomFloor = 339;
const double _kBottomCornerR = 48;

const double _kBaseRadius = 23.5;
const double _kMinRadius = 6.5;
const double _kJarUsableArea = 236 * 265;
const double _kMaxFillRatio = 0.80;
const double _kPackingEfficiency = 0.74;

double _computeTargetRadius(int count) {
  if (count <= 0) return _kBaseRadius;
  final maxArea = _kJarUsableArea * _kMaxFillRatio * _kPackingEfficiency;
  final ideal = math.sqrt(maxArea / (count * math.pi));
  return ideal.clamp(_kMinRadius, _kBaseRadius);
}

class _BadgeBody {
  double x, y, vx, vy, angle, va, radius, scale, highlight;
  final JarMood type;
  final DiaryEntry entry;

  _BadgeBody({
    required this.x,
    required this.y,
    required this.type,
    required this.entry,
    this.vx = 0,
    this.angle = 0,
    this.radius = _kBaseRadius,
    this.scale = 0.35,
  })  : vy = 0,
        va = 0,
        highlight = 0;

  void bounceImpulse() {
    final rnd = math.Random();
    vy = -11.5 - rnd.nextDouble() * 3.5;
    vx = (rnd.nextDouble() - 0.5) * 9;
    va = (rnd.nextDouble() - 0.5) * 0.28;
    scale = 1.28;
    highlight = 1.0;
  }
}

class _Ripple {
  double x, y, r, alpha;
  final Color color;
  _Ripple(this.x, this.y, this.r, this.alpha, this.color);
}

/// 日记统计视图：心情罐（物理玻璃罐 + 心情徽章 + 月度频率）
class DiaryStatsScreen extends StatefulWidget {
  const DiaryStatsScreen({super.key});

  @override
  State<DiaryStatsScreen> createState() => _DiaryStatsScreenState();
}

class _DiaryStatsScreenState extends State<DiaryStatsScreen>
    with SingleTickerProviderStateMixin {
  Map<DateTime, DiaryEntry> _entries = {};
  late DateTime _selectedMonth;
  final List<_BadgeBody> _badges = [];
  final List<_Ripple> _ripples = [];
  double _targetRadius = _kBaseRadius;

  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _lastTick = Duration.zero;
  double _accMs = 0;

  final LayerLink _monthLink = LayerLink();
  OverlayEntry? _monthOverlay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _ticker = createTicker(_onTick)..start();
    _loadEntries();
    for (final e in const [
      'diary_refresh',
      'diary_entry_created',
      'diary_entry_updated',
      'diary_entry_deleted',
    ]) {
      EventManager.instance.subscribe(e, _handleRefresh);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _closeMonthDropdown();
    for (final e in const [
      'diary_refresh',
      'diary_entry_created',
      'diary_entry_updated',
      'diary_entry_deleted',
    ]) {
      EventManager.instance.unsubscribe(e, _handleRefresh);
    }
    super.dispose();
  }

  void _handleRefresh(EventArgs args) => _loadEntries();

  Future<void> _loadEntries() async {
    final entries = await DiaryUtils.loadDiaryEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      // 若当前选中月没有心情日记，则落到最近一个有数据的月份
      if (_monthBadgeCount(_selectedMonth) == 0) {
        final months = _monthsWithBadges();
        if (months.isNotEmpty) _selectedMonth = months.first;
      }
      _spawnBadges();
    });
  }

  /// 有心情记录的月份（倒序）及对应徽章数
  List<DateTime> _monthsWithBadges() {
    final set = <DateTime>{};
    for (final e in _entries.values) {
      if (e.mood != null) set.add(DateTime(e.date.year, e.date.month));
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  int _monthBadgeCount(DateTime month) {
    return _entries.values
        .where((e) =>
            e.mood != null &&
            e.date.year == month.year &&
            e.date.month == month.month)
        .length;
  }

  List<DiaryEntry> _monthEntries(DateTime month) {
    final list = _entries.values
        .where((e) =>
            e.mood != null &&
            e.date.year == month.year &&
            e.date.month == month.month)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  void _spawnBadges() {
    final rnd = math.Random();
    final monthEntries = _monthEntries(_selectedMonth);
    _targetRadius = _computeTargetRadius(monthEntries.length);
    _badges.clear();
    for (final entry in monthEntries) {
      _badges.add(_BadgeBody(
        x: 80 + rnd.nextDouble() * 180,
        y: 170 + rnd.nextDouble() * 140,
        type: _jarMoodOf(entry.mood!),
        entry: entry,
        radius: _targetRadius,
        vx: (rnd.nextDouble() - 0.5) * 3,
        angle: (rnd.nextDouble() - 0.5) * 0.7,
        scale: 1,
      ));
    }
  }

  // ==================== 物理引擎 ====================

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    var dtMs = (elapsed - _lastTick).inMicroseconds / 1000.0;
    _lastTick = elapsed;
    if (dtMs > 100) dtMs = 100;
    _accMs += dtMs;
    const step = 1000 / 60;
    var stepped = false;
    while (_accMs >= step) {
      _accMs -= step;
      _stepPhysics();
      stepped = true;
    }
    if (stepped && mounted) {
      _frame.value++;
    }
  }

  void _stepPhysics() {
    final dt = 1 / _kSubSteps;
    for (var s = 0; s < _kSubSteps; s++) {
      for (final b in _badges) {
        b.vy += _kGravity * dt;
        b.vx *= math.pow(_kFriction, dt).toDouble();
        b.vy *= math.pow(_kFriction, dt).toDouble();
        b.va *= math.pow(_kAngularDamping, dt).toDouble();
        b.x += b.vx * dt;
        b.y += b.vy * dt;
        b.angle += b.va * dt;
        if (b.vx.abs() < 0.015) b.vx = 0;
        if (b.va.abs() < 0.0005) b.va = 0;
        _resolveJarBoundary(b);
      }
      for (var i = 0; i < _badges.length; i++) {
        for (var j = i + 1; j < _badges.length; j++) {
          _resolvePairCollision(_badges[i], _badges[j]);
        }
      }
    }
    for (final b in _badges) {
      b.radius += (_targetRadius - b.radius) * 0.14;
      b.scale += (1 - b.scale) * 0.18;
      if (b.highlight > 0) b.highlight = math.max(0, b.highlight - 0.03);
    }
  }

  void _resolveJarBoundary(_BadgeBody b) {
    const e = _kRestitution;
    final r = b.radius;
    final minX = _kLeftWall + r;
    final maxX = _kRightWall - r;
    final maxY = _kBottomFloor - r;

    // 底部左右圆弧内壁
    final leftCx = _kLeftWall + _kBottomCornerR;
    final rightCx = _kRightWall - _kBottomCornerR;
    final cornerCy = _kBottomFloor - _kBottomCornerR;

    if (b.x < leftCx && b.y > cornerCy) {
      _resolveCorner(b, leftCx, cornerCy, e);
      return;
    }
    if (b.x > rightCx && b.y > cornerCy) {
      _resolveCorner(b, rightCx, cornerCy, e);
      return;
    }

    if (b.x < minX) {
      b.x = minX;
      if (b.vx < 0) {
        b.vx = -b.vx * e;
        b.va += b.vy * 0.004;
      }
    } else if (b.x > maxX) {
      b.x = maxX;
      if (b.vx > 0) {
        b.vx = -b.vx * e;
        b.va -= b.vy * 0.004;
      }
    }

    if (b.y > maxY) {
      b.y = maxY;
      if (b.vy > 0) {
        b.vy = -b.vy * e;
        b.vx *= 0.94;
        b.va += b.vx * 0.006;
      }
    } else if (b.y < _kTopCeiling + r) {
      b.y = _kTopCeiling + r;
      if (b.vy < 0) b.vy = -b.vy * e;
    }
  }

  void _resolveCorner(_BadgeBody b, double cx, double cy, double e) {
    final dx = b.x - cx;
    final dy = b.y - cy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final maxDist = _kBottomCornerR - b.radius;
    if (dist > maxDist && dist > 0.0001) {
      final nx = dx / dist;
      final ny = dy / dist;
      b.x = cx + nx * maxDist;
      b.y = cy + ny * maxDist;
      final vn = b.vx * nx + b.vy * ny;
      if (vn > 0) {
        b.vx -= (1 + e) * vn * nx;
        b.vy -= (1 + e) * vn * ny;
        b.va += (b.vx * ny - b.vy * nx) * 0.003;
      }
    }
  }

  void _resolvePairCollision(_BadgeBody b1, _BadgeBody b2) {
    final dx = b2.x - b1.x;
    final dy = b2.y - b1.y;
    final distSq = dx * dx + dy * dy;
    final minDist = b1.radius + b2.radius - 1.2;
    if (distSq < minDist * minDist && distSq > 0.0001) {
      final dist = math.sqrt(distSq);
      final nx = dx / dist;
      final ny = dy / dist;
      final overlap = minDist - dist;
      final sepX = nx * overlap * 0.52;
      final sepY = ny * overlap * 0.52;
      b1.x -= sepX;
      b1.y -= sepY;
      b2.x += sepX;
      b2.y += sepY;

      final rvx = b2.vx - b1.vx;
      final rvy = b2.vy - b1.vy;
      final velN = rvx * nx + rvy * ny;
      if (velN < 0) {
        final j = -(1 + _kRestitution) * velN * 0.5;
        b1.vx -= j * nx;
        b1.vy -= j * ny;
        b2.vx += j * nx;
        b2.vy += j * ny;
        final vt = rvx * -ny + rvy * nx;
        b1.va -= vt * 0.0018;
        b2.va += vt * 0.0018;
      }
    }
  }

  // ==================== 交互 ====================

  void _onJarTap(TapDownDetails details) {
    final pos = details.localPosition;
    _BadgeBody? hit;
    for (var i = _badges.length - 1; i >= 0; i--) {
      final b = _badges[i];
      final d = math.sqrt(
          math.pow(pos.dx - b.x, 2) + math.pow(pos.dy - b.y, 2));
      if (d <= b.radius * 1.18) {
        hit = b;
        break;
      }
    }
    if (hit == null) return;

    hit.bounceImpulse();
    final rnd = math.Random();
    for (final other in _badges) {
      if (identical(other, hit)) continue;
      final dx = other.x - hit.x;
      final dy = other.y - hit.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < 110 && dist > 0) {
        final force = (110 - dist) / 110;
        other.vx += (dx / dist) * force * 6.5;
        other.vy -= force * 5.5;
        other.va += (rnd.nextDouble() - 0.5) * 0.15;
      }
    }
    _ripples.add(_Ripple(
        hit.x, hit.y, 12, 0.9, _jarMoodSpecs[hit.type]!.barColor));

    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _openMoodModal(hit!);
    });
  }

  void _shakeJar() {
    final rnd = math.Random();
    for (final b in _badges) {
      b.vy = -8 - rnd.nextDouble() * 8;
      b.vx = (rnd.nextDouble() - 0.5) * 16;
      b.va = (rnd.nextDouble() - 0.5) * 0.35;
    }
  }

  void _onInfoTap() {
    if (_badges.isEmpty) return;
    final b = _badges[math.Random().nextInt(_badges.length)];
    b.bounceImpulse();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _openMoodModal(b);
    });
  }

  void _openMoodModal(_BadgeBody badge) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'mood',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Center(
            child: ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.0).animate(curved),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _MoodModalCard(
                  badge: badge,
                  monthLabel: _monthNames[_selectedMonth.month - 1],
                  onBounceAgain: () => badge.bounceImpulse(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== 月份下拉 ====================

  void _toggleMonthDropdown() {
    if (_monthOverlay != null) {
      _closeMonthDropdown();
      return;
    }
    final months = _monthsWithBadges();
    _monthOverlay = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeMonthDropdown,
        child: Stack(
          children: [
            CompositedTransformFollower(
              link: _monthLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 150,
                  decoration: BoxDecoration(
                    color: const Color(0xF2181C26),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 24),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: months.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('暂无心情记录',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final m in months)
                              _buildMonthOption(m),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_monthOverlay!);
  }

  Widget _buildMonthOption(DateTime m) {
    final selected = m.year == _selectedMonth.year &&
        m.month == _selectedMonth.month;
    final color =
        selected ? const Color(0xFF639BFF) : const Color(0xFFD1D5DB);
    return InkWell(
      onTap: () {
        _closeMonthDropdown();
        if (!selected) {
          setState(() {
            _selectedMonth = m;
            _spawnBadges();
          });
          _shakeJar();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _monthNames[m.month - 1],
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            Text(
              '${_monthBadgeCount(m)}',
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _closeMonthDropdown() {
    _monthOverlay?.remove();
    _monthOverlay = null;
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: const Text('统计', style: TextStyle(color: Colors.white)),
      largeTitle: '统计',
      enableLargeTitle: false,
      backgroundColor: const Color(0xFF08090C),
      body: Container(
        color: const Color(0xFF08090C),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildJarSection()),
            _buildSummaryCard(),
            const SizedBox(height: 100), // 避让底部悬浮导航栏
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Insights',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          CompositedTransformTarget(
            link: _monthLink,
            child: GestureDetector(
              onTap: _toggleMonthDropdown,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF141D2E),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _monthNames[_selectedMonth.month - 1],
                      style: const TextStyle(
                        color: Color(0xFF639BFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_drop_down,
                        color: Color(0xFF639BFF), size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJarSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
            constraints.maxWidth / _kJarW, constraints.maxHeight / _kJarH);
        return Center(
          child: SizedBox(
            width: _kJarW * scale,
            height: _kJarH * scale,
            child: Stack(
              children: [
                Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: _kJarW,
                    height: _kJarH,
                    child: GestureDetector(
                      onTapDown: _onJarTap,
                      child: Stack(
                        children: [
                          const CustomPaint(
                            size: Size(_kJarW, _kJarH),
                            painter: _JarBackPainter(),
                          ),
                          CustomPaint(
                            size: const Size(_kJarW, _kJarH),
                            painter: _BadgesPainter(_badges, _ripples, _frame),
                          ),
                          const CustomPaint(
                            size: Size(_kJarW, _kJarH),
                            painter: _JarFrontPainter(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 左上角信息按钮
                Positioned(
                  left: 4,
                  top: 24 * scale,
                  child: _JarIconButton(
                    icon: Icons.more_horiz,
                    onTap: _onInfoTap,
                  ),
                ),
                // 右上角分享/摇晃按钮
                Positioned(
                  right: 4,
                  top: 24 * scale,
                  child: _JarIconButton(
                    icon: Icons.ios_share,
                    onTap: _shakeJar,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard() {
    final counts = {for (final m in JarMood.values) m: 0};
    for (final b in _badges) {
      counts[b.type] = counts[b.type]! + 1;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141419),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                children: [
                  for (final m in JarMood.values) ...[
                    if (m != JarMood.perfect)
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    Expanded(
                      child: _MoodColumn(
                        type: m,
                        count: counts[m]!,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildFrequencyBars(),
            const SizedBox(height: 10),
            const Text(
              'Monthly Frequency',
              style: TextStyle(
                color: Color(0xFF70707C),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyBars() {
    const totalBars = 27;
    final active = math.min(totalBars, _badges.length);
    final start = ((totalBars - active) / 2).floor();

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          for (var i = 0; i < totalBars; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.25),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: (i >= start && i < start + active)
                        ? _jarMoodSpecs[_badges[i - start].type]!.barColor
                        : const Color(0xFF26262E),
                    boxShadow: (i >= start && i < start + active)
                        ? [
                            BoxShadow(
                              color: _jarMoodSpecs[_badges[i - start].type]!
                                  .barColor
                                  .withValues(alpha: 0.27),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _JarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _JarIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(icon, size: 20, color: const Color(0xFF55565E)),
      ),
    );
  }
}

class _MoodColumn extends StatelessWidget {
  final JarMood type;
  final int count;

  const _MoodColumn({required this.type, required this.count});

  @override
  Widget build(BuildContext context) {
    final spec = _jarMoodSpecs[type]!;
    return Column(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: CustomPaint(painter: _BadgePainter(type)),
        ),
        const SizedBox(height: 8),
        Text(
          spec.name,
          style: const TextStyle(
            color: Color(0xFFE6E6EB),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: spec.barColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'x$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== 心情弹窗 ====================

class _MoodModalCard extends StatefulWidget {
  final _BadgeBody badge;
  final String monthLabel;
  final VoidCallback onBounceAgain;

  const _MoodModalCard({
    required this.badge,
    required this.monthLabel,
    required this.onBounceAgain,
  });

  @override
  State<_MoodModalCard> createState() => _MoodModalCardState();
}

class _MoodModalCardState extends State<_MoodModalCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtl;
  late ({String cn, String en}) _quote;
  final _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _floatCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _quote = _randomQuote();
  }

  @override
  void dispose() {
    _floatCtl.dispose();
    super.dispose();
  }

  ({String cn, String en}) _randomQuote() {
    final quotes = _jarMoodSpecs[widget.badge.type]!.quotes;
    return quotes[_rnd.nextInt(quotes.length)];
  }

  @override
  Widget build(BuildContext context) {
    final spec = _jarMoodSpecs[widget.badge.type]!;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E2029), Color(0xFF13141A)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40)],
      ),
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          // 背景炫光
          Positioned(
            top: -48,
            left: 0,
            right: 0,
            child: Center(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: spec.barColor.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    child: const Icon(Icons.close,
                        size: 16, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: spec.pillBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  spec.name.toUpperCase(),
                  style: TextStyle(
                    color: spec.pillText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 悬浮大徽章
              AnimatedBuilder(
                animation: _floatCtl,
                builder: (context, child) {
                  final t = _floatCtl.value * 2 - 1; // -1..1
                  return Transform.translate(
                    offset: Offset(0, -8 * t),
                    child: Transform.rotate(
                      angle: t * 0.06,
                      child: Transform.scale(scale: 1 + 0.04 * t, child: child),
                    ),
                  );
                },
                child: SizedBox(
                  width: 128,
                  height: 128,
                  child: CustomPaint(painter: _BadgePainter(widget.badge.type)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.monthLabel} ${widget.badge.entry.date.day} · Mood Jar Memory',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _quote.cn,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _quote.en,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        widget.onBounceAgain();
                        setState(() => _quote = _randomQuote());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            '✨ 再弹一下',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF639BFF),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF639BFF)
                                  .withValues(alpha: 0.25),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '收起卡片',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== 绘制：花边心情徽章 ====================

/// 生成 12 瓣波浪花边路径（复刻 SVG buildScallopedPath）
Path _buildScallopPath(
    double cx, double cy, double baseR, double amp, int lobes, int steps) {
  final path = Path();
  for (var i = 0; i <= steps; i++) {
    final theta = (i / steps) * math.pi * 2;
    final r = baseR + amp * math.cos(lobes * theta);
    final x = cx + r * math.cos(theta);
    final y = cy + r * math.sin(theta);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

final Path _scallopOuter = _buildScallopPath(50, 50, 42.5, 4.6, 12, 160);
final Path _scallopInner = _buildScallopPath(50, 50, 34.5, 2.2, 12, 120);

class _BadgePaints {
  final Paint outer, outerStroke, inner, innerStroke, holo, highlight;
  final Paint blush, feature, mouthFill;

  _BadgePaints(JarMood type)
      : outer = Paint(),
        outerStroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
        inner = Paint(),
        innerStroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
        holo = Paint(),
        highlight = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
        blush = Paint(),
        feature = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
        mouthFill = Paint() {
    const rect = Rect.fromLTWH(0, 0, 100, 100);
    switch (type) {
      case JarMood.perfect:
        outer.shader = const LinearGradient(
          begin: Alignment(-0.9, -0.9),
          end: Alignment(0.9, 0.9),
          colors: [
            Color(0xFFFFF3A8), Color(0xFFF5C242),
            Color(0xFFD89216), Color(0xFF9E6204),
          ],
          stops: [0, 0.32, 0.68, 1],
        ).createShader(rect);
        outerStroke.color = const Color(0xA6FFF6C7);
        inner.shader = const LinearGradient(
          begin: Alignment(-0.8, -0.8),
          end: Alignment(0.8, 0.8),
          colors: [
            Color(0xFFFFF7C2), Color(0xFFFFDF6E), Color(0xFFF3B73B),
            Color(0xFFFFD080), Color(0xFFCF8A18),
          ],
          stops: [0, 0.28, 0.55, 0.8, 1],
        ).createShader(rect);
        innerStroke.color = const Color(0x59B87409);
        holo.shader = const LinearGradient(
          begin: Alignment(-0.7, 0.7),
          end: Alignment(0.7, -0.7),
          colors: [
            Color(0x00FFFFFF), Color(0x38FF9EBC), Color(0x7AFFFBE0),
            Color(0x2E7EF2FF), Color(0x00FFFFFF),
          ],
          stops: [0, 0.35, 0.5, 0.65, 1],
        ).createShader(rect);
        highlight.color = const Color(0xA6FFFFFF);
        blush.color = const Color(0x8CEB6B40);
        feature.color = const Color(0xFF6B4205);
        mouthFill.color = const Color(0x47D96B27);
      case JarMood.good:
        outer.shader = const LinearGradient(
          begin: Alignment(-0.9, -0.9),
          end: Alignment(0.9, 0.9),
          colors: [
            Color(0xFFEEF9FF), Color(0xFFA8D5F2),
            Color(0xFF6B9BC3), Color(0xFF42688C),
          ],
          stops: [0, 0.35, 0.7, 1],
        ).createShader(rect);
        outerStroke.color = const Color(0xB3F0F9FF);
        inner.shader = const LinearGradient(
          begin: Alignment(-0.8, -0.8),
          end: Alignment(0.8, 0.8),
          colors: [
            Color(0xFFF2FBFF), Color(0xFFBCE4FA), Color(0xFFD8C7F7),
            Color(0xFF8EC2E6), Color(0xFF5C89B0),
          ],
          stops: [0, 0.28, 0.52, 0.76, 1],
        ).createShader(rect);
        innerStroke.color = const Color(0x59527B9E);
        holo.shader = const LinearGradient(
          begin: Alignment(-0.7, 0.7),
          end: Alignment(0.7, -0.7),
          colors: [
            Color(0x00FFFFFF), Color(0x52FFADE2), Color(0x8CFFFFFF),
            Color(0x4D88F7E2), Color(0x00FFFFFF),
          ],
          stops: [0, 0.32, 0.5, 0.68, 1],
        ).createShader(rect);
        highlight.color = const Color(0xBFFFFFFF);
        blush.color = const Color(0x85F27999);
        feature.color = const Color(0xFF2C4963);
      case JarMood.nice:
        outer.shader = const LinearGradient(
          begin: Alignment(-0.9, -0.9),
          end: Alignment(0.9, 0.9),
          colors: [
            Color(0xFFFFF0E3), Color(0xFFF2BE96),
            Color(0xFFC98B5F), Color(0xFF87532D),
          ],
          stops: [0, 0.35, 0.7, 1],
        ).createShader(rect);
        outerStroke.color = const Color(0xA6FFF3E8);
        inner.shader = const LinearGradient(
          begin: Alignment(-0.8, -0.8),
          end: Alignment(0.8, 0.8),
          colors: [
            Color(0xFFFFF4EB), Color(0xFFFCD2B3), Color(0xFFF7B7B7),
            Color(0xFFDFA376), Color(0xFFA86A3D),
          ],
          stops: [0, 0.30, 0.55, 0.78, 1],
        ).createShader(rect);
        innerStroke.color = const Color(0x59965B30);
        holo.shader = const LinearGradient(
          begin: Alignment(-0.7, 0.7),
          end: Alignment(0.7, -0.7),
          colors: [
            Color(0x00FFFFFF), Color(0x42AEE8FF), Color(0x85FFF8EB),
            Color(0x47FFA8D2), Color(0x00FFFFFF),
          ],
          stops: [0, 0.32, 0.52, 0.7, 1],
        ).createShader(rect);
        highlight.color = const Color(0xB3FFFFFF);
        blush.color = const Color(0x80E85D56);
        feature.color = const Color(0xFF5E3619);
    }
  }
}

final Map<JarMood, _BadgePaints> _badgePaints = {
  for (final m in JarMood.values) m: _BadgePaints(m),
};

/// 在 100x100 逻辑坐标中绘制花边心情徽章（调用方负责缩放定位）
void _drawBadge(Canvas canvas, JarMood type) {
  final p = _badgePaints[type]!;
  canvas.drawPath(_scallopOuter, p.outer);
  canvas.drawPath(_scallopOuter, p.outerStroke);
  canvas.drawPath(_scallopInner, p.inner);
  canvas.drawPath(_scallopInner, p.innerStroke);
  canvas.drawPath(_scallopInner, p.holo);

  // 顶部高光月牙
  final hl = Path()
    ..moveTo(28, 30)
    ..cubicTo(38, 19, 62, 19, 72, 30);
  canvas.drawPath(hl, p.highlight);

  // 腮红
  canvas.drawOval(Rect.fromCenter(
      center: const Offset(30, 56), width: 12.4, height: 7.6), p.blush);
  canvas.drawOval(Rect.fromCenter(
      center: const Offset(70, 56), width: 12.4, height: 7.6), p.blush);

  switch (type) {
    case JarMood.perfect:
      // 弯弯笑眼
      p.feature.strokeWidth = 3.2;
      final eyeL = Path()
        ..moveTo(31, 44)
        ..quadraticBezierTo(37, 36, 43, 44);
      final eyeR = Path()
        ..moveTo(57, 44)
        ..quadraticBezierTo(63, 36, 69, 44);
      canvas.drawPath(eyeL, p.feature);
      canvas.drawPath(eyeR, p.feature);
      // 灿烂微笑（带底色填充）
      final mouth = Path()
        ..moveTo(38, 56)
        ..quadraticBezierTo(50, 69, 62, 56);
      canvas.drawPath(mouth, p.mouthFill);
      p.feature.strokeWidth = 3.3;
      canvas.drawPath(mouth, p.feature);
    case JarMood.good:
      // 圆点眼睛 + 高光点
      final dot = Paint()..color = p.feature.color;
      canvas.drawCircle(const Offset(37, 43), 3.1, dot);
      canvas.drawCircle(const Offset(63, 43), 3.1, dot);
      final dotHl = Paint()..color = Colors.white;
      canvas.drawCircle(const Offset(35.8, 41.8), 1.1, dotHl);
      canvas.drawCircle(const Offset(61.8, 41.8), 1.1, dotHl);
      p.feature.strokeWidth = 3.2;
      final mouth = Path()
        ..moveTo(39, 55)
        ..quadraticBezierTo(50, 65, 61, 55);
      canvas.drawPath(mouth, p.feature);
    case JarMood.nice:
      p.feature.strokeWidth = 3.1;
      final eyeL = Path()
        ..moveTo(31, 43)
        ..quadraticBezierTo(37, 37, 43, 43);
      final eyeR = Path()
        ..moveTo(57, 43)
        ..quadraticBezierTo(63, 37, 69, 43);
      canvas.drawPath(eyeL, p.feature);
      canvas.drawPath(eyeR, p.feature);
      p.feature.strokeWidth = 3.2;
      final mouth = Path()
        ..moveTo(40, 55)
        ..quadraticBezierTo(50, 64, 60, 55);
      canvas.drawPath(mouth, p.feature);
  }
}

/// 静态徽章绘制（统计列图标 / 弹窗大图），充满给定区域
class _BadgePainter extends CustomPainter {
  final JarMood type;
  const _BadgePainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale, scale);
    _drawBadge(canvas, type);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.type != type;
}

// ==================== 绘制：罐子场景 ====================

/// 玻璃罐主体路径（340x368 逻辑坐标，复刻 SVG）
Path _buildJarBodyPath() {
  return Path()
    ..moveTo(86, 60)
    ..lineTo(254, 60)
    ..cubicTo(254, 69, 294, 76, 294, 128)
    ..lineTo(294, 276)
    ..cubicTo(294, 322, 260, 344, 210, 344)
    ..lineTo(130, 344)
    ..cubicTo(80, 344, 46, 322, 46, 276)
    ..lineTo(46, 128)
    ..cubicTo(46, 76, 86, 69, 86, 60)
    ..close();
}

/// 徽章裁剪路径（含瓶口上方投入区）
Path _buildBadgeClipPath() {
  return Path()
    ..moveTo(80, 20)
    ..lineTo(260, 20)
    ..lineTo(254, 60)
    ..cubicTo(254, 69, 294, 76, 294, 128)
    ..lineTo(294, 276)
    ..cubicTo(294, 322, 260, 344, 210, 344)
    ..lineTo(130, 344)
    ..cubicTo(80, 344, 46, 322, 46, 276)
    ..lineTo(46, 128)
    ..cubicTo(46, 76, 86, 69, 86, 60)
    ..close();
}

final Path _jarBodyPath = _buildJarBodyPath();
final Path _badgeClipPath = _buildBadgeClipPath();

class _JarBackPainter extends CustomPainter {
  const _JarBackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 底部桌面环境反光晕
    final floorShadow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFAAB4C4).withValues(alpha: 0.18),
          const Color(0xFF454A54).withValues(alpha: 0.12),
          const Color(0x0008090C),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromCenter(
          center: const Offset(170, 350), width: 230, height: 28));
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(170, 350), width: 230, height: 28),
        floorShadow);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(170, 346), width: 184, height: 12),
      Paint()..color = Colors.black.withValues(alpha: 0.75),
    );

    // 瓶身深邃玻璃渐变
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF222328), Color(0xFF0D0E12), Color(0xFF28292E),
          Color(0xFF121317), Color(0xFF050608), Color(0xFF191A20),
          Color(0xFF2E3038),
        ],
        stops: [0, 0.08, 0.28, 0.43, 0.78, 0.92, 1],
      ).createShader(const Rect.fromLTWH(44, 0, 252, _kJarH));
    canvas.drawPath(_jarBodyPath, bodyPaint);

    // 裁剪区内部：左侧柔光带 + 瓶颈暗部
    canvas.save();
    canvas.clipPath(_jarBodyPath);
    final leftGlow = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0x03FFFFFF), Color(0x29FFFFFF),
          Color(0x12FFFFFF), Color(0x00FFFFFF),
        ],
        stops: [0, 0.4, 0.7, 1],
      ).createShader(const Rect.fromLTWH(95, 60, 68, 286));
    canvas.drawRect(const Rect.fromLTWH(95, 60, 68, 286), leftGlow);
    final neckShadow = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xE0000000), Color(0x00000000)],
      ).createShader(const Rect.fromLTWH(44, 56, 252, 22));
    canvas.drawRect(const Rect.fromLTWH(44, 56, 252, 22), neckShadow);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_JarBackPainter old) => false;
}

class _BadgesPainter extends CustomPainter {
  final List<_BadgeBody> badges;
  final List<_Ripple> ripples;

  _BadgesPainter(this.badges, this.ripples, Listenable repaint)
      : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(_badgeClipPath);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    for (final b in badges) {
      final drawRadius = b.radius * 1.12 * b.scale;
      canvas.save();
      canvas.translate(b.x, b.y);
      canvas.rotate(b.angle);

      // 徽章立体投影
      canvas.drawCircle(const Offset(0, 3), drawRadius * 0.9, shadowPaint);

      final k = drawRadius * 2 / 100;
      canvas.scale(k, k);
      canvas.translate(-50, -50);
      _drawBadge(canvas, b.type);
      canvas.restore();

      // 点击发光光环
      if (b.highlight > 0) {
        canvas.drawCircle(
          Offset(b.x, b.y),
          b.radius * 1.05,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white.withValues(alpha: b.highlight * 0.85),
        );
      }
    }

    // 点击波纹
    for (var i = ripples.length - 1; i >= 0; i--) {
      final rp = ripples[i];
      rp.r += 2.6;
      rp.alpha -= 0.045;
      if (rp.alpha <= 0) {
        ripples.removeAt(i);
        continue;
      }
      canvas.drawCircle(
        Offset(rp.x, rp.y),
        rp.r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = rp.color.withValues(alpha: rp.alpha),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BadgesPainter old) => true;
}

class _JarFrontPainter extends CustomPainter {
  const _JarFrontPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(_jarBodyPath);

    // 瓶肩横向柔光弧（整体透明度 0.45，已折算进渐变 alpha）
    final shoulder = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.126),
          Colors.white.withValues(alpha: 0.054),
          Colors.white.withValues(alpha: 0.009),
          Colors.white.withValues(alpha: 0.09),
        ],
        stops: const [0, 0.35, 0.75, 1],
      ).createShader(const Rect.fromLTWH(58, 72, 224, 40));
    canvas.save();
    canvas.translate(170, 92);
    canvas.scale(1, 20 / 112);
    canvas.drawCircle(Offset.zero, 112, shoulder);
    canvas.restore();

    Paint stroke(double alpha, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: alpha);

    // 左侧亮边反光条
    canvas.drawPath(
      Path()
        ..moveTo(55, 122)
        ..cubicTo(55, 95, 78, 78, 95, 68),
      stroke(0.26, 3.5),
    );
    canvas.drawPath(
      Path()
        ..moveTo(53, 130)
        ..lineTo(53, 272)
        ..cubicTo(53, 305, 75, 328, 108, 335),
      stroke(0.18, 2.5),
    );

    // 右侧亮边反光条
    canvas.drawPath(
      Path()
        ..moveTo(285, 122)
        ..cubicTo(285, 95, 262, 78, 245, 68),
      stroke(0.22, 3),
    );
    canvas.drawPath(
      Path()
        ..moveTo(287, 132)
        ..lineTo(287, 272)
        ..cubicTo(287, 305, 265, 328, 232, 335),
      stroke(0.22, 3),
    );

    // 底部厚玻璃双重弧形折射
    final refract = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0),
          const Color(0xFFD8DDE6).withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.32),
          const Color(0xFF7C828D).withValues(alpha: 0.2),
        ],
        stops: const [0, 0.55, 0.85, 1],
      ).createShader(const Rect.fromLTWH(54, 295, 232, 51));
    canvas.drawPath(
      Path()
        ..moveTo(54, 295)
        ..cubicTo(62, 332, 102, 342, 170, 342)
        ..cubicTo(238, 342, 278, 332, 286, 295)
        ..cubicTo(276, 337, 240, 345, 170, 345)
        ..cubicTo(100, 345, 64, 337, 54, 295)
        ..close(),
      refract,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(170, 338), width: 152, height: 11),
      stroke(0.22, 1.2),
    );

    canvas.restore();

    // 玻璃罐外框描边
    canvas.drawPath(_jarBodyPath, stroke(0.16, 1.5));

    // ============ 3D 香槟金瓶盖 ============
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(170, 61), width: 184, height: 16),
      Paint()..color = Colors.black.withValues(alpha: 0.65),
    );

    // 瓶盖圆柱侧面
    final capSide = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF8B6F3B), Color(0xFFFEF4CF), Color(0xFFD5B36B),
          Color(0xFF9E7834), Color(0xFF725219), Color(0xFFB9934C),
          Color(0xFFFEF5D1), Color(0xFFD1AE67), Color(0xFF7C5E27),
        ],
        stops: [0, 0.08, 0.16, 0.28, 0.45, 0.63, 0.78, 0.91, 1],
      ).createShader(const Rect.fromLTWH(74, 0, 192, 64));
    canvas.drawPath(
      Path()
        ..moveTo(74, 27)
        ..lineTo(74, 53)
        ..cubicTo(74, 59.5, 117, 64, 170, 64)
        ..cubicTo(223, 64, 266, 59.5, 266, 53)
        ..lineTo(266, 27)
        ..close(),
      capSide,
    );

    // 瓶盖底沿高光金边
    canvas.drawPath(
      Path()
        ..moveTo(74, 52.5)
        ..cubicTo(74, 59, 117, 63.5, 170, 63.5)
        ..cubicTo(223, 63.5, 266, 59, 266, 52.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFFFFAED).withValues(alpha: 0.45),
    );

    // 瓶盖顶部椭圆盖面
    final capTop = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF997C45), Color(0xFFE3CA8C), Color(0xFF9C7E44),
          Color(0xFFCAB074), Color(0xFF7A5E2B),
        ],
        stops: [0, 0.3, 0.55, 0.85, 1],
      ).createShader(const Rect.fromLTWH(74, 17.5, 192, 19));
    final capTopRect =
        Rect.fromCenter(center: const Offset(170, 27), width: 192, height: 19);
    canvas.drawOval(capTopRect, capTop);
    canvas.drawOval(
      capTopRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFFFF3C4).withValues(alpha: 0.6),
    );
    // 顶面内圈拉丝高光
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(170, 26.5), width: 176, height: 13.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_JarFrontPainter old) => false;
}
