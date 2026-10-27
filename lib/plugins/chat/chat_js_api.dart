part of 'chat_plugin.dart';

// ==================== JS API 定义 ====================

/// 构建 chat 插件的 JS API 表（由 ChatPlugin.defineJSAPI 调用）
Map<String, Function> buildChatJSAPI() {
  return {
    // 频道相关
    'getChannels': _jsGetChannels,
    'createChannel': _jsCreateChannel,
    'deleteChannel': _jsDeleteChannel,

    // 消息相关
    'sendMessage': _jsSendMessage,
    'getMessages': _jsGetMessages,
    'getMessagesByDate': _jsGetMessagesByDate, // 按日期范围获取所有消息
    'deleteMessage': _jsDeleteMessage,
    'selectMessages': _jsSelectMessages, // 弹出多选消息选择器（chat.messages）

    // 用户相关
    'getCurrentUser': _jsGetCurrentUser,
    'getAIUser': _jsGetAIUser,

    // 频道查找方法
    'findChannelBy': _jsFindChannelBy,
    'findChannelById': _jsFindChannelById,
    'findChannelByTitle': _jsFindChannelByTitle,

    // 消息查找方法
    'findMessageBy': _jsFindMessageBy,
    'findMessageById': _jsFindMessageById,
    'findMessageByContent': _jsFindMessageByContent,

    // 贴图相关
    'importStickerCollection': _jsImportStickerCollection,
  };
}

// ==================== JS API 实现 ====================

/// 获取所有频道
/// 支持分页参数: offset, count
Future<String> _jsGetChannels(Map<String, dynamic> params) async {
  final result = await ChatPlugin.instance.chatUseCase.getChannels(params);
  return result.toJsonString();
}

/// 创建频道
Future<String> _jsCreateChannel(Map<String, dynamic> params) async {
  return jsonEncode(
    await AboutmeDataService.instance.call('chat', 'create', params),
  );
}

/// 删除频道
Future<String> _jsDeleteChannel(Map<String, dynamic> params) async {
  final result = await ChatPlugin.instance.chatUseCase.deleteChannel(params);
  return result.toJsonString();
}

/// 发送消息
Future<String> _jsSendMessage(Map<String, dynamic> params) async {
  return jsonEncode(
    await AboutmeDataService.instance.call('chat', 'sendMessage', {
      ...params,
      if (!params.containsKey('user'))
        'user': ChatPlugin.instance.userService.currentUser.toJson(),
    }),
  );
}

/// 获取频道消息
/// 支持分页参数: offset, count (或旧版 limit)
Future<String> _jsGetMessages(Map<String, dynamic> params) async {
  final result = await ChatPlugin.instance.chatUseCase.getMessages(params);
  return result.toJsonString();
}

/// 删除消息
Future<String> _jsDeleteMessage(Map<String, dynamic> params) async {
  final result = await ChatPlugin.instance.chatUseCase.deleteMessage(params);
  return result.toJsonString();
}

/// 获取当前用户
Future<String> _jsGetCurrentUser(Map<String, dynamic> params) async {
  final result = await ChatPlugin.instance.chatUseCase.getCurrentUser(params);
  return result.toJsonString();
}

/// 获取 AI 用户
Future<String> _jsGetAIUser(Map<String, dynamic> params) async {
  final result = await ChatPlugin.instance.chatUseCase.getAIUser();
  return result.toJsonString();
}

// ==================== 频道查找方法 ====================
/// 通用频道查找
/// @param params.field 要匹配的字段名 (必需)
/// @param params.value 要匹配的值 (必需)
/// @param params.findAll 是否返回所有匹配项 (可选，默认 false)
/// @param params.offset 分页起始位置 (可选，仅 findAll=true 时有效)
/// @param params.count 分页返回数量 (可选，仅 findAll=true 时有效，默认 100)
Future<String> _jsFindChannelBy(Map<String, dynamic> params) async {
  final result = await ChatPlugin.instance.chatUseCase.findChannelBy(params);
  return result.toJsonString();
}

/// 根据ID查找频道
/// @param params.id 频道ID (必需)
Future<String> _jsFindChannelById(Map<String, dynamic> params) async {
  final result = await ChatPlugin.instance.chatUseCase.findChannelById(params);
  return result.toJsonString();
}

/// 根据标题查找频道
/// @param params.title 频道标题 (必需)
/// @param params.fuzzy 是否模糊匹配 (可选，默认 false)
/// @param params.findAll 是否返回所有匹配项 (可选，默认 false)
/// @param params.offset 分页起始位置 (可选，仅 findAll=true 时有效)
/// @param params.count 分页返回数量 (可选，仅 findAll=true 时有效，默认 100)
Future<String> _jsFindChannelByTitle(Map<String, dynamic> params) async {
  final result = await ChatPlugin.instance.chatUseCase.findChannelByTitle(
    params,
  );
  return result.toJsonString();
}

// ==================== 消息查找方法 ====================

/// 通用消息查找
/// @param params.field 要匹配的字段名 (必需)
/// @param params.value 要匹配的值 (必需)
/// @param params.channelId 限定在特定频道内查找 (可选)
/// @param params.findAll 是否返回所有匹配项 (可选，默认 false)
/// @param params.offset 分页起始位置 (可选，仅 findAll=true 时有效)
/// @param params.count 分页返回数量 (可选，仅 findAll=true 时有效，默认 100)
Future<String> _jsFindMessageBy(Map<String, dynamic> params) async {
  final result = await ChatPlugin.instance.chatUseCase.findMessageBy(params);
  return result.toJsonString();
}

/// 根据ID查找消息
/// @param params.id 消息ID (必需)
/// @param params.channelId 限定在特定频道内查找 (可选)
Future<String> _jsFindMessageById(Map<String, dynamic> params) async {
  final result = await ChatPlugin.instance.chatUseCase.findMessageById(params);
  return result.toJsonString();
}

/// 根据内容查找消息
/// @param params.content 消息内容 (必需)
/// @param params.fuzzy 是否模糊匹配 (可选，默认 false)
/// @param params.channelId 限定在特定频道内查找 (可选)
/// @param params.findAll 是否返回所有匹配项 (可选，默认 false)
/// @param params.offset 分页起始位置 (可选，仅 findAll=true 时有效)
/// @param params.count 分页返回数量 (可选，仅 findAll=true 时有效，默认 100)
Future<String> _jsFindMessageByContent(Map<String, dynamic> params) async {
  final result = await ChatPlugin.instance.chatUseCase.findMessageByContent(
    params,
  );
  return result.toJsonString();
}

/// 根据日期范围获取所有频道的消息
/// @param params.startDate 开始日期，格式 "YYYY-MM-DD" (必需)
/// @param params.endDate 结束日期，格式 "YYYY-MM-DD" (必需)
/// @param params.offset 分页起始位置 (可选)
/// @param params.count 返回数量 (可选，默认 100)
/// @return JSON 字符串，包含消息列表
Future<String> _jsGetMessagesByDate(Map<String, dynamic> params) async {
  try {
    // 验证必需参数
    if (!params.containsKey('startDate')) {
      return '{"error": "缺少必需参数: startDate", "messages": []}';
    }
    if (!params.containsKey('endDate')) {
      return '{"error": "缺少必需参数: endDate", "messages": []}';
    }

    final startDateStr = params['startDate'] as String;
    final endDateStr = params['endDate'] as String;

    // 解析日期
    final startDate = DateTime.parse(startDateStr);
    final endDate = DateTime.parse(
      endDateStr,
    ).add(const Duration(days: 1)); // 包含结束日期当天的消息

    // 获取所有频道
    final channelsResult = await ChatPlugin.instance.chatUseCase.getChannels(
      {},
    );
    if (channelsResult.isFailure) {
      return '{"error": "获取频道失败", "messages": []}';
    }

    final channelsData = channelsResult.dataOrNull;
    if (channelsData is! List) {
      return '{"error": "频道数据格式错误", "messages": []}';
    }

    final channelsList = channelsData;
    final allMessages = <Map<String, dynamic>>[];

    // 遍历每个频道获取消息
    for (final channelData in channelsList) {
      if (channelData is! Map) continue;

      final channel = channelData as Map<String, dynamic>;
      final channelId = channel['id'] as String?;

      if (channelId == null || channelId.isEmpty) continue;

      try {
        // 获取频道的所有消息
        final messagesResult = await ChatPlugin.instance.chatUseCase
            .getMessages({'channelId': channelId});

        if (messagesResult.isSuccess) {
          final messagesData = messagesResult.dataOrNull;
          if (messagesData is List) {
            final messages = messagesData;

            // 过滤日期范围内的消息
            for (final msgData in messages) {
              if (msgData is! Map) continue;

              final msg = msgData as Map<String, dynamic>;
              final timestampStr = msg['date'] as String?;

              if (timestampStr != null) {
                try {
                  final timestamp = DateTime.parse(timestampStr);

                  // 检查是否在日期范围内
                  if (timestamp.isAfter(startDate) &&
                      timestamp.isBefore(endDate)) {
                    allMessages.add(msg);
                  }
                } catch (e) {
                  // 忽略日期解析错误的消息
                }
              }
            }
          }
        }
      } catch (e) {
        // 忽略获取单个频道消息的错误，继续处理其他频道
        debugPrint('Error getting messages for channel $channelId: $e');
      }
    }

    // 按时间排序（最新的在前）
    allMessages.sort((a, b) {
      final aTime = DateTime.parse(a['date'] as String);
      final bTime = DateTime.parse(b['date'] as String);
      return bTime.compareTo(aTime);
    });

    // 处理分页
    final offset = params['offset'] as int? ?? 0;
    final count = params['count'] as int? ?? 100;

    final paginatedMessages = allMessages.skip(offset).take(count).toList();

    // 返回结果
    final result = {
      'total': allMessages.length,
      'offset': offset,
      'count': count,
      'hasMore': offset + count < allMessages.length,
      'messages': paginatedMessages,
    };

    return const JsonEncoder().convert(result);
  } catch (e) {
    debugPrint('Error in getMessagesByDate: $e');
    return '{"error": "获取消息失败: $e", "messages": []}';
  }
}

// ==================== 消息选择器 ====================

/// 本地文件路径 → 本地 HTTP 服务器 URL（供 webview 页面加载图片/头像）
///
/// 支持 asset:// 资源引用、'./' 相对路径、绝对路径、file:// URL；
/// http(s) 直接返回原值
Future<String?> _localPathToHttpUrl(String? rawPath) async {
  if (rawPath == null || rawPath.isEmpty) return null;

  // asset://<uuid> 资源：内容 base64 存在 assets/<uuid>.json，无独立磁盘文件，
  // 需物化成文件放入缓存目录后才能经 HTTP 服务器提供
  final assetId = ImageUtils.sdkAssetId(rawPath);
  if (assetId != null) return _assetRefToHttpUrl(assetId);

  if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
    return rawPath;
  }

  try {
    final webPlugin = WebViewPlugin.instance;
    if (!webPlugin.localHttpServer.isRunning) return null;

    var rel = rawPath;
    if (!rel.startsWith('./') && !rel.startsWith('file://')) {
      // 绝对路径 → './app_data/xxx'（相对 Documents 目录）
      rel = await FilePathConverter.toRelativePath(rel);
    }
    if (rel.startsWith('./app_data/')) {
      rel = './${rel.substring('./app_data/'.length)}';
    }

    final root = await webPlugin.getHttpServerRootDir();
    return await LocalHttpServer.convertImageToHttpUrl(
      imagePath: rel,
      httpServerRoot: root,
      port: webPlugin.localHttpServer.port,
    );
  } catch (e) {
    debugPrint('[_localPathToHttpUrl] 转换失败: $rawPath - $e');
    return null;
  }
}

/// asset:// 资源 → 物化字节复制到 webview/.assets_cache/ 后返回 http URL
Future<String?> _assetRefToHttpUrl(String assetId) async {
  try {
    final webPlugin = WebViewPlugin.instance;
    if (!webPlugin.localHttpServer.isRunning) return null;

    final assets = AboutmeDataService.instance.data.assets;
    final meta = await assets.getMetadata(assetId);
    final handle = await assets.materialize(assetId);
    try {
      // 扩展名白名单校验，避免文件名异常字符进入缓存路径
      final rawExt = meta.fileName.contains('.')
          ? meta.fileName.substring(meta.fileName.lastIndexOf('.'))
          : '';
      final ext = RegExp(r'^\.[a-zA-Z0-9]{1,6}$').hasMatch(rawExt) ? rawExt : '';

      final appData = await StorageManager.appDataDirectory();
      final cacheDir = Directory('${appData.path}/webview/.assets_cache');
      await cacheDir.create(recursive: true);
      await File(handle.path).copy('${cacheDir.path}/$assetId$ext');

      return 'http://localhost:${webPlugin.localHttpServer.port}'
          '/webview/.assets_cache/$assetId$ext';
    } finally {
      await handle.dispose();
    }
  } catch (e) {
    debugPrint('[_assetRefToHttpUrl] 物化失败: $assetId - $e');
    return null;
  }
}

/// 弹出多选消息选择器（频道 -> 多选消息）
/// @param params 无必需参数
/// @return {cancelled, messages: [{id, content, date, type, username, channelId, avatar?, image?}]}
///         avatar 仅当前用户可取到（个人主页头像）；image 为 image/video 消息的 http URL
Future<String> _jsSelectMessages(Map<String, dynamic> params) async {
  try {
    final context = Get.context;
    if (context == null) {
      return '{"error": "无可用 UI 上下文，无法打开选择器"}';
    }

    final result = await pluginDataSelectorService.showSelector(
      context,
      'chat.messages',
      config: const SelectorConfig(title: '选择消息'),
    );

    if (result == null || result.cancelled) {
      return '{"cancelled": true, "messages": []}';
    }

    // MultiSelectorResult.selectedItems 的 rawData 即 Message
    final items = result is MultiSelectorResult
        ? result.selectedItems
        : const <SelectableItem>[];

    // 当前用户头像（个人主页数据源）；其他用户模型不含头像
    final currentUserAvatar = await _localPathToHttpUrl(
      ChatPlugin.instance.configService.currentUserAvatarPath,
    );

    final messages = <Map<String, dynamic>>[];
    for (final item in items) {
      final m = item.rawData;
      if (m is! Message) continue;

      // image/video 消息带 fileInfo 中的文件路径
      // （注意：历史消息路径字段为 path，新消息为 filePath，两者都兼容）
      String? imagePath;
      if (m.type == MessageType.image || m.type == MessageType.video) {
        final fileInfo = m.metadata?[Message.metadataKeyFileInfo];
        if (fileInfo is Map<String, dynamic>) {
          final filePath = fileInfo['filePath'] ?? fileInfo['path'];
          if (m.type == MessageType.video) {
            // 视频文件本身 <img> 无法显示，优先用缩略图
            imagePath = (fileInfo['thumbPath'] ?? filePath) as String?;
          } else {
            imagePath = filePath as String?;
          }
        }
      }

      messages.add({
        'id': m.id,
        'content': m.content,
        'date': m.date.toIso8601String(),
        'type': m.type.name,
        'username': m.user.username,
        'channelId': m.channelId,
        if (currentUserAvatar != null && m.user.id == 'default_user')
          'avatar': currentUserAvatar,
        if (await _localPathToHttpUrl(imagePath) case final url?) 'image': url,
      });
    }

    return jsonEncode({'cancelled': false, 'messages': messages});
  } catch (e) {
    debugPrint('Error in selectMessages: $e');
    return '{"error": "打开消息选择器失败: $e", "messages": []}';
  }
}

// ==================== 贴图相关 ====================

/// 导入贴图合集（供 line_sticker 等脚本下载贴图包后持久化）
/// @param params.name 合集名称 (必需)
/// @param params.paths 贴图文件路径列表 (必需，支持存储相对路径或本地绝对路径)
/// @return {success, id, name, count} 或 {error}
Future<String> _jsImportStickerCollection(Map<String, dynamic> params) async {
  try {
    final name = params['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      return '{"error": "缺少必需参数: name"}';
    }
    final paths = (params['paths'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .where((p) => p.isNotEmpty)
        .toList();
    if (paths.isEmpty) {
      return '{"error": "缺少必需参数: paths（至少一张贴图文件）"}';
    }

    final collection = await StickerService.instance.createCollection(
      name,
      sourcePaths: paths,
    );
    return jsonEncode({
      'success': true,
      'id': collection.id,
      'name': collection.name,
      'count': collection.stickerCount,
    });
  } catch (e) {
    debugPrint('Error in importStickerCollection: $e');
    return '{"error": "导入贴图合集失败: $e"}';
  }
}
