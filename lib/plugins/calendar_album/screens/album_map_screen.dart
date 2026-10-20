import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:aboutme/plugins/calendar_album/screens/album_photo_query.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 解析 GCJ-02 "lat,lng" 字符串并转 WGS84（OSM 瓦片坐标系），失败返回 null
LatLng? parseGcj02ToWgs84(String? latLng) {
  if (latLng == null || latLng.isEmpty) return null;
  final parts = latLng.split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0].trim());
  final lng = double.tryParse(parts[1].trim());
  if (lat == null || lng == null) return null;

  // GCJ-02 → WGS84 标准近似逆变换（国内偏移约数百米）
  const a = 6378245.0;
  const ee = 0.00669342162296594323;

  double transformLat(double x, double y) {
    var ret = -100.0 +
        2.0 * x +
        3.0 * y +
        0.2 * y * y +
        0.1 * x * y +
        0.2 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) *
        2.0 /
        3.0;
    ret += (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) *
        2.0 /
        3.0;
    ret += (160.0 * math.sin(y / 12.0 * math.pi) +
            320.0 * math.sin(y * math.pi / 30.0)) *
        2.0 /
        3.0;
    return ret;
  }

  double transformLng(double x, double y) {
    var ret = 300.0 +
        x +
        2.0 * y +
        0.1 * x * x +
        0.1 * x * y +
        0.1 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) +
            20.0 * math.sin(2.0 * x * math.pi)) *
        2.0 /
        3.0;
    ret += (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) *
        2.0 /
        3.0;
    ret += (150.0 * math.sin(x / 12.0 * math.pi) +
            300.0 * math.sin(x / 30.0 * math.pi)) *
        2.0 /
        3.0;
    return ret;
  }

  var dLat = transformLat(lng - 105.0, lat - 35.0);
  var dLng = transformLng(lng - 105.0, lat - 35.0);
  final radLat = lat / 180.0 * math.pi;
  var magic = math.sin(radLat);
  magic = 1 - ee * magic * magic;
  final sqrtMagic = math.sqrt(magic);
  dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * math.pi);
  dLng = (dLng * 180.0) / (a / sqrtMagic * math.cos(radLat) * math.pi);
  return LatLng(lat - dLat, lng - dLng);
}

/// 照片地图：带定位信息的日记照片以照片大头针形式标记在 OSM 地图上，
/// 同一坐标的多张照片堆叠成一组。视觉参考 lib/widgets/moments_nyc_map_demo.dart。
/// 与相册页共用多条件过滤栏与搜索，过滤条件变化时大头针实时增减
class AlbumMapScreen extends StatefulWidget {
  const AlbumMapScreen({super.key, this.initialQuery, this.onOpenGallery});

  /// 进入地图页时继承的过滤条件（相册页当前过滤状态）
  final AlbumPhotoQuery? initialQuery;

  /// 点击照片大头针打开图库（当前过滤结果列表 + 点击索引）
  final void Function(List<AlbumMapPhoto> photos, int index)? onOpenGallery;

  @override
  State<AlbumMapScreen> createState() => _AlbumMapScreenState();
}

/// 同一坐标的照片分组（同一日记条目的照片共享 latLng）
class _PinGroup {
  const _PinGroup({required this.point, required this.indices});

  final LatLng point;

  /// 组内照片在过滤结果中的索引（首张用于打开图库）
  final List<int> indices;
}

const _monthLabels = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

class _AlbumMapScreenState extends State<AlbumMapScreen> {
  final _mapController = MapController();

  late AlbumPhotoQuery _query =
      widget.initialQuery ?? const AlbumPhotoQuery();

  /// 当前过滤结果（build 时更新，供大头针点击回调使用）
  List<AlbumMapPhoto> _records = const [];

  bool _mapReady = false;

  /// 待适配的视野坐标集合；地图就绪后或坐标集合变化时消费
  List<LatLng>? _pendingFitPoints;
  String? _lastFitSignature;

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

  /// 坐标集合签名变化时安排一次视野适配（签名相同不重置，避免打断用户平移）
  void _maybeScheduleFit(List<_PinGroup> groups) {
    final points = groups.map((g) => g.point).toList();
    final signature =
        points.map((p) => '${p.latitude},${p.longitude}').join('|');
    if (signature == _lastFitSignature) return;
    _lastFitSignature = signature;
    _pendingFitPoints = points;
    if (!_mapReady) return; // onMapReady 兜底消费
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingFit());
  }

  void _consumePendingFit() {
    if (!mounted) return;
    final points = _pendingFitPoints;
    if (points == null || points.isEmpty) return;
    _pendingFitPoints = null;
    if (points.length == 1) {
      _mapController.move(points.first, 15);
    } else {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          // 上下留出导航栏/过滤栏与底部安全区
          padding: const EdgeInsets.fromLTRB(60, 180, 60, 140),
        ),
      );
    }
  }

  /// 坐标 → 照片索引分组（保持插入顺序，同一条目的照片共享坐标）
  List<_PinGroup> _buildGroups(List<AlbumMapPhoto> records) {
    final groups = <String, _PinGroup>{};
    for (var i = 0; i < records.length; i++) {
      final photo = records[i];
      final point = parseGcj02ToWgs84(photo.entry.latLng);
      if (point == null) continue;
      final key = photo.entry.latLng!;
      final group = groups[key];
      if (group != null) {
        group.indices.add(i);
      } else {
        groups[key] = _PinGroup(point: point, indices: [i]);
      }
    }
    return groups.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarController>(
      builder: (context, controller, _) {
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
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    // 初始视野先取首组坐标，就绪后按全部坐标适配
                    initialCenter: groups.first.point,
                    initialZoom: 13,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onMapReady: () {
                      _mapReady = true;
                      _consumePendingFit();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'github.hunmer.aboutme',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final group in groups)
                          Marker(
                            point: group.point,
                            width: group.indices.length > 1 ? 150 : 76,
                            height: group.indices.length > 1 ? 132 : 96,
                            alignment: Alignment.center,
                            child: GestureDetector(
                              onTap: () => widget.onOpenGallery
                                  ?.call(_records, group.indices.first),
                              child: _buildPin(group),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
        );
      },
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
