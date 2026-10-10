enum StorageErrorKind {
  unauthorized,
  notFound,
  conflict,
  offline,
  server,
  invalidData,
  invalidRequest,
}

class StorageException implements Exception {
  const StorageException(this.kind, this.message, {this.statusCode});

  final StorageErrorKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'StorageException($kind${statusCode == null ? '' : ', HTTP $statusCode'}): $message';
}

/// 存储路径非法（穿越根目录、绝对路径等），HTTP 层映射为 400。
class StoragePathException implements Exception {
  const StoragePathException([this.message = 'INVALID_STORAGE_PATH']);

  final String message;

  @override
  String toString() => 'StoragePathException: $message';
}
