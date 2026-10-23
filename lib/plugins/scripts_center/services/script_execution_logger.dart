import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';

/// 单条脚本执行记录
class ScriptExecutionLogEntry {
  final String scriptId;
  final String scriptName;
  final bool success;

  /// 执行方式：手动 / 事件触发 / 脚本互调 / 自动运行
  final String trigger;
  final DateTime time;
  final int durationMs;

  /// 失败时的错误信息（已截断）
  final String? error;

  /// 成功时的返回值摘要（已截断，可能包含 base64 等大结果）
  final String? resultSummary;

  /// 脚本生成的图片本地路径（约定从 result.data.localPaths 提取）
  final List<String> images;

  const ScriptExecutionLogEntry({
    required this.scriptId,
    required this.scriptName,
    required this.success,
    required this.trigger,
    required this.time,
    required this.durationMs,
    this.error,
    this.resultSummary,
    this.images = const [],
  });

  factory ScriptExecutionLogEntry.fromJson(Map<String, dynamic> json) {
    return ScriptExecutionLogEntry(
      scriptId: json['scriptId'] as String? ?? '',
      scriptName: json['scriptName'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      trigger: json['trigger'] as String? ?? '手动',
      time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      durationMs: json['durationMs'] as int? ?? 0,
      error: json['error'] as String?,
      resultSummary: json['resultSummary'] as String?,
      images: (json['images'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scriptId': scriptId,
      'scriptName': scriptName,
      'success': success,
      'trigger': trigger,
      'time': time.toIso8601String(),
      'durationMs': durationMs,
      if (error != null) 'error': error,
      if (resultSummary != null) 'resultSummary': resultSummary,
      if (images.isNotEmpty) 'images': images,
    };
  }
}

/// 正在运行中的脚本
class RunningScript {
  final String scriptId;
  final String scriptName;
  final String trigger;
  final DateTime startTime;

  const RunningScript({
    required this.scriptId,
    required this.scriptName,
    required this.trigger,
    required this.startTime,
  });
}

/// 脚本执行记录器
///
/// 由 ScriptExecutor 在每次执行结束时调用 record，
/// 内存保存最近 [maxEntries] 条并异步经 SDK 命令持久化到
/// scripts_center 分区 execution_log.json（滚动上限由命令保证）
class ScriptExecutionLogger extends ChangeNotifier {
  static const int maxEntries = 200;

  final StorageManager storage;
  final List<ScriptExecutionLogEntry> _entries = [];
  bool _loaded = false;

  ScriptExecutionLogger(this.storage) {
    _load();
  }

  /// 全部记录（新的在前）
  List<ScriptExecutionLogEntry> get entries => List.unmodifiable(_entries);

  /// 是否已从磁盘加载完成
  bool get loaded => _loaded;

  /// 当前运行中的脚本（executor 开始时加入、结束时移除）
  final List<RunningScript> _running = [];

  List<RunningScript> get running => List.unmodifiable(_running);

  /// 标记脚本开始执行
  void startRun({
    required String scriptId,
    required String scriptName,
    required String trigger,
  }) {
    _running.add(RunningScript(
      scriptId: scriptId,
      scriptName: scriptName,
      trigger: trigger,
      startTime: DateTime.now(),
    ));
    notifyListeners();
  }

  /// 标记脚本执行结束（从运行中列表移除）
  void endRun(String scriptId) {
    _running.removeWhere((r) => r.scriptId == scriptId);
    notifyListeners();
  }

  /// 结果/错误摘要的最大长度
  static const int _summaryLimit = 500;

  static String? summarizeResult(dynamic result) {
    if (result == null) return null;
    // 深拷贝剔除大体量字段（如 ai_image 返回的 base64 图片数组），避免摘要全是截断的 base64
    dynamic sanitized = result;
    if (result is Map) {
      sanitized = Map<String, dynamic>.from(result);
      final data = sanitized['data'];
      if (data is Map) {
        final dataCopy = Map<String, dynamic>.from(data);
        final images = dataCopy['images'];
        if (images is List && images.isNotEmpty) {
          dataCopy['images'] = '<${images.length} 张图片，已省略>';
        }
        sanitized['data'] = dataCopy;
      }
    }
    String text;
    try {
      text = sanitized is String ? sanitized : jsonEncode(sanitized);
    } catch (_) {
      text = result.toString();
    }
    if (text.length > _summaryLimit) {
      return '${text.substring(0, _summaryLimit)}...(共${text.length}字符，已截断)';
    }
    return text;
  }

  static String? summarizeError(Object error) {
    final text = error.toString();
    if (text.length > _summaryLimit) {
      return '${text.substring(0, _summaryLimit)}...(已截断)';
    }
    return text;
  }

  /// 记录一次执行（异步持久化，不阻塞调用方；滚动上限由 SDK 命令保证）
  void record({
    required String scriptId,
    required String scriptName,
    required bool success,
    required String trigger,
    required int durationMs,
    Object? error,
    dynamic result,
    List<String> images = const [],
  }) {
    _entries.insert(
      0,
      ScriptExecutionLogEntry(
        scriptId: scriptId,
        scriptName: scriptName,
        success: success,
        trigger: trigger,
        time: DateTime.now(),
        durationMs: durationMs,
        error: error == null ? null : summarizeError(error),
        resultSummary: success ? summarizeResult(result) : null,
        images: images,
      ),
    );
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    notifyListeners();
    _save();
  }

  /// 清空全部记录
  Future<void> clear() async {
    _entries.clear();
    notifyListeners();
    try {
      final r = await AboutmeDataService.instance.call(
        'scripts_center',
        'clearExecLog',
        const {},
      );
      if (r['success'] != true) throw Exception(r['error']);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final r = await AboutmeDataService.instance.call(
        'scripts_center',
        'getExecLog',
        const {},
      );
      if (r['success'] == true && r['data'] is List) {
        _entries.addAll(
          (r['data'] as List)
              .whereType<Map>()
              .map(
                (e) =>
                    ScriptExecutionLogEntry.fromJson(Map<String, dynamic>.from(e)),
              ),
        );
      }
    } catch (e) {
      debugPrint('加载脚本执行记录失败: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    try {
      if (_entries.isEmpty) return;
      final r = await AboutmeDataService.instance.call(
        'scripts_center',
        'recordExecution',
        {'entry': _entries.first.toJson()},
      );
      if (r['success'] != true) throw Exception(r['error']);
    } catch (e) {
      debugPrint('保存脚本执行记录失败: $e');
    }
  }
}
