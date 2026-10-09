import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';

import 'jelly_status_panel_config.dart';
import 'jelly_status_panel_editor.dart';

class JellyStatusPanelStyle {
  const JellyStatusPanelStyle({
    required this.id,
    required this.label,
    required this.asset,
    required this.defaultConfig,
    this.visibleBounds = const Rect.fromLTWH(0, 0, 1, 1),
  });

  final String id;
  final String label;
  final String asset;
  final JellyStatusPanelConfig defaultConfig;
  final Rect visibleBounds;

  double get visibleAspectRatio =>
      (16 / 9) * visibleBounds.width / visibleBounds.height;

  Rect mapToVisible(Rect source) {
    return Rect.fromLTRB(
      (source.left - visibleBounds.left) / visibleBounds.width,
      (source.top - visibleBounds.top) / visibleBounds.height,
      (source.right - visibleBounds.left) / visibleBounds.width,
      (source.bottom - visibleBounds.top) / visibleBounds.height,
    );
  }
}

class JellyStatusPanelSettings extends ChangeNotifier {
  JellyStatusPanelSettings._();

  static final instance = JellyStatusPanelSettings._();
  static const double maxDisplayHeight = 150;

  static const builtInStyles = <JellyStatusPanelStyle>[
    JellyStatusPanelStyle(
      id: 'rabbit_a1',
      label: '奶油兔兔',
      asset: 'assets/images/jelly_status_panel.png',
      defaultConfig: JellyStatusPanelConfig.defaults,
      visibleBounds: Rect.fromLTRB(
        34 / 2048,
        236 / 1152,
        2018 / 2048,
        758 / 1152,
      ),
    ),
    JellyStatusPanelStyle(
      id: 'rabbit_a2',
      label: '粉彩兔兔',
      asset: 'assets/images/jelly_status_panel_a2.png',
      defaultConfig: JellyStatusPanelConfig.defaults,
      visibleBounds: Rect.fromLTRB(
        20 / 2048,
        298 / 1152,
        2022 / 2048,
        754 / 1152,
      ),
    ),
    JellyStatusPanelStyle(
      id: 'rabbit_a3',
      label: '莓果兔兔',
      asset: 'assets/images/jelly_status_panel_a3.png',
      defaultConfig: JellyStatusPanelConfig.defaults,
      visibleBounds: Rect.fromLTRB(
        20 / 2048,
        286 / 1152,
        2026 / 2048,
        722 / 1152,
      ),
    ),
  ];

  static const _selectedStyleKey = 'jelly_status_panel.style';
  static const _legacyConfigKey = 'jelly_status_panel.config';
  static const _avatarKey = 'user_avatar_path';
  static const _userNameKey = 'user_name';
  static const _customStylesKey = 'jelly_status_panel.custom_styles';

  bool _loaded = false;
  String _selectedStyleId = builtInStyles.first.id;
  JellyStatusPanelConfig _config = builtInStyles.first.defaultConfig;
  final List<JellyStatusPanelStyle> _customStyles = [];
  String? _avatarPath;
  String _userName = '用户';

  List<JellyStatusPanelStyle> get styles => [
    ...builtInStyles,
    ..._customStyles,
  ];
  JellyStatusPanelStyle get selectedStyle => styles.firstWhere(
    (style) => style.id == _selectedStyleId,
    orElse: () => builtInStyles.first,
  );
  JellyStatusPanelConfig get config => _config;
  String? get avatarPath => _avatarPath;
  String get userName => _userName;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    _customStyles.clear();
    final customJson = prefs.getString(_customStylesKey);
    if (customJson != null) {
      try {
        final entries = jsonDecode(customJson) as List<dynamic>;
        for (final entry in entries.cast<Map<String, dynamic>>()) {
          final path = entry['path'] as String;
          final bounds = (entry['bounds'] as List<dynamic>).cast<num>();
          _customStyles.add(
            JellyStatusPanelStyle(
              id: 'custom:$path',
              label: '自定义 ${_customStyles.length + 1}',
              asset: path,
              defaultConfig: JellyStatusPanelConfig.defaults,
              visibleBounds: Rect.fromLTRB(
                bounds[0].toDouble(),
                bounds[1].toDouble(),
                bounds[2].toDouble(),
                bounds[3].toDouble(),
              ),
            ),
          );
        }
      } catch (_) {
        _customStyles.clear();
      }
    }
    final storedStyle = prefs.getString(_selectedStyleKey);
    if (styles.any((style) => style.id == storedStyle)) {
      _selectedStyleId = storedStyle!;
    }
    _loadStyleConfig(prefs);
    _avatarPath = prefs.getString(_avatarKey);
    final name = prefs.getString(_userNameKey)?.trim();
    _userName = name == null || name.isEmpty ? '用户' : name;
    notifyListeners();
  }

  Future<void> selectStyle(String styleId) async {
    if (styleId == _selectedStyleId ||
        !styles.any((style) => style.id == styleId)) {
      return;
    }
    _selectedStyleId = styleId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedStyleKey, styleId);
    _loadStyleConfig(prefs);
    notifyListeners();
  }

  Future<void> upload(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          const ImagePickerDialog(saveDirectory: 'live2d/status_panels'),
    );
    final path = result?['url'] as String?;
    if (path == null || path.isEmpty) return;
    if (!_customStyles.any((style) => style.asset == path)) {
      final bytes = result?['bytes'];
      final visibleBounds = bytes is Uint8List
          ? await _detectVisibleBounds(bytes)
          : const Rect.fromLTWH(0, 0, 1, 1);
      _customStyles.add(
        JellyStatusPanelStyle(
          id: 'custom:$path',
          label: '自定义 ${_customStyles.length + 1}',
          asset: path,
          defaultConfig: JellyStatusPanelConfig.defaults,
          visibleBounds: visibleBounds,
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _customStylesKey,
        jsonEncode(
          _customStyles
              .map(
                (style) => {
                  'path': style.asset,
                  'bounds': [
                    style.visibleBounds.left,
                    style.visibleBounds.top,
                    style.visibleBounds.right,
                    style.visibleBounds.bottom,
                  ],
                },
              )
              .toList(),
        ),
      );
    }
    await selectStyle('custom:$path');
    if (context.mounted) await edit(context);
  }

  Future<void> edit(BuildContext context) async {
    await load();
    if (!context.mounted) return;
    final next = await showJellyStatusPanelEditor(
      context: context,
      asset: selectedStyle.asset,
      initial: _config,
      userName: _userName,
      avatarPath: _avatarPath,
      onAvatarChanged: _saveAvatar,
    );
    if (next == null) return;
    _config = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey(_selectedStyleId), next.encode());
    notifyListeners();
  }

  void _loadStyleConfig(SharedPreferences prefs) {
    final encoded =
        prefs.getString(_configKey(_selectedStyleId)) ??
        (_selectedStyleId == builtInStyles.first.id
            ? prefs.getString(_legacyConfigKey)
            : null);
    _config = JellyStatusPanelConfig.parse(
      encoded,
      fallback: selectedStyle.defaultConfig,
    );
  }

  Future<void> _saveAvatar(String path) async {
    _avatarPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey, path);
    notifyListeners();
  }

  static String _configKey(String styleId) =>
      'jelly_status_panel.config.$styleId';

  static Future<Rect> _detectVisibleBounds(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return const Rect.fromLTWH(0, 0, 1, 1);
      final pixels = data.buffer.asUint8List();
      var minX = image.width;
      var minY = image.height;
      var maxX = -1;
      var maxY = -1;
      for (var y = 0; y < image.height; y += 2) {
        for (var x = 0; x < image.width; x += 2) {
          if (pixels[(y * image.width + x) * 4 + 3] <= 8) continue;
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
      if (maxX < minX || maxY < minY) {
        return const Rect.fromLTWH(0, 0, 1, 1);
      }
      return Rect.fromLTRB(
        minX / image.width,
        minY / image.height,
        (maxX + 2).clamp(0, image.width) / image.width,
        (maxY + 2).clamp(0, image.height) / image.height,
      );
    } finally {
      image.dispose();
      codec.dispose();
    }
  }
}
