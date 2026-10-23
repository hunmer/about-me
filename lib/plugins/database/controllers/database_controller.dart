import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/item_event_args.dart';
import 'package:aboutme/plugins/database/models/database_model.dart';
import 'package:aboutme/plugins/database/models/record.dart';
import 'package:aboutme/plugins/database/services/database_service.dart';

class DatabaseController {
  final DatabaseService service;
  DatabaseModel? currentDatabase;

  DatabaseController(this.service);

  /// 业务命令结果校验：失败向上抛（损坏数据不再伪装为空列表）
  dynamic _result(Map<String, dynamic> res) {
    if (res['success'] != true) {
      throw Exception('数据库记录操作失败: ${res['error']}');
    }
    return res['data'];
  }

  Future<void> loadDatabase(String databaseId) async {
    final databases = await service.getAllDatabases();
    currentDatabase = databases.firstWhere((db) => db.id == databaseId);
  }

  Future<void> updateDatabase(DatabaseModel database) async {
    await service.updateDatabase(database);
    currentDatabase = database;
    _notifyDatabaseEvent('updated', database);
  }

  Future<void> createDatabase(DatabaseModel database) async {
    await service.createDatabase(database);
    _notifyDatabaseEvent('added', database);
  }

  Future<void> deleteDatabase() async {
    if (currentDatabase != null) {
      final db = currentDatabase!;
      await service.deleteDatabase(currentDatabase!.id);
      _notifyDatabaseEvent('deleted', db);
      currentDatabase = null;
    }
  }

  Future<List<Record>> getRecords(String databaseId) async {
    final result = _result(
      await AboutmeDataService.instance.get('database', 'getRecords', {
        'databaseId': databaseId,
      }),
    ) as Map<String, dynamic>;
    final list = result['data'] as List;
    return list
        .map((r) => Record.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> createRecord(Record record) async {
    _result(
      await AboutmeDataService.instance.call('database', 'createRecord', {
        ...record.toMap(),
        'databaseId': record.tableId,
      }),
    );
    _notifyRecordEvent('added', record);
  }

  Future<void> updateRecord(Record record) async {
    _result(
      await AboutmeDataService.instance.call('database', 'updateRecord', {
        ...record.toMap(),
        'databaseId': record.tableId,
      }),
    );
    _notifyRecordEvent('updated', record);
  }

  Future<void> deleteRecord(String recordId) async {
    if (currentDatabase == null) return;
    final records = await getRecords(currentDatabase!.id);
    final index = records.indexWhere((r) => r.id == recordId);
    if (index != -1) {
      final record = records[index];
      _result(
        await AboutmeDataService.instance.call('database', 'deleteRecord', {
          'databaseId': currentDatabase!.id,
          'id': recordId,
        }),
      );
      _notifyRecordEvent('deleted', record);
    }
  }

  // 触发数据库事件
  void _notifyDatabaseEvent(String action, DatabaseModel database) {
    final eventArgs = ItemEventArgs(
      eventName: 'database_$action',
      itemId: database.id,
      title: database.name,
      action: action,
    );
    EventManager.instance.broadcast('database_$action', eventArgs);
  }

  // 触发记录事件
  void _notifyRecordEvent(String action, Record record) {
    // 从字段中获取标题，优先使用 title/name 字段
    String title = '未命名';
    if (record.fields.containsKey('title')) {
      title = record.fields['title']?.toString() ?? '未命名';
    } else if (record.fields.containsKey('name')) {
      title = record.fields['name']?.toString() ?? '未命名';
    }

    final eventArgs = ItemEventArgs(
      eventName: 'database_record_$action',
      itemId: record.id,
      title: title,
      action: action,
    );
    EventManager.instance.broadcast('database_record_$action', eventArgs);
  }
}
