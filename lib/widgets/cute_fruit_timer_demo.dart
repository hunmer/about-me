import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class CuteFruitTimerDemo extends StatelessWidget {
  const CuteFruitTimerDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EADF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: const SizedBox(
                    width: 420,
                    height: 904,
                    child: _FruitFocusTimer(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _FruitKind { orange, tomato, lemon, peach, apple, blueberry, watermelon }

class _FruitTheme {
  const _FruitTheme({
    required this.name,
    required this.slogan,
    required this.sloganColor,
    required this.colors,
    this.eyeColor = const Color(0xFF3A2C24),
    this.leafColor = const Color(0xFF28B446),
  });

  final String name;
  final String slogan;
  final Color sloganColor;
  final List<Color> colors;
  final Color eyeColor;
  final Color leafColor;
}

const _fruitThemes = <_FruitKind, _FruitTheme>{
  _FruitKind.orange: _FruitTheme(
    name: '橙子',
    slogan: 'get cute oranges',
    sloganColor: Color(0xFFE89143),
    colors: [
      Color(0xFFFF8B38),
      Color(0xFFFF9440),
      Color(0xFFFF8530),
      Color(0xFFFF9D47),
      Color(0xFFF9D448),
    ],
  ),
  _FruitKind.tomato: _FruitTheme(
    name: '小番茄',
    slogan: 'get cute tomatoes',
    sloganColor: Color(0xFFE88B3E),
    colors: [
      Color(0xFFFF8736),
      Color(0xFFFF913D),
      Color(0xFFFF7E2B),
      Color(0xFFFF9A46),
      Color(0xFFF9D448),
    ],
  ),
  _FruitKind.lemon: _FruitTheme(
    name: '柠檬',
    slogan: 'get cute lemons',
    sloganColor: Color(0xFFE0B422),
    colors: [
      Color(0xFFFAE04B),
      Color(0xFFF8D438),
      Color(0xFFFCE868),
      Color(0xFFF5C72C),
      Color(0xFFFFB642),
    ],
    leafColor: Color(0xFF2EB84B),
  ),
  _FruitKind.peach: _FruitTheme(
    name: '水蜜桃',
    slogan: 'get cute peaches',
    sloganColor: Color(0xFFF2827F),
    colors: [
      Color(0xFFFF9A96),
      Color(0xFFFF8B88),
      Color(0xFFFFA8A3),
      Color(0xFFFFB59C),
      Color(0xFFFFCF6B),
    ],
    leafColor: Color(0xFF34B850),
  ),
  _FruitKind.apple: _FruitTheme(
    name: '青苹果',
    slogan: 'get cute apples',
    sloganColor: Color(0xFF68B836),
    colors: [
      Color(0xFF8FD957),
      Color(0xFF7EC947),
      Color(0xFF9BE364),
      Color(0xFFFF7666),
      Color(0xFFF9D448),
    ],
    leafColor: Color(0xFF259E3E),
  ),
  _FruitKind.blueberry: _FruitTheme(
    name: '蓝莓',
    slogan: 'get cute blueberries',
    sloganColor: Color(0xFF6279D9),
    colors: [
      Color(0xFF6B85E8),
      Color(0xFF5C75DB),
      Color(0xFF7B94F2),
      Color(0xFF8373E6),
      Color(0xFFF9D448),
    ],
    eyeColor: Color(0xFF252136),
  ),
  _FruitKind.watermelon: _FruitTheme(
    name: '小西瓜',
    slogan: 'get cute melons',
    sloganColor: Color(0xFF3EA859),
    colors: [
      Color(0xFF4EC46B),
      Color(0xFF43B55F),
      Color(0xFF5CD178),
      Color(0xFF3DA657),
    ],
    eyeColor: Color(0xFF263829),
  ),
};

class _FruitBody {
  _FruitBody({
    required this.position,
    required this.radius,
    required this.kind,
    required this.color,
    required this.faceOffset,
    required this.leafTilt,
    required this.angle,
    this.velocity = Offset.zero,
    this.angularVelocity = 0,
  });

  Offset position;
  Offset velocity;
  final double radius;
  _FruitKind kind;
  Color color;
  final Offset faceOffset;
  final double leafTilt;
  double angle;
  double angularVelocity;
  double blinkIn = 1.5 + math.Random().nextDouble() * 4;
  double blinkFor = 0;
}

class _FruitFocusTimer extends StatefulWidget {
  const _FruitFocusTimer();

  @override
  State<_FruitFocusTimer> createState() => _FruitFocusTimerState();
}

class _FruitFocusTimerState extends State<_FruitFocusTimer>
    with SingleTickerProviderStateMixin {
  static const _cardSize = Size(354, 652);
  static const _buttonCenter = Offset(177, 348.82);
  static const _buttonSize = Size(148, 55);
  static const _fruitKinds = _FruitKind.values;

  late final Ticker _ticker;
  final _random = math.Random();
  final _fruits = <_FruitBody>[];
  final _tags = const ['Focus Tag', 'Reading', 'Coding', 'Design', 'Study'];

  _FruitKind? _selectedKind = _FruitKind.orange;
  Duration _lastElapsed = Duration.zero;
  Duration _secondAccumulator = Duration.zero;
  Duration _dropElapsed = Duration.zero;
  _FruitBody? _draggedFruit;
  int _durationMinutes = 25;
  int _remainingSeconds = 25 * 60;
  int _dropIntervalSeconds = 3;
  String _tag = 'Focus Tag';
  bool _isRunning = false;
  bool _hasStarted = false;
  bool _isConfigOpen = false;

  _FruitTheme get _currentTheme =>
      _fruitThemes[_selectedKind ?? _FruitKind.orange]!;

  @override
  void initState() {
    super.initState();
    _populateInitialPile();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final delta = _lastElapsed == Duration.zero
        ? const Duration(milliseconds: 16)
        : elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    final dt = math.min(delta.inMicroseconds / 1000000, 0.034);
    if (dt <= 0) return;

    _stepPhysics(dt);
    for (final fruit in _fruits) {
      if (fruit.blinkFor > 0) {
        fruit.blinkFor -= dt;
      } else {
        fruit.blinkIn -= dt;
        if (fruit.blinkIn <= 0) {
          fruit.blinkFor = 0.14;
          fruit.blinkIn = 2 + _random.nextDouble() * 4;
        }
      }
    }

    if (_isRunning && _remainingSeconds > 0) {
      _secondAccumulator += delta;
      _dropElapsed += delta;
      final interval = Duration(seconds: _dropIntervalSeconds);
      if (_dropElapsed >= interval) {
        _dropElapsed -= interval;
        _spawnFruit();
      }
      while (_secondAccumulator >= const Duration(seconds: 1)) {
        _secondAccumulator -= const Duration(seconds: 1);
        _remainingSeconds = math.max(0, _remainingSeconds - 1);
      }
      if (_remainingSeconds == 0) _completeFocus();
    }
    if (mounted) setState(() {});
  }

  void _stepPhysics(double dt) {
    final damping = math.pow(0.992, dt * 60).toDouble();
    for (final fruit in _fruits) {
      if (identical(fruit, _draggedFruit)) continue;
      fruit.velocity += Offset(0, 1080 * dt);
      fruit.velocity *= damping;
      fruit.position += fruit.velocity * dt;
      fruit.angle += fruit.angularVelocity * dt;
      fruit.angularVelocity *= math.pow(0.985, dt * 60);
      _collideWithBounds(fruit);
      _collideWithButton(fruit);
    }

    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < _fruits.length; i++) {
        for (var j = i + 1; j < _fruits.length; j++) {
          _collidePair(_fruits[i], _fruits[j]);
        }
      }
    }
  }

  void _collideWithBounds(_FruitBody fruit) {
    final r = fruit.radius;
    if (fruit.position.dx < r + 3) {
      fruit.position = Offset(r + 3, fruit.position.dy);
      if (fruit.velocity.dx < 0) {
        fruit.velocity = Offset(-fruit.velocity.dx * 0.3, fruit.velocity.dy);
      }
    } else if (fruit.position.dx > _cardSize.width - r - 3) {
      fruit.position = Offset(_cardSize.width - r - 3, fruit.position.dy);
      if (fruit.velocity.dx > 0) {
        fruit.velocity = Offset(-fruit.velocity.dx * 0.3, fruit.velocity.dy);
      }
    }
    if (fruit.position.dy > _cardSize.height - r - 4) {
      fruit.position = Offset(fruit.position.dx, _cardSize.height - r - 4);
      if (fruit.velocity.dy > 0) {
        fruit.velocity = Offset(
          fruit.velocity.dx * 0.88,
          -fruit.velocity.dy * 0.25,
        );
        fruit.angularVelocity += fruit.velocity.dx * 0.0008;
      }
    }
  }

  void _collideWithButton(_FruitBody fruit) {
    final half = _buttonSize / 2;
    final closest = Offset(
      fruit.position.dx.clamp(
        _buttonCenter.dx - half.width,
        _buttonCenter.dx + half.width,
      ),
      fruit.position.dy.clamp(
        _buttonCenter.dy - half.height,
        _buttonCenter.dy + half.height,
      ),
    );
    var delta = fruit.position - closest;
    var distance = delta.distance;
    if (distance >= fruit.radius) return;
    if (distance < 0.001) {
      final dx = half.width - (fruit.position.dx - _buttonCenter.dx).abs();
      final dy = half.height - (fruit.position.dy - _buttonCenter.dy).abs();
      delta = dx < dy
          ? Offset(fruit.position.dx < _buttonCenter.dx ? -1 : 1, 0)
          : Offset(0, fruit.position.dy < _buttonCenter.dy ? -1 : 1);
      distance = 0;
    }
    final normal = distance == 0 ? delta : delta / distance;
    fruit.position += normal * (fruit.radius - distance + 0.2);
    final speed = fruit.velocity.dx * normal.dx + fruit.velocity.dy * normal.dy;
    if (speed < 0) {
      fruit.velocity -= normal * (speed * 1.35);
    }
  }

  void _collidePair(_FruitBody a, _FruitBody b) {
    final delta = b.position - a.position;
    final minDistance = a.radius + b.radius;
    final distance = delta.distance;
    if (distance >= minDistance || distance < 0.001) return;
    final normal = delta / distance;
    final overlap = minDistance - distance;
    if (!identical(a, _draggedFruit)) a.position -= normal * (overlap / 2);
    if (!identical(b, _draggedFruit)) b.position += normal * (overlap / 2);
    final relative = b.velocity - a.velocity;
    final speed = relative.dx * normal.dx + relative.dy * normal.dy;
    if (speed >= 0) return;
    final impulse = normal * (-(1 + 0.28) * speed / 2);
    if (!identical(a, _draggedFruit)) a.velocity -= impulse;
    if (!identical(b, _draggedFruit)) b.velocity += impulse;
  }

  Color _pickColor(_FruitKind kind, {bool forceYellow = false}) {
    if (forceYellow ||
        ((kind == _FruitKind.orange || kind == _FruitKind.tomato) &&
            _random.nextDouble() < 0.15)) {
      return const Color(0xFFF9D448);
    }
    final colors = _fruitThemes[kind]!.colors;
    return colors[_random.nextInt(colors.length)];
  }

  _FruitBody _createFruit(
    Offset position, {
    double? radius,
    _FruitKind? kind,
    bool forceYellow = false,
  }) {
    final resolvedKind =
        kind ??
        _selectedKind ??
        _fruitKinds[_random.nextInt(_fruitKinds.length)];
    final roll = _random.nextDouble();
    final resolvedRadius =
        radius ??
        (roll < 0.08
            ? 30 + _random.nextDouble() * 7
            : roll < 0.32
            ? 15.5 + _random.nextDouble() * 2.5
            : 19 + _random.nextDouble() * 4.5);
    final fruit = _FruitBody(
      position: position,
      radius: resolvedRadius,
      kind: resolvedKind,
      color: _pickColor(resolvedKind, forceYellow: forceYellow),
      faceOffset: Offset(
        (_random.nextDouble() - 0.62) * resolvedRadius * 0.24,
        (_random.nextDouble() - 0.55) * resolvedRadius * 0.18,
      ),
      leafTilt: (_random.nextDouble() - 0.5) * 0.32,
      angle: (_random.nextDouble() - 0.5) * 1.15,
      velocity: position.dy < 120
          ? Offset((_random.nextDouble() - 0.5) * 130, 90)
          : Offset.zero,
      angularVelocity: position.dy < 120
          ? (_random.nextDouble() - 0.5) * 3.6
          : 0,
    );
    _fruits.add(fruit);
    if (_fruits.length > 85) _fruits.removeAt(0);
    return fruit;
  }

  void _spawnFruit() {
    _createFruit(Offset(38 + _random.nextDouble() * 278, -28));
  }

  void _populateInitialPile() {
    _fruits.clear();
    _createFruit(const Offset(287, 606), radius: 37);
    _createFruit(const Offset(198, 560), radius: 32);
    for (var i = 0; i < 43; i++) {
      final col = i % 7;
      final row = i ~/ 7;
      var x = 32 + col * 48.3 + (_random.nextDouble() - 0.5) * 18;
      var y = 617 - row * 44 + (_random.nextDouble() - 0.5) * 12;
      if ((x - _buttonCenter.dx).abs() < 86 &&
          (y - _buttonCenter.dy).abs() < 42) {
        y -= 75;
      }
      _createFruit(
        Offset(x, y),
        forceYellow: const [5, 12, 19, 24, 31, 38].contains(i),
      );
    }
  }

  void _selectFruit(_FruitKind? kind) {
    setState(() {
      _selectedKind = kind;
      for (var i = 0; i < _fruits.length; i++) {
        final fruit = _fruits[i];
        fruit.kind = kind ?? _fruitKinds[i % _fruitKinds.length];
        fruit.color = _pickColor(fruit.kind, forceYellow: i % 7 == 0);
      }
      _spawnFruit();
    });
  }

  void _toggleFocus() {
    setState(() {
      _isRunning = !_isRunning;
      _hasStarted = true;
      if (_isRunning) {
        if (_remainingSeconds == 0) {
          _remainingSeconds = _durationMinutes * 60;
        }
        _dropElapsed = Duration.zero;
        _spawnFruit();
      }
    });
  }

  void _resetTimer() {
    setState(() {
      _isRunning = false;
      _hasStarted = false;
      _remainingSeconds = _durationMinutes * 60;
      _dropElapsed = Duration.zero;
    });
  }

  void _completeFocus() {
    _isRunning = false;
    for (var i = 0; i < 6; i++) {
      Future.delayed(Duration(milliseconds: i * 140), () {
        if (mounted) setState(_spawnFruit);
      });
    }
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isMixed = _selectedKind == null;
    return Column(
      children: [
        SizedBox(
          height: 43,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _Toolbar(
                  children: [
                    for (final kind in _fruitKinds)
                      _ToolbarButton(
                        label:
                            '${_fruitEmoji(kind)} ${_fruitThemes[kind]!.name}',
                        selected: _selectedKind == kind,
                        onTap: () => _selectFruit(kind),
                      ),
                    _ToolbarButton(
                      label: '🧺 混合',
                      selected: isMixed,
                      onTap: () => _selectFruit(null),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        _Toolbar(
          children: [
            _ToolbarButton(
              label: '+ 掉一颗',
              color: const Color(0xFFD97724),
              onTap: () => setState(_spawnFruit),
            ),
            _ToolbarButton(
              label: '铺满',
              onTap: () => setState(_populateInitialPile),
            ),
            _ToolbarButton(label: '清空', onTap: () => setState(_fruits.clear)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: 372,
          height: 670,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFFE6DFD5),
            borderRadius: BorderRadius.circular(46),
            boxShadow: const [
              BoxShadow(
                color: Color(0x21574C43),
                blurRadius: 48,
                offset: Offset(0, 24),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(37),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFEFE0),
                    Color(0xFFFFF8F1),
                    Colors.white,
                    Colors.white,
                  ],
                  stops: [0, 0.24, 0.45, 1],
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: (_) => _draggedFruit = null,
                      onPanCancel: () => _draggedFruit = null,
                      child: CustomPaint(painter: _FruitPainter(_fruits)),
                    ),
                  ),
                  Positioned(
                    top: 42,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              setState(() => _isConfigOpen = !_isConfigOpen),
                          child: Text(
                            _formattedTime,
                            style: const TextStyle(
                              fontSize: 78,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.5,
                              color: Color(0xFF574C43),
                              fontFeatures: [],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _isConfigOpen = !_isConfigOpen),
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _tag,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF5A4F46),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                AnimatedRotation(
                                  turns: _isConfigOpen ? 0.25 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: const Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: Color(0xFF9E948A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedOpacity(
                          opacity: _isRunning ? 1 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 64,
                                height: 3,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value:
                                        _dropElapsed.inMilliseconds /
                                        (_dropIntervalSeconds * 1000),
                                    backgroundColor: const Color(0x14574C43),
                                    valueColor: const AlwaysStoppedAnimation(
                                      Color(0xFFE89143),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '每 $_dropIntervalSeconds 秒掉落一颗${isMixed ? '随机水果' : _currentTheme.name}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF9E948A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 103,
                    top: 321.32,
                    child: _StartButton(
                      label: _isRunning
                          ? 'Pause Focus'
                          : _hasStarted && _remainingSeconds > 0
                          ? 'Resume Focus'
                          : 'Start Focus',
                      running: _isRunning,
                      onTap: _toggleFocus,
                    ),
                  ),
                  if (_hasStarted)
                    Positioned(
                      left: 134,
                      top: 394,
                      child: _ResetButton(onTap: _resetTimer),
                    ),
                  Positioned(
                    top: 155,
                    left: 18,
                    child: IgnorePointer(
                      ignoring: !_isConfigOpen,
                      child: AnimatedOpacity(
                        opacity: _isConfigOpen ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: AnimatedScale(
                          scale: _isConfigOpen ? 1 : 0.96,
                          duration: const Duration(milliseconds: 200),
                          child: _buildConfigPanel(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigPanel() {
    return Container(
      width: 318,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFAFFFCF8),
        border: Border.all(color: const Color(0xFFEDE4D8), width: 2),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E574C43),
            blurRadius: 36,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _PanelLabel('专注标签 (FOCUS TAG)')),
              GestureDetector(
                onTap: () => setState(() => _isConfigOpen = false),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close, size: 17, color: Color(0xFF9C8F82)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in _tags)
                _OptionChip(
                  label: tag,
                  selected: _tag == tag,
                  onTap: () => setState(() => _tag = tag),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const _PanelLabel('专注时长 (DURATION)'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final minutes in const [1, 5, 15, 25, 45])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _OptionChip(
                      label: '${minutes}m',
                      selected: _durationMinutes == minutes,
                      onTap: () => setState(() {
                        _durationMinutes = minutes;
                        _remainingSeconds = minutes * 60;
                      }),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const _PanelLabel('掉落频率 (计时中自动掉落)'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final seconds in const [3, 8, 20, 60])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _OptionChip(
                      label: seconds == 60 ? '每 1 分钟' : '每 $seconds 秒',
                      selected: _dropIntervalSeconds == seconds,
                      onTap: () => setState(() {
                        _dropIntervalSeconds = seconds;
                        _dropElapsed = Duration.zero;
                      }),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    for (final fruit in _fruits.reversed) {
      if ((details.localPosition - fruit.position).distance <= fruit.radius) {
        _draggedFruit = fruit;
        fruit.velocity = Offset.zero;
        break;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final fruit = _draggedFruit;
    if (fruit == null) return;
    fruit.velocity = details.delta * 45;
    fruit.position = Offset(
      (fruit.position.dx + details.delta.dx).clamp(
        fruit.radius,
        _cardSize.width - fruit.radius,
      ),
      (fruit.position.dy + details.delta.dy).clamp(
        fruit.radius,
        _cardSize.height - fruit.radius,
      ),
    );
  }

  static String _fruitEmoji(_FruitKind kind) => switch (kind) {
    _FruitKind.orange => '🍊',
    _FruitKind.tomato => '🍅',
    _FruitKind.lemon => '🍋',
    _FruitKind.peach => '🍑',
    _FruitKind.apple => '🍏',
    _FruitKind.blueberry => '🫐',
    _FruitKind.watermelon => '🍉',
  };
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xE0FFFBF6),
        border: Border.all(color: const Color(0xFFE6DFD5), width: 2),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14574C43),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5B5045) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : color ?? const Color(0xFF786B5F),
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.label,
    required this.running,
    required this.onTap,
  });

  final String label;
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: running ? const Color(0xFF4A4036) : const Color(0xFF5B5045),
      borderRadius: BorderRadius.circular(30),
      elevation: 4,
      shadowColor: const Color(0x405B5045),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          width: 148,
          height: 55,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xD9FFFFFF),
          border: Border.all(color: const Color(0xFFE6DFD5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Reset Timer',
          style: TextStyle(
            color: Color(0xFF786B5F),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PanelLabel extends StatelessWidget {
  const _PanelLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: Color(0xFF9C8F82),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5B5045) : const Color(0xFFF3EADF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF574C43),
          ),
        ),
      ),
    );
  }
}

class _FruitPainter extends CustomPainter {
  const _FruitPainter(this.fruits);

  final List<_FruitBody> fruits;

  @override
  void paint(Canvas canvas, Size size) {
    for (final fruit in fruits) {
      canvas.save();
      canvas.translate(fruit.position.dx, fruit.position.dy);
      canvas.rotate(fruit.angle);
      _paintFruit(canvas, fruit);
      canvas.restore();
    }
  }

  void _paintFruit(Canvas canvas, _FruitBody fruit) {
    final r = fruit.radius;
    final theme = _fruitThemes[fruit.kind]!;
    final fill = Paint()..color = fruit.color;
    final bodyRect = Rect.fromCenter(
      center: Offset(0, r * 0.02),
      width: r * 2.02,
      height: r * (fruit.kind == _FruitKind.lemon ? 1.84 : 1.92),
    );
    canvas.drawOval(bodyRect, fill);

    if (fruit.kind == _FruitKind.watermelon) {
      canvas.save();
      canvas.clipPath(Path()..addOval(bodyRect));
      final stripe = Paint()
        ..color = const Color(0xFF298040)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.2, r * 0.13)
        ..strokeCap = StrokeCap.round;
      for (final offset in [-0.52, 0.0, 0.52]) {
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(offset * r * 1.35, 0),
            radius: r * 1.1,
          ),
          -0.38 * math.pi,
          0.76 * math.pi,
          false,
          stripe,
        );
      }
      canvas.restore();
    } else if (fruit.kind == _FruitKind.peach) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(-r * 0.15, 0), radius: r * 0.72),
        -0.35 * math.pi,
        0.6 * math.pi,
        false,
        Paint()
          ..color = const Color(0x38DB5C5C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, r * 0.06),
      );
    }

    _paintCalyx(canvas, r, theme.leafColor, fruit.leafTilt);
    if (fruit.kind == _FruitKind.orange) {
      final dots = Paint()..color = const Color(0x38D65A12);
      for (final point in [
        Offset(r * .38, r * .28),
        Offset(r * .24, r * .44),
        Offset(r * .45, r * .08),
      ]) {
        canvas.drawCircle(point, math.max(.8, r * .038), dots);
      }
    }
    _paintFace(canvas, fruit, theme.eyeColor);
  }

  void _paintCalyx(Canvas canvas, double r, Color color, double tilt) {
    canvas.save();
    canvas.translate(0, -r * 0.82);
    canvas.rotate(tilt);
    canvas.scale(r / 22);
    final path = Path()
      ..moveTo(0, -10.5)
      ..quadraticBezierTo(2.2, -5.5, 3.2, -3.2)
      ..quadraticBezierTo(8.5, -5.8, 11.5, -3.5)
      ..quadraticBezierTo(7.5, -0.2, 4.8, 1.2)
      ..quadraticBezierTo(8.2, 4.8, 7.8, 7.8)
      ..quadraticBezierTo(3.2, 5.2, 0.2, 3.4)
      ..quadraticBezierTo(-3.2, 5.8, -6.8, 7.5)
      ..quadraticBezierTo(-6.2, 3.2, -4.5, 0.8)
      ..quadraticBezierTo(-9.5, -1.2, -11.5, -4.2)
      ..quadraticBezierTo(-6.5, -5.5, -2.6, -3.2)
      ..quadraticBezierTo(-1.8, -7.2, 0, -10.5)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  void _paintFace(Canvas canvas, _FruitBody fruit, Color color) {
    final r = fruit.radius;
    canvas.save();
    canvas.translate(fruit.faceOffset.dx, fruit.faceOffset.dy);
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final spacing = math.max(3.2, r * 0.19);
    final eyeY = -r * 0.08;
    final eyeRadiusX = math.max(1.3, r * 0.068);
    final eyeRadiusY = math.max(1.7, r * 0.088);
    if (fruit.blinkFor > 0) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, r * 0.065);
      canvas.drawLine(
        Offset(-spacing - eyeRadiusX, eyeY),
        Offset(-spacing + eyeRadiusX, eyeY),
        paint,
      );
      canvas.drawLine(
        Offset(spacing - eyeRadiusX, eyeY),
        Offset(spacing + eyeRadiusX, eyeY),
        paint,
      );
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-spacing, eyeY),
          width: eyeRadiusX * 2,
          height: eyeRadiusY * 2,
        ),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(spacing, eyeY),
          width: eyeRadiusX * 2,
          height: eyeRadiusY * 2,
        ),
        paint,
      );
    }
    final smileWidth = math.max(2.6, r * 0.15);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, r * 0.068);
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(0, eyeY + math.max(2.5, r * 0.14) - smileWidth * 0.25),
        radius: smileWidth,
      ),
      0.22 * math.pi,
      0.56 * math.pi,
      false,
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FruitPainter oldDelegate) => true;
}
