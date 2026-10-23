/// Checkin 插件 - 客户端 Repository 实现
///
/// 全部读写经统一数据 SDK（data.call/query/get），与 REST/MCP 共用同一套处理器
library;

import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:shared_models/shared_models.dart';

/// 客户端 Checkin Repository 实现
class ClientCheckinRepository extends ICheckinRepository {
  final dynamic storage; // 兼容旧构造签名保留，不再直接使用
  final String pluginId;

  ClientCheckinRepository({required this.storage, this.pluginId = 'checkin'});

  // ============ 内部辅助方法 ============

  Future<Map<String, dynamic>> _command(
    String action,
    Map<String, dynamic> params,
  ) async {
    final response = await AboutmeDataService.instance.data.call(
      pluginId,
      action,
      params,
    );
    if (response['success'] != true) throw QueryFailure(response);
    return response;
  }

  Future<Result<T>> _result<T>(Future<T> Function() run) async {
    try {
      return Result.success(await run());
    } on QueryFailure catch (e) {
      return Result.failure(
        '${e.result['error'] ?? e}',
        code: e.result['code'] as String? ?? ErrorCodes.serverError,
      );
    } catch (e) {
      return Result.failure('$e', code: ErrorCodes.serverError);
    }
  }

  Map<String, dynamic> _page(PaginationParams? p) => {
    if (p?.offset != null) 'offset': p!.offset,
    if (p?.count != null) 'count': p!.count,
  };

  CheckinItemDto _item(dynamic raw) =>
      CheckinItemDto.fromJson(Map<String, dynamic>.from(raw as Map));

  String _dateKey(DateTime time) =>
      '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';

  Future<CheckinItemDto> _getItem(String id) async {
    final response = await AboutmeDataService.instance.data.get(
      pluginId,
      'getById',
      {'id': id},
    );
    if (response['success'] != true) throw QueryFailure(response);
    return _item(response['data']);
  }

  // ============ Repository 实现 ============

  @override
  Future<Result<List<CheckinItemDto>>> getItems({
    PaginationParams? pagination,
  }) =>
      _result(() async {
        final response = await AboutmeDataService.instance.data.query(
          pluginId,
          'getList',
          _page(pagination),
        );
        if (response['success'] != true) throw QueryFailure(response);
        return ((response['data'] as Map)['data'] as List)
            .map(_item)
            .toList();
      });

  @override
  Future<Result<CheckinItemDto?>> getItemById(String id) => _result(() async {
    final response = await AboutmeDataService.instance.data.get(
      pluginId,
      'getById',
      {'id': id},
    );
    if (response['code'] == 'NOT_FOUND') return null;
    if (response['success'] != true) throw QueryFailure(response);
    return _item(response['data']);
  });

  @override
  Future<Result<CheckinItemDto>> createItem(CheckinItemDto item) =>
      _result(() async => _item((await _command('create', item.toJson()))['data']));

  @override
  Future<Result<CheckinItemDto>> updateItem(String id, CheckinItemDto item) =>
      _result(
        () async => _item(
          (await _command('update', {...item.toJson(), 'id': id}))['data'],
        ),
      );

  @override
  Future<Result<bool>> deleteItem(String id) => _result(() async {
    await _command('delete', {'id': id});
    return true;
  });

  @override
  Future<Result<CheckinItemDto>> addCheckinRecord(
    String itemId,
    CheckinRecordDto record,
  ) =>
      _result(() async {
        await _command('addRecord', {
          'id': itemId,
          'date': _dateKey(record.checkinTime),
          'startTime': record.startTime.toIso8601String(),
          'endTime': record.endTime.toIso8601String(),
          'checkinTime': record.checkinTime.toIso8601String(),
          if (record.note != null) 'note': record.note,
        });
        return _getItem(itemId);
      });

  @override
  Future<Result<CheckinItemDto>> deleteCheckinRecord(
    String itemId,
    String date,
    int recordIndex,
  ) =>
      _result(
        () async => _item(
          (await _command('deleteRecord', {
            'id': itemId,
            'date': date,
            'recordIndex': recordIndex,
          }))['data'],
        ),
      );

  @override
  Future<Result<CheckinStatsDto>> getStats() => _result(() async {
    final response = await AboutmeDataService.instance.data.query(
      pluginId,
      'getStats',
    );
    if (response['success'] != true) throw QueryFailure(response);
    return CheckinStatsDto.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  });
}
