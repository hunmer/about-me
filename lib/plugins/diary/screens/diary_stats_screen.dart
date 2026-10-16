import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/diary/models/diary_entry.dart';
import 'package:aboutme/plugins/diary/utils/diary_utils.dart';
import 'package:aboutme/plugins/diary/widgets/diary_mood_face.dart';
import 'package:aboutme/widgets/quill_viewer/index.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 心情罐分类（开心系 / 平静系 / 低能量系）
enum JarMood { perfect, good, nice }

class _JarMoodSpec {
  final JarMood type;
  final String nameKey;
  final String repEmoji; // 概览列代表表情

  const _JarMoodSpec({
    required this.type,
    required this.nameKey,
    required this.repEmoji,
  });
}

const Map<JarMood, _JarMoodSpec> _jarMoodSpecs = {
  JarMood.perfect: _JarMoodSpec(
    type: JarMood.perfect,
    nameKey: 'diary_stats_perfectDay',
    repEmoji: '😊',
  ),
  JarMood.good: _JarMoodSpec(
    type: JarMood.good,
    nameKey: 'diary_stats_goodDay',
    repEmoji: '🤔',
  ),
  JarMood.nice: _JarMoodSpec(
    type: JarMood.nice,
    nameKey: 'diary_stats_niceDay',
    repEmoji: '😴',
  ),
};

/// 分类主题色（禁止硬编码数据色，走主题语义色）
Color _jarMoodColor(AppThemeData theme, JarMood mood) => switch (mood) {
      JarMood.perfect => theme.primary,
      JarMood.good => theme.secondary,
      JarMood.nice => theme.warning,
    };

Color _jarMoodOnColor(AppThemeData theme, JarMood mood) => switch (mood) {
      JarMood.perfect => theme.onPrimary,
      JarMood.good => theme.onSecondary,
      JarMood.nice => theme.onWarning,
    };

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

// ==================== 物理常量（逻辑坐标 340x368） ====================
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

/// 心情罐音效器：池化 AudioPlayer 避免重叠截断，42ms 限流防抖，
/// 音量随碰撞强度变化（对应 HTML 版 SoundEngine）
class _JarSound {
  static final _pool = List.generate(4, (_) => AudioPlayer());
  static var _idx = 0;
  static var _lastPlay = 0;

  static Future<void> _play(String asset, double volume) async {
    final p = _pool[_idx++ % _pool.length];
    await p.setVolume(volume.clamp(0.05, 0.3));
    await p.play(AssetSource(asset));
  }

  static Future<void> clink(double intensity) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPlay < 42) return; // 限流，同 HTML
    _lastPlay = now;
    await _play('audio/glass_clink.mp3', intensity);
  }

  static Future<void> pop() => _play('audio/pop.mp3', 0.3);
}

/// 心情表情绘制缓存：底色 + 表情位图 + 墨线圆环（RoughDrawing 可跨帧复用）
class _FaceInk {
  _FaceInk(this.spec);

  final DiaryMoodSpec spec;
  ui.Image? image;

  DrawConfig? ringConfig;
  RoughDrawing? ring;
}

// ==================== 日记统计视图：心情罐（手绘纸墨风） ====================
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
  final Map<String, _FaceInk> _faceInks = {};
  double _targetRadius = _kBaseRadius;

  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _lastTick = Duration.zero;
  double _accMs = 0;

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
    for (final ink in _faceInks.values) {
      ink.image?.dispose();
    }
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

  /// 有心情记录的月份（倒序）
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
    unawaited(_preloadFaces(monthEntries));
  }

  /// 预解码当月心情表情位图，供徽章绘制器同步取用
  Future<void> _preloadFaces(List<DiaryEntry> entries) async {
    for (final entry in entries) {
      final mood = entry.mood!;
      if (_faceInks.containsKey(mood)) continue;
      final ink = _FaceInk(diaryMoodSpecOf(mood));
      _faceInks[mood] = ink;
      final asset = ink.spec.asset;
      if (asset != null) {
        try {
          final data = await rootBundle.load(asset);
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
            targetWidth: 160,
          );
          final frameInfo = await codec.getNextFrame();
          ink.image = frameInfo.image;
          codec.dispose();
        } catch (_) {
          // 缺图时绘制器回退 emoji 文字
        }
      }
      if (mounted) setState(() {});
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
        if (b.vx.abs() > 2.2) _JarSound.clink(b.vx.abs() / 14);
        b.vx = -b.vx * e;
        b.va += b.vy * 0.004;
      }
    } else if (b.x > maxX) {
      b.x = maxX;
      if (b.vx > 0) {
        if (b.vx > 2.2) _JarSound.clink(b.vx / 14);
        b.vx = -b.vx * e;
        b.va -= b.vy * 0.004;
      }
    }

    if (b.y > maxY) {
      b.y = maxY;
      if (b.vy > 0) {
        if (b.vy > 2.2) _JarSound.clink(b.vy / 14);
        b.vy = -b.vy * e;
        b.vx *= 0.94;
        b.va += b.vx * 0.006;
      }
    } else if (b.y < _kTopCeiling + r) {
      b.y = _kTopCeiling + r;
      if (b.vy < 0) {
        if (b.vy.abs() > 2.2) _JarSound.clink(b.vy.abs() / 14);
        b.vy = -b.vy * e;
      }
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
        if (vn > 2.2) _JarSound.clink(vn / 14);
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
        if (velN.abs() > 2.3) _JarSound.clink(velN.abs() / 14);
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
    unawaited(_JarSound.pop());
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
        hit.x, hit.y, 12, 0.9, _jarMoodColor(DSThemeBridge.resolve(context), hit.type)));

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
    SmoothBottomSheet.showWithTitle(
      context: context,
      title: 'diary_stats_moodJarMemory'.tr,
      child: Builder(
        builder: (context) => _MoodModalCard(
          theme: DSThemeBridge.resolve(context),
          badge: badge,
          onBounceAgain: () => badge.bounceImpulse(),
        ),
      ),
    );
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(builder: (context) {
        final theme = AppTheme.of(context);
        return SuperCupertinoNavigationWrapper(
          title: Text('diary_stats'.tr),
          largeTitle: 'diary_stats'.tr,
          enableLargeTitle: false,
          backgroundColor: dsScaffoldBackground(theme),
          body: Container(
            color: dsScaffoldBackground(theme),
            child: Column(
              children: [
                _buildHeader(theme),
                Expanded(child: _buildJarSection(theme)),
                _buildSummaryCard(theme),
                const SizedBox(height: 100), // 避让底部悬浮导航栏
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHeader(AppThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'diary_stats'.tr,
            style: DsTypography.title.copyWith(color: theme.text),
          ),
          _buildMonthPicker(theme),
        ],
      ),
    );
  }

  Widget _buildMonthPicker(AppThemeData theme) {
    return Pressable(
      onPressed: _showMonthSheet,
      builder: (context, states) => JellyBox(
        color: theme.surface,
        radius: theme.radii.circle,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_selectedMonth.year}/${_selectedMonth.month}',
              style: DsTypography.body.copyWith(
                color: theme.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            DsIcon(DsIconKind.chevronDown, size: 16, color: theme.primaryText),
          ],
        ),
      ),
    );
  }

  void _showMonthSheet() {
    final months = _monthsWithBadges();
    SmoothBottomSheet.showWithTitle(
      context: context,
      title: 'diary_stats_selectMonth'.tr,
      child: Builder(
        builder: (context) {
          final theme = AppTheme.of(context);
          if (months.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(theme.spacing.lg),
              child: Text(
                'diary_stats_noMoodRecords'.tr,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            );
          }
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: months.length,
              itemBuilder: (context, i) {
                final m = months[i];
                final selected = m.year == _selectedMonth.year &&
                    m.month == _selectedMonth.month;
                return SmoothSheetAction(
                  icon: DsIconKind.calendar,
                  label: '${m.year}/${m.month}',
                  onTap: () {
                    Navigator.of(context).pop();
                    if (!selected) {
                      setState(() {
                        _selectedMonth = m;
                        _spawnBadges();
                      });
                      _shakeJar();
                    }
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'x${_monthBadgeCount(m)}',
                        style: DsTypography.caption
                            .copyWith(color: theme.textSub),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 6),
                        DsIcon(DsIconKind.check,
                            size: 16, color: theme.primary),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildJarSection(AppThemeData theme) {
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
                          CustomPaint(
                            size: const Size(_kJarW, _kJarH),
                            painter:
                                _JarSketchPainter(theme: theme, front: false),
                          ),
                          CustomPaint(
                            size: const Size(_kJarW, _kJarH),
                            painter: _BadgesPainter(
                              theme: theme,
                              badges: _badges,
                              ripples: _ripples,
                              faceInks: _faceInks,
                              repaint: _frame,
                            ),
                          ),
                          CustomPaint(
                            size: const Size(_kJarW, _kJarH),
                            painter: _JarSketchPainter(theme: theme, front: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 左上角：随机挑一枚回忆
                Positioned(
                  left: 12,
                  top: 20 * scale,
                  child: DSIconButton(
                    icon: DsIconKind.sparkle,
                    size: 36,
                    color: theme.surface,
                    iconColor: theme.textSub,
                    onPressed: _onInfoTap,
                  ),
                ),
                // 右上角：摇晃罐子
                Positioned(
                  right: 12,
                  top: 20 * scale,
                  child: DSIconButton(
                    icon: DsIconKind.refresh,
                    size: 36,
                    color: theme.surface,
                    iconColor: theme.textSub,
                    onPressed: _shakeJar,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(AppThemeData theme) {
    final counts = {for (final m in JarMood.values) m: 0};
    for (final b in _badges) {
      counts[b.type] = counts[b.type]! + 1;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DsSketchPanel(
        theme: theme,
        radius: theme.radii.xxl,
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
                        color: theme.ink.withValues(alpha: 0.18),
                      ),
                    Expanded(
                      child: _MoodColumn(
                        theme: theme,
                        type: m,
                        count: counts[m]!,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildFrequencyBars(theme),
            const SizedBox(height: 10),
            Text(
              'diary_stats_monthlyFrequency'.tr,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyBars(AppThemeData theme) {
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
                child: Container(
                  decoration: dsSketchDecoration(
                    theme: theme,
                    radius: BorderRadius.circular(999),
                    strokeWidth: 1.1,
                    stroke: theme.ink.withValues(
                        alpha: (i >= start && i < start + active) ? 0.55 : 0.25),
                    fillColor: (i >= start && i < start + active)
                        ? _jarMoodColor(theme, _badges[i - start].type)
                        : theme.surfaceAlt,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== 概览列 / 表情徽章 ====================

class _MoodColumn extends StatelessWidget {
  final AppThemeData theme;
  final JarMood type;
  final int count;

  const _MoodColumn({
    required this.theme,
    required this.type,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final spec = _jarMoodSpecs[type]!;
    return Column(
      children: [
        _MoodFaceBadge(
          theme: theme,
          spec: diaryMoodSpecOf(spec.repEmoji),
          size: 44,
        ),
        const SizedBox(height: 8),
        Text(
          spec.nameKey.tr,
          style: DsTypography.body.copyWith(color: theme.text),
        ),
        const SizedBox(height: 8),
        JellyBox(
          color: _jarMoodColor(theme, type),
          radius: theme.radii.circle,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Text(
            'x$count',
            style: DsTypography.caption.copyWith(
              color: _jarMoodOnColor(theme, type),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// 日记心情徽章：心情底色圆 + 表情图（缺图回退 emoji）+ 墨线抖动描边
class _MoodFaceBadge extends StatelessWidget {
  final AppThemeData theme;
  final DiaryMoodSpec spec;
  final double size;

  const _MoodFaceBadge({
    required this.theme,
    required this.spec,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final faceSize = size * 0.62;
    return Container(
      width: size,
      height: size,
      decoration:
          dsSketchDecoration(theme: theme, fillColor: spec.bg, circle: true),
      child: Center(
        child: SizedBox(
          width: faceSize,
          height: faceSize,
          child: spec.asset != null
              ? Image.asset(
                  spec.asset!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _fallback(faceSize),
                )
              : _fallback(faceSize),
        ),
      ),
    );
  }

  Widget _fallback(double faceSize) {
    return Center(
      child: Text(spec.emoji, style: TextStyle(fontSize: faceSize * 0.55)),
    );
  }
}

// ==================== 心情弹窗 ====================

class _MoodModalCard extends StatefulWidget {
  final AppThemeData theme;
  final _BadgeBody badge;
  final VoidCallback onBounceAgain;

  const _MoodModalCard({
    required this.theme,
    required this.badge,
    required this.onBounceAgain,
  });

  @override
  State<_MoodModalCard> createState() => _MoodModalCardState();
}

class _MoodModalCardState extends State<_MoodModalCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtl;

  @override
  void initState() {
    super.initState();
    _floatCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final mood = widget.badge.entry.mood!;
    final moodNameKey = diaryMoodNameKeys[mood];
    final moodName = moodNameKey != null ? moodNameKey.tr : mood;
    final entry = widget.badge.entry;
    final hasContent = entry.content.trim().isNotEmpty;

    // 面板/把手/标题行由 SmoothBottomSheet 提供，这里只出内容
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: JellyBox(
                color: _jarMoodColor(theme, widget.badge.type),
                radius: theme.radii.circle,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                child: Text(
                  moodName,
                  style: DsTypography.caption.copyWith(
                    color: _jarMoodOnColor(theme, widget.badge.type),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: theme.spacing.md),
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
              child: Center(
                child: _MoodFaceBadge(
                  theme: theme,
                  spec: diaryMoodSpecOf(mood),
                  size: 104,
                ),
              ),
            ),
            SizedBox(height: theme.spacing.md),
            Text(
              '${DateFormat('MMMM d, yyyy').format(entry.date)}'
              ' · ${'diary_stats_moodJarMemory'.tr}',
              textAlign: TextAlign.center,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
              // 日记正文（有内容才渲染）
              if (hasContent) ...[
                SizedBox(height: theme.spacing.md),
                Container(
                  decoration: dsSketchDecoration(
                    theme: theme,
                    radius: theme.radii.lg,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.title.trim().isNotEmpty) ...[
                        Text(
                          entry.title,
                          style: DsTypography.body.copyWith(
                            color: theme.text,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: theme.spacing.sm),
                      ],
                      QuillViewer(data: entry.content, selectable: true),
                    ],
                  ),
                ),
              ],
              SizedBox(height: theme.spacing.xl),
              Row(
                children: [
                  Expanded(
                    child: DSButton(
                      label: 'diary_stats_bounceAgain'.tr,
                      variant: DSButtonVariant.outline,
                      onPressed: widget.onBounceAgain,
                    ),
                  ),
                  SizedBox(width: theme.spacing.md),
                  Expanded(
                    child: DSButton(
                      label: 'diary_stats_closeCard'.tr,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== 绘制：手绘罐子场景 ====================

/// 玻璃罐主体路径（340x368 逻辑坐标）
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

/// 沿路径等距取样，供 rough 引擎 curvePath 连成墨线
List<PointD> _samplePath(Path path, double step) {
  final metric = path.computeMetrics().first;
  final points = <PointD>[];
  for (var d = 0.0; d < metric.length; d += step) {
    final pos = metric.getTangentForOffset(d)?.position;
    if (pos != null) points.add(PointD(pos.dx, pos.dy));
  }
  final end = metric.getTangentForOffset(metric.length)?.position;
  if (end != null) points.add(PointD(end.dx, end.dy));
  return points;
}

final List<PointD> _jarOutlinePoints = _samplePath(_jarBodyPath, 16);

/// 手绘罐子：back 画罐身轮廓与地面线，front 画反光、瓶盖与描边补线
/// （风格随全局墨线档位，颜色一律主题墨线）
class _JarSketchPainter extends CustomPainter {
  final AppThemeData theme;
  final bool front;

  const _JarSketchPainter({required this.theme, required this.front});

  @override
  void paint(Canvas canvas, Size size) {
    final config = theme.wired.drawConfig;
    config.randomizer.reset();
    final generator = Generator(config, NoFiller());

    Paint ink(double width, double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = theme.ink.withValues(alpha: alpha);

    if (!front) {
      // 罐身墨线轮廓
      final body = generator.curvePath(_jarOutlinePoints);
      RoughDrawing(body, ink(2.2, 0.9), ink(2.2, 0.9))
          .paint(canvas, pressure: 0);
      // 桌面接地短线
      RoughDrawing(generator.line(34, 356, 126, 358), ink(1.8, 0.4),
              ink(1.8, 0.4))
          .paint(canvas, pressure: 0);
      RoughDrawing(generator.line(158, 358, 306, 356), ink(1.8, 0.4),
              ink(1.8, 0.4))
          .paint(canvas, pressure: 0);
    } else {
      // 轻描一遍罐身轮廓，让徽章看起来在罐内
      final body = generator.curvePath(_jarOutlinePoints);
      RoughDrawing(body, ink(1.6, 0.4), ink(1.6, 0.4))
          .paint(canvas, pressure: 0);
      // 玻璃反光两笔
      RoughDrawing(
          generator.curvePath([
            PointD(62, 150),
            PointD(60, 195),
            PointD(63, 240),
          ]),
          ink(1.4, 0.28),
          ink(1.4, 0.28)).paint(canvas, pressure: 0);
      RoughDrawing(
          generator.curvePath([
            PointD(272, 160),
            PointD(275, 200),
            PointD(272, 228),
          ]),
          ink(1.4, 0.28),
          ink(1.4, 0.28)).paint(canvas, pressure: 0);
      // 瓶盖：墨线框 + 排线填充（画在徽章之上盖住瓶口）
      final capGen = Generator(
        config,
        HachureFiller(FillerConfig.build(
          drawConfig: config,
          hachureGap: 6,
          fillWeight: 1.2,
        )),
      );
      final cap = capGen.roundedRectangle(80, 18, 180, 40, 16, 16, 16, 16);
      final hatch = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = theme.hatch;
      RoughDrawing(cap, ink(2.2, 0.9), hatch).paint(canvas, pressure: 0);
    }
  }

  @override
  bool shouldRepaint(_JarSketchPainter old) =>
      old.front != front || !identical(old.theme, theme);
}

/// 罐中心情徽章：心情底色圆 + 日记表情位图 + 墨线圆环 + 点击波纹
class _BadgesPainter extends CustomPainter {
  final AppThemeData theme;
  final List<_BadgeBody> badges;
  final List<_Ripple> ripples;
  final Map<String, _FaceInk> faceInks;

  _BadgesPainter({
    required this.theme,
    required this.badges,
    required this.ripples,
    required this.faceInks,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(_badgeClipPath);

    final config = theme.wired.drawConfig;

    for (final b in badges) {
      final mood = b.entry.mood!;
      final ink =
          faceInks[mood] ?? _FaceInk(diaryMoodSpecOf(mood));
      final drawRadius = b.radius * b.scale;

      canvas.save();
      canvas.translate(b.x, b.y);
      canvas.rotate(b.angle);

      // 心情底色圆 + 表情图（缺图回退 emoji 文字）
      canvas.drawCircle(Offset.zero, drawRadius, Paint()..color = ink.spec.bg);
      final faceSide = drawRadius * 1.24;
      final img = ink.image;
      if (img != null) {
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromCenter(
              center: Offset.zero, width: faceSide, height: faceSide),
          Paint()..filterQuality = FilterQuality.medium,
        );
      } else {
        final tp = TextPainter(
          text: TextSpan(
              text: ink.spec.emoji,
              style: TextStyle(fontSize: faceSide * 0.7)),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      }

      // 墨线圆环（100x100 逻辑圆，缓存跨帧复用；墨线档位变化时重建）
      if (!identical(ink.ringConfig, config)) {
        ink.ringConfig = config;
        config.randomizer.reset();
        final gen = Generator(config, NoFiller());
        final stroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = theme.ink;
        ink.ring = RoughDrawing(gen.circle(50, 50, 96), stroke, stroke);
      }
      final k = drawRadius * 2 / 96;
      canvas.scale(k, k);
      canvas.translate(-50, -50);
      ink.ring!.paint(canvas, pressure: 0);
      canvas.restore();

      // 点击高光环
      if (b.highlight > 0) {
        canvas.drawCircle(
          Offset(b.x, b.y),
          b.radius * 1.12,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = theme.ink.withValues(alpha: b.highlight * 0.85),
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
