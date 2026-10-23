import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/database/models/database_model.dart';
import 'package:aboutme/plugins/base_plugin.dart';

class DatabaseService {
  final BasePlugin plugin;
  DatabaseService(this.plugin);

  /// 业务命令结果校验：失败向上抛（不再静默降级为空数据）
  dynamic _result(Map<String, dynamic> res) {
    if (res['success'] != true) {
      throw Exception('数据库操作失败: ${res['error']}');
    }
    return res['data'];
  }

  /// 获取所有数据库
  Future<List<DatabaseModel>> getAllDatabases() async {
    final result = _result(
      await AboutmeDataService.instance.get('database', 'getList'),
    ) as Map<String, dynamic>;
    final list = result['data'] as List;
    return list
        .map((db) => DatabaseModel.fromMap(Map<String, dynamic>.from(db)))
        .toList();
  }

  /// 创建新数据库
  Future<void> createDatabase(DatabaseModel database) async {
    _result(
      await AboutmeDataService.instance.call(
        'database',
        'create',
        database.toMap(),
      ),
    );
  }

  /// 更新数据库
  Future<void> updateDatabase(DatabaseModel database) async {
    _result(
      await AboutmeDataService.instance.call(
        'database',
        'update',
        database.toMap(),
      ),
    );
  }

  /// 删除数据库（服务端级联删除该库全部记录）
  Future<void> deleteDatabase(String databaseId) async {
    _result(
      await AboutmeDataService.instance.call('database', 'delete', {
        'id': databaseId,
      }),
    );
  }

  /// 初始化默认数据（幂等：仅在无任何库时种入默认库）
  Future<void> initializeDefaultData() async {
    _result(await AboutmeDataService.instance.call('database', 'seedExamples'));
  }

  /// 获取数据库数量
  Future<int> getDatabaseCount() async {
    final result = _result(
      await AboutmeDataService.instance.get('database', 'getList'),
    ) as Map<String, dynamic>;
    return result['total'] as int? ?? (result['data'] as List).length;
  }

  /// 获取今日新增记录数（所有数据库）
  Future<int> getTodayRecordCount(dynamic controller) async {
    final databases = await getAllDatabases();
    int todayCount = 0;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    for (final db in databases) {
      final records = await controller.getRecords(db.id);
      final filteredRecords = records.where((record) {
        final recordDate = DateTime(
          record.createdAt.year,
          record.createdAt.month,
          record.createdAt.day,
        );
        return recordDate.isAtSameMomentAs(todayDate);
      }).toList();
      todayCount += filteredRecords.length as int;
    }

    return todayCount;
  }

  /// 获取总记录数（所有数据库）
  Future<int> getTotalRecordCount(dynamic controller) async {
    final databases = await getAllDatabases();
    int totalCount = 0;

    for (final db in databases) {
      final records = await controller.getRecords(db.id);
      totalCount += records.length as int;
    }

    return totalCount;
  }
}
