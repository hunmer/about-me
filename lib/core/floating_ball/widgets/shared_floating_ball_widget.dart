import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:aboutme/core/floating_ball/adapters/floating_ball_platform_adapter.dart';
import 'package:aboutme/core/floating_ball/models/floating_ball_gesture.dart';
import 'package:aboutme/core/floating_ball/config/floating_ball_config.dart';
import 'package:aboutme/core/floating_ball/floating_ball_manager.dart';
import 'package:aboutme/core/floating_ball/floating_ball_service.dart';

/// 可复用的悬浮球组件
class SharedFloatingBallWidget extends StatefulWidget {
  /// 基础尺寸
  final double baseSize;

  /// 主题色
  final Color color;

  /// 图标路径
  final String iconPath;

  /// 平台适配器
  final FloatingBallPlatformAdapter? platformAdapter;

  /// 手势回调
  final Function(FloatingBallGesture gesture)? onGesture;

  /// 位置变化回调
  final Function(Offset position)? onPositionChanged;

  /// 大小变化回调
  final Function(double scale)? onSizeChanged;

  /// 配置变更回调
  final VoidCallback? onConfigChanged;

  const SharedFloatingBallWidget({
    super.key,
    this.baseSize = 60,
    this.color = Colors.blue,
    this.iconPath = 'assets/icon/icon.png',
    this.platformAdapter,
    this.onGesture,
    this.onPositionChanged,
    this.onSizeChanged,
    this.onConfigChanged,
  });

  @override
  State<SharedFloatingBallWidget> createState() =>
      _SharedFloatingBallWidgetState();
}

class _SharedFloatingBallWidgetState extends State<SharedFloatingBallWidget>
    with TickerProviderStateMixin {
  late FloatingBallPlatformAdapter _adapter;
  final FloatingBallManager _manager = FloatingBallManager();
  Offset? _position;
  bool _isDragging = false;
  Timer? _longPressTimer;
  Offset? _dragStartPosition;
  bool _isLoading = true;
  bool _canDrag = false;
  Offset? _lastLongPressDragUpdate;
  Offset? _panStartPosition;
  DateTime? _panStartTime;
  bool _pointerDown = false;
  final GlobalKey _ballKey = GlobalKey();

  // 大小缩放（从配置加载）
  double _sizeScale = 1.0;

  // 自定义双击检测
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  Timer? _doubleTapTimer;
  static const int _doubleTapThresholdMs = 300; // 双击时间阈值
  static const double _doubleTapDistanceThreshold = 50.0; // 双击位置阈值（像素）

  // 监听大小和位置变化的订阅
  StreamSubscription<double>? _sizeSubscription;
  StreamSubscription<Offset>? _positionSubscription;
  StreamSubscription<void>? _configSubscription;

  // 贴边收纳状态
  bool _edgeDockEnabled = false;
  bool _isDocked = false;
  Timer? _dockTimer;

  // 图标配置
  String _iconKey = FloatingBallIconPresets.defaultKey;
  Uint8List? _customIconBytes;

  /// 展开后无操作恢复收纳的时长
  static const Duration _undockTimeout = Duration(seconds: 5);

  /// 收纳时露出屏幕外的比例（0.3 = 露出 30%）
  static const double _dockVisibleRatio = 0.3;

  /// 收纳/展开位移动画时长
  static const Duration _dockAnimDuration = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _initialize();

    // 监听大小变化
    _sizeSubscription = FloatingBallService().sizeChangeStream.listen((scale) {
      if (mounted && !_isDragging) {
        // 只在非拖动状态下响应大小变化
        setState(() {
          _sizeScale = scale;
        });
      }
    });

    // 监听位置变化（重置位置）
    _positionSubscription = FloatingBallService().positionChangeStream.listen((
      position,
    ) async {
      // 只在非拖动状态下响应位置变化（用于重置位置功能）
      if (mounted && !_isDragging) {
        final newPosition = await _manager.getPosition();
        setState(() {
          _position = _clampPosition(newPosition);
          _isDocked = false;
        });
        _cancelDockTimer();
      }
    });

    // 监听配置变化（如贴边收纳开关、图标设置）
    _configSubscription = FloatingBallService().configChangeStream.listen((
      _
    ) async {
      // 图标刷新不依赖拖动状态，先处理
      await _loadIconConfig();

      if (!mounted || _isDragging) return;
      final enabled = await _manager.isEdgeDockEnabled();
      if (!mounted || _isDragging) return;
      setState(() {
        _edgeDockEnabled = enabled;
      });
      if (enabled && _position != null) {
        _dock();
      } else if (!enabled && _isDocked) {
        _undock();
      }
    });
  }

  Future<void> _initialize() async {
    // 初始化平台适配器
    _adapter =
        widget.platformAdapter ??
        FloatingBallAdapterFactory.create(isInOverlay: false);

    await _adapter.initialize();

    // 加载大小缩放
    final scale = await _manager.getSizeScale();

    // 加载贴边收纳开关
    final edgeDockEnabled = await _manager.isEdgeDockEnabled();

    // 加载图标配置
    await _loadIconConfig();

    if (mounted) {
      setState(() {
        _sizeScale = scale;
        _edgeDockEnabled = edgeDockEnabled;
      });
    }

    _initializePosition();

    // 通知初始化完成
    widget.onConfigChanged?.call();
  }

  void _initializePosition() {
    // 从配置加载位置
    _loadPositionFromConfig();
  }

  /// 确保位置在有效范围内
  Offset _clampPosition(Offset position) {
    final screenSize = _effectiveScreenSize();
    // 确保屏幕尺寸有效，避免出现0.0的情况
    final safeWidth = screenSize.width > 0 ? screenSize.width : 400.0;
    final safeHeight = screenSize.height > 0 ? screenSize.height : 400.0;

    // 确保当前尺寸有效
    final currentSize = _currentSize > 0 ? _currentSize : 60.0;

    // 计算最大位置，确保结果大于0
    final maxX = math.max(0.0, safeWidth - currentSize);
    final maxY = math.max(0.0, safeHeight - currentSize);

    return Offset(position.dx.clamp(0, maxX), position.dy.clamp(0, maxY));
  }

  Future<void> _loadPositionFromConfig() async {
    try {
      // 从 FloatingBallManager 加载位置
      final position = await _manager.getPosition();

      if (!mounted) return;

      final screenSize = _adapter.getScreenSize(context);
      // 确保屏幕尺寸减去悬浮球尺寸后仍为正值
      final maxX = math.max(0.0, screenSize.width - _currentSize);
      final maxY = math.max(0.0, screenSize.height - _currentSize);

      // 贴边收纳开启时，超出左右边界的存储位置视为收纳态，保持原样
      final isDockedPosition =
          _edgeDockEnabled && (position.dx < 0 || position.dx > maxX);

      Offset safePosition = position;
      if (!isDockedPosition) {
        safePosition = Offset(
          position.dx.clamp(0, maxX),
          position.dy.clamp(0, maxY),
        );
      }

      setState(() {
        _position = safePosition;
        _isDocked = isDockedPosition;
        _isLoading = false;
      });

      // 只在初始化时，如果位置被调整了才保存
      if (safePosition != position) {
        await _manager.savePosition(safePosition);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _position = const Offset(20, 100);
          _isLoading = false;
        });
      }
    }
  }

  double get _currentSize => widget.baseSize * _sizeScale;

  /// 加载图标配置（预设图标 + 自定义图片）
  Future<void> _loadIconConfig() async {
    final iconKey = await _manager.getIconKey();
    final customIcon = await _manager.getCustomIcon();
    if (!mounted) return;

    Uint8List? customBytes;
    if (customIcon != null) {
      try {
        customBytes = base64Decode(customIcon);
      } catch (e) {
        debugPrint('Error decoding custom floating ball icon: $e');
      }
    }

    setState(() {
      _iconKey = iconKey;
      _customIconBytes = customBytes;
    });
  }

  // ==================== 贴边收纳 ====================

  /// 收纳位置：吸附到距离较近的左右边缘，露出一部分在屏幕内
  Offset _computeDockPosition() {
    final screenSize = _adapter.getScreenSize(context);
    final visible = _currentSize * _dockVisibleRatio;
    final dockToLeft =
        (_position!.dx + _currentSize / 2) < screenSize.width / 2;
    final x = dockToLeft
        ? -(_currentSize - visible)
        : screenSize.width - visible;
    final maxY = math.max(0.0, screenSize.height - _currentSize);
    return Offset(x, _position!.dy.clamp(0.0, maxY));
  }

  /// 收纳到屏幕边缘
  void _dock({bool save = true}) {
    if (_position == null || _isDocked) return;
    final dockPosition = _computeDockPosition();
    _cancelDockTimer();
    setState(() {
      _position = dockPosition;
      _isDocked = true;
    });
    if (save) {
      widget.onPositionChanged?.call(dockPosition);
    }
  }

  /// 展开（短暂取消收纳），并启动无操作恢复收纳的计时
  void _undock() {
    if (_position == null) return;
    final screenSize = _adapter.getScreenSize(context);
    final fromLeft = _position!.dx < 0;
    final expandX = fromLeft
        ? 4.0
        : math.max(0.0, screenSize.width - _currentSize - 4.0);
    setState(() {
      _position = Offset(expandX, _position!.dy);
      _isDocked = false;
    });
    _restartDockTimer();
  }

  /// 重置无操作计时（有交互时调用）
  void _restartDockTimer() {
    _cancelDockTimer();
    if (!_edgeDockEnabled) return;
    _dockTimer = Timer(_undockTimeout, () {
      if (!mounted) return;
      // 正在交互时顺延，等操作结束后再恢复收纳
      if (_pointerDown || _isDragging) {
        _restartDockTimer();
        return;
      }
      _dock(save: false);
    });
  }

  void _cancelDockTimer() {
    _dockTimer?.cancel();
    _dockTimer = null;
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _doubleTapTimer?.cancel();
    _dockTimer?.cancel();
    _sizeSubscription?.cancel();
    _positionSubscription?.cancel();
    _configSubscription?.cancel();
    _adapter.dispose();
    super.dispose();
  }

  // 长按按下（长按尚未确认，快速点击也会触发，不能在这里设置拖动状态）
  void _handleLongPressDown(LongPressDownDetails details) {
    if (!_adapter.supportsDragging || _position == null) return;

    // 只记录拖动起始位置，供松手时判断滑动/位移
    _dragStartPosition = details.globalPosition;
  }

  // 长按确认（500ms 后），进入可拖动状态
  void _handleLongPressStart(LongPressStartDetails details) {
    if (!_adapter.supportsDragging || _position == null) return;

    // 震动反馈，提示已进入移动模式
    HapticFeedback.mediumImpact();

    setState(() {
      _pointerDown = true;
      _canDrag = true;
      _isDragging = true;
      _lastLongPressDragUpdate = details.globalPosition;
    });
  }

  // 显示子菜单（简化版）

  // 检查指针是否在球内
  bool _isPointerInsideBall(Offset globalPosition, double ballSize) {
    if (_ballKey.currentContext == null) return false;

    final RenderBox renderBox =
        _ballKey.currentContext!.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final Offset localPosition = renderBox.globalToLocal(globalPosition);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final distance = (localPosition - center).distance;

    return distance <= radius;
  }

  // 长按拖动更新
  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_adapter.supportsDragging || _position == null || !_canDrag) return;

    final delta =
        details.globalPosition -
        (_lastLongPressDragUpdate ?? details.globalPosition);
    _lastLongPressDragUpdate = details.globalPosition;

    final screenSize = _adapter.getScreenSize(context);
    // 确保屏幕尺寸减去悬浮球尺寸后仍为正值
    final maxX = math.max(0.0, screenSize.width - _currentSize);
    final maxY = math.max(0.0, screenSize.height - _currentSize);

    final newPosition = Offset(
      (_position!.dx + delta.dx).clamp(0, maxX),
      (_position!.dy + delta.dy).clamp(0, maxY),
    );

    setState(() {
      _position = newPosition;
    });

    // 拖动过程中不触发回调，避免频繁保存和重构

    // 检查指针是否移出悬浮球
    if (_pointerDown &&
        !_isPointerInsideBall(details.globalPosition, _currentSize)) {
      _handlePointerExit(details.globalPosition);
    }
  }

  // 处理指针移出
  void _handlePointerExit(Offset exitPosition) {
    if (!_pointerDown || !_canDrag) return;

    if (_dragStartPosition != null) {
      final dragVector = exitPosition - _dragStartPosition!;
      final dragDistance = dragVector.distance;

      if (dragDistance > 10) {
        _handleSwipe(dragVector);
      }
    }

    setState(() {
      _pointerDown = false;
      _canDrag = false;
      _isDragging = false;
      _lastLongPressDragUpdate = null;
    });
  }

  // 长按结束
  void _handleLongPressEnd(LongPressEndDetails details) {
    _longPressTimer?.cancel();

    if (_position == null) return;

    if (_isDragging && _canDrag) {
      // 只在拖动结束时保存位置并触发回调
      widget.onPositionChanged?.call(_position!);

      if (_dragStartPosition != null) {
        final dragDistance =
            (_dragStartPosition! - details.globalPosition).distance;
        if (dragDistance < 10) {
          final dragVector = details.globalPosition - _dragStartPosition!;
          _handleSwipe(dragVector);
        }
      }

      // 贴边收纳开启时，拖动结束后吸附到屏幕边缘
      if (_edgeDockEnabled && !_isDocked) {
        _dock();
      }
    }

    setState(() {
      _pointerDown = false;
      _isDragging = false;
      _canDrag = false;
      _lastLongPressDragUpdate = null;
      _dragStartPosition = null;
    });
  }

  // 处理滑动
  void _handleSwipe(Offset velocity) {
    if (velocity.distance < 5) return;

    final absX = velocity.dx.abs();
    final absY = velocity.dy.abs();
    const directionThreshold = 2.0;

    FloatingBallGesture gesture;

    if (absX > absY * directionThreshold) {
      gesture =
          velocity.dx > 0
              ? FloatingBallGesture.swipeRight
              : FloatingBallGesture.swipeLeft;
    } else if (absY > absX * directionThreshold) {
      gesture =
          velocity.dy > 0
              ? FloatingBallGesture.swipeDown
              : FloatingBallGesture.swipeUp;
    } else if (absX > absY) {
      gesture =
          velocity.dx > 0
              ? FloatingBallGesture.swipeRight
              : FloatingBallGesture.swipeLeft;
    } else {
      gesture =
          velocity.dy > 0
              ? FloatingBallGesture.swipeDown
              : FloatingBallGesture.swipeUp;
    }

    // 检查适配器是否支持该手势
    if (_adapter.shouldHandleGesture(gesture)) {
      widget.onGesture?.call(gesture);
    }
  }

  // 处理点击和双击（使用 TapUp 避免与长按拖动冲突）
  void _handleTapUp(TapUpDetails details) {
    // 收纳态点击仅展开，不触发手势动作
    if (_isDocked) {
      _undock();
      return;
    }

    // 如果刚刚结束拖动，忽略此次点击
    if (_isDragging || _canDrag) {
      return;
    }

    final now = DateTime.now();
    final currentPosition = details.globalPosition;

    // 检查是否是双击
    if (_lastTapTime != null) {
      final timeDiff = now.difference(_lastTapTime!).inMilliseconds;
      final positionDiff = _lastTapPosition != null
          ? (currentPosition - _lastTapPosition!).distance
          : double.infinity;

      if (timeDiff < _doubleTapThresholdMs &&
          positionDiff < _doubleTapDistanceThreshold) {
        // 确认为双击
        widget.onGesture?.call(FloatingBallGesture.doubleTap);

        // 重置双击检测状态
        _lastTapTime = null;
        _lastTapPosition = null;
        _doubleTapTimer?.cancel();
        _doubleTapTimer = null;
        return;
      }
    }

    // 记录第一次点击
    _lastTapTime = now;
    _lastTapPosition = currentPosition;

    // 启动定时器，如果超时则认为是单击
    _doubleTapTimer?.cancel();
    _doubleTapTimer = Timer(const Duration(milliseconds: _doubleTapThresholdMs), () {
        // 超时认为是单击
      widget.onGesture?.call(FloatingBallGesture.tap);
      _lastTapTime = null;
      _lastTapPosition = null;
      _doubleTapTimer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Positioned(
        left: 170, // (400-60)/2 = 170，在400x400窗口内居中
        top: 170,
        child: SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    if (_position == null) {
      return const Positioned(
        left: 170,
        top: 170,
        child: SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    // 拖动时零时长保证跟手，收纳/展开时平滑滑动
    return AnimatedPositioned(
      left: _position!.dx,
      top: _position!.dy,
      duration: _isDragging ? Duration.zero : _dockAnimDuration,
      curve: Curves.easeOutCubic,
      child: _buildMainBall(),
    );
  }

  Widget _buildMainBall() {
    return Listener(
      onPointerDown: (event) {
        // 展开状态下任何按下都重置恢复收纳的计时
        if (_edgeDockEnabled && !_isDocked) {
          _restartDockTimer();
        }
      },
      onPointerUp: (event) {
        // 只清除按下状态；_canDrag/_isDragging 必须留给 _handleLongPressEnd
        // 清理并保存位置——原始指针事件先于手势回调执行，这里提前清空
        // 会导致 onLongPressEnd 里的保存逻辑永远不触发
        if (_pointerDown) {
          setState(() {
            _pointerDown = false;
          });
        }
      },
      onPointerMove: (event) {
        if (_pointerDown &&
            _canDrag &&
            !_isPointerInsideBall(event.position, _currentSize)) {
          _handlePointerExit(event.position);
        }
      },
      child: GestureDetector(
        onTapUp: _handleTapUp,
        onLongPressDown: _handleLongPressDown,
        onLongPressStart: _handleLongPressStart,
        onLongPressMoveUpdate: _handleLongPressMoveUpdate,
        onLongPressEnd: _handleLongPressEnd,
        onPanStart: (details) {
          if (_isDragging) return;
          setState(() {
            _panStartPosition = details.globalPosition;
            _panStartTime = DateTime.now();
          });
        },
        onPanUpdate: (details) {
          if (_isDragging || _panStartPosition == null) {
            return;
          }
        },
        onPanEnd: (details) {
          if (_isDragging || _panStartPosition == null) {
            return;
          }

          final now = DateTime.now();
          final duration = now.difference(_panStartTime!).inMilliseconds;
          final endPosition = details.globalPosition;
          final distance = (endPosition - _panStartPosition!).distance;
          final velocity = endPosition - _panStartPosition!;

          if (duration < 500 && distance > 10) {
            _handleSwipe(velocity);
          }

          setState(() {
            _panStartPosition = null;
            _panStartTime = null;
          });
        },
        child: _adapter.adaptChildWidget(
          SizedBox(
            key: _ballKey,
            width: _currentSize,
            height: _currentSize,
            child: ClipOval(
              child: Container(
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: _buildBallContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 球体内容：自定义图片 > 预设图标 > 默认图片
  Widget _buildBallContent() {
    if (_customIconBytes != null) {
      return Image.memory(
        _customIconBytes!,
        width: _currentSize,
        height: _currentSize,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildDefaultImage(),
      );
    }

    final presetIcon = FloatingBallIconPresets.iconOf(_iconKey);
    if (presetIcon != null) {
      return Icon(
        presetIcon,
        color: Colors.white,
        size: _currentSize * 0.55,
      );
    }

    return _buildDefaultImage();
  }

  Widget _buildDefaultImage() {
    return Image.asset(
      widget.iconPath,
      width: _currentSize,
      height: _currentSize,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.radio_button_on, color: Colors.white, size: _currentSize * 0.4),
    );
  }

  Size _effectiveScreenSize() {
    final screenSize = _adapter.getScreenSize(context);

    // 确保屏幕尺寸有合理的最小值，避免因窗口太小导致计算错误
    final minWidth = math.max(screenSize.width, _currentSize + 50.0);
    final minHeight = math.max(screenSize.height, _currentSize + 50.0);

    return Size(minWidth, minHeight);
  }
}
