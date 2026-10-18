import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 状态面板用户资料（头像/用户名），组件化面板的数据源
class JellyStatusPanelSettings extends ChangeNotifier {
  JellyStatusPanelSettings._();

  static final instance = JellyStatusPanelSettings._();

  /// 面板显示高度上限（与 jelly_home_screen 的避让计算共用）
  static const double maxDisplayHeight = 150;

  /// 面板纵横比：窄屏按此比例压缩面板高度，宽屏恒为 [maxDisplayHeight]
  static const double panelAspectRatio = 3.8;

  static const _avatarKey = 'user_avatar_path';
  static const _userNameKey = 'user_name';

  bool _loaded = false;
  String? _avatarPath;
  String _userName = '用户';

  String? get avatarPath => _avatarPath;
  String get userName => _userName;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    _avatarPath = prefs.getString(_avatarKey);
    final name = prefs.getString(_userNameKey)?.trim();
    _userName = name == null || name.isEmpty ? '用户' : name;
    notifyListeners();
  }

  Future<void> saveAvatar(String path) async {
    _avatarPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarKey, path);
    notifyListeners();
  }
}
