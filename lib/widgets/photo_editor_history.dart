import 'dart:io';

import 'package:aboutme/core/data/aboutme_data_service.dart';

/// 照片编辑器打开历史：记录每次成功打开进编辑器的图片
/// （url + 名称 + 时间戳，同 url 去重置顶，上限 50 条），
/// 主界面据此展示"最近打开"供继续编辑。
class PhotoEditorHistory {
  PhotoEditorHistory._();

  static const _path = 'photo_editor/history.json';
  static const _limit = 50;

  /// 读取历史（新→旧），过滤图片已不存在的记录
  static Future<List<Map<String, dynamic>>> list() async {
    try {
      final data = await AboutmeDataService.instance.readPath(_path);
      final entries = data is List
          ? data.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      // 校验存在性，失效记录剔除（不回写，下次保存时自然清理）
      final valid = <Map<String, dynamic>>[];
      for (final entry in entries) {
        final url = entry['url'] as String?;
        if (url == null || url.isEmpty) continue;
        if (_isHttp(url) || url.startsWith('assets/')) {
          valid.add(entry);
          continue;
        }
        // 本地绝对路径（file_picker 选择）走文件系统，其余走存储后端
        final isLocalAbs =
            url.startsWith('/') || RegExp(r'^[A-Za-z]:[/\\]').hasMatch(url);
        final exists = isLocalAbs
            ? File(url).existsSync()
            : await AboutmeDataService.instance.existsPath(url);
        if (exists) valid.add(entry);
      }
      return valid;
    } catch (_) {
      return [];
    }
  }

  /// 记录一次打开（同 url 移到最前并刷新时间）
  static Future<void> record(String url, {String? name}) async {
    if (url.isEmpty) return;
    try {
      final history = (await list())
        ..removeWhere((e) => e['url'] == url);
      history.insert(0, {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'url': url,
        'name': name ?? _defaultName(url),
      });
      await AboutmeDataService.instance.writePath(
        _path,
        history.take(_limit).toList(),
      );
    } catch (_) {
      /* 历史记录失败不影响编辑主流程 */
    }
  }

  /// 删除单条
  static Future<void> remove(Map<String, dynamic> entry) async {
    try {
      final history = await list()
        ..removeWhere((e) => e['url'] == entry['url']);
      await AboutmeDataService.instance.writePath(_path, history);
    } catch (_) {}
  }

  /// 清空
  static Future<void> clear() async {
    try {
      await AboutmeDataService.instance.writePath(_path, []);
    } catch (_) {}
  }

  static String _defaultName(String url) {
    final clean = url.split('?').first;
    final segments = clean.split(RegExp(r'[/\\]'));
    return segments.isEmpty || segments.last.isEmpty
        ? clean
        : segments.last;
  }

  static bool _isHttp(String url) =>
      url.startsWith('http://') || url.startsWith('https://');
}
