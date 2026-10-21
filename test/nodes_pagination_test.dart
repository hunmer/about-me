import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/repositories/nodes/nodes_repository.dart';
import 'package:shared_models/usecases/nodes/nodes_usecase.dart';
import 'package:shared_models/utils/pagination.dart';
import 'package:shared_models/utils/result.dart';

class _Repository extends Fake implements INodesRepository {
  PaginationParams? pagination;

  @override
  Future<Result<List<NotebookDto>>> getNotebooks({
    PaginationParams? pagination,
  }) async {
    this.pagination = pagination;
    return Result.success([
      const NotebookDto(id: 'nb-1', title: '工作'),
      const NotebookDto(id: 'nb-2', title: '生活'),
    ]);
  }

  @override
  Future<Result<List<NodeDto>>> getNodes(
    String notebookId, {
    PaginationParams? pagination,
  }) async {
    this.pagination = pagination;
    return Result.success([
      NodeDto(id: 'node-1', title: '节点1', createdAt: DateTime(2025)),
      NodeDto(id: 'node-2', title: '节点2', createdAt: DateTime(2025)),
    ]);
  }
}

void main() {
  // 带 offset/count 时 UseCase 返回分页 Map（键为 data），
  // nodes_js_api 的 getNotebooks/getNodes 按该结构提取列表。
  test('getNotebooks 无分页参数时返回数组', () async {
    final repository = _Repository();
    final useCase = NodesUseCase(repository);

    final result = await useCase.getNotebooks({});

    expect(result.isSuccess, isTrue, reason: result.errorOrNull?.message);
    expect(result.dataOrNull, isA<List<dynamic>>());
    expect(repository.pagination, isNull);
  });

  for (final params in [
    {'offset': 0, 'count': 50},
    {'offset': 0.0, 'count': 50.0},
  ]) {
    test('getNotebooks 分页 $params 返回 {data,total,...} 结构', () async {
      final repository = _Repository();
      final useCase = NodesUseCase(repository);

      final result = await useCase.getNotebooks(params);

      expect(result.isSuccess, isTrue, reason: result.errorOrNull?.message);
      final map = result.dataOrNull! as Map<String, dynamic>;
      expect(map.containsKey('data'), isTrue,
          reason: '分页结果必须包含 data 键，nodes_js_api 依赖它提取列表');
      expect(map['data'], isA<List<dynamic>>());
      expect(map['total'], 2);
      expect(map['offset'], 0);
      expect(map['count'], 2);
      expect(map['hasMore'], isFalse);
      expect(repository.pagination!.offset, 0);
      expect(repository.pagination!.count, 50);
    });

    test('getNodes 分页 $params 返回 {data,total,...} 结构', () async {
      final repository = _Repository();
      final useCase = NodesUseCase(repository);

      final result = await useCase.getNodes({'notebookId': 'nb-1', ...params});

      expect(result.isSuccess, isTrue, reason: result.errorOrNull?.message);
      final map = result.dataOrNull! as Map<String, dynamic>;
      expect(map.containsKey('data'), isTrue);
      expect(map['data'], isA<List<dynamic>>());
      expect(repository.pagination!.count, 50);
    });
  }
}
