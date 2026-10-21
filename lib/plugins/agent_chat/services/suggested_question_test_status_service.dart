/// 预设问题最近一次测试状态（用于选择面板的错误标记）
class SuggestedQuestionTestStatus {
  const SuggestedQuestionTestStatus({
    required this.lastTestAt,
    required this.hasError,
  });

  /// 最近一次测试时间
  final DateTime lastTestAt;

  /// 最近一次测试是否失败；之后通过测试即清除标记（保留时间）
  final bool hasError;
}

/// 从 test_runs 报告 JSON（Map 列表）中提取指定题目的最新测试状态。
SuggestedQuestionTestStatus? latestSuggestedQuestionTestStatus(
  Iterable<Object?> reports, {
  required String category,
  required String question,
}) {
  final records = <(DateTime, bool?)>[];
  for (final report in reports.whereType<Map>()) {
    final results = report['results'];
    if (results is! List) continue;
    final reportFinishedAt = _parseDate(report['finishedAt']);
    for (final rawResult in results.whereType<Map>()) {
      if (rawResult['category'] != category ||
          rawResult['question'] != question) {
        continue;
      }
      final testedAt =
          _parseDate(rawResult['finishedAt']) ??
          _parseDate(rawResult['startedAt']) ??
          reportFinishedAt;
      if (testedAt == null) continue;
      final toolErrors = rawResult['toolErrors'];
      final hasToolError = toolErrors is List && toolErrors.isNotEmpty;
      final hasRequestError = rawResult['requestError'] != null;
      final hasPersistenceError = rawResult['persistenceError'] != null;
      final hasError =
          rawResult['status'] == 'failed' ||
          hasToolError ||
          hasRequestError ||
          hasPersistenceError;
      final status = rawResult['status'];
      records.add((
        testedAt,
        status == 'failed' || hasError
            ? true
            : status == 'passed'
            ? false
            : null,
      ));
    }
  }
  if (records.isEmpty) return null;
  records.sort((a, b) => a.$1.compareTo(b.$1));
  final latest = records.last;
  var hasError = false;
  for (final record in records) {
    if (record.$2 != null) hasError = record.$2!;
  }
  return SuggestedQuestionTestStatus(lastTestAt: latest.$1, hasError: hasError);
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
