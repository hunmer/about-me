import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/repositories/notes/notes_repository.dart';
import 'package:shared_models/usecases/notes/notes_usecase.dart';
import 'package:shared_models/utils/pagination.dart';
import 'package:shared_models/utils/result.dart';

class _Repository extends Fake implements INotesRepository {
  PaginationParams? pagination;
  NoteQuery? query;

  @override
  Future<Result<List<NoteDto>>> getNotes({
    String? folderId,
    PaginationParams? pagination,
  }) async {
    this.pagination = pagination;
    return Result.success([]);
  }

  @override
  Future<Result<List<NoteDto>>> searchNotes(NoteQuery query) async {
    this.query = query;
    pagination = query.pagination;
    return Result.success([]);
  }

  @override
  Future<Result<List<FolderDto>>> getFolders({
    String? parentId,
    PaginationParams? pagination,
  }) async {
    this.pagination = pagination;
    return Result.success([]);
  }

  @override
  Future<Result<List<NoteDto>>> getFolderNotes(
    String folderId, {
    PaginationParams? pagination,
  }) async {
    this.pagination = pagination;
    return Result.success([]);
  }
}

void main() {
  for (final method in [
    'getNotes',
    'searchNotes',
    'getFolders',
    'getFolderNotes',
  ]) {
    for (final paginationJson in [
      '{}',
      '{"offset":null,"count":null}',
      '{"offset":0,"count":100}',
      '{"offset":0.0,"count":100.0}',
      '{"offset":2.0,"count":3.0}',
    ]) {
      test('$method accepts pagination $paginationJson', () async {
        final repository = _Repository();
        final useCase = NotesUseCase(repository);
        final params = <String, dynamic>{
          ...jsonDecode(paginationJson) as Map<String, dynamic>,
          'id': 'root',
          'keyword': '',
          // notes JS API 将 tags 数组转换为逗号分隔字符串。
          'tags': '工作',
        };
        final result = await switch (method) {
          'getNotes' => useCase.getNotes(params),
          'searchNotes' => useCase.searchNotes(params),
          'getFolders' => useCase.getFolders(params),
          _ => useCase.getFolderNotes(params),
        };
        expect(result.isSuccess, isTrue, reason: result.errorOrNull?.message);
        if (params['offset'] == null && params['count'] == null) {
          expect(repository.pagination, isNull);
        } else {
          expect(repository.pagination!.offset, params['offset']);
          expect(repository.pagination!.count, params['count']);
        }
        if (method == 'searchNotes') {
          expect(repository.query!.tags, ['工作']);
          expect(repository.query!.keyword, '');
        }
      });
    }
  }
}
