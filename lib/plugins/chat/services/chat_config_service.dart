import 'dart:async';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/plugins/chat/events/user_events.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_data_service.dart';

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
  final _subscriptions = <StreamSubscription<QuerySnapshot>>[];

  /// 当前用户资料统一来自个人主页（SharedPreferences 的 user_name/user_avatar_path），
  /// 不再使用 chat/users 文件中的独立设置；头像不进 User 模型，单独实时读取
  User get currentUser {
    final name = _prefs?.getString('user_name')?.trim();
    return User(
      id: 'default_user',
      username: (name == null || name.isEmpty) ? '用户' : name,
    );
  }

  /// 当前用户全局头像路径（个人主页数据源），chat 不再单独维护头像
  String? get currentUserAvatarPath {
    final avatar = _prefs?.getString('user_avatar_path');
    return (avatar == null || avatar.isEmpty) ? null : avatar;
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
    for (final action in ['getSettings', 'getUsers']) {
      _subscriptions.add(
        AboutmeDataService.instance.data.watch('chat', action).listen((
          snapshot,
        ) {
          if (snapshot.status == QueryStatus.data && snapshot.result != null) {
            final value = ChatDataService.resultData(snapshot.result!) as Map;
            if (action == 'getSettings') {
              _showAvatarInChat = value['showAvatarInChat'] as bool? ?? true;
              _showAvatarInTimeline =
                  value['showAvatarInTimeline'] as bool? ?? true;
              _playSoundOnSend = value['playSoundOnSend'] as bool? ?? true;
            } else {
              _users.clear();
              for (final user in value['users'] as List? ?? []) {
                _addOrUpdateUser(
                  User.fromJson(Map<String, dynamic>.from(user as Map)),
                );
              }
            }
            _plugin.refresh();
          } else if (snapshot.error != null) {
            debugPrint('[Chat] 配置查询失败: ${snapshot.error}');
          }
        }),
      );
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> _initializeUsers() async {
    // 从存储中加载用户信息
    final userData =
        ChatDataService.resultData(
              await AboutmeDataService.instance.get('chat', 'getUsers'),
            )
            as Map;

    // 加载所有用户信息
    final usersList = userData['users'] as List<dynamic>? ?? [];
    _users.clear();
    for (var userJson in usersList) {
      final user = User.fromJson(userJson as Map<String, dynamic>);
      _addOrUpdateUser(user);
    }
  }

  Future<void> _initializeSettings() async {
    try {
      final settings =
          ChatDataService.resultData(
                await AboutmeDataService.instance.get('chat', 'getSettings'),
              )
              as Map;
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

  Future<void> updateUser(User user) async {
    final json = ChatDataService.resultData(
      await AboutmeDataService.instance.call(
        'chat',
        'updateUser',
        user.toJson(),
      ),
    );
    _addOrUpdateUser(User.fromJson(Map<String, dynamic>.from(json as Map)));
    EventManager.instance.broadcast(
      UserEventNames.userAvatarUpdated,
      UserAvatarUpdatedEventArgs(user),
    );
    _plugin.refresh();
  }

  // ==================== 设置操作 ====================

  Future<void> setPlaySoundOnSend(bool value) async {
    ChatDataService.resultData(
      await AboutmeDataService.instance.call('chat', 'updateSettings', {
        'patch': {'playSoundOnSend': value},
      }),
    );
    _playSoundOnSend = value;
    _plugin.refresh();
  }

  Future<void> setShowAvatarInChat(bool value) async {
    ChatDataService.resultData(
      await AboutmeDataService.instance.call('chat', 'updateSettings', {
        'patch': {'showAvatarInChat': value},
      }),
    );
    _showAvatarInChat = value;
    _plugin.refresh();
  }

  Future<void> setShowAvatarInTimeline(bool value) async {
    ChatDataService.resultData(
      await AboutmeDataService.instance.call('chat', 'updateSettings', {
        'patch': {'showAvatarInTimeline': value},
      }),
    );
    _showAvatarInTimeline = value;
    _plugin.refresh();
  }

  bool shouldPlayMessageSound() {
    return _playSoundOnSend;
  }
}
