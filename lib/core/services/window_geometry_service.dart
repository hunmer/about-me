import 'dart:async';
import 'dart:ui';

import 'package:aboutme/core/app_initializer.dart';
import 'package:flutter/foundation.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面端窗口状态记忆：
/// - 启动时恢复上次的位置、大小与最大化状态
/// - 移动/缩放/最大化/关闭时防抖保存到应用级配置
/// - 恢复前校验保存的窗口区域与当前显示器仍有交集，
///   避免恢复到已被拔掉的屏幕上导致窗口不可见
class WindowGeometryService with WindowListener {
  WindowGeometryService._();

  static final WindowGeometryService instance = WindowGeometryService._();

  static const _keyX = 'windowX';
  static const _keyY = 'windowY';
  static const _keyWidth = 'windowWidth';
  static const _keyHeight = 'windowHeight';
  static const _keyMaximized = 'windowMaximized';

  /// 首次启动的默认尺寸，与 windows/runner/main.cpp 保持一致
  static const _defaultSize = Size(1280, 720);

  /// 移动/缩放结束后的保存防抖间隔
  static const _saveDebounce = Duration(milliseconds: 400);

  Timer? _pendingSave;
  bool _destroying = false;

  /// 仅桌面原生平台（Windows/macOS/Linux）启用；Web 端恒为 false
  bool get isSupported => UniversalPlatform.isDesktop;

  /// runApp 之前调用：初始化并恢复上次的窗口几何信息
  Future<void> initialize() async {
    if (!isSupported) return;

    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    // 拦截关闭事件，退出前落盘最新几何信息
    await windowManager.setPreventClose(true);

    final size = _restoreSize();
    final position = await _restorePosition(size);
    final maximized =
        globalConfigManager.getAppConfigValue<bool>(_keyMaximized, false);

    windowManager.waitUntilReadyToShow(
      WindowOptions(size: size, center: position == null),
      () async {
        if (position != null) {
          await windowManager.setPosition(position);
        }
        if (maximized) {
          await windowManager.maximize();
        }
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  Size _restoreSize() {
    final width =
        globalConfigManager.getAppConfigValue<num?>(_keyWidth, null);
    final height =
        globalConfigManager.getAppConfigValue<num?>(_keyHeight, null);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return _defaultSize;
    }
    return Size(width.toDouble(), height.toDouble());
  }

  /// 返回可恢复的窗口坐标；无记忆或已落到屏幕外时返回 null（调用方走居中）
  Future<Offset?> _restorePosition(Size size) async {
    final x = globalConfigManager.getAppConfigValue<num?>(_keyX, null);
    final y = globalConfigManager.getAppConfigValue<num?>(_keyY, null);
    if (x == null || y == null) return null;

    final rect = Rect.fromLTWH(
      x.toDouble(),
      y.toDouble(),
      size.width,
      size.height,
    );
    try {
      final displays = await ScreenRetriever.instance.getAllDisplays();
      final anyOverlap = displays.any((d) {
        final origin = d.visiblePosition ?? Offset.zero;
        return Rect.fromLTWH(
              origin.dx,
              origin.dy,
              d.size.width,
              d.size.height,
            ).overlaps(rect);
      });
      if (!anyOverlap) {
        return null;
      }
    } catch (e) {
      // 取不到显示器信息时按原值恢复
      debugPrint('WindowGeometryService: 获取显示器信息失败: $e');
    }
    return Offset(x.toDouble(), y.toDouble());
  }

  void _scheduleSave() {
    if (!isSupported) return;
    _pendingSave?.cancel();
    _pendingSave = Timer(_saveDebounce, _save);
  }

  Future<void> _save() async {
    try {
      if (await windowManager.isMaximized()) {
        // 最大化时 getSize/getPosition 是最大化后的值，
        // 只记忆状态、保留上次的普通几何信息
        if (!globalConfigManager.getAppConfigValue<bool>(
          _keyMaximized,
          false,
        )) {
          await globalConfigManager.setAppConfigValue(_keyMaximized, true);
        }
        return;
      }

      final position = await windowManager.getPosition();
      final size = await windowManager.getSize();
      await globalConfigManager.setAppConfigValues({
        _keyX: position.dx,
        _keyY: position.dy,
        _keyWidth: size.width,
        _keyHeight: size.height,
        _keyMaximized: false,
      });
    } catch (e) {
      debugPrint('WindowGeometryService: 保存窗口状态失败: $e');
    }
  }

  @override
  void onWindowMove() => _scheduleSave();

  @override
  void onWindowResize() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();

  @override
  void onWindowClose() async {
    if (_destroying) return;
    _destroying = true;
    _pendingSave?.cancel();
    await _save();
    await windowManager.destroy();
  }
}
