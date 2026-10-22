import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:aboutme/plugins/calendar_album/screens/album_photo_query.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// Web 墨卡托世界边长（zoom 0 时 256px，高德瓦片同规格）
double _worldSize(double zoom) => 256.0 * math.pow(2.0, zoom);

/// GCJ-02 经纬度 → zoom 级世界像素坐标（高德静态图/瓦片同投影）
(double, double) _latLngToWorld(LatLng p, double zoom) {
  final size = _worldSize(zoom);
  final x = (p.longitude + 180.0) / 360.0 * size;
  final sinLat = math.sin(p.latitude * math.pi / 180.0);
  final y =
      (0.5 - math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi)) *
      size;
  return (x, y);
}

/// zoom 级世界像素坐标 → GCJ-02 经纬度
LatLng _worldToLatLng(double x, double y, double zoom) {
  final size = _worldSize(zoom);
  final lng = x / size * 360.0 - 180.0;
  final n = math.pi - 2.0 * math.pi * y / size;
  final lat = 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  return LatLng(lat, lng);
}

/// 解析 "lat,lng" 字符串为原始 GCJ-02 LatLng，失败返回 null
LatLng? parseRawLatLng(String? latLng) {
  if (latLng == null || latLng.isEmpty) return null;
  final parts = latLng.split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0].trim());
  final lng = double.tryParse(parts[1].trim());
  if (lat == null || lng == null) return null;
  return LatLng(lat, lng);
}

/// 照片地图：带定位信息的日记照片以照片大头针形式标记在高德静态地图上，
/// 同一坐标的多张照片堆叠成一组。地图底图来自高德静态图 API
/// （https://lbs.amap.com/api/webservice/guide/api/staticmaps/），
/// 平移/捏合/滚轮结束后按新中心点与缩放级重新请求；
/// 大头针按 Web 墨卡托投影本地叠加（GCJ-02 坐标直接使用）。
/// 与相册页共用多条件过滤栏与搜索，过滤条件变化时大头针实时增减
class AlbumMapScreen extends StatefulWidget {
  const AlbumMapScreen({
    super.key,
    required this.controller,
    this.initialQuery,
    this.onOpenGallery,
  });

  /// 相册页的日历控制器。push 出的本页不在相册 Provider 作用域内，
  /// 直接传实例并用 ListenableBuilder 监听数据变化
  final CalendarController controller;

  /// 进入地图页时继承的过滤条件（相册页当前过滤状态）
  final AlbumPhotoQuery? initialQuery;

  /// 点击照片大头针打开图库（当前过滤结果列表 + 点击索引）
  final void Function(List<AlbumMapPhoto> photos, int index)? onOpenGallery;

  @override
  State<AlbumMapScreen> createState() => _AlbumMapScreenState();
}

/// 同一坐标的照片分组（同一日记条目的照片共享 latLng）
class _PinGroup {
  const _PinGroup({
    required this.latLng,
    required this.point,
    required this.indices,
  });

  /// 分组原始坐标串（GCJ-02 "lat,lng"）
  final String latLng;

  final LatLng point;

  /// 组内照片在过滤结果中的索引（首张用于打开图库）
  final List<int> indices;
}

const _monthLabels = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// 高德静态图 zoom 范围 [1,17]，过低无街道细节
const _minZoom = 3;
const _maxZoom = 17;

class _AlbumMapScreenState extends State<AlbumMapScreen> {
  late AlbumPhotoQuery _query =
      widget.initialQuery ?? const AlbumPhotoQuery();

  /// 当前过滤结果（build 时更新，供大头针点击回调使用）
  List<AlbumMapPhoto> _records = const [];

  /// 高德 Web 服务 key：null=读取中，''=未配置；与设置页「定位 API Key」共用
  String? _apiKey;

  /// 当前地图中心（GCJ-02）与缩放级
  LatLng? _center;
  int _zoom = 13;

  /// 最近一次已知的地图视口尺寸（请求静态图尺寸与投影定位用）
  Size? _viewportSize;

  /// 手势期间的本地变换（平移/捏合即时反馈），交互结束提交后重置
  final _transformController = TransformationController();

  String? _lastFitSignature;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _apiKey = prefs.getString('location_api_key') ?? '');
  }

  /// 过滤条件变化 → 重建大头针；坐标集合变化 → 重新适配视野
  void _applyFilters(Map<String, dynamic> filters) {
    // addPostFrameCallback 避免在过滤栏 build 阶段调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _query = AlbumPhotoQuery(
            multiFilters: filters,
            searchQuery: _query.searchQuery,
          );
        });
      }
    });
  }

  /// 坐标集合签名变化时适配一次中心/缩放（签名相同不重置，避免打断用户浏览）
  void _maybeScheduleFit(List<_PinGroup> groups) {
    final signature = groups.map((g) => g.latLng).join('|');
    if (signature == _lastFitSignature) return;
    _lastFitSignature = signature;
    _fitToPoints(groups.map((g) => g.point).toList());
  }

  /// 按坐标集合估算中心与缩放级（bbox → Web 墨卡托跨度反推）
  void _fitToPoints(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _center = points.first;
      _zoom = 15;
      return;
    }
    final viewport =
        _viewportSize ??
        (mounted ? MediaQuery.sizeOf(context) : const Size(600, 400));
    // 上下留出导航栏/过滤栏与底部安全区的近似余量
    final usableW = math.max(120.0, viewport.width - 120);
    final usableH = math.max(120.0, viewport.height - 320);
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final (minX, minY) = _latLngToWorld(LatLng(maxLat, minLng), 0);
    final (maxX, maxY) = _latLngToWorld(LatLng(minLat, maxLng), 0);
    final ratio = math.max(
      (maxX - minX) / usableW,
      (maxY - minY) / usableH,
    );
    // zoom 0 世界边长 256：span(256)/256=ratio → 目标边长 256/ratio
    _zoom = ratio <= 0
        ? _maxZoom
        // -1 留一级余量，避免大头针贴边
        : (math.log(256.0 / ratio) / math.ln2).floor() - 1;
    _zoom = _zoom.clamp(_minZoom, _maxZoom);
    _center = _worldToLatLng((minX + maxX) / 2, (minY + maxY) / 2, 0);
  }

  /// 手势结束：按本地变换反算新中心/缩放级并重新请求静态图
  void _commitTransform() {
    final center = _center;
    if (center == null) return;
    final viewport = _viewportSize ?? MediaQuery.sizeOf(context);
    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();
    // 视口中心在图片坐标系中的位置（图片未变换时与视口重合）
    final inv = Matrix4.inverted(matrix);
    final dx = viewport.width / 2;
    final dy = viewport.height / 2;
    final px = inv.entry(0, 0) * dx + inv.entry(0, 1) * dy + inv.entry(0, 3);
    final py = inv.entry(1, 0) * dx + inv.entry(1, 1) * dy + inv.entry(1, 3);
    final (cx, cy) = _latLngToWorld(center, _zoom.toDouble());
    final newCenter = _worldToLatLng(
      cx + px - viewport.width / 2,
      cy + py - viewport.height / 2,
      _zoom.toDouble(),
    );
    final newZoom = (_zoom + math.log(scale) / math.ln2)
        .round()
        .clamp(_minZoom, _maxZoom);
    setState(() {
      _center = newCenter;
      _zoom = newZoom;
      _transformController.value = Matrix4.identity();
    });
  }

  /// 直接调整缩放级（桌面滚轮 / 双击放大），中心点不变
  void _zoomBy(int delta) {
    if (_center == null) return;
    final next = (_zoom + delta).clamp(_minZoom, _maxZoom);
    if (next == _zoom) return;
    setState(() {
      _zoom = next;
      _transformController.value = Matrix4.identity();
    });
  }

  /// 高德静态图请求 URL（key/中心/zoom/尺寸，scale=2 高清）
  String _staticMapUrl(Size size) {
    final w = size.width.round().clamp(1, 1024);
    final h = size.height.round().clamp(1, 1024);
    final loc =
        '${_center!.longitude.toStringAsFixed(6)},'
        '${_center!.latitude.toStringAsFixed(6)}';
    return 'https://restapi.amap.com/v3/staticmap'
        '?key=$_apiKey&location=$loc&zoom=$_zoom&size=$w*$h&scale=2';
  }

  /// 坐标 → 照片索引分组（保持插入顺序，同一条目的照片共享坐标）
  List<_PinGroup> _buildGroups(List<AlbumMapPhoto> records) {
    final groups = <String, _PinGroup>{};
    for (var i = 0; i < records.length; i++) {
      final photo = records[i];
      final point = parseRawLatLng(photo.entry.latLng);
      if (point == null) continue;
      final key = photo.entry.latLng!;
      final group = groups[key];
      if (group != null) {
        group.indices.add(i);
      } else {
        groups[key] = _PinGroup(latLng: key, point: point, indices: [i]);
      }
    }
    return groups.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        _records = _query.apply(AlbumPhotoQuery.buildRecords(controller));
        final groups = _buildGroups(_records);
        _maybeScheduleFit(groups);

        return SuperCupertinoNavigationWrapper(
          title: Text('calendar_album_photo_map'.tr),
          largeTitle: 'calendar_album_photo_map'.tr,
          enableLargeTitle: true,
          // ===== 搜索 =====
          enableSearchBar: true,
          searchPlaceholder: 'calendar_album_search_photos_placeholder'.tr,
          onSearchChanged: (query) {
            setState(() {
              _query = AlbumPhotoQuery(
                multiFilters: _query.multiFilters,
                searchQuery: query,
              );
            });
          },
          // ===== 多条件过滤（与相册页共用） =====
          enableMultiFilter: true,
          multiFilterItems: AlbumPhotoQuery.buildFilterItems(controller),
          onMultiFilterChanged: _applyFilters,
          body: groups.isEmpty
              ? Center(
                  child: DSThemeBridge(
                    child: DSEmptyState(
                      emoji: '🗺️',
                      title: 'calendar_album_map_empty'.tr,
                      message: 'calendar_album_map_empty_hint'.tr,
                    ),
                  ),
                )
              : _buildAmapBody(groups),
        );
      },
    );
  }

  // ------------------------------ 高德静态图 ------------------------------

  Widget _buildAmapBody(List<_PinGroup> groups) {
    final key = _apiKey;
    if (key == null) {
      return Center(
        child: DSLoadingDots(color: AppTheme.of(context).primary),
      );
    }
    if (key.isEmpty) {
      return Center(
        child: DSThemeBridge(
          child: DSEmptyState(
            emoji: '🔑',
            title: 'calendar_album_map_key_missing'.tr,
            message: 'calendar_album_map_key_missing_hint'.tr,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;
        return Listener(
          // 桌面滚轮缩放
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              _zoomBy(event.scrollDelta.dy < 0 ? 1 : -1);
            }
          },
          child: GestureDetector(
            // 双击放大
            onDoubleTap: () => _zoomBy(1),
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.5,
              maxScale: 4,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              onInteractionEnd: (_) => _commitTransform(),
              child: SizedBox.fromSize(
                size: constraints.biggest,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      _staticMapUrl(constraints.biggest),
                      fit: BoxFit.cover,
                      // 交互结束重请求期间保持旧图，避免闪烁
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => _buildMapError(),
                    ),
                    _buildPinsLayer(groups, constraints.biggest),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 静态图加载失败兜底（key 无效/网络异常时高德返回非图片内容）
  Widget _buildMapError() {
    final theme = AppTheme.of(context);
    return Container(
      color: const Color(0xFFE7E2D6),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        'calendar_album_map_load_failed'.tr,
        textAlign: TextAlign.center,
        style: DsTypography.caption.copyWith(color: theme.textSub),
      ),
    );
  }

  /// 大头针层：按与中心的像素偏移叠加在静态图上
  Widget _buildPinsLayer(List<_PinGroup> groups, Size size) {
    final (cx, cy) = _latLngToWorld(_center!, _zoom.toDouble());
    return Stack(
      children: [
        for (final group in groups)
          () {
            final (x, y) = _latLngToWorld(group.point, _zoom.toDouble());
            final w = group.indices.length > 1 ? 150.0 : 76.0;
            final h = group.indices.length > 1 ? 132.0 : 96.0;
            return Positioned(
              left: x - cx + size.width / 2 - w / 2,
              top: y - cy + size.height / 2 - h / 2,
              width: w,
              height: h,
              child: GestureDetector(
                onTap: () => widget.onOpenGallery
                    ?.call(_records, group.indices.first),
                child: _buildPin(group),
              ),
            );
          }(),
      ],
    );
  }

  // ------------------------------ 照片大头针 ------------------------------

  /// 单张：白框照片 + 左上日期徽章；多张：前 3 张扇形堆叠 + 数量贴纸
  Widget _buildPin(_PinGroup group) {
    if (group.indices.length == 1) {
      final photo = _records[group.indices.first];
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _photoFrame(size: 64, rotationDeg: -4, photo: photo),
          Positioned(
            top: -6,
            left: -4,
            child: _calBadge(photo.entry.createdAt),
          ),
        ],
      );
    }

    final count = group.indices.length;
    final stacked = math.min(3, count);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // 后层照片：绕中心小幅旋转错开
        for (var i = stacked - 1; i >= 1; i--)
          Transform.rotate(
            angle: (i % 2 == 0 ? 9 : -11) * math.pi / 180,
            child: Transform.translate(
              offset: Offset((i - 1) * 16.0, (i - 1) * 4.0),
              child: _photoFrame(
                size: 64,
                rotationDeg: 0,
                photo: _records[group.indices[i]],
              ),
            ),
          ),
        // 前景主照片
        _photoFrame(
          size: 72,
          rotationDeg: 3,
          photo: _records[group.indices.first],
        ),
        // 右下角数量贴纸
        Positioned(
          bottom: -2,
          right: -6,
          child: _countBadge(count),
        ),
      ],
    );
  }

  /// 白框照片：拍立得式边框 + 阴影，参考 demo 的 _photoFrame
  Widget _photoFrame({
    required double size,
    required double rotationDeg,
    required AlbumMapPhoto photo,
  }) {
    return Transform.rotate(
      angle: rotationDeg * math.pi / 180,
      child: Container(
        width: size,
        height: size + 4,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3814141E),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
            BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _pinImage(photo.url),
        ),
      ),
    );
  }

  /// 日历日期徽章（月份缩写 + 日）
  Widget _calBadge(DateTime date) {
    final month = _monthLabels[date.month - 1];
    return Container(
      width: 30,
      height: 33,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            decoration: const BoxDecoration(
              color: Color(0xFF522120),
              borderRadius: BorderRadius.vertical(top: Radius.circular(6.5)),
            ),
            child: Text(
              month,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${date.day}',
                style: const TextStyle(
                  color: Color(0xFF1C1917),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 数量贴纸：白底圆角 xN
  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF3843F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Text(
        'x$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }

  /// 大头针缩略图：网络图直接加载，本地图经 ImageUtils 解析绝对路径
  Widget _pinImage(String url) {
    Widget placeholder() => Container(
          color: const Color(0xFFE7E2D6),
          alignment: Alignment.center,
          child: const Icon(Icons.image_outlined, size: 18, color: Colors.black26),
        );

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }
    return FutureBuilder<String>(
      future: ImageUtils.getAbsolutePath(url),
      builder: (context, snapshot) {
        final p = snapshot.data;
        if (p != null && p.isNotEmpty) {
          final file = File(p);
          if (file.existsSync()) {
            return Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder(),
            );
          }
        }
        return placeholder();
      },
    );
  }
}
