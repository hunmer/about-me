import 'package:flutter/material.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/events/user_events.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/widgets/adaptive_image.dart';

class MessageAvatar extends StatefulWidget {
  final User user;

  /// AI 消息的 agentId：头像实时读取 agent 配置，不随消息保存
  final String? agentId;

  final VoidCallback? onTap;

  const MessageAvatar({
    super.key,
    required this.user,
    this.agentId,
    this.onTap,
  });

  @override
  State<MessageAvatar> createState() => _MessageAvatarState();
}

class _MessageAvatarState extends State<MessageAvatar> {
  late User _currentUser;

  /// agent 消息实时解析出的头像（assets/网络/本地相对路径）
  String? _agentAvatarUrl;

  User get user => _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _resolveAgentAvatar();
    // 订阅用户头像更新事件（全局用户资料变更时刷新）
    EventManager.instance.subscribe(
      UserEventNames.userAvatarUpdated,
      _handleAvatarUpdate,
    );
  }

  @override
  void didUpdateWidget(MessageAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _currentUser = widget.user;
    }
    if (oldWidget.agentId != widget.agentId) {
      _resolveAgentAvatar();
    }
  }

  @override
  void dispose() {
    // 取消订阅
    EventManager.instance.unsubscribe(UserEventNames.userAvatarUpdated);
    super.dispose();
  }

  void _handleAvatarUpdate(EventArgs args) {
    if (args is UserAvatarUpdatedEventArgs) {
      // 只有当更新的是当前显示的用户时才刷新（头像实时重读全局数据源）
      if (args.user.id == user.id) {
        setState(() {
          _currentUser = args.user;
        });
      }
    }
  }

  Future<void> _resolveAgentAvatar() async {
    final agentId = widget.agentId;
    if (agentId == null) {
      if (_agentAvatarUrl != null) {
        setState(() => _agentAvatarUrl = null);
      }
      return;
    }
    try {
      final plugin = PluginManager.instance.getPlugin('openai');
      if (plugin is! OpenAIPlugin) return;
      final agent = await plugin.controller.getAgent(agentId);
      if (!mounted || widget.agentId != agentId || agent == null) return;
      setState(() => _agentAvatarUrl = agent.avatarUrl);
    } catch (_) {
      // agent 已删除等情况：回落到默认头像
      if (mounted && _agentAvatarUrl != null) {
        setState(() => _agentAvatarUrl = null);
      }
    }
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    return Center(
      child: Text(
        user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  /// 个人主页同款默认头像资产（未设置自定义头像时与 profile 展示一致）
  static const _defaultAvatarAsset = 'assets/images/default_avatar.jpg';

  Widget _buildDefaultAssetAvatar(BuildContext context) {
    return AdaptiveImage(
      imagePath: _defaultAvatarAsset,
      width: 32,
      height: 32,
      fit: BoxFit.cover,
      shape: BoxShape.circle,
      errorImage: _buildDefaultAvatar(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primaryContainer,
          boxShadow: DsShadows.soft,
        ),
        child: _buildAvatarContent(context),
      ),
    );
  }

  Widget _buildAvatarContent(BuildContext context) {
    // agent 消息：优先使用 agent 配置的头像（实时读取）
    final agentAvatar = _agentAvatarUrl;
    if (widget.agentId != null &&
        agentAvatar != null &&
        agentAvatar.isNotEmpty) {
      return AdaptiveImage(
        imagePath: agentAvatar,
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        shape: BoxShape.circle,
        errorImage: _buildDefaultAvatar(context),
      );
    }

    // 当前用户：实时读取全局头像（个人主页数据源），渲染链路与个人主页一致
    final userService = ChatPlugin.instance.userService;
    if (user.id == userService.currentUser.id) {
      final avatarPath = userService.currentUserAvatarPath;
      if (avatarPath != null && avatarPath.isNotEmpty) {
        return AdaptiveImage(
          imagePath: avatarPath,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          shape: BoxShape.circle,
          errorImage: _buildDefaultAssetAvatar(context),
        );
      }
      // 未设置自定义头像：回退默认头像资产，与个人主页展示保持一致
      return _buildDefaultAssetAvatar(context);
    }

    // 其他用户：不再有独立头像来源，显示默认首字母
    return _buildDefaultAvatar(context);
  }
}
