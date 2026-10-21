import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/repositories/nodes/nodes_repository.dart';
import 'package:shared_models/usecases/nodes/nodes_usecase.dart';
import 'package:shared_models/utils/result.dart';

class _Repository extends Fake implements INodesRepository {
  NodeDto? created;
  NodeDto? updated;
  NodeStatus existingStatus = NodeStatus.todo;

  @override
  Future<Result<NodeDto?>> getNodeById(String id) async {
    return Result.success(
      NodeDto(
        id: id,
        title: '现有节点',
        createdAt: DateTime(2025),
        status: existingStatus,
      ),
    );
  }

  @override
  Future<Result<NodeDto>> createNode(NodeDto node) async {
    created = node;
    return Result.success(node);
  }

  @override
  Future<Result<NodeDto>> updateNode(String id, NodeDto node) async {
    updated = node;
    return Result.success(node);
  }
}

void main() {
  // 工具调用可能把 status 传成字符串（如 'inProgress'）或 double，
  // UseCase 需容错解析而不是抛类型转换错误。
  for (final statusValue in [1, 1.0, '1', 'inProgress', 'doing', '进行中']) {
    test('createNode 接受 status=$statusValue', () async {
      final repository = _Repository();
      final useCase = NodesUseCase(repository);

      final result = await useCase.createNode({
        'title': '新节点',
        'status': statusValue,
      });

      expect(result.isSuccess, isTrue, reason: result.errorOrNull?.message);
      expect(repository.created!.status, NodeStatus.doing);
    });
  }

  test('createNode 未提供 status 时默认 todo', () async {
    final repository = _Repository();
    final useCase = NodesUseCase(repository);

    final result = await useCase.createNode({'title': '新节点'});

    expect(result.isSuccess, isTrue, reason: result.errorOrNull?.message);
    expect(repository.created!.status, NodeStatus.todo);
  });

  test('createNode 无效 status 返回明确错误而非类型异常', () async {
    final useCase = NodesUseCase(_Repository());

    final result = await useCase.createNode({
      'title': '新节点',
      'status': 'blocked',
    });

    expect(result.isFailure, isTrue);
    expect(result.errorOrNull!.code, 'INVALID_PARAMS');
    expect(result.errorOrNull!.message, contains('status'));
  });

  test('updateNode 接受字符串 status 并保留未提供时的原状态', () async {
    final repository = _Repository()..existingStatus = NodeStatus.done;
    final useCase = NodesUseCase(repository);

    final updated = await useCase.updateNode({
      'id': 'node-1',
      'status': 'inProgress',
    });
    expect(updated.isSuccess, isTrue, reason: updated.errorOrNull?.message);
    expect(repository.updated!.status, NodeStatus.doing);

    final untouched = await useCase.updateNode({'id': 'node-1'});
    expect(untouched.isSuccess, isTrue, reason: untouched.errorOrNull?.message);
    expect(repository.updated!.status, NodeStatus.done);
  });

  test('createNode status 越界数字返回明确错误而非 RangeError', () async {
    final useCase = NodesUseCase(_Repository());

    final result = await useCase.createNode({
      'title': '新节点',
      'status': 9,
    });

    expect(result.isFailure, isTrue);
    expect(result.errorOrNull!.message, contains('status'));
  });
}
