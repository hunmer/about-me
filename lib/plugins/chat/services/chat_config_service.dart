import 'package:flutter/foundation.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/plugins/chat/events/user_events.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 聊天配置服务
///
/// 职责：统一管理用户和设置的配置
/// - 用户管理（当前用户、用户列表）
/// - 插件设置（头像显示、声音等）
/// - 配置持久化
class ChatConfigService {
  final ChatPlugin _plugin;

  // ==================== 用户管理 ====================

  final List<User> _users = [];

  SharedPreferences? _prefs;

  /// 当前用户资料统一来自个人主页（SharedPreferences 的 user_name/user_avatar_path），
  /// 不再使用 chat/users 文件中的独立设置
  User get currentUser {
    final name = _prefs?.getString('user_name')?.trim();
    final avatar = _prefs?.getString('user_avatar_path');
    return User(
      id: 'default_user',
      username: (name == null || name.isEmpty) ? '用户' : name,
      iconPath: (avatar == null || avatar.isEmpty) ? null : avatar,
    );
  }

  // ==================== 设置管理 ====================

  bool _showAvatarInChat = true;
  bool _showAvatarInTimeline = true;
  bool _playSoundOnSend = true;

  bool get showAvatarInChat => _showAvatarInChat;
  bool get showAvatarInTimeline => _showAvatarInTimeline;
  bool get playSoundOnSend => _playSoundOnSend;

  ChatConfigService(this._plugin);

  // ==================== 初始化 ====================

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _initializeUsers();
    await _initializeSettings();
  }

  Future<void> _initializeUsers() async {
    // 确保头像目录存在
    await _plugin.storage.createDirectory('chat/avatars');

    // 从存储中加载用户信息
    final userData = await AboutmeDataService.instance.readPath('chat/users', {
      'users': [
        {
          'id': 'default_user',
          'username': 'Default User',
        }
      ]
    });

    // 加载所有用户信息
    final usersList = userData['users'] as List<dynamic>;
    for (var userJson in usersList) {
      final user = User.fromJson(userJson as Map<String, dynamic>);
      _addOrUpdateUser(user);
    }
  }

  Future<void> _initializeSettings() async {
    try {
      final settings = await AboutmeDataService.instance.readPath(
        'chat/settings.json',
      );
      _showAvatarInChat = settings['showAvatarInChat'] ?? true;
      _showAvatarInTimeline = settings['showAvatarInTimeline'] ?? true;
      _playSoundOnSend = settings['playSoundOnSend'] ?? true;
    } catch (e) {
      debugPrint('Error loading chat settings: $e');
      _showAvatarInChat = true;
      _showAvatarInTimeline = true;
      _playSoundOnSend = true;
    }
  }

  // ==================== 用户操作 ====================

  List<User> getAllUsers() {
    return List.from(_users);
  }

  void _addOrUpdateUser(User user) {
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index >= 0) {
      _users[index] = user;
    } else {
      _users.add(user);
    }
  }

  Future<void> _saveAllUsers() async {
    await AboutmeDataService.instance.writePath('chat/users', {
      'users': _users.map((user) => user.toJson()).toList(),
    });
  }

  Future<void> updateUser(User user) async {
    _addOrUpdateUser(user);
    await _saveAllUsers();

    EventManager.instance.broadcast(
      UserEventNames.userAvatarUpdated,
      UserAvatarUpdatedEventArgs(user)
    );

    _plugin.refresh();
  }

  // ==================== 设置操作 ====================

  Future<void> setPlaySoundOnSend(bool value) async {
    _playSoundOnSend = value;
    await _saveSettings();
    _plugin.refresh();
  }

  Future<void> setShowAvatarInChat(bool value) async {
    _showAvatarInChat = value;
    await _saveSettings();
    _plugin.refresh();
  }

  Future<void> setShowAvatarInTimeline(bool value) async {
    _showAvatarInTimeline = value;
    await _saveSettings();
    _plugin.refresh();
  }

  bool shouldPlayMessageSound() {
    return _playSoundOnSend;
  }

  Future<void> _saveSettings() async {
    await AboutmeDataService.instance.writePath('chat/settings.json', {
      'showAvatarInChat': _showAvatarInChat,
      'showAvatarInTimeline': _showAvatarInTimeline,
      'playSoundOnSend': _playSoundOnSend,
    });
  }
}
