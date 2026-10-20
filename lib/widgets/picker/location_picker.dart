import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    // Auto-load current location or recent? maybe not to save data/permissions
    // _getCurrentLocation();
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
                const SizedBox(width: 40), // 占位保持标题居中
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
            child:
                _isLoading
                    ? Center(child: DSLoadingDots(color: theme.primary))
                    : _searchResults.isNotEmpty
                    ? ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _searchResults.length,
                      separatorBuilder:
                          (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(height: 1, color: theme.stroke),
                          ),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        final isCurrent = result['isCurrent'] == true;
                        return Pressable(
                          onPressed: () {
                            widget.onLocationSelected(result['address']);
                            // 高德 location 格式为 "lng,lat"（GCJ-02）
                            final parts = (result['location'] as String? ?? '')
                                .split(',');
                            if (parts.length == 2) {
                              final lng = double.tryParse(parts[0]);
                              final lat = double.tryParse(parts[1]);
                              if (lat != null && lng != null) {
                                widget.onLatLngSelected?.call(lat, lng);
                              }
                            }
                            Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                DsIcon(
                                  DsIconKind.pin,
                                  size: 22,
                                  color:
                                      isCurrent ? theme.primary : theme.textSub,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        result['name'],
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
                              ],
                            ),
                          ),
                        );
                      },
                    )
                    : Center(
                      child: Text(
                        '暂无搜索结果',
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
