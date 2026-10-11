import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';

// Contact 插件专用处理器（移植自 nodejs handlers/contact.ts）。
//
// 数据格式：
// - contacts.json: 联系人列表（数组格式）
// - interactions.json: 互动记录 {records: [...]}

PluginHandlers createContactHandlers(PluginData data) {
  // 读取所有联系人
  Future<List<Map<String, dynamic>>> readAllContacts() async {
    final content = await data.read('contact', 'contacts.json');
    // contacts.json 直接是数组格式
    if (content is List) return List<Map<String, dynamic>>.from(content);
    if (content is Map) {
      final contacts = content['contacts'];
      if (contacts is List) return List<Map<String, dynamic>>.from(contacts);
    }
    return [];
  }

  // 保存所有联系人
  Future<void> saveAllContacts(List<Map<String, dynamic>> contacts) {
    return data.write('contact', 'contacts.json', contacts);
  }

  return {
    // 获取联系人列表
    'getList': (data, params) async {
      try {
        final contacts = await readAllContacts();

        // 分页
        final offset = params['offset'] as int? ?? 0;
        final count = params['count'] as int? ?? 100;
        final total = contacts.length;
        final end = (offset + count).clamp(0, total);
        final paginatedContacts = offset >= total
            ? <Map<String, dynamic>>[]
            : contacts.sublist(offset, end);

        return PluginResult.success({
          'data': paginatedContacts,
          'total': total,
          'offset': offset,
          'count': paginatedContacts.length,
          'hasMore': offset + paginatedContacts.length < total,
        });
      } catch (e) {
        return PluginResult.failure('获取联系人失败: $e');
      }
    },

    // 根据 ID 获取
    'getById': (data, params) async {
      try {
        final contacts = await readAllContacts();
        final index = contacts.indexWhere((c) => c['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('联系人不存在', 'NOT_FOUND');
        }

        return PluginResult.success(contacts[index]);
      } catch (e) {
        return PluginResult.failure('获取联系人失败: $e');
      }
    },

    // 创建联系人
    'create': (data, params) async {
      try {
        final contacts = await readAllContacts();
        final now = jsIsoDateTime(DateTime.now());

        final id = params['id'];
        final newContact = <String, dynamic>{
          ...params,
          'id': id != null && id.toString().isNotEmpty ? id : generateUUID(),
          'createdAt': now,
          'updatedAt': now,
        };

        contacts.add(newContact);
        await saveAllContacts(contacts);

        return PluginResult.success(newContact);
      } catch (e) {
        return PluginResult.failure('创建联系人失败: $e');
      }
    },

    // 更新联系人
    'update': (data, params) async {
      try {
        final contacts = await readAllContacts();
        final index = contacts.indexWhere((c) => c['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('联系人不存在', 'NOT_FOUND');
        }

        final updatedContact = <String, dynamic>{
          ...contacts[index],
          ...params,
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };
        contacts[index] = updatedContact;

        await saveAllContacts(contacts);
        return PluginResult.success(updatedContact);
      } catch (e) {
        return PluginResult.failure('更新联系人失败: $e');
      }
    },

    // 删除联系人
    'delete': (data, params) async {
      try {
        final contacts = await readAllContacts();
        final initialLength = contacts.length;
        final filtered = contacts
            .where((c) => c['id'] != params['id'])
            .toList();

        if (filtered.length == initialLength) {
          return const PluginResult.failure('联系人不存在', 'NOT_FOUND');
        }

        await saveAllContacts(filtered);
        return PluginResult.success({'id': params['id']});
      } catch (e) {
        return PluginResult.failure('删除联系人失败: $e');
      }
    },

    // 搜索联系人
    'search': (data, params) async {
      try {
        var contacts = await readAllContacts();
        final keyword = params['keyword'];

        if (keyword != null && keyword.toString().isNotEmpty) {
          final kw = keyword.toString().toLowerCase();
          contacts = contacts
              .where(
                (c) =>
                    (c['name'] ?? '').toString().toLowerCase().contains(kw) ||
                    // 与原版一致：phone 不做小写化
                    (c['phone'] ?? '').toString().contains(kw) ||
                    (c['email'] ?? '').toString().toLowerCase().contains(kw),
              )
              .toList();
        }

        return PluginResult.success({
          'data': contacts,
          'total': contacts.length,
        });
      } catch (e) {
        return PluginResult.failure('搜索失败: $e');
      }
    },

    // 获取统计
    'getStats': (data, params) async {
      try {
        final contacts = await readAllContacts();

        return PluginResult.success({
          'totalContacts': contacts.length,
        });
      } catch (e) {
        return PluginResult.failure('获取统计失败: $e');
      }
    },
  };
}
