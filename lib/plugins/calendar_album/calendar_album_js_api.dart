// ignore_for_file: unintended_html_in_doc_comment

part of 'calendar_album_plugin.dart';

// 以下函数供 CalendarAlbumPlugin.defineJSAPI() 使用

// ==================== JS API 实现 ====================

/// 获取所有日记条目
/// 支持分页参数: offset, count
Future<String> _jsGetEntries(Map<String, dynamic> params) async {
  try {
    final result = await CalendarAlbumPlugin.instance.useCase.getEntries(params);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message, 'items': []});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '获取日记列表失败: $e', 'items': []});
  }
}

/// 获取指定日期的日记条目
/// @param params.dateStr - 日期字符串 (YYYY-MM-DD)
/// 返回: List<CalendarEntry> (JSON数组)
Future<String> _jsGetEntriesForDate(Map<String, dynamic> params) async {
  final String? dateStr = params['dateStr'];
  if (dateStr == null || dateStr.isEmpty) {
    return jsonEncode({'error': '缺少必需参数: dateStr'});
  }

  try {
    final result =
        await CalendarAlbumPlugin.instance.useCase.getEntriesByDate(params);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message, 'items': []});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({
      'error': '日期格式错误: $dateStr',
      'message': '请使用 YYYY-MM-DD 格式',
    });
  }
}

/// 添加日记条目
/// @param params.title - 标题
/// @param params.content - 内容
/// @param params.createdAt - 创建时间 (可选, 默认今天)
/// @param params.tags - 标签数组 (可选)
/// @param params.location - 位置 (可选)
/// @param params.mood - 心情 (可选)
/// @param params.weather - 天气 (可选)
/// @param params.imageUrls - 图片URL数组 (可选)
Future<String> _jsAddEntry(Map<String, dynamic> params) async {
  final String? title = params['title'];
  if (title == null || title.isEmpty) {
    return jsonEncode({'error': '缺少必需参数: title'});
  }
  if (params['content'] == null) {
    return jsonEncode({'error': '缺少必需参数: content'});
  }

  try {
    final result = await CalendarAlbumPlugin.instance.useCase.createEntry(params);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({
      'error': '添加日记失败',
      'message': e.toString(),
    });
  }
}

/// 更新日记条目
/// @param params.id - 日记ID
/// @param params.title - 新标题 (可选)
/// @param params.content - 新内容 (可选)
/// @param params.tags - 新标签数组 (可选)
/// @param params.location - 新位置 (可选)
/// @param params.mood - 新心情 (可选)
/// @param params.weather - 新天气 (可选)
/// @param params.imageUrls - 新图片URL数组 (可选)
Future<String> _jsUpdateEntry(Map<String, dynamic> params) async {
  final String? id = params['id'];
  if (id == null || id.isEmpty) {
    return jsonEncode({'error': '缺少必需参数: id'});
  }

  try {
    final result = await CalendarAlbumPlugin.instance.useCase.updateEntry(params);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({
      'error': '更新日记失败',
      'message': e.toString(),
    });
  }
}

/// 删除日记条目
/// @param params.id - 日记ID
Future<String> _jsDeleteEntry(Map<String, dynamic> params) async {
  final String? id = params['id'];
  if (id == null || id.isEmpty) {
    return jsonEncode({
      'success': false,
      'error': '缺少必需参数: id',
    });
  }

  try {
    final result = await CalendarAlbumPlugin.instance.useCase.deleteEntry(params);

    if (result.isFailure) {
      return jsonEncode({
        'success': false,
        'error': result.errorOrNull?.message,
      });
    }

    return jsonEncode({
      'success': true,
      'id': id,
    });
  } catch (e) {
    return jsonEncode({
      'success': false,
      'error': '删除日记失败',
      'message': e.toString(),
    });
  }
}

/// 根据ID获取日记条目
/// @param params.id - 日记ID
Future<String> _jsGetEntryById(Map<String, dynamic> params) async {
  final String? id = params['id'];
  if (id == null || id.isEmpty) {
    return jsonEncode({'error': '缺少必需参数: id'});
  }

  try {
    final result = await CalendarAlbumPlugin.instance.useCase.getEntryById(params);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    if (result.dataOrNull == null) {
      return jsonEncode({
        'error': '日记不存在',
        'id': id,
      });
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '获取日记失败: $e'});
  }
}

/// 获取所有标签
/// @param params - 参数对象（可选）
/// 返回: List<String> (JSON数组)
Future<String> _jsGetTags(Map<String, dynamic> params) async {
  try {
    final result = await CalendarAlbumPlugin.instance.useCase.getTags(params);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message, 'tags': []});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '获取标签列表失败: $e', 'tags': []});
  }
}

/// 根据单个标签获取日记
/// 支持分页参数: offset, count
Future<String> _jsGetEntriesByTag(Map<String, dynamic> params) async {
  final String? tag = params['tag'];
  if (tag == null || tag.isEmpty) {
    return jsonEncode({'error': '缺少必需参数: tag'});
  }

  try {
    final result =
        await CalendarAlbumPlugin.instance.useCase.getEntriesByTag(params);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message, 'items': []});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '根据标签获取日记失败: $e', 'items': []});
  }
}

/// 根据多个标签获取日记 (AND逻辑)
/// 支持分页参数: offset, count
Future<String> _jsGetEntriesByTags(Map<String, dynamic> params) async {
  final List<String> tags = params['tags'] != null ? List<String>.from(params['tags']) : [];
  if (tags.isEmpty) {
    return jsonEncode([]);
  }

  try {
    final result =
        await CalendarAlbumPlugin.instance.useCase.getEntriesByTags(params);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message, 'items': []});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '根据多标签获取日记失败: $e', 'items': []});
  }
}

/// 获取所有照片（包含完整日记数据）
/// 支持分页参数: offset, count
/// 支持 get_http_image 参数：是否将图片路径转换为 HTTP URL
Future<String> _jsGetPhotos(Map<String, dynamic> params) async {
  try {
    final getHttpImage = params['get_http_image'] == true;
    params.remove('get_http_image');

    final controller = CalendarAlbumPlugin.instance.calendarController;
    if (controller == null) {
      return jsonEncode({
        'success': false,
        'data': [],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'error': 'calendarController 未初始化'
      });
    }

    // 获取所有包含图片的日记数据
    final images = controller.getAllImages();
    var photos = <Map<String, dynamic>>[];

    for (final imageUrl in images) {
      // 根据图片URL获取对应的日记
      final entry = controller.getDiaryEntryForImage(imageUrl);
      if (entry != null) {
        final photoData = {
          'id': entry.id,
          'title': entry.title,
          'content': entry.content,
          'imageUrl': imageUrl,
          'createdAt': entry.createdAt.toIso8601String(),
          'updatedAt': entry.updatedAt.toIso8601String(),
          'tags': entry.tags,
          'location': entry.location,
          'mood': entry.mood,
          'weather': entry.weather,
        };
        photos.add(photoData);
      }
    }

    // 处理图片路径转换
    if (getHttpImage && photos.isNotEmpty) {
      photos = await LocalHttpServer.convertImagesWithAutoConfig(
        items: photos,
        pluginId: CalendarAlbumPlugin.instance.id,
        imageKey: 'imageUrl',
        storageManager: CalendarAlbumPlugin.instance.storage,
      );
    }

    // 应用分页
    final offset = params['offset'] as int? ?? 0;
    final count = params['count'] as int?;

    List<Map<String, dynamic>> paginatedPhotos;
    if (count != null && count > 0) {
      final end = (offset + count).clamp(0, photos.length);
      paginatedPhotos = photos.sublist(offset, end);
    } else {
      paginatedPhotos = photos.skip(offset).toList();
    }

    return jsonEncode({
      'success': true,
      'data': paginatedPhotos,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (e) {
    return jsonEncode({
      'success': false,
      'data': [],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'error': '获取照片列表失败: $e',
    });
  }
}

/// 根据日期范围获取照片（包含完整日记数据）
/// 支持分页参数: offset, count
/// 支持 get_http_image 参数：是否将图片路径转换为 HTTP URL
Future<String> _jsGetPhotosByDateRange(Map<String, dynamic> params) async {
  final String? startDateStr = params['startDate'];
  final String? endDateStr = params['endDate'];
  if (startDateStr == null || startDateStr.isEmpty) {
    return jsonEncode({'error': '缺少必需参数: startDate'});
  }
  if (endDateStr == null || endDateStr.isEmpty) {
    return jsonEncode({'error': '缺少必需参数: endDate'});
  }

  try {
    final getHttpImage = params['get_http_image'] == true;
    params.remove('get_http_image');

    final startDate = DateTime.parse(startDateStr);
    final endDate = DateTime.parse(endDateStr);

    final controller = CalendarAlbumPlugin.instance.calendarController;
    if (controller == null) {
      return jsonEncode({
        'success': false,
        'data': [],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'error': 'calendarController 未初始化'
      });
    }

    var photos = <Map<String, dynamic>>[];
    controller.entries.forEach((date, entries) {
      if ((date.isAfter(startDate) || date.isAtSameMomentAs(startDate)) &&
          (date.isBefore(endDate) || date.isAtSameMomentAs(endDate))) {
        for (var entry in entries) {
          final allImages = <String>[...entry.imageUrls, ...entry.extractImagesFromMarkdown()];
          for (var imageUrl in allImages) {
            photos.add({
              'id': entry.id,
              'title': entry.title,
              'content': entry.content,
              'imageUrl': imageUrl,
              'date': date.toIso8601String(),
              'createdAt': entry.createdAt.toIso8601String(),
              'updatedAt': entry.updatedAt.toIso8601String(),
              'tags': entry.tags,
              'location': entry.location,
              'mood': entry.mood,
              'weather': entry.weather,
            });
          }
        }
      }
    });

    // 处理图片路径转换
    if (getHttpImage && photos.isNotEmpty) {
      photos = await LocalHttpServer.convertImagesWithAutoConfig(
        items: photos,
        pluginId: CalendarAlbumPlugin.instance.id,
        imageKey: 'imageUrl',
        storageManager: CalendarAlbumPlugin.instance.storage,
      );
    }

    // 应用分页
    final offset = params['offset'] as int? ?? 0;
    final count = params['count'] as int?;

    List<Map<String, dynamic>> paginatedPhotos;
    if (count != null && count > 0) {
      final end = (offset + count).clamp(0, photos.length);
      paginatedPhotos = photos.sublist(offset, end);
    } else {
      paginatedPhotos = photos.skip(offset).toList();
    }

    return jsonEncode({
      'success': true,
      'data': paginatedPhotos,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (e) {
    return jsonEncode({
      'success': false,
      'data': [],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'error': '获取照片列表失败: $e',
    });
  }
}

/// 创建照片日记
/// @param params.caption - 照片说明/标题（必需）
/// @param params.imageUrl - 图片URL（必需）
/// @param params.date - 日期字符串（可选，格式 YYYY-MM-DD，默认今天）
/// @param params.tags - 标签数组（可选）
/// @param params.content - 额外内容描述（可选）
Future<String> _jsCreatePhoto(Map<String, dynamic> params) async {
  final String? caption = params['caption'];
  if (caption == null || caption.isEmpty) {
    return jsonEncode({'error': '缺少必需参数: caption'});
  }

  final String? imageUrl = params['imageUrl'];
  if (imageUrl == null || imageUrl.isEmpty) {
    return jsonEncode({'error': '缺少必需参数: imageUrl'});
  }

  try {
    // 解析日期或使用今天
    DateTime createdAt = DateTime.now();
    if (params['date'] != null) {
      createdAt = DateTime.parse(params['date'] + 'T00:00:00.000Z');
    }

    final result = await CalendarAlbumPlugin.instance.useCase.createEntry({
      'title': caption,
      'content': params['content'] ?? '',
      'createdAt': createdAt.toIso8601String(),
      'tags': params['tags'] ?? [],
      'imageUrls': [imageUrl],
    });

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    return jsonEncode(result.dataOrNull ?? {});
  } catch (e) {
    return jsonEncode({
      'error': '创建照片日记失败',
      'message': e.toString(),
    });
  }
}

/// 获取统计信息
/// @param params - 参数对象（无参数）
/// 返回: {todayEntries, last7DaysEntries, allEntries, tagsCount, photoCount}
Future<String> _jsGetStatistics(Map<String, dynamic> params) async {
  try {
    final result = await CalendarAlbumPlugin.instance.useCase.getStats(params);

    if (result.isFailure) {
      return jsonEncode({
        'error': result.errorOrNull?.message,
        'todayEntries': 0,
        'last7DaysEntries': 0,
        'allEntries': 0,
        'tagsCount': 0,
        'photoCount': 0,
      });
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({
      'error': '获取统计信息失败: $e',
      'todayEntries': 0,
      'last7DaysEntries': 0,
      'allEntries': 0,
      'tagsCount': 0,
      'photoCount': 0,
    });
  }
}

// ==================== 日记查找方法 ====================

/// 通用日记查找
/// @param params.field 要匹配的字段名 (必需)
/// @param params.value 要匹配的值 (必需)
/// @param params.findAll 是否返回所有匹配项 (可选，默认 false)
/// @param params.offset 分页起始位置 (可选，仅 findAll=true 时有效)
/// @param params.count 分页返回数量 (可选，仅 findAll=true 时有效，默认 100)
Future<String> _jsFindEntryBy(Map<String, dynamic> params) async {
  final String? field = params['field'];
  if (field == null || field.isEmpty) {
    return jsonEncode({'error': '缺少必需参数: field'});
  }

  final dynamic value = params['value'];
  if (value == null) {
    return jsonEncode({'error': '缺少必需参数: value'});
  }

  try {
    // 使用 searchEntries 方法进行查找
    final searchParams = Map<String, dynamic>.from(params);
    final result = await CalendarAlbumPlugin.instance.useCase.searchEntries(searchParams);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message, 'items': []});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '查找日记失败: $e', 'items': []});
  }
}

/// 根据ID查找日记
/// @param params.id 日记ID (必需)
Future<String> _jsFindEntryById(Map<String, dynamic> params) async {
  final String? id = params['id'];
  if (id == null || id.isEmpty) {
    return jsonEncode({'error': '缺少必需参数: id'});
  }

  try {
    final result = await CalendarAlbumPlugin.instance.useCase.getEntryById(params);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    if (result.dataOrNull == null) {
      return jsonEncode(null);
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '查找日记失败: $e'});
  }
}

/// 根据标题查找日记
/// @param params.title 日记标题 (必需)
/// @param params.fuzzy 是否模糊匹配 (可选，默认 false)
/// @param params.findAll 是否返回所有匹配项 (可选，默认 false)
/// @param params.offset 分页偏移量 (可选，与 count 配合使用)
/// @param params.count 分页数量 (可选，默认 100)
Future<String> _jsFindEntryByTitle(Map<String, dynamic> params) async {
  final String? title = params['title'];
  if (title == null || title.isEmpty) {
    return jsonEncode({'error': '缺少必需参数: title'});
  }

  try {
    // 使用 searchEntries 方法进行查找
    final searchParams = Map<String, dynamic>.from(params);
    final result = await CalendarAlbumPlugin.instance.useCase.searchEntries(searchParams);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message, 'items': []});
    }

    // 如果不查找所有项，只返回第一个结果
    final bool findAll = params['findAll'] ?? false;
    if (!findAll && result.dataOrNull is List) {
      final List<dynamic> entries = result.dataOrNull;
      if (entries.isEmpty) {
        return jsonEncode(null);
      }
      return jsonEncode(entries.first);
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '查找日记失败: $e', 'items': []});
  }
}
