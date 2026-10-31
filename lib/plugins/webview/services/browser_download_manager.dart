import 'dart:async';

import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'dart:io' as io;

/// 浏览器下载记录状态
enum BrowserDownloadStatus { downloading, completed, failed, cancelled }

/// 单条浏览器下载记录
class BrowserDownloadRecord {
  final String id;
  final String url;
  final String fileName;
  final String savePath;
  final DateTime createdAt;
  BrowserDownloadStatus status;
  double progress; // 0~1，未知总大小时为 -1
  int receivedBytes;
  int? totalBytes;

  BrowserDownloadRecord({
    required this.id,
    required this.url,
    required this.fileName,
    required this.savePath,
    required this.createdAt,
    this.status = BrowserDownloadStatus.downloading,
    this.progress = 0,
    this.receivedBytes = 0,
    this.totalBytes,
  });

  bool get isActive => status == BrowserDownloadStatus.downloading;

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'fileName': fileName,
        'savePath': savePath,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'progress': progress,
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
      };

  static BrowserDownloadRecord? fromJson(Map<String, dynamic> json) {
    final status = BrowserDownloadStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => BrowserDownloadStatus.failed,
    );
    return BrowserDownloadRecord(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      savePath: json['savePath'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      status: status,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      receivedBytes: (json['receivedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt(),
    );
  }
}

/// 浏览器下载管理器：记录 WebView 触发的文件下载并提供进度查询
///
/// 会话级内存记录（不持久化），供下载管理页与底部栏 badge 共用。
class BrowserDownloadManager extends ChangeNotifier {
  static const _recordsKey = 'webview_download_records';

  final List<BrowserDownloadRecord> _records = [];
  final Map<String, http.Client> _clients = {};

  /// 从本地恢复历史下载记录（上次会话仍在下载中的记录视为失败，不恢复为进行中）
  Future<void> load() async {
    try {
      final raw = await AboutmeDataService.instance.getConfig(_recordsKey);
      if (raw is! List) return;
      _records
        ..clear()
        ..addAll(
          raw
              .whereType<Map>()
              .map((e) => BrowserDownloadRecord.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v))))
              .whereType<BrowserDownloadRecord>()
              .where((r) => r.id.isNotEmpty && r.fileName.isNotEmpty),
        );
      _records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      debugPrint('[BrowserDownloadManager] 恢复记录失败: $e');
    }
  }

  /// 持久化当前记录（失败仅打印日志，不影响下载流程）
  Future<void> _persist() async {
    try {
      await AboutmeDataService.instance.setConfig(
        _recordsKey,
        _records.map((r) => r.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('[BrowserDownloadManager] 保存记录失败: $e');
    }
  }

  List<BrowserDownloadRecord> get records => List.unmodifiable(_records);

  /// 正在下载的数量（用于 badge）
  int get activeCount =>
      _records.where((r) => r.status == BrowserDownloadStatus.downloading).length;

  BrowserDownloadRecord? getRecord(String id) =>
      _records.where((r) => r.id == id).firstOrNull;

  /// 创建下载记录并立即开始异步下载，返回该记录（进度经 notifyListeners 广播）
  BrowserDownloadRecord startDownload({
    required String url,
    required String fileName,
    required String savePath,
  }) {
    final record = BrowserDownloadRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: url,
      fileName: fileName,
      savePath: savePath,
      createdAt: DateTime.now(),
    );
    _records.insert(0, record);
    notifyListeners();
    unawaited(_persist());
    unawaited(_runDownload(record));
    return record;
  }

  Future<void> _runDownload(BrowserDownloadRecord record) async {
    final client = http.Client();
    _clients[record.id] = client;
    try {
      final response =
          await client.send(http.Request('GET', Uri.parse(record.url)));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      record.totalBytes = response.contentLength;
      record.progress =
          record.totalBytes != null && record.totalBytes! > 0 ? 0 : -1;
      notifyListeners();

      final sink = io.File(record.savePath).openWrite();
      try {
        await for (final chunk in response.stream) {
          if (record.status == BrowserDownloadStatus.cancelled) {
            break;
          }
          sink.add(chunk);
          record.receivedBytes += chunk.length;
          if (record.totalBytes != null && record.totalBytes! > 0) {
            record.progress = record.receivedBytes / record.totalBytes!;
          }
          notifyListeners();
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      if (record.status == BrowserDownloadStatus.cancelled) {
        // 取消后删除半成品文件
        try {
          final f = io.File(record.savePath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      } else {
        record.status = BrowserDownloadStatus.completed;
        record.progress = 1;
        notifyListeners();
        unawaited(_persist());
      }
    } catch (e) {
      debugPrint('[BrowserDownloadManager] 下载失败: $e');
      record.status = BrowserDownloadStatus.failed;
      notifyListeners();
      unawaited(_persist());
      // 清理失败残留
      try {
        final f = io.File(record.savePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    } finally {
      _clients.remove(record.id);
      client.close();
    }
  }

  /// 等待某条记录下载结束（完成/失败/取消或被移除）
  Future<void> waitForDone(String id) {
    final record = getRecord(id);
    if (record == null || !record.isActive) return Future.value();
    final completer = Completer<void>();
    void listener() {
      final r = getRecord(id);
      if (r == null || !r.isActive) {
        removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      }
    }
    addListener(listener);
    return completer.future;
  }

  /// 取消正在进行的下载
  void cancel(String id) {
    final record = getRecord(id);
    if (record == null || !record.isActive) return;
    record.status = BrowserDownloadStatus.cancelled;
    notifyListeners();
    unawaited(_persist());
  }

  /// 删除一条记录（进行中的先取消）
  void removeRecord(String id) {
    cancel(id);
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  /// 清空已结束的记录（完成/失败/取消）
  void clearFinished() {
    _records.removeWhere((r) => !r.isActive);
    notifyListeners();
  }
}
