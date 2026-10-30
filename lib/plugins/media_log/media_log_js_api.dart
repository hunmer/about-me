part of 'media_log_plugin.dart';

// ==================== JS API 实现 ====================
/// 获取全部媒体记录
/// 可选参数: kind（'reading' / 'watching'）
/// 返回: JSON 数组（含点评）
Future<String> _jsGetMediaItems(Map<String, dynamic> params) async {
  try {
    final kind = params['kind'] as String?;
    final items = MediaLogPlugin.instance.items
        .where((item) => kind == null || item.kind.name == kind)
        .map((item) => item.toJson())
        .toList();
    return jsonEncode(items);
  } catch (e) {
    return jsonEncode({'error': '获取媒体记录失败: ${e.toString()}'});
  }
}

/// 获取指定条目（含点评）
/// 参数: id
Future<String> _jsGetMediaItem(Map<String, dynamic> params) async {
  try {
    final item = MediaLogPlugin.instance.getItem(params['id'] as String? ?? '');
    if (item == null) {
      return jsonEncode({'error': '条目不存在'});
    }
    return jsonEncode(item.toJson());
  } catch (e) {
    return jsonEncode({'error': '获取媒体记录失败: ${e.toString()}'});
  }
}

/// 新建媒体记录
/// 参数: kind, title, author?, rating?, overview?, tags?, finishedAt?(ISO8601), cover?(CoverStyle 名), coverImage?
Future<String> _jsCreateMediaItem(Map<String, dynamic> params) async {
  try {
    final title = params['title'] as String?;
    if (title == null || title.trim().isEmpty) {
      return jsonEncode({'error': 'title 不能为空'});
    }
    final item = MediaItem(
      id: MediaLogPlugin.newId(),
      kind: params['kind'] == 'watching' ? MediaKind.watching : MediaKind.reading,
      title: title.trim(),
      author: params['author'] as String?,
      coverImage: params['coverImage'] as String?,
      cover: CoverStyle.values.firstWhere(
        (s) => s.name == params['cover'],
        orElse: () => CoverStyle.sheep,
      ),
      rating: (params['rating'] as num?)?.toDouble(),
      overview: params['overview'] as String?,
      tags: (params['tags'] as List?)?.cast<String>() ?? const [],
      finishedAt: tryParseIsoDateTime(params['finishedAt'] as String? ?? ''),
      createdAt: DateTime.now(),
      reviews: const [],
    );
    await MediaLogPlugin.instance.saveItem(item);
    return jsonEncode(item.toJson());
  } catch (e) {
    return jsonEncode({'error': '创建媒体记录失败: ${e.toString()}'});
  }
}

/// 更新媒体记录（按 id 合并传入字段）
/// 参数: id, 以及可选的 kind/title/author/rating/overview/tags/finishedAt/cover/coverImage
Future<String> _jsUpdateMediaItem(Map<String, dynamic> params) async {
  try {
    final item = MediaLogPlugin.instance.getItem(params['id'] as String? ?? '');
    if (item == null) {
      return jsonEncode({'error': '条目不存在'});
    }
    final updated = item.copyWith(
      kind: params['kind'] == 'watching'
          ? MediaKind.watching
          : params['kind'] == 'reading' ? MediaKind.reading : null,
      title: params['title'] as String?,
      author: params['author'] as String?,
      coverImage: params['coverImage'] as String?,
      rating: (params['rating'] as num?)?.toDouble(),
      overview: params['overview'] as String?,
      tags: (params['tags'] as List?)?.cast<String>(),
      finishedAt: tryParseIsoDateTime(params['finishedAt'] as String? ?? ''),
    );
    await MediaLogPlugin.instance.saveItem(updated);
    return jsonEncode(updated.toJson());
  } catch (e) {
    return jsonEncode({'error': '更新媒体记录失败: ${e.toString()}'});
  }
}

/// 删除媒体记录
/// 参数: id
Future<String> _jsDeleteMediaItem(Map<String, dynamic> params) async {
  try {
    await MediaLogPlugin.instance.deleteItem(params['id'] as String? ?? '');
    return jsonEncode({'success': true});
  } catch (e) {
    return jsonEncode({'success': false, 'error': '删除媒体记录失败: ${e.toString()}'});
  }
}

/// 新增点评（多条带时间戳）
/// 参数: itemId, text, rating?, timestamp?(ISO8601，默认当前时间), author?, avatar?
Future<String> _jsAddMediaReview(Map<String, dynamic> params) async {
  try {
    final itemId = params['itemId'] as String? ?? '';
    final item = MediaLogPlugin.instance.getItem(itemId);
    if (item == null) {
      return jsonEncode({'error': '条目不存在'});
    }
    final text = params['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      return jsonEncode({'error': 'text 不能为空'});
    }
    final review = MediaReview(
      id: MediaLogPlugin.newId(),
      text: text.trim(),
      timestamp:
          tryParseIsoDateTime(params['timestamp'] as String? ?? '') ??
          DateTime.now(),
      rating: (params['rating'] as num?)?.toDouble(),
      author: params['author'] as String?,
      avatar: params['avatar'] as String?,
    );
    await MediaLogPlugin.instance.saveReview(itemId, review);
    return jsonEncode(review.toJson());
  } catch (e) {
    return jsonEncode({'error': '新增点评失败: ${e.toString()}'});
  }
}

/// 删除点评
/// 参数: itemId, reviewId
Future<String> _jsDeleteMediaReview(Map<String, dynamic> params) async {
  try {
    await MediaLogPlugin.instance.deleteReview(
      params['itemId'] as String? ?? '',
      params['reviewId'] as String? ?? '',
    );
    return jsonEncode({'success': true});
  } catch (e) {
    return jsonEncode({'success': false, 'error': '删除点评失败: ${e.toString()}'});
  }
}
