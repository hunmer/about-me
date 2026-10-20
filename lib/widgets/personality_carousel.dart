import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 人格特质徽章数据
class PersonalityTrait {
  ///  emoji 图标
  final String icon;

  /// 标签文案
  final String label;

  const PersonalityTrait({required this.icon, required this.label});
}

/// 内置小人（发光圆球）的面部风格
enum PersonalityOrbStyle { friend, commander, guardian, dataNerd }

/// 人格选项数据
///
/// 展示内容二选一：
/// - [orbStyle]：使用内置的发光小圆球（带面部五官）
/// - [avatarBuilder]：自定义展示组件（如图片、图标等），优先级高于 [orbStyle]
class PersonalityItem {
  /// 人格名称
  final String name;

  /// 气泡语录
  final String quote;

  /// 描述文案
  final String description;

  /// 特质徽章列表
  final List<PersonalityTrait> traits;

  /// 气泡倾斜角度（度）
  final double bubbleAngle;

  /// 气泡小尾巴的水平位置（百分比 0-100）
  final double tailLeftPercent;

  /// 顶部氛围光主色
  final Color glowPrimary;

  /// 顶部氛围光辅色
  final Color glowSecondary;

  /// 内置小圆球风格（为 null 时必须提供 [avatarBuilder]）
  final PersonalityOrbStyle? orbStyle;

  /// 自定义展示组件（如图片），优先级高于 [orbStyle]
  /// [size] 为可用展示区域边长（约 176）
  final Widget Function(BuildContext context, double size)? avatarBuilder;

  const PersonalityItem({
    required this.name,
    required this.quote,
    required this.description,
    this.traits = const [],
    this.bubbleAngle = 0,
    this.tailLeftPercent = 50,
    required this.glowPrimary,
    required this.glowSecondary,
    this.orbStyle,
    this.avatarBuilder,
  }) : assert(
          orbStyle != null || avatarBuilder != null,
          'orbStyle 与 avatarBuilder 至少提供一个',
        );

  /// 内置默认人格（Friend / Commander / Guardian / Data Nerd）
  static List<PersonalityItem> get defaultPersonas => const [
        PersonalityItem(
          name: 'Friend',
          orbStyle: PersonalityOrbStyle.friend,
          glowPrimary: Color.fromRGBO(148, 142, 255, 1),
          glowSecondary: Color.fromRGBO(195, 190, 255, 1),
          quote: 'You’re doing great! Small steps like this really add up.',
          bubbleAngle: -3.4,
          tailLeftPercent: 28,
          traits: [
            PersonalityTrait(icon: '❤️', label: 'Supportive'),
            PersonalityTrait(icon: '✨', label: 'Positive'),
            PersonalityTrait(icon: '🤗', label: 'Caring'),
          ],
          description:
              'Focuses on how you’re feeling and helps you stay balanced. Offers gentle guidance, celebrates small wins, and supports healthy habits without pressure.',
        ),
        PersonalityItem(
          name: 'Commander',
          orbStyle: PersonalityOrbStyle.commander,
          glowPrimary: Color.fromRGBO(246, 136, 118, 1),
          glowSecondary: Color.fromRGBO(252, 198, 168, 1),
          quote: 'Focus up! Stay sharp and keep moving forward.',
          bubbleAngle: 0,
          tailLeftPercent: 50,
          traits: [
            PersonalityTrait(icon: '⚡', label: 'Focused'),
            PersonalityTrait(icon: '🔥', label: 'Decisive'),
            PersonalityTrait(icon: '🫡', label: 'Action-Driven'),
          ],
          description:
              'Cuts through the noise and helps you move forward. Highlights what matters most and gives clear, direct guidance so you can stay on track and keep momentum.',
        ),
        PersonalityItem(
          name: 'Guardian',
          orbStyle: PersonalityOrbStyle.guardian,
          glowPrimary: Color.fromRGBO(245, 182, 95, 1),
          glowSecondary: Color.fromRGBO(253, 218, 158, 1),
          quote: 'Take it steady today. Protect your energy.',
          bubbleAngle: 3.4,
          tailLeftPercent: 72,
          traits: [
            PersonalityTrait(icon: '💗', label: 'Protective'),
            PersonalityTrait(icon: '💪', label: 'Cautious'),
            PersonalityTrait(icon: '😌', label: 'Steady'),
          ],
          description:
              'Keeps an eye on your wellbeing and helps you avoid pushing too far. Points out risks, encourages balance, and supports choices that protect your long-term health.',
        ),
        PersonalityItem(
          name: 'Data Nerd',
          orbStyle: PersonalityOrbStyle.dataNerd,
          glowPrimary: Color.fromRGBO(98, 212, 168, 1),
          glowSecondary: Color.fromRGBO(172, 238, 212, 1),
          quote: 'I’m seeing a pattern in your data that’s worth exploring.',
          bubbleAngle: 0,
          tailLeftPercent: 34,
          traits: [
            PersonalityTrait(icon: '🧐', label: 'Curious'),
            PersonalityTrait(icon: '🔎', label: 'Insightful'),
            PersonalityTrait(icon: '🧠', label: 'Analytical'),
          ],
          description:
              'Looks closely at your data to uncover patterns and trends. Explains what’s happening in a clear way so you can better understand how your habits affect your health.',
        ),
      ];
}

/// 内置小圆球的配色方案
class _OrbPalette {
  final Color aura;
  final List<Color> sphere;

  const _OrbPalette(this.aura, this.sphere);
}

const Map<PersonalityOrbStyle, _OrbPalette> _orbPalettes = {
  PersonalityOrbStyle.friend: _OrbPalette(
    Color(0xFF7986FF),
    [Color(0xFF9EB2FF), Color(0xFF6D7CFF), Color(0xFF5C64F4)],
  ),
  PersonalityOrbStyle.commander: _OrbPalette(
    Color(0xFFFF6B63),
    [Color(0xFFFFA69E), Color(0xFFF4635A), Color(0xFFE34339)],
  ),
  PersonalityOrbStyle.guardian: _OrbPalette(
    Color(0xFFF8A54B),
    [Color(0xFFFFD39E), Color(0xFFF59C42), Color(0xFFE58225)],
  ),
  PersonalityOrbStyle.dataNerd: _OrbPalette(
    Color(0xFF52C79F),
    [Color(0xFFAEF4DC), Color(0xFF52C29B), Color(0xFF3BA882)],
  ),
};

/// PersonalityCarousel - AI 人格选择轮播
///
/// 由 ai_personality_carousel.html 的选择弹窗部分转换而来（不含初始设置页）。
/// 支持水平拖拽/点按切换、弹簧物理回弹、眨眼与眼球视差动效、氛围光渐变。
///
/// 使用示例：
/// ```dart
/// PersonalityCarousel(
///   items: PersonalityItem.defaultPersonas,
///   onConfirm: (item, index) => print('选择了 ${item.name}'),
///   onClose: () => Navigator.pop(context),
/// )
/// ```
class PersonalityCarousel extends StatefulWidget {
  /// 人格选项列表，默认使用内置 4 个小人
  final List<PersonalityItem>? items;

  /// 初始（已保存）选中下标
  final int initialIndex;

  /// 标题
  final String title;

  /// 背景色
  final Color backgroundColor;

  /// 是否显示顶部标题栏（关闭/标题/确认按钮）
  final bool showHeader;

  /// 确认回调（点击右上角 ✓）
  final void Function(PersonalityItem item, int index)? onConfirm;

  /// 关闭回调（点击左上角 ×），为空时默认 Navigator.maybePop
  final VoidCallback? onClose;

  const PersonalityCarousel({
    super.key,
    this.items,
    this.initialIndex = 0,
    this.title = 'Personality',
    this.backgroundColor = const Color(0xFFF4F4F8),
    this.showHeader = true,
    this.onConfirm,
    this.onClose,
  });

  @override
  State<PersonalityCarousel> createState() => _PersonalityCarouselState();
}

class _PersonalityCarouselState extends State<PersonalityCarousel>
    with TickerProviderStateMixin {
  static const double _orbSize = 176;
  static const double _orbSpacing = 242;
  static const double _dragSensitivity = 250; // 每个人格步进所需像素
  static const double _springStiffness = 0.14;
  static const double _springDamping = 0.76;
  static const double _floatPeriod = 4.2; // 漂浮/脉冲周期（秒）

  late final List<PersonalityItem> _items;
  late final Ticker _ticker;

  late int _savedIndex;
  late double _targetIndex;
  late double _currentPosition;
  double _velocity = 0;
  int _displayedIndex = -1;

  // 拖拽状态
  bool _isDragging = false;
  double _dragStartX = 0;
  double _dragStartPosition = 0;
  double _lastDragX = 0;
  int _lastDragTimeMs = 0;
  double _dragVelocityX = 0; // px / ms

  // 空闲眼球游移
  double _eyeX = 0, _eyeY = 0, _eyeTargetX = 0, _eyeTargetY = 0;
  Timer? _glanceTimer;

  // 眨眼
  double _blinkScaleY = 1;
  Timer? _blinkTimer;
  Timer? _blinkResetTimer;

  double _elapsedSeconds = 0;
  int _lastTickUs = 0;
  final math.Random _random = math.Random();

  int get _count => _items.length;

  @override
  void initState() {
    super.initState();
    _items = widget.items ?? PersonalityItem.defaultPersonas;
    _savedIndex = widget.initialIndex.clamp(0, _count - 1);
    _targetIndex = _savedIndex.toDouble();
    _currentPosition = _savedIndex.toDouble();
    _ticker = createTicker(_onTick)..start();
    _scheduleBlink();
    _scheduleGlance();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _glanceTimer?.cancel();
    _blinkTimer?.cancel();
    _blinkResetTimer?.cancel();
    super.dispose();
  }

  // ---------------- 动画主循环 ----------------

  void _onTick(Duration elapsed) {
    final dt = _lastTickUs == 0
        ? 1 / 60
        : ((elapsed.inMicroseconds - _lastTickUs) / 1e6).clamp(0.0, 0.1);
    _lastTickUs = elapsed.inMicroseconds;
    _elapsedSeconds = elapsed.inMicroseconds / 1e6;

    if (!_isDragging) {
      // 弹簧物理（以 60fps 为基准，按帧数倍率积分）
      final frames = dt * 60;
      final diff = _wrappedDelta(_targetIndex, _currentPosition);
      _velocity = (_velocity + diff * _springStiffness * frames) *
          math.pow(_springDamping, frames);
      _currentPosition += _velocity * frames;
      _currentPosition = _normalize(_currentPosition);

      // 到位后完全静止，避免微幅残速造成的抖动
      if (diff.abs() < 0.0005 && _velocity.abs() < 0.0005) {
        _velocity = 0;
        _currentPosition = _targetIndex;
      }
    }

    // 眼球游移平滑插值
    _eyeX = _lerp(_eyeX, _eyeTargetX, 0.08);
    _eyeY = _lerp(_eyeY, _eyeTargetY, 0.08);

    final nearest = _normalize(_currentPosition.roundToDouble()).toInt();
    if (_displayedIndex != nearest) {
      _displayedIndex = nearest;
    }
    if (mounted) setState(() {});
  }

  double _normalize(double v) => ((v % _count) + _count) % _count;

  /// 环形最短带符号偏移
  double _wrappedDelta(double itemIndex, double scrollPos) {
    var diff = itemIndex - scrollPos;
    while (diff > _count / 2) {
      diff -= _count;
    }
    while (diff < -_count / 2) {
      diff += _count;
    }
    return diff;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _goTo(int index) {
    setState(() => _targetIndex = _normalize(index.toDouble()));
  }

  // ---------------- 眨眼 / 游移 ----------------

  void _scheduleBlink() {
    _blinkTimer =
        Timer(Duration(milliseconds: 2200 + _random.nextInt(2800)), () {
      if (!mounted) return;
      if (!_isDragging) {
        setState(() => _blinkScaleY = 0.08);
        _blinkResetTimer?.cancel();
        _blinkResetTimer = Timer(const Duration(milliseconds: 110), () {
          if (mounted) setState(() => _blinkScaleY = 1);
        });
      }
      _scheduleBlink();
    });
  }

  void _scheduleGlance() {
    _glanceTimer =
        Timer(Duration(milliseconds: 1800 + _random.nextInt(2200)), () {
      if (!mounted) return;
      if (!_isDragging) {
        if (_random.nextDouble() < 0.45) {
          _eyeTargetX = 0;
          _eyeTargetY = 0;
        } else {
          _eyeTargetX = (_random.nextDouble() - 0.5) * 9;
          _eyeTargetY = (_random.nextDouble() - 0.5) * 5;
        }
      }
      _scheduleGlance();
    });
  }

  // ---------------- 拖拽手势 ----------------

  void _onDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragStartX = details.globalPosition.dx;
    _lastDragX = _dragStartX;
    _dragStartPosition = _currentPosition;
    _lastDragTimeMs = DateTime.now().millisecondsSinceEpoch;
    _dragVelocityX = 0;
    _velocity = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dtMs = math.max(1, now - _lastDragTimeMs);
    final dx = details.globalPosition.dx - _lastDragX;
    _dragVelocityX = dx / dtMs;
    _lastDragX = details.globalPosition.dx;
    _lastDragTimeMs = now;

    final totalDx = details.globalPosition.dx - _dragStartX;
    setState(() {
      _currentPosition =
          _normalize(_dragStartPosition - totalDx / _dragSensitivity);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;
    final projected = _currentPosition - _dragVelocityX * 0.45;
    _velocity = -_dragVelocityX * 0.04;
    setState(() {
      _targetIndex = _normalize(projected.roundToDouble());
    });
  }

  // ---------------- 构建 ----------------

  @override
  Widget build(BuildContext context) {
    final activeItem = _items[_displayedIndex < 0 ? _savedIndex : _displayedIndex];
    final distFromSnap =
        _wrappedDelta(_normalize(_currentPosition.roundToDouble()), _currentPosition)
            .abs();
    final visibility = math.max(0.0, 1 - distFromSnap * 2.85);

    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          // 顶部氛围光（随当前位置渐变插值）
          Positioned(
            top: -60,
            left: -MediaQuery.of(context).size.width * 0.15,
            right: -MediaQuery.of(context).size.width * 0.15,
            height: 410,
            child: IgnorePointer(child: _buildAmbientGlow()),
          ),
          Column(
            children: [
              if (widget.showHeader) _buildHeader(),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      SizedBox(height: 225, child: _buildOrbsTrack()),
                      // 对话气泡
                      SizedBox(
                        height: 86,
                        child: Center(
                          child: Opacity(
                            opacity: visibility.clamp(0.0, 1.0),
                            child: Transform(
                              alignment: Alignment.topCenter,
                              transform: Matrix4.identity()
                                ..translate(0.0, _lerp(10, 0, visibility))
                                ..scale(_lerp(0.9, 1.0, visibility))
                                ..rotateZ(activeItem.bubbleAngle * math.pi / 180),
                              child: _buildSpeechBubble(activeItem),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildPaginationDots(),
                      const SizedBox(height: 20),
                      // 详情（名称 / 特质 / 描述）
                      Opacity(
                        opacity: math.max(0.08, visibility),
                        child: Transform.translate(
                          offset: Offset(0, _lerp(8, 0, visibility)),
                          child: _buildDetails(activeItem),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientGlow() {
    final floorIdx = _currentPosition.floor() % _count;
    final ceilIdx = (floorIdx + 1) % _count;
    final fraction = _currentPosition - _currentPosition.floor();

    final primary =
        Color.lerp(_items[floorIdx].glowPrimary, _items[ceilIdx].glowPrimary, fraction)!;
    final secondary = Color.lerp(
        _items[floorIdx].glowSecondary, _items[ceilIdx].glowSecondary, fraction)!;

    // 径向渐变本身已是软边缘，无需再高斯模糊（模糊每层每帧开销很大）
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.44),
          radius: 0.9,
          colors: [
            primary.withValues(alpha: 0.52),
            secondary.withValues(alpha: 0.28),
            widget.backgroundColor.withValues(alpha: 0),
          ],
          stops: const [0, 0.48, 0.8],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isSaved = _displayedIndex == _savedIndex;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleButton(
            backgroundColor: Colors.white.withValues(alpha: 0.65),
            icon: Icons.close,
            iconColor: const Color(0xFF1C1C1E),
            onTap: widget.onClose ?? () => Navigator.maybePop(context),
          ),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.2,
            ),
          ),
          _CircleButton(
            backgroundColor: isSaved
                ? const Color.fromRGBO(122, 118, 136, 0.42)
                : const Color(0xFF1C1C1E),
            icon: Icons.check,
            iconColor: Colors.white.withValues(alpha: isSaved ? 0.92 : 1),
            onTap: () {
              final index = _displayedIndex < 0 ? _savedIndex : _displayedIndex;
              setState(() => _savedIndex = index);
              widget.onConfirm?.call(_items[index], index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrbsTrack() {
    // 按 zIndex 排序绘制：离中心越远的越先画（在底层）
    final order = List<int>.generate(_count, (i) => i)
      ..sort((a, b) => _wrappedDelta(b.toDouble(), _currentPosition)
          .abs()
          .compareTo(_wrappedDelta(a.toDouble(), _currentPosition).abs()));

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [for (final i in order) _buildOrb(i)],
    );
  }

  Widget _buildOrb(int index) {
    final item = _items[index];
    final delta = _wrappedDelta(index.toDouble(), _currentPosition);
    final absDelta = delta.abs();

    final translateX = delta * _orbSpacing;
    final translateY = math.min(1.0, absDelta) * 10;
    final scale = _lerp(1.0, 0.8, math.min(1.0, absDelta));
    final extraBlur = math.max(0.0, (absDelta - 0.15) * 6.5);
    final opacity =
        absDelta > 1.45 ? 0.0 : _lerp(1.0, 0.78, math.min(1.0, absDelta));

    // 眼球视差：滑动时反向看 + 空闲游移（仅激活球）
    final swipeLookX = (delta * -28 - _velocity * 36).clamp(-24.0, 24.0);
    final activeWeight = math.max(0.0, 1 - absDelta * 1.5);
    var eyeX = swipeLookX + _eyeX * activeWeight;
    var eyeY = _eyeY * activeWeight;

    // 漂浮动效相位（与 HTML orbFloat 一致，带相位偏移）
    final phase =
        ((_elapsedSeconds / _floatPeriod) - (index * 1.1 / _floatPeriod)) % 1.0;

    // 空闲且静止时冻结侧位球的内部动效：
    // 侧位球带高斯模糊，内部动效每帧变化会迫使模糊每帧重算，导致抖动。
    // 冻结后模糊子树完全静态，由 GPU 缓存。
    final frozen = !_isDragging &&
        _velocity == 0 &&
        _currentPosition == _targetIndex &&
        extraBlur > 0.1;
    var effectivePhase = phase;
    if (frozen) {
      effectivePhase = 0.25; // 漂浮中段姿态
      eyeX = 0;
      eyeY = 0;
    }
    final floatWave = math.sin(effectivePhase * math.pi);
    final floatY = -6 * floatWave;
    final floatScale = 1 + 0.018 * floatWave;

    Widget content = SizedBox(
      width: _orbSize,
      height: _orbSize,
      child: Transform.translate(
        offset: Offset(0, floatY),
        child: Transform.scale(
          scale: floatScale,
          child: item.avatarBuilder != null
              ? _buildCustomAvatar(item, effectivePhase)
              : _buildBuiltInOrb(item, effectivePhase),
        ),
      ),
    );

    // 眼球层（自定义组件不叠加五官）
    if (item.avatarBuilder == null) {
      content = SizedBox(
        width: _orbSize,
        height: _orbSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            content,
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.translate(
                  offset: Offset(eyeX, eyeY),
                  child: Center(
                    child: _buildFace(
                      item.orbStyle!,
                      blink: index == _displayedIndex,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (extraBlur > 0.1) {
      content = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: extraBlur, sigmaY: extraBlur),
        child: content,
      );
    }

    return Transform.translate(
      offset: Offset(translateX, translateY),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if ((_dragStartX - _lastDragX).abs() < 6 &&
                  _targetIndex.round() != index) {
                _goTo(index);
              }
            },
            child: RepaintBoundary(child: content),
          ),
        ),
      ),
    );
  }

  /// 内置发光小圆球（光环 + 球体 + 高光）
  Widget _buildBuiltInOrb(PersonalityItem item, double phase) {
    final palette = _orbPalettes[item.orbStyle]!;
    final auraWave = math.sin(phase * math.pi);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 外层弥散光环（外扩 18px）
        Positioned(
          top: -18,
          left: -18,
          right: -18,
          bottom: -18,
          child: Transform.scale(
            scale: 1 + 0.08 * auraWave,
            child: Opacity(
              opacity: _lerp(0.62, 0.82, auraWave),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [palette.aura, palette.aura.withValues(alpha: 0)],
                    stops: const [0, 0.72],
                  ),
                ),
              ),
            ),
          ),
        ),
        // 球体（渐变末段透明过渡，天然软边缘）
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                colors: [...palette.sphere, palette.sphere.last.withValues(alpha: 0.2)],
                stops: const [0, 0.52, 0.82, 1],
              ),
            ),
          ),
        ),
        // 内核高光
        Positioned(
          top: _orbSize * 0.12,
          left: _orbSize * 0.16,
          width: _orbSize * 0.68,
          height: _orbSize * 0.62,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(0, -0.24),
                  colors: [
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.72],
                ),
              ),
            ),
          ),
        ),
        // Guardian 光环
        if (item.orbStyle == PersonalityOrbStyle.guardian)
          Positioned(
            top: -14 - 4 * auraWave,
            left: (_orbSize - 96) / 2,
            child: Transform.rotate(
              angle: _lerp(-4, -2, auraWave) * math.pi / 180,
              child: Transform.scale(
                scale: 1 + 0.03 * auraWave,
                child: Container(
                  width: 96,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.88),
                      width: 5.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFF0C8).withValues(alpha: 0.95),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 自定义展示组件（图片等），背后带一层同色光环
  Widget _buildCustomAvatar(PersonalityItem item, double phase) {
    final auraWave = math.sin(phase * math.pi);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Transform.scale(
          scale: 1 + 0.08 * auraWave,
          child: Opacity(
            opacity: _lerp(0.5, 0.7, auraWave),
            child: Container(
              width: _orbSize + 36,
              height: _orbSize + 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    item.glowPrimary,
                    item.glowPrimary.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.72],
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: _orbSize,
          height: _orbSize,
          child: item.avatarBuilder!(context, _orbSize),
        ),
      ],
    );
  }

  /// 内置五官（带眨眼动画）
  Widget _buildFace(PersonalityOrbStyle style, {required bool blink}) {
    const eyeColor = Color(0xE6FFFFFF); // white 90%
    const eyeShadow = [
      BoxShadow(color: Color(0x80FFFFFF), blurRadius: 12),
    ];

    Widget eyes;
    switch (style) {
      case PersonalityOrbStyle.friend:
        eyes = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _eye(24, 38, eyeColor, eyeShadow),
            const SizedBox(width: 24),
            _eye(24, 38, eyeColor, eyeShadow),
          ],
        );
        break;
      case PersonalityOrbStyle.commander:
        eyes = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: 15 * math.pi / 180,
              child: _commanderEye(eyeColor),
            ),
            const SizedBox(width: 20),
            Transform.rotate(
              angle: -15 * math.pi / 180,
              child: _commanderEye(eyeColor),
            ),
          ],
        );
        break;
      case PersonalityOrbStyle.guardian:
        eyes = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _eye(34, 19, eyeColor, eyeShadow),
            const SizedBox(width: 24),
            _eye(34, 19, eyeColor, eyeShadow),
          ],
        );
        break;
      case PersonalityOrbStyle.dataNerd:
        eyes = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _stem(),
            _lens(eyeColor),
            Container(width: 14, height: 4.5, color: eyeColor),
            _lens(eyeColor),
            _stem(),
          ],
        );
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeInOut,
      transformAlignment: Alignment.center,
      transform: Matrix4.diagonal3Values(1, blink ? _blinkScaleY : 1, 1),
      child: eyes,
    );
  }

  Widget _eye(double w, double h, Color color, List<BoxShadow> shadow) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: shadow,
      ),
    );
  }

  Widget _commanderEye(Color color) {
    return Container(
      width: 34,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(5),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [BoxShadow(color: Color(0x73FFFFFF), blurRadius: 12)],
      ),
    );
  }

  Widget _stem() {
    return Container(
      width: 9,
      height: 4.5,
      decoration: BoxDecoration(
        color: const Color(0xEBFFFFFF),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _lens(Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Color(0x80FFFFFF), blurRadius: 14)],
      ),
    );
  }

  Widget _buildSpeechBubble(PersonalityItem item) {
    const bubbleWidth = 288.0;
    return SizedBox(
      width: bubbleWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 小尾巴
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: const Cubic(0.22, 1, 0.36, 1),
            top: -9,
            left: bubbleWidth * item.tailLeftPercent / 100 - 10,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          Container(
            width: bubbleWidth,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(20, 20, 40, 0.09),
                  blurRadius: 32,
                  offset: Offset(0, 14),
                  spreadRadius: -8,
                ),
                BoxShadow(
                  color: Color.fromRGBO(20, 20, 40, 0.04),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Text(
              item.quote,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationDots() {
    final active = _displayedIndex < 0 ? _savedIndex : _displayedIndex;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _count; i++)
          GestureDetector(
            onTap: () => _goTo(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 7,
                height: 7,
                transform: i == active
                    ? (Matrix4.identity()..scale(1.1))
                    : Matrix4.identity(),
                transformAlignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == active
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFFC7C7CC),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetails(PersonalityItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C1C1E),
              letterSpacing: -0.46,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final trait in item.traits)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.04),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(trait.icon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        trait.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C2C2E),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 318),
            child: Text(
              item.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.52,
                color: Color(0xFF52525B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 圆形图标按钮（关闭 / 确认）
class _CircleButton extends StatelessWidget {
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _CircleButton({
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.06),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}
