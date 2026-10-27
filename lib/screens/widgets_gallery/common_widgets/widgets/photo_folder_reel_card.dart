/// 3D 毛玻璃照片文件夹轮播卡片
///
/// 复刻自 3d_frosted_glass_photo_folder_reel.html：
/// 多个深色文件夹横向轮播（弹簧物理拖拽 + 聚焦缩放 + 前盖 3D 倾角），
/// 每个文件夹内错落塞入若干照片卡，点击中央文件夹展开为扇形照片条，
/// 展开态横向拖拽切换照片、下滑或点击收起，顶部显示圆点指示器。
library;

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

class PhotoFolderReelCardWidget extends StatefulWidget {
  /// 文件夹数据列表
  final List<PhotoReelFolderData> folders;

  /// 初始聚焦的文件夹下标
  final int initialIndex;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const PhotoFolderReelCardWidget({
    super.key,
    required this.folders,
    this.initialIndex = 0,
    this.inline = false,
    this.size = const Large3Size(),
  });

  /// 从 props 创建实例
  factory PhotoFolderReelCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    Color parseColor(dynamic value, Color fallback) {
      if (value is Color) return value;
      if (value is int) return Color(value);
      if (value is String) {
        try {
          if (value.startsWith('#')) {
            return Color(
              int.parse(value.substring(1), radix: 16) + 0xFF000000,
            );
          }
          if (value.startsWith('0x')) {
            return Color(int.parse(value.substring(2), radix: 16));
          }
        } catch (_) {}
      }
      return fallback;
    }

    List<PhotoReelFolderData> parseFolders(dynamic data) {
      if (data is! List) return [];
      return data.map((f) {
        if (f is! Map) return const PhotoReelFolderData(title: '', photos: []);
        final rawPhotos = f['photos'];
        final photos = <PhotoReelPhotoData>[];
        if (rawPhotos is List) {
          for (int i = 0; i < rawPhotos.length; i++) {
            final p = rawPhotos[i];
            if (p is! Map) continue;
            final rawColors = p['colors'];
            final colors = <Color>[];
            if (rawColors is List) {
              for (final c in rawColors) {
                colors.add(parseColor(c, const Color(0xFF8B96A1)));
              }
            }
            final imageUrl = p['imageUrl'] as String?;
            photos.add(
              PhotoReelPhotoData.tucked(
                index: i,
                image: imageUrl != null && imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
                colors: colors.length >= 2
                    ? colors
                    : const [Color(0xFF8B96A1), Color(0xFF31363C)],
              ),
            );
          }
        }
        return PhotoReelFolderData(
          title: f['title'] as String? ?? '',
          photos: photos,
        );
      }).toList();
    }

    return PhotoFolderReelCardWidget(
      folders: parseFolders(props['folders']),
      initialIndex: (props['initialIndex'] as num?)?.toInt() ?? 0,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<PhotoFolderReelCardWidget> createState() =>
      _PhotoFolderReelCardWidgetState();
}

class _PhotoFolderReelCardWidgetState extends State<PhotoFolderReelCardWidget>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _entryAnimation;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  // 轮播弹簧状态
  late double _targetIndex;
  late double _currentPos;
  double _posVelocity = 0;

  // 展开弹簧状态
  bool _isExpanded = false;
  double _targetOpen = 0;
  double _openProgress = 0;
  double _openVelocity = 0;

  // 展开态照片弹簧状态
  double _targetPhotoIndex = 0;
  double _photoPos = 0;
  double _photoVelocity = 0;

  // 拖拽状态
  Offset _dragStart = Offset.zero;
  Offset _dragCurrent = Offset.zero;
  double _dragStartPos = 0;

  // 最近一次布局的舞台中心（用于点击命中）
  double _centerX = 0;
  double _centerY = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIndex
        .clamp(0, math.max(0, widget.folders.length - 1))
        .toDouble();
    _targetIndex = initial;
    _currentPos = initial;

    _entryController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _entryController.forward();

    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _entryController.dispose();
    super.dispose();
  }

  double get _u => widget.size.scale;

  double _defaultHeight() {
    final u = _u;
    if (widget.size is Large3Size || widget.size is Wide3Size) {
      return 440 * u;
    }
    return 400 * u;
  }

  PhotoReelFolderData get _activeFolder =>
      widget.folders[_targetIndex.round().clamp(0, widget.folders.length - 1)];

  void _onTick(Duration elapsed) {
    var dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;
    dt = math.min(dt, 0.05);

    // 与 HTML 一致的弹簧积分
    const posStiffness = 190.0;
    const posDamping = 22.0;
    final posForce = (_targetIndex - _currentPos) * posStiffness;
    _posVelocity =
        (_posVelocity + posForce * dt) * math.exp(-posDamping * dt);
    _currentPos += _posVelocity * dt;

    const openStiffness = 210.0;
    const openDamping = 23.0;
    final openForce = (_targetOpen - _openProgress) * openStiffness;
    _openVelocity =
        (_openVelocity + openForce * dt) * math.exp(-openDamping * dt);
    _openProgress += _openVelocity * dt;

    const photoStiffness = 200.0;
    const photoDamping = 24.0;
    final photoForce = (_targetPhotoIndex - _photoPos) * photoStiffness;
    _photoVelocity =
        (_photoVelocity + photoForce * dt) * math.exp(-photoDamping * dt);
    _photoPos += _photoVelocity * dt;

    if (mounted) setState(() {});
  }

  void _toggleExpand([bool? force]) {
    final next = force ?? !_isExpanded;
    _isExpanded = next;
    _targetOpen = next ? 1 : 0;
    if (next) {
      final count = _activeFolder.photos.length;
      _targetPhotoIndex = math.max(0, count - 2).toDouble();
      _photoPos = _targetPhotoIndex;
      _photoVelocity = 0;
    }
    setState(() {});
  }

  void _onPanStart(DragStartDetails details) {
    _dragStart = details.localPosition;
    _dragCurrent = _dragStart;
    _dragStartPos = _isExpanded ? _photoPos : _currentPos;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _dragCurrent = details.localPosition;
    final dx = _dragCurrent.dx - _dragStart.dx;
    if (_isExpanded) {
      final maxIdx = math.max(0, _activeFolder.photos.length - 1).toDouble();
      var next = _dragStartPos - dx / (135 * _u);
      if (next < 0) next *= 0.35;
      if (next > maxIdx) next = maxIdx + (next - maxIdx) * 0.35;
      _targetPhotoIndex = next;
    } else {
      final maxFolder = math.max(0, widget.folders.length - 1).toDouble();
      var next = _dragStartPos - dx / (145 * _u);
      if (next < 0) next *= 0.3;
      if (next > maxFolder) next = maxFolder + (next - maxFolder) * 0.3;
      _targetIndex = next;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    final dx = _dragCurrent.dx - _dragStart.dx;
    final dy = _dragCurrent.dy - _dragStart.dy;
    if (_isExpanded) {
      if (dy > 80 * _u && dy.abs() > dx.abs()) {
        _toggleExpand(false);
        return;
      }
      final maxIdx = math.max(0, _activeFolder.photos.length - 1).toDouble();
      _targetPhotoIndex = _targetPhotoIndex.round().clamp(0, maxIdx).toDouble();
    } else {
      final maxFolder = math.max(0, widget.folders.length - 1).toDouble();
      _targetIndex = _targetIndex.round().clamp(0, maxFolder).toDouble();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.folders.isEmpty) return;
    if (_isExpanded) {
      _toggleExpand(false);
      return;
    }
    final u = _u;
    final local = details.localPosition;
    final hit = _hitFolder(local, u);
    if (hit == null) return;
    if (hit == _targetIndex.round()) {
      _toggleExpand(true);
    } else {
      _targetIndex = hit.toDouble();
    }
  }

  /// 点击位置命中的文件夹下标（按当前轮播偏移计算）
  int? _hitFolder(Offset local, double u) {
    const spacing = 148.0;
    int? best;
    var bestDist = double.infinity;
    for (int idx = 0; idx < widget.folders.length; idx++) {
      final d = idx - _currentPos;
      final absD = d.abs();
      final nonLinearOffset =
          d.sign * (math.min(absD, 1.0) + math.max(0.0, absD - 1) * 0.82);
      final folderX = _centerX + nonLinearOffset * spacing * u;
      final dist = (local.dx - folderX).abs();
      if (dist < 93 * u && (local.dy - _centerY).abs() < 100 * u) {
        if (dist < bestDist) {
          bestDist = dist;
          best = idx;
        }
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final u = _u;

    return FadeTransition(
      opacity: _entryAnimation,
      child: SizedBox(
        width: widget.inline ? double.maxFinite : 384 * u,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _centerX = constraints.maxWidth / 2;
            _centerY = constraints.maxHeight / 2;
            if (widget.folders.isEmpty) return const SizedBox.shrink();

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onTapUp: _onTapUp,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ..._buildFolders(theme, u),
                  _buildDotsIndicator(u),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 按 |d| 降序绘制，保证聚焦文件夹在最上层
  List<Widget> _buildFolders(AppThemeData theme, double u) {
    final entries = <MapEntry<int, double>>[];
    for (int i = 0; i < widget.folders.length; i++) {
      entries.add(MapEntry(i, (i - _currentPos).abs()));
    }
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map((e) => _buildFolderItem(e.key, theme, u))
        .toList();
  }

  Widget _buildFolderItem(int idx, AppThemeData theme, double u) {
    const spacing = 148.0;
    final folder = widget.folders[idx];
    final d = idx - _currentPos;
    final absD = d.abs();

    final focusWeight = math.max(
      0.0,
      math.cos(math.min(absD, 1.2) * (math.pi / 2.4)),
    );
    final nonLinearOffset =
        d.sign * (math.min(absD, 1.0) + math.max(0.0, absD - 1) * 0.82);
    final x = nonLinearOffset * spacing * u;
    final baseScale = 0.56 + 0.44 * math.pow(focusWeight, 1.35);

    final isCenterFolder = absD < 0.45;
    final openP = _openProgress.clamp(0.0, 1.2);

    final folderY = (isCenterFolder ? openP * 108 : openP * 30) * u;
    final folderOpacity = isCenterFolder
        ? 1.0
        : (1 - openP * 1.6).clamp(0.0, 1.0);
    final folderScale = isCenterFolder
        ? baseScale * (1 - openP * 0.22)
        : baseScale * (1 - openP * 0.18);

    final flapTilt =
        -focusWeight * 6 - (isCenterFolder ? openP * 18 : 0);

    final labelColor = Color.lerp(
      theme.text,
      theme.textSub,
      (1 - focusWeight).clamp(0.0, 1.0),
    );

    return Positioned(
      left: _centerX + x - 93 * u,
      top: _centerY + folderY - 94 * u,
      child: Opacity(
        opacity: folderOpacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()..scale(folderScale),
              child: SizedBox(
                width: 184 * u,
                height: 146 * u,
                child: _buildFolderBody(folder, isCenterFolder, openP,
                    focusWeight, flapTilt, u),
              ),
            ),
            SizedBox(height: 15 * u),
            Text(
              folder.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16 * u,
                height: 1.2,
                letterSpacing: -0.015 * 16 * u,
                color: labelColor,
                fontWeight:
                    focusWeight > 0.65 ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 文件夹主体：背部底板 + 照片槽 + 毛玻璃前盖（带 3D 倾角）
  Widget _buildFolderBody(
    PhotoReelFolderData folder,
    bool isCenterFolder,
    double openP,
    double focusWeight,
    double flapTilt,
    double u,
  ) {
    final photos = folder.photos;

    // 照片堆叠顺序：展开后按与当前照片距离排序（远处先画），否则按 tuckedZ
    final order = List<int>.generate(photos.length, (i) => i);
    if (isCenterFolder && openP > 0.35) {
      order.sort(
        (a, b) => (b - _photoPos).abs().compareTo((a - _photoPos).abs()),
      );
    } else {
      order.sort((a, b) => photos[a].tuckedZ.compareTo(photos[b].tuckedZ));
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 背部深色底板 + 标签凸起
        Positioned.fill(
          child: CustomPaint(painter: _FolderBackPainter(scale: u)),
        ),
        // 照片槽
        for (final pIdx in order)
          Positioned(
            left: 43 * u,
            bottom: 8 * u,
            width: 98 * u,
            height: 122 * u,
            child: _buildPhotoCard(
              photos[pIdx],
              pIdx,
              isCenterFolder,
              openP,
              focusWeight,
              u,
            ),
          ),
        // 毛玻璃前盖（绕底部 X 轴倾斜）
        Positioned(
          left: 0,
          right: 0,
          top: 20 * u,
          bottom: 0,
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateX(flapTilt * math.pi / 180),
            child: ClipPath(
              clipper: _FolderFrontClipper(),
              child: CustomPaint(
                painter: _FolderFrontPainter(scale: u),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard(
    PhotoReelPhotoData photo,
    int pIdx,
    bool isCenterFolder,
    double openP,
    double focusWeight,
    double u,
  ) {
    final t = photo;
    final peekBoost = focusWeight * 6;
    final tuckedX = t.tuckedX * u;
    final tuckedY = t.tuckedY * u - peekBoost * u;
    final tuckedRot = t.tuckedRotation * (0.85 + 0.15 * focusWeight);
    final tuckedScale = t.tuckedScale;

    double curX = tuckedX;
    double curY = tuckedY;
    double curRot = tuckedRot;
    double curScale = tuckedScale;

    if (isCenterFolder && openP > 0.001) {
      final relP = pIdx - _photoPos;
      final absRelP = relP.abs();
      final expandedX = relP * 142 * u;
      final expandedY = (-205 + absRelP * 14) * u;
      final expandedRot = relP * 5.5;
      final expandedScale = math.max(0.86, 1.52 - absRelP * 0.18);

      curX = tuckedX + (expandedX - tuckedX) * openP;
      curY = tuckedY + (expandedY - tuckedY) * openP;
      curRot = tuckedRot + (expandedRot - tuckedRot) * openP;
      curScale = tuckedScale + (expandedScale - tuckedScale) * openP;
    }

    return Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.translationValues(curX, curY, 0)
        ..rotateZ(curRot * math.pi / 180)
        ..scale(curScale),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11 * u),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.36),
              blurRadius: 16 * u,
              offset: Offset(0, 6 * u),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 3 * u,
              offset: Offset(0, 1 * u),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11 * u),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photo.image != null)
                Image(image: photo.image!, fit: BoxFit.cover)
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: photo.colors,
                    ),
                  ),
                ),
              // 表面微弱光泽
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x2EFFFFFF),
                      Color(0x00FFFFFF),
                      Color(0x2E000000),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 展开态顶部圆点指示器
  Widget _buildDotsIndicator(double u) {
    final visible = _openProgress > 0.5;
    final count = widget.folders.isEmpty ? 0 : _activeFolder.photos.length;
    final active = _photoPos.round().clamp(0, math.max(0, count - 1));
    final dotColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Positioned(
      left: 0,
      right: 0,
      top: _centerY - 178 * u,
      child: IgnorePointer(
        child: Opacity(
          opacity: visible ? 1 : 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: EdgeInsets.symmetric(horizontal: 3 * u),
                  width: i == active ? 14 * u : 5 * u,
                  height: 5 * u,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: dotColor.withValues(alpha: i == active ? 0.75 : 0.2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 文件夹背部：标签小凸起 + 深色渐变底板
class _FolderBackPainter extends CustomPainter {
  final double scale;

  _FolderBackPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final u = scale;
    final backRect = Rect.fromLTRB(6 * u, 12 * u, size.width - 6 * u, size.height - 2 * u);

    // 投影
    final shadowPath = Path()
      ..addRRect(RRect.fromRectAndRadius(backRect, Radius.circular(16 * u)));
    canvas.drawShadow(shadowPath, Colors.black.withValues(alpha: 0.3), 10 * u, true);

    // 左上角标签小凸起
    final tabRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(6 * u, 7 * u, 68 * u, 20 * u),
      topLeft: Radius.circular(11 * u),
      topRight: Radius.circular(11 * u),
    );
    canvas.drawRRect(tabRect, Paint()..color = const Color(0xFF232428));

    // 底板渐变
    final backPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF27282C), Color(0xFF151618)],
      ).createShader(backRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(backRect, Radius.circular(16 * u)),
      backPaint,
    );

    // 顶部内高光
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 * u;
    canvas.drawLine(
      Offset(backRect.left + 16 * u, backRect.top + 0.5 * u),
      Offset(backRect.right - 16 * u, backRect.top + 0.5 * u),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FolderBackPainter oldDelegate) =>
      oldDelegate.scale != scale;
}

/// 文件夹前盖轮廓（HTML clipPath 等比换算到 184x126 坐标系）
class _FolderFrontClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => folderFrontPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 前盖路径：弧形标签口 + 梯形透视，输入尺寸内等比缩放（基准 184x126）
Path folderFrontPath(Size size) {
  final sx = size.width / 184;
  final sy = size.height / 126;
  Offset p(double x, double y) => Offset(x * sx, y * sy);

  return Path()
    ..moveTo(p(2.208, 10.71).dx, p(2.208, 10.71).dy)
    ..quadraticBezierTo(
      p(1.472, 0.504).dx, p(1.472, 0.504).dy,
      p(15.088, 0.504).dx, p(15.088, 0.504).dy,
    )
    ..lineTo(p(72.68, 0.504).dx, p(72.68, 0.504).dy)
    ..cubicTo(
      p(87.4, 0.504).dx, p(87.4, 0.504).dy,
      p(91.08, 15.75).dx, p(91.08, 15.75).dy,
      p(106.352, 15.75).dx, p(106.352, 15.75).dy,
    )
    ..lineTo(p(168.912, 15.75).dx, p(168.912, 15.75).dy)
    ..quadraticBezierTo(
      p(182.528, 15.75).dx, p(182.528, 15.75).dy,
      p(181.792, 25.83).dx, p(181.792, 25.83).dy,
    )
    ..lineTo(p(176.272, 112.77).dx, p(176.272, 112.77).dy)
    ..quadraticBezierTo(
      p(175.168, 124.992).dx, p(175.168, 124.992).dy,
      p(159.16, 124.992).dx, p(159.16, 124.992).dy,
    )
    ..lineTo(p(24.84, 124.992).dx, p(24.84, 124.992).dy)
    ..quadraticBezierTo(
      p(8.832, 124.992).dx, p(8.832, 124.992).dy,
      p(7.728, 112.77).dx, p(7.728, 112.77).dy,
    )
    ..close();
}

/// 毛玻璃前盖：深色纵向渐变 + 顶部径向高光 + 边缘白色描边
class _FolderFrontPainter extends CustomPainter {
  final double scale;

  _FolderFrontPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final u = scale;
    final rect = Offset.zero & size;
    final path = folderFrontPath(size);

    // 玻璃渐变
    final glassPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x6B9BA0A5),
          Color(0x94525660),
          Color(0xDB1C1E20),
          Color(0xF5101113),
        ],
        stops: [0.0, 0.38, 0.76, 1.0],
      ).createShader(rect);
    canvas.drawPath(path, glassPaint);

    // 顶部径向高光
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.7),
        radius: 1.1,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.52],
      ).createShader(rect);
    canvas.drawPath(path, highlightPaint);

    // 边缘描边（沿顶部轮廓的白色渐变 rim）
    final rimPath = Path();
    final sx = size.width / 184;
    final sy = size.height / 126;
    Offset rp(double x, double y) => Offset(x * sx, y * sy);
    rimPath
      ..moveTo(rp(2.5, 11).dx, rp(2.5, 11).dy)
      ..quadraticBezierTo(
        rp(2, 1).dx, rp(2, 1).dy,
        rp(15, 1).dx, rp(15, 1).dy,
      )
      ..lineTo(rp(72.5, 1).dx, rp(72.5, 1).dy)
      ..cubicTo(
        rp(87, 1).dx, rp(87, 1).dy,
        rp(91, 16).dx, rp(91, 16).dy,
        rp(106, 16).dx, rp(106, 16).dy,
      )
      ..lineTo(rp(169, 16).dx, rp(169, 16).dy)
      ..quadraticBezierTo(
        rp(182, 16).dx, rp(182, 16).dy,
        rp(181.5, 26).dx, rp(181.5, 26).dy,
      );
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35 * u
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.62),
          Colors.white.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0.34),
          Colors.white.withValues(alpha: 0.06),
        ],
        stops: const [0.0, 0.42, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawPath(rimPath, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _FolderFrontPainter oldDelegate) =>
      oldDelegate.scale != scale;
}

/// 照片数据模型
class PhotoReelPhotoData {
  /// 照片图片（为 null 时使用 [colors] 渐变占位）
  final ImageProvider? image;

  /// 占位渐变颜色（至少 2 个）
  final List<Color> colors;

  /// 塞入文件夹时的位姿
  final double tuckedX;
  final double tuckedY;
  final double tuckedRotation;
  final double tuckedScale;
  final int tuckedZ;

  const PhotoReelPhotoData({
    this.image,
    this.colors = const [Color(0xFF8B96A1), Color(0xFF31363C)],
    this.tuckedX = 0,
    this.tuckedY = -18,
    this.tuckedRotation = 0,
    this.tuckedScale = 0.95,
    this.tuckedZ = 1,
  });

  /// 按下标生成默认错落塞入位姿
  factory PhotoReelPhotoData.tucked({
    int index = 0,
    ImageProvider? image,
    List<Color>? colors,
  }) {
    const presets = [
      (26.0, -15.0, 4.5, 0.94, 1),
      (-4.0, -19.0, 1.5, 0.95, 2),
      (-23.0, -21.0, -2.8, 0.97, 3),
      (0.0, -8.0, 0.0, 0.88, 0),
    ];
    final p = presets[index % presets.length];
    return PhotoReelPhotoData(
      image: image,
      colors: colors ?? const [Color(0xFF8B96A1), Color(0xFF31363C)],
      tuckedX: p.$1,
      tuckedY: p.$2,
      tuckedRotation: p.$3,
      tuckedScale: p.$4,
      tuckedZ: p.$5,
    );
  }
}

/// 文件夹数据模型
class PhotoReelFolderData {
  /// 文件夹标题（如 'Paris 2025'）
  final String title;

  /// 文件夹内的照片列表
  final List<PhotoReelPhotoData> photos;

  const PhotoReelFolderData({required this.title, required this.photos});
}
