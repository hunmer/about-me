import '../../storage_errors.dart';
import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';

Never _invalid(String message, {bool stored = false}) => throw StorageException(
  stored ? StorageErrorKind.invalidData : StorageErrorKind.invalidRequest,
  message,
);

bool _strings(dynamic value) =>
    value is List && value.every((v) => v is String);

void _fields(
  Map value,
  Map<String, bool Function(dynamic)> rules, {
  bool stored = false,
}) {
  for (final field in rules.entries) {
    if (value.containsKey(field.key) && !field.value(value[field.key])) {
      _invalid('聊天字段类型错误: ${field.key}', stored: stored);
    }
  }
}

void _settings(Map value, {bool stored = false}) => _fields(value, {
  for (final key in [
    'showAvatarInChat',
    'showAvatarInTimeline',
    'playSoundOnSend',
  ])
    key: (v) => v is bool,
}, stored: stored);

void _timeline(Map value, {bool stored = false}) {
  _fields(value, {
    'filterData': (v) => v == null || v is Map<String, dynamic>,
    'viewState': (v) => v == null || v is Map<String, dynamic>,
    'lastUpdate': (v) => v is String && DateTime.tryParse(v) != null,
  }, stored: stored);
  if (value['filterData'] is Map) {
    _fields(value['filterData'] as Map, {
      'type': (v) => v is int && v >= 0,
      'selectedChannelIds': _strings,
      'selectedUserIds': _strings,
      'isAI': (v) => v == null || v is bool,
      'isFavorite': (v) => v == null || v is bool,
    }, stored: stored);
  }
  if (value['viewState'] is Map) {
    _fields(value['viewState'] as Map, {
      'isFilterActive': (v) => v is bool,
      'searchQuery': (v) => v == null || v is String,
    }, stored: stored);
  }
}

void _user(Map value, {bool stored = false}) {
  if (value['id'] is! String ||
      (value['id'] as String).isEmpty ||
      (stored && (value['username'] ?? value['name']) is! String)) {
    _invalid('用户字段错误', stored: stored);
  }
  _fields(value, {
    'username': (v) => v is String,
    'name': (v) => v is String,
    'iconPath': (v) => v == null || v is String,
    'avatarPath': (v) => v == null || v is String,
    'isAI': (v) => v is bool,
    'metadata': (v) => v == null || v is Map<String, dynamic>,
  }, stored: stored);
}

void _threadMessage(Map value, {bool stored = false, bool patch = false}) {
  if (!patch &&
      (value['id'] is! String ||
          (value['id'] as String).isEmpty ||
          value['content'] is! String)) {
    _invalid('线程消息字段错误', stored: stored);
  }
  _fields(value, {
    'content': (v) => v is String,
    'role': (v) => v == 'user' || v == 'assistant',
    'type': (v) => v == 'text' || v == 'audio',
    'status': (v) => ['thinking', 'done', 'error'].contains(v),
    'audioPath': (v) => v == null || v is String,
    'audioDurationSec': (v) => v == null || (v is int && v >= 0),
    'agentId': (v) => v == null || v is String,
    'agentName': (v) => v == null || v is String,
    if (stored) 'date': (v) => v is String && DateTime.tryParse(v) != null,
  }, stored: stored);
}

void _threads(Map value) {
  final threads = value['threads'];
  if (threads == null && value.isEmpty) return;
  if (threads is! Map<String, dynamic>) _invalid('线程集合损坏', stored: true);
  for (final entry in threads.entries) {
    final thread = entry.value;
    if (thread is! Map<String, dynamic> ||
        thread['rootMessageId'] != entry.key ||
        thread['channelId'] is! String ||
        thread['messages'] is! List ||
        (thread['agentIds'] != null && !_strings(thread['agentIds']))) {
      _invalid('线程字段损坏', stored: true);
    }
    final ids = <String>{};
    for (final message in thread['messages'] as List) {
      if (message is! Map<String, dynamic>) _invalid('线程消息损坏', stored: true);
      _threadMessage(message, stored: true);
      if (!ids.add(message['id'] as String))
        _invalid('线程消息 ID 重复', stored: true);
    }
  }
}

Future<Map<String, dynamic>> _object(PluginData data, String file) async {
  final value = await data.read('chat', file);
  if (value == null) return {};
  if (value is! Map<String, dynamic>) {
    throw StorageException(StorageErrorKind.invalidData, '聊天配置结构损坏: $file');
  }
  if (file == 'settings.json') _settings(value, stored: true);
  if (file == 'timeline.json') _timeline(value, stored: true);
  if (file.startsWith('ai_threads/')) _threads(value);
  if (file == 'users.json') {
    if (value['users'] is! List) _invalid('用户集合损坏', stored: true);
    final ids = <String>{};
    for (final user in value['users'] as List) {
      if (user is! Map<String, dynamic>) _invalid('用户数据损坏', stored: true);
      _user(user, stored: true);
      if (!ids.add(user['id'] as String)) _invalid('用户 ID 重复', stored: true);
    }
  }
  return value;
}

Future<void> removeChatThreads(
  PluginData data,
  String id,
  List<String> roots,
) async {
  final value = await _object(data, 'ai_threads/$id.json');
  final threads = Map<String, dynamic>.from(value['threads'] as Map? ?? {});
  for (final root in roots) {
    threads.remove(root);
  }
  if (value.isNotEmpty)
    await data.write('chat', 'ai_threads/$id.json', {
      ...value,
      'threads': threads,
    });
}

PluginHandlers createChatSupportHandlers(PluginData data) {
  Future<Map<String, dynamic>> threads(String id) =>
      _object(data, 'ai_threads/$id.json');
  Future<void> writeThread(
    String channel,
    String root,
    Map<String, dynamic> thread,
  ) async {
    final value = await threads(channel);
    await data.write('chat', 'ai_threads/$channel.json', {
      ...value,
      'threads': {...value['threads'] as Map? ?? {}, root: thread},
    });
  }

  Future<Map<String, dynamic>> getThread(Map<String, dynamic> params) async {
    final value = await threads(params['channelId'].toString());
    final thread = (value['threads'] as Map? ?? {})[params['rootMessageId']];
    if (thread is! Map)
      throw const StorageException(StorageErrorKind.notFound, 'AI 线程不存在');
    return Map<String, dynamic>.from(thread);
  }

  final handlers = <String, PluginHandler>{};
  for (final entry in {
    'Settings': 'settings.json',
    'TimelineState': 'timeline.json',
  }.entries) {
    handlers['get${entry.key}'] = (_, __) async =>
        PluginResult.success(await _object(data, entry.value));
    handlers['update${entry.key}'] = (_, params) async {
      final patch = params['patch'];
      if (patch is! Map<String, dynamic>)
        return const PluginResult.failure('patch 必须是对象', 'INVALID_PARAMS');
      if (entry.key == 'Settings') _settings(patch);
      if (entry.key == 'TimelineState') _timeline(patch);
      final old = await _object(data, entry.value);
      final next = {...old, ...patch};
      // 时间线各分组同样按字段合并，避免设备间改不同筛选项互相覆盖。
      if (entry.key == 'TimelineState') {
        for (final key in ['filterData', 'viewState']) {
          if (old[key] is Map && patch[key] is Map)
            next[key] = {...old[key] as Map, ...patch[key] as Map};
        }
      }
      await data.write('chat', entry.value, next);
      return PluginResult.success(next);
    };
  }
  final result = <String, PluginHandler>{
    ...handlers,
    'getUsers': (_, __) async =>
        PluginResult.success(await _object(data, 'users.json')),
    'updateUser': (_, params) async {
      final id = params['id'];
      if (id is! String || id.isEmpty)
        return const PluginResult.failure('缺少用户 ID', 'INVALID_PARAMS');
      _user(params);
      final value = await _object(data, 'users.json');
      final users = List<dynamic>.from(value['users'] as List? ?? []);
      final index = users.indexWhere((u) => u['id'] == id);
      final next = {
        ...(index < 0 ? <String, dynamic>{} : users[index] as Map),
        ...params,
      };
      if (params.containsKey('name') && !params.containsKey('username'))
        next['username'] = params['name'];
      if (params.containsKey('avatarPath') && !params.containsKey('iconPath'))
        next['iconPath'] = params['avatarPath'];
      _user(next, stored: false);
      if (next['username'] is! String) _invalid('新用户需要 username');
      if (index < 0) {
        users.add(next);
      } else {
        users[index] = next;
      }
      await data.write('chat', 'users.json', {...value, 'users': users});
      return PluginResult.success(next);
    },
    'getQuickActions': (_, __) async {
      final value = await data.read('chat', 'quick_toolbar_actions.json');
      if (value != null && !_strings(value))
        throw const StorageException(StorageErrorKind.invalidData, '快捷动作配置损坏');
      return PluginResult.success(value ?? ['photo', 'video']);
    },
    'updateQuickActions': (_, params) async {
      final ids = params['ids'];
      if (ids is! List || ids.any((id) => id is! String))
        return const PluginResult.failure('ids 必须是字符串数组', 'INVALID_PARAMS');
      await data.write('chat', 'quick_toolbar_actions.json', ids);
      return PluginResult.success(ids);
    },
    'getThreads': (_, params) async =>
        PluginResult.success(await threads(params['channelId'].toString())),
    'ensureThread': (_, params) async {
      final channelId = params['channelId'].toString();
      final root = params['rootMessageId'].toString();
      final channel = await data.read('chat', 'channel/$channelId.json');
      final messages = await data.read('chat', 'messages/$channelId.json');
      if (messages != null &&
          (messages is! Map ||
              messages['messages'] is! List ||
              (messages['messages'] as List).any(
                (m) => m is! Map || m['id'] is! String,
              ))) {
        _invalid('线程根消息集合损坏', stored: true);
      }
      if (channel == null ||
          messages == null ||
          !(messages['messages'] as List).any((m) => m['id'] == root)) {
        return const PluginResult.failure('线程根消息不存在', 'NOT_FOUND');
      }
      final value = await threads(channelId);
      final thread = Map<String, dynamic>.from(
        (value['threads'] as Map? ?? {})[root] as Map? ??
            {
              'rootMessageId': root,
              'channelId': channelId,
              'messages': <dynamic>[],
            },
      );
      final agents = List<String>.from(thread['agentIds'] as List? ?? []);
      final agent = params['agentId'];
      if (agent is! String || agent.isEmpty)
        return const PluginResult.failure('缺少 agentId', 'INVALID_PARAMS');
      if (!agents.contains(agent)) agents.add(agent);
      thread['agentIds'] = agents;
      await writeThread(channelId, root, thread);
      return PluginResult.success(thread);
    },
    'appendThreadMessage': (_, params) async {
      final thread = await getThread(params);
      final raw = params['message'];
      if (raw is! Map<String, dynamic> ||
          raw['id'] is! String ||
          raw['content'] is! String) {
        return const PluginResult.failure('线程消息字段错误', 'INVALID_PARAMS');
      }
      _threadMessage(raw);
      final items = List<dynamic>.from(thread['messages'] as List? ?? []);
      if (items.any((m) => m['id'] == raw['id']))
        return const PluginResult.failure('线程消息已存在', 'CONFLICT');
      final now = jsIsoDateTime(DateTime.now());
      items.add({...raw, 'date': now});
      thread['messages'] = items;
      await writeThread(
        params['channelId'].toString(),
        params['rootMessageId'].toString(),
        thread,
      );
      return PluginResult.success(thread);
    },
    'updateThreadMessage': (_, params) async {
      final thread = await getThread(params);
      final items = List<dynamic>.from(thread['messages'] as List? ?? []);
      final index = items.indexWhere((m) => m['id'] == params['messageId']);
      if (index < 0) return const PluginResult.failure('线程消息不存在', 'NOT_FOUND');
      final patch = params['patch'];
      if (patch is! Map<String, dynamic> ||
          patch.keys.any(
            (key) => !{
              'content',
              'status',
              'audioPath',
              'audioDurationSec',
            }.contains(key),
          )) {
        return const PluginResult.failure('无效线程消息变更', 'INVALID_PARAMS');
      }
      _threadMessage(patch, patch: true);
      items[index] = {...items[index] as Map, ...patch};
      thread['messages'] = items;
      await writeThread(
        params['channelId'].toString(),
        params['rootMessageId'].toString(),
        thread,
      );
      return PluginResult.success(thread);
    },
    'deleteThreadMessage': (_, params) async {
      final thread = await getThread(params);
      final items = List<dynamic>.from(thread['messages'] as List? ?? [])
        ..removeWhere((m) => m['id'] == params['messageId']);
      thread['messages'] = items;
      await writeThread(
        params['channelId'].toString(),
        params['rootMessageId'].toString(),
        thread,
      );
      return PluginResult.success(thread);
    },
    'deleteThread': (_, params) async {
      await removeChatThreads(data, params['channelId'].toString(), [
        params['rootMessageId'].toString(),
      ]);
      return PluginResult.success({'deleted': params['rootMessageId']});
    },
  };
  return {
    for (final entry in result.entries)
      entry.key: (data, params) async {
        if (entry.key.toLowerCase().contains('thread')) {
          for (final key in [
            'channelId',
            if (entry.key != 'getThreads') 'rootMessageId',
            if (entry.key == 'updateThreadMessage' ||
                entry.key == 'deleteThreadMessage')
              'messageId',
          ]) {
            if (params[key] is! String || (params[key] as String).isEmpty) {
              _invalid('缺少有效的 $key');
            }
          }
        }
        return entry.value(data, params);
      },
  };
}
