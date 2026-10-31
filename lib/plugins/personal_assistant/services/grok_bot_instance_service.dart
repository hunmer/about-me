import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/plugins/openai/services/chat_assistant_service.dart';
import 'package:grok_icon_study/grok_icon_study.dart';

/// 单个 grokbot 实例：创建时随机抽取的身形/墨色，各实例会话互相独立
class GrokBotInstance {
  const GrokBotInstance({
    required this.id,
    required this.shapeId,
    required this.colorId,
  });

  final String id;
  final String shapeId;
  final String colorId;

  /// 专属临时会话路由：首个实例沿用聊天助手原路由（保留既有历史消息），
  /// 其余按实例 id 派生，互不串扰
  String get conversationRoute => id == GrokBotInstanceService.firstBotId
      ? ChatAssistantService.conversationRoute
      : '${ChatAssistantService.conversationRoute}_bot_$id';

  Map<String, dynamic> toJson() => {
    'id': id,
    'shapeId': shapeId,
    'colorId': colorId,
  };

  factory GrokBotInstance.fromJson(Map<String, dynamic> json) =>
      GrokBotInstance(
        id: json['id'] as String,
        shapeId: json['shapeId'] as String? ?? 'blob',
        colorId: json['colorId'] as String? ?? 'black',
      );
}

/// grokbot 实例列表管理：加载 / 新增（形象随机抽取）/ 更新形象，持久化到插件配置
class GrokBotInstanceService extends ChangeNotifier {
  /// 配置键名
  static const String _configKey = 'grok_bot_instances';

  /// 首个实例固定 id（沿用聊天助手既有会话路由，避免升级丢历史）
  static const String firstBotId = 'main';

  final math.Random _random = math.Random();

  List<GrokBotInstance> _bots = const [];
  bool _loaded = false;

  /// 已加载的实例列表（未加载时为空）
  List<GrokBotInstance> get bots => _bots;

  /// 从配置加载实例列表（幂等）
  Future<List<GrokBotInstance>> loadBots() async {
    if (_loaded) return _bots;
    try {
      final config = await globalConfigManager.getPluginConfig(_configKey);
      if (config != null && config['bots'] is List) {
        _bots = [
          for (final item in config['bots'] as List)
            if (item is Map<String, dynamic>) GrokBotInstance.fromJson(item),
        ];
      }
    } catch (e) {
      debugPrint('加载 grokbot 实例列表失败: $e');
    }
    _loaded = true;
    notifyListeners();
    return _bots;
  }

  /// 新增实例并持久化；未显式指定时身形/墨色随机抽取
  Future<GrokBotInstance> addBot({
    String? id,
    String? shapeId,
    String? colorId,
  }) async {
    final bot = GrokBotInstance(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      shapeId: shapeId ?? _randomShapeId(),
      colorId: colorId ?? _randomColorId(),
    );
    _bots = [..._bots, bot];
    await _save();
    notifyListeners();
    return bot;
  }

  /// 更新指定实例的身形/墨色（外观设置面板）并持久化
  Future<void> updateStyle(
    String botId, {
    String? shapeId,
    String? colorId,
  }) async {
    final index = _bots.indexWhere((bot) => bot.id == botId);
    if (index < 0) return;
    final old = _bots[index];
    final nextShape =
        shapeId != null && GrokGeometry.shapes.containsKey(shapeId)
        ? shapeId
        : old.shapeId;
    final nextColor =
        colorId != null && GrokGeometry.palette.containsKey(colorId)
        ? colorId
        : old.colorId;
    if (nextShape == old.shapeId && nextColor == old.colorId) return;
    _bots[index] = GrokBotInstance(
      id: old.id,
      shapeId: nextShape,
      colorId: nextColor,
    );
    await _save();
    notifyListeners();
  }

  String _randomShapeId() {
    final keys = GrokGeometry.shapes.keys.toList(growable: false);
    return keys[_random.nextInt(keys.length)];
  }

  String _randomColorId() {
    final keys = GrokGeometry.palette.keys.toList(growable: false);
    return keys[_random.nextInt(keys.length)];
  }

  Future<void> _save() async {
    try {
      await globalConfigManager.savePluginConfig(_configKey, {
        'bots': [for (final bot in _bots) bot.toJson()],
      });
    } catch (e) {
      debugPrint('保存 grokbot 实例列表失败: $e');
    }
  }
}
