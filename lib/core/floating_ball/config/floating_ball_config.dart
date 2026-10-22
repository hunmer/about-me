import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/floating_ball/models/floating_ball_gesture.dart';

/// 悬浮球配置数据模型
class FloatingBallConfig {
  /// 默认大小比例
  static const double defaultSizeScale = 0.6;

  /// 默认位置
  static const Offset defaultPosition = Offset(21, 99);

  /// 默认手势动作映射
  static const Map<FloatingBallGesture, String> defaultGestureMappings = {
    FloatingBallGesture.tap: '打开上次插件',
    FloatingBallGesture.swipeUp: '返回上一页',
    FloatingBallGesture.swipeDown: '选择打开插件',
    FloatingBallGesture.swipeLeft: '选择打开插件小窗口',
    FloatingBallGesture.swipeRight: '刷新页面',
  };

  final Map<FloatingBallGesture, String> actionMappings;
  final double sizeScale;
  final Offset position;
  final bool enabled;

  const FloatingBallConfig({
    this.actionMappings = defaultGestureMappings,
    this.sizeScale = defaultSizeScale,
    this.position = defaultPosition,
    this.enabled = true,
  });

  /// 从JSON创建配置
  factory FloatingBallConfig.fromJson(Map<String, dynamic> json) {
    try {
      // 解析动作映射
      final actionsJson = json['actions'] as Map<String, dynamic>? ?? {};
      final actionMappings = <FloatingBallGesture, String>{};

      for (final entry in actionsJson.entries) {
        final gesture = _parseGesture(entry.key);
        if (gesture != null) {
          actionMappings[gesture] = entry.value as String;
        }
      }

      // 解析位置
      final positionJson = json['position'] as Map<String, dynamic>? ?? {};
      final position = Offset(
        (positionJson['x'] as num?)?.toDouble() ?? defaultPosition.dx,
        (positionJson['y'] as num?)?.toDouble() ?? defaultPosition.dy,
      );

      return FloatingBallConfig(
        actionMappings: actionMappings,
        sizeScale: (json['size_scale'] as num?)?.toDouble() ?? defaultSizeScale,
        position: position,
        enabled: json['enabled'] as bool? ?? true,
      );
    } catch (e) {
      debugPrint('Error parsing FloatingBallConfig: $e');
      // 返回默认配置
      return FloatingBallConfig();
    }
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    final actionsJson = <String, String>{};
    for (final entry in actionMappings.entries) {
      actionsJson[_gestureToString(entry.key)] = entry.value;
    }

    return {
      'actions': actionsJson,
      'size_scale': sizeScale,
      'position': {
        'x': position.dx,
        'y': position.dy,
      },
      'enabled': enabled,
    };
  }

  /// 从JSON字符串创建配置
  factory FloatingBallConfig.fromJsonString(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return FloatingBallConfig.fromJson(json);
    } catch (e) {
      debugPrint('Error parsing FloatingBallConfig from string: $e');
      return FloatingBallConfig();
    }
  }

  /// 转换为JSON字符串
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// 创建副本并修改指定属性
  FloatingBallConfig copyWith({
    Map<FloatingBallGesture, String>? actionMappings,
    double? sizeScale,
    Offset? position,
    bool? enabled,
  }) {
    return FloatingBallConfig(
      actionMappings: actionMappings ?? this.actionMappings,
      sizeScale: sizeScale ?? this.sizeScale,
      position: position ?? this.position,
      enabled: enabled ?? this.enabled,
    );
  }

  /// 获取默认配置
  static FloatingBallConfig get defaultConfig => FloatingBallConfig(
    sizeScale: defaultSizeScale,
    position: defaultPosition,
    enabled: true,
    actionMappings: defaultGestureMappings,
  );

  /// 配置迁移：从旧版本升级
  static FloatingBallConfig migrateFromOldConfig(Map<String, dynamic> oldConfig) {
    try {
      // 直接返回从JSON解析的配置
      return FloatingBallConfig.fromJson(oldConfig);
    } catch (e) {
      debugPrint('Error migrating config: $e');
      return FloatingBallConfig.defaultConfig;
    }
  }

  /// 获取手势的字符串表示
  static String _gestureToString(FloatingBallGesture gesture) {
    switch (gesture) {
      case FloatingBallGesture.tap:
        return 'tap';
      case FloatingBallGesture.doubleTap:
        return 'doubleTap';
      case FloatingBallGesture.longPress:
        return 'longPress';
      case FloatingBallGesture.swipeUp:
        return 'swipeUp';
      case FloatingBallGesture.swipeDown:
        return 'swipeDown';
      case FloatingBallGesture.swipeLeft:
        return 'swipeLeft';
      case FloatingBallGesture.swipeRight:
        return 'swipeRight';
    }
  }

  /// 从字符串解析手势
  static FloatingBallGesture? _parseGesture(String gestureString) {
    switch (gestureString) {
      case 'tap':
        return FloatingBallGesture.tap;
      case 'doubleTap':
        return FloatingBallGesture.doubleTap;
      case 'longPress':
        return FloatingBallGesture.longPress;
      case 'swipeUp':
        return FloatingBallGesture.swipeUp;
      case 'swipeDown':
        return FloatingBallGesture.swipeDown;
      case 'swipeLeft':
        return FloatingBallGesture.swipeLeft;
      case 'swipeRight':
        return FloatingBallGesture.swipeRight;
      default:
        return null;
    }
  }

  /// 获取特定手势的动作
  String? getAction(FloatingBallGesture gesture) {
    return actionMappings[gesture];
  }

  /// 设置特定手势的动作
  FloatingBallConfig setAction(FloatingBallGesture gesture, String action) {
    final newMappings = Map<FloatingBallGesture, String>.from(actionMappings);
    newMappings[gesture] = action;
    return copyWith(actionMappings: newMappings);
  }

  /// 清除特定手势的动作
  FloatingBallConfig clearAction(FloatingBallGesture gesture) {
    final newMappings = Map<FloatingBallGesture, String>.from(actionMappings);
    newMappings.remove(gesture);
    return copyWith(actionMappings: newMappings);
  }

  /// 获取配置的哈希值（用于比较配置是否发生变化）
  @override
  int get hashCode => toJsonString().hashCode;

  /// 检查配置是否相等
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FloatingBallConfig &&
           other.sizeScale == sizeScale &&
           other.position == position &&
           other.enabled == enabled;
  }

  @override
  String toString() {
    return 'FloatingBallConfig('
        'sizeScale: $sizeScale, '
        'position: $position, '
        'enabled: $enabled, '
        'actionMappings: $actionMappings'
        ')';
  }
}

/// 悬浮球配置管理器：悬浮球配置存储读写的唯一入口
class FloatingBallConfigManager {
  /// 存储键名（沿用历史键名，兼容已有数据）
  static const String storageKey = 'floating_ball_config.json';

  /// 写入锁，防止并发写入导致数据覆盖
  static bool _isWriting = false;

  /// 读取配置（无数据或损坏时返回默认配置）
  static Future<FloatingBallConfig> loadConfig() async {
    try {
      final data = await globalStorage.read(storageKey);
      if (data == null) {
        return FloatingBallConfig.defaultConfig;
      }

      // Web 平台返回 LinkedMap，需要转换为 Map<String, dynamic>
      if (data is Map<String, dynamic>) {
        return FloatingBallConfig.fromJson(data);
      } else if (data is Map) {
        return FloatingBallConfig.fromJson(
          Map<String, dynamic>.from(data),
        );
      }

      debugPrint('Invalid floating ball config type: ${data.runtimeType}');
      return FloatingBallConfig.defaultConfig;
    } catch (e) {
      debugPrint('Error loading FloatingBallConfig: $e');
      return FloatingBallConfig.defaultConfig;
    }
  }

  /// 保存配置（带锁机制防止竞态条件）
  static Future<void> saveConfig(FloatingBallConfig config) async {
    while (_isWriting) {
      await Future.delayed(const Duration(milliseconds: 10));
    }

    _isWriting = true;
    try {
      await globalStorage.write(storageKey, config.toJson());
    } finally {
      _isWriting = false;
    }
  }

  /// 重置为默认配置
  static Future<void> resetToDefault() async {
    await saveConfig(FloatingBallConfig.defaultConfig);
  }
}
