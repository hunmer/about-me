import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

// 定义Position类
class Position {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final double altitude;
  final double heading;
  final double speed;
  final double speedAccuracy;

  Position({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    required this.altitude,
    required this.heading,
    required this.speed,
    required this.speedAccuracy,
  });
}

class LocationPicker extends StatefulWidget {
  final ValueChanged<String> onLocationSelected;

  /// 选择结果附带经纬度（GCJ-02 火星坐标，latitude 在前）。
  /// 搜索结果缺失经纬度时不回调。
  final void Function(double latitude, double longitude)? onLatLngSelected;

  final bool isMobile;

  const LocationPicker({
    super.key,
    required this.onLocationSelected,
    this.onLatLngSelected,
    required this.isMobile,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String _apiKey = 'dad6a772bf826842c3049e9c7198115c'; // 默认 API Key
  // String? _selectedLocation; // No longer needed for single tap select

  static const String _favoritesKey = 'location_favorites';
  List<Map<String, dynamic>> _favorites = [];
  bool _showFavorites = false;

  /// 手机 GPS（WGS-84）与高德（GCJ-02）存在坐标系偏差，阈值放宽到 1km
  static const double _nearbyThresholdMeters = 1000;
  Map<String, dynamic>? _guessedFavorite;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadFavorites();
    if (widget.isMobile) {
      _guessLocationFromFavorites();
    }
    // Auto-load current location or recent? maybe not to save data/permissions
    // _getCurrentLocation();
  }

  Future<List<Map<String, dynamic>>> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoritesKey);
    if (raw == null) return _favorites;
    try {
      final list = json.decode(raw) as List;
      setState(() {
        _favorites = list.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint('Error loading location favorites: $e');
    }
    return _favorites;
  }

  Future<void> _guessLocationFromFavorites() async {
    var favorites = _favorites;
    if (favorites.isEmpty) {
      favorites = await _loadFavorites();
    }
    if (favorites.isEmpty) return;
    try {
      final position = await _getCurrentPosition();
      Map<String, dynamic>? nearest;
      var nearestDistance = double.infinity;
      for (final fav in favorites) {
        final d = _distanceToFavorite(
          position.latitude,
          position.longitude,
          fav,
        );
        if (d < nearestDistance) {
          nearestDistance = d;
          nearest = fav;
        }
      }
      if (nearest != null && nearestDistance <= _nearbyThresholdMeters) {
        setState(() {
          _guessedFavorite = nearest;
        });
      }
    } catch (e) {
      debugPrint('Error guessing location from favorites: $e');
    }
  }

  double _distanceToFavorite(double lat, double lng, Map<String, dynamic> fav) {
    final parts = (fav['location'] as String? ?? '').split(',');
    if (parts.length != 2) return double.infinity;
    final favLng = double.tryParse(parts[0]);
    final favLat = double.tryParse(parts[1]);
    if (favLat == null || favLng == null) return double.infinity;
    return _haversineMeters(lat, lng, favLat, favLng);
  }

  double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favoritesKey, json.encode(_favorites));
  }

  bool _isFavorite(Map<String, dynamic> item) {
    return _favorites.any(
      (f) => f['name'] == item['name'] && f['location'] == item['location'],
    );
  }

  void _toggleFavoritesView() {
    setState(() {
      _showFavorites = !_showFavorites;
      if (_showFavorites) {
        _searchController.clear();
        _searchResults = [];
      }
    });
  }

  Future<void> _toggleFavorite(Map<String, dynamic> item) async {
    if (_isFavorite(item)) {
      setState(() {
        _favorites.removeWhere(
          (f) => f['name'] == item['name'] && f['location'] == item['location'],
        );
        if (identical(item, _guessedFavorite)) {
          _guessedFavorite = null;
        }
      });
      await _saveFavorites();
      return;
    }
    final alias = await _showAliasDialog(item);
    if (alias == null) return; // 用户取消
    setState(() {
      _favorites.add({...item, 'alias': alias});
    });
    await _saveFavorites();
  }

  Future<String?> _showAliasDialog(
    Map<String, dynamic> item, {
    String initialAlias = '',
  }) {
    final controller = TextEditingController(text: initialAlias);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          (initialAlias.isEmpty
                  ? 'location_picker_addAliasTitle'
                  : 'location_picker_editAliasTitle')
              .tr,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'location_picker_aliasHint'.tr,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('app_cancel'.tr),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text('app_ok'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _editAlias(Map<String, dynamic> item) async {
    final alias = await _showAliasDialog(
      item,
      initialAlias: (item['alias'] as String?) ?? '',
    );
    if (alias == null) return; // 用户取消
    setState(() {
      item['alias'] = alias;
    });
    await _saveFavorites();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _favorites.removeAt(oldIndex);
      _favorites.insert(newIndex, item);
    });
    _saveFavorites();
  }

  Widget _buildEmptyHint(BuildContext context, String text) {
    final theme = DSThemeBridge.resolve(context);
    return Center(
      child: Text(
        text,
        style: DsTypography.caption.copyWith(color: theme.textSub),
      ),
    );
  }

  Widget _buildStarButton(BuildContext context, Map<String, dynamic> result) {
    final theme = DSThemeBridge.resolve(context);
    final isFav = _isFavorite(result);
    return Pressable(
      onPressed: () => _toggleFavorite(result),
      semanticLabel: 'location_picker_removeFavorite'.tr,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DsIcon(
          isFav ? DsIconKind.star : DsIconKind.starOutline,
          size: 20,
          color: isFav ? theme.primary : theme.textSub,
        ),
      ),
    );
  }

  Widget _buildItemRow(
    BuildContext context,
    Map<String, dynamic> result, {
    Widget? trailing,
    VoidCallback? onLongPress,
  }) {
    final theme = DSThemeBridge.resolve(context);
    final isCurrent = result['isCurrent'] == true;
    final isGuess = identical(result, _guessedFavorite);
    final alias = result['alias'] as String?;
    final displayName = (alias == null || alias.isEmpty)
        ? result['name']
        : alias;
    final title = isGuess
        ? '${'location_picker_guessYouAreHere'.tr} · $displayName'
        : displayName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          DsIcon(
            DsIconKind.pin,
            size: 22,
            color: (isCurrent || isGuess) ? theme.primary : theme.textSub,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Pressable(
              onPressed: () {
                widget.onLocationSelected(result['address']);
                // 高德 location 格式为 "lng,lat"（GCJ-02）
                final parts = (result['location'] as String? ?? '').split(',');
                if (parts.length == 2) {
                  final lng = double.tryParse(parts[0]);
                  final lat = double.tryParse(parts[1]);
                  if (lat != null && lng != null) {
                    widget.onLatLngSelected?.call(lat, lng);
                  }
                }
                Navigator.of(context).pop();
              },
              onLongPress: onLongPress,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: DsTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result['address'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.caption.copyWith(
                      color: theme.textSub,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildFavoritesList(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _favorites.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final result = _favorites[index];
        return Column(
          key: ValueKey('location_favorite_${result['location']}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildItemRow(
              context,
              result,
              onLongPress: () => _editAlias(result),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStarButton(context, result),
                  ReorderableDragStartListener(
                    index: index,
                    child: Semantics(
                      label: 'location_picker_dragToSort'.tr,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: DsIcon(
                          DsIconKind.drag,
                          size: 20,
                          color: theme.textSub,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (index < _favorites.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 1, color: theme.stroke),
              ),
          ],
        );
      },
    );
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey =
          prefs.getString('location_api_key') ??
          'dad6a772bf826842c3049e9c7198115c';
    });
  }

  Future<Position> _getCurrentPosition() async {
    final location = Location();

    // 检查服务是否可用
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        throw Exception('Location services are disabled');
      }
    }

    // 检查权限状态
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        debugPrint('Location permissions are denied');
        throw Exception('Location permissions are denied');
      }
    }

    // 获取当前位置
    try {
      final locationData = await location.getLocation();
      return Position(
        latitude: locationData.latitude ?? 0,
        longitude: locationData.longitude ?? 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          locationData.time?.toInt() ?? 0,
        ),
        accuracy: locationData.accuracy ?? 0,
        altitude: locationData.altitude ?? 0,
        heading: locationData.heading ?? 0,
        speed: locationData.speed ?? 0,
        speedAccuracy: locationData.speedAccuracy ?? 0,
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      rethrow;
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _showFavorites = false;
      _searchResults = [];
    });

    try {
      final position = await _getCurrentPosition();
      final response = await http.get(
        Uri.parse(
          'http://restapi.amap.com/v3/geocode/regeo?key=$_apiKey&location=${position.longitude},${position.latitude}&poitype=&radius=1000&extensions=all&batch=false&roadlevel=0',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == '1' && data['regeocode'] != null) {
          final regeocode = data['regeocode'];
          final currentLocation = {
            'name': '当前位置',
            'address': regeocode['formatted_address'],
            'location': '${position.longitude},${position.latitude}',
            'isCurrent': true,
          };

          // 添加周边POI信息
          final pois = <Map<String, dynamic>>[];
          if (regeocode['pois'] != null) {
            for (var poi in regeocode['pois']) {
              pois.add({
                'name': poi['name'],
                'address': poi['address'] ?? 'location_picker_noAddressInfo'.tr,
                'location': poi['location'],
                'isCurrent': false,
              });
            }
          }

          setState(() {
            _searchResults = [currentLocation, ...pois];
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _showFavorites = false;
      _searchResults = [];
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://restapi.amap.com/v3/place/text?key=$_apiKey&keywords=$query&types=&city=&children=&offset=20&page=1&extensions=base',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == '1' && data['pois'] != null) {
          setState(() {
            _searchResults =
                (data['pois'] as List).map((poi) {
                  return {
                    'name': poi['name'],
                    'address':
                        poi['address'] ?? 'location_picker_noAddressInfo'.tr,
                    'location': poi['location'],
                    'isCurrent': false,
                  };
                }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Material(
      color: theme.background,
      borderRadius: theme.radii.xxl,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示器
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Pressable(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'app_cancel'.tr,
                      style: DsTypography.body.copyWith(color: theme.textSub),
                    ),
                  ),
                ),
                Text(
                  'app_selectLocation'.tr,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                Pressable(
                  onPressed: _toggleFavoritesView,
                  semanticLabel: 'location_picker_favoriteAddresses'.tr,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: DsIcon(
                      _showFavorites
                          ? DsIconKind.star
                          : DsIconKind.starOutline,
                      size: 22,
                      color: _showFavorites ? theme.primary : theme.textSub,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: DSInput(
              controller: _searchController,
              hint: 'location_picker_searchLocation'.tr,
              onSubmitted: _searchLocation,
              suffix: Pressable(
                onPressed: _getCurrentLocation,
                semanticLabel: 'location_picker_getCurrentLocation'.tr,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: DsIcon(DsIconKind.pin, size: 20, color: theme.primary),
                ),
              ),
            ),
          ),
          // 内容区域
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Builder(
              builder: (context) {
                if (_isLoading) {
                  return Center(child: DSLoadingDots(color: theme.primary));
                }
                if (_showFavorites) {
                  if (_favorites.isEmpty) {
                    return _buildEmptyHint(
                      context,
                      'location_picker_noFavorites'.tr,
                    );
                  }
                  return _buildFavoritesList(context);
                }
                final items = [
                  if (_guessedFavorite != null) _guessedFavorite!,
                  ..._searchResults,
                ];
                if (items.isEmpty) {
                  return _buildEmptyHint(
                    context,
                    'location_picker_noResults'.tr,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder:
                      (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(height: 1, color: theme.stroke),
                      ),
                  itemBuilder: (context, index) => _buildItemRow(
                    context,
                    items[index],
                    trailing: _buildStarButton(context, items[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
