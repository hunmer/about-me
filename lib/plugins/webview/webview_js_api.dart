part of 'webview_plugin.dart';

// JS API 实现 - 私有方法
// defineJSAPI() 方法在主插件类中实现

Future<String> _jsGetCards(Map<String, dynamic> params) async {
  if (!WebViewPlugin.instance._isInitialized) return jsonEncode({'error': '插件未初始化'});
  return jsonEncode(WebViewPlugin.instance.cardManager.getAllCards().map((c) => c.toJson()).toList());
}

Future<String> _jsAddCard(Map<String, dynamic> params) async {
  final plugin = WebViewPlugin.instance;
  if (!plugin._isInitialized) return jsonEncode({'error': '插件未初始化'});

  final title = params['title'] as String?;
  final url = params['url'] as String?;
  final type = params['type'] as String? ?? 'url';

  if (title == null || url == null) {
    return jsonEncode({'error': '缺少必需参数: title, url'});
  }

  final card = await plugin.cardManager.addCard(
    title: title,
    url: url,
    type: type == 'localFile' ? CardType.localFile : CardType.url,
    description: params['description'] as String?,
    tags: (params['tags'] as List<dynamic>?)?.cast<String>(),
  );

  return jsonEncode(card.toJson());
}

Future<String> _jsDeleteCard(Map<String, dynamic> params) async {
  if (!WebViewPlugin.instance._isInitialized) return jsonEncode({'error': '插件未初始化'});

  final cardId = params['cardId'] as String?;
  if (cardId == null) {
    return jsonEncode({'error': '缺少必需参数: cardId'});
  }

  await WebViewPlugin.instance.cardManager.deleteCard(cardId);
  return jsonEncode({'success': true});
}

Future<String> _jsUpdateCard(Map<String, dynamic> params) async {
  if (!WebViewPlugin.instance._isInitialized) return jsonEncode({'error': '插件未初始化'});

  final cardId = params['cardId'] as String?;
  if (cardId == null) {
    return jsonEncode({'error': '缺少必需参数: cardId'});
  }

  final card = WebViewPlugin.instance.cardManager.getCardById(cardId);
  if (card == null) {
    return jsonEncode({'error': '卡片不存在'});
  }

  final updatedCard = card.copyWith(
    title: params['title'] as String?,
    url: params['url'] as String?,
    description: params['description'] as String?,
  );

  await WebViewPlugin.instance.cardManager.updateCard(updatedCard);
  return jsonEncode(updatedCard.toJson());
}

Future<String> _jsFindCardById(Map<String, dynamic> params) async {
  if (!WebViewPlugin.instance._isInitialized) return jsonEncode(null);

  final id = params['id'] as String?;
  if (id == null) return jsonEncode(null);

  final card = WebViewPlugin.instance.cardManager.getCardById(id);
  return jsonEncode(card?.toJson());
}

Future<String> _jsFindCardByUrl(Map<String, dynamic> params) async {
  if (!WebViewPlugin.instance._isInitialized) return jsonEncode(null);

  final url = params['url'] as String?;
  if (url == null) return jsonEncode(null);

  final card = WebViewPlugin.instance.cardManager.getCardByUrl(url);
  return jsonEncode(card?.toJson());
}

Future<String> _jsGetTabs(Map<String, dynamic> params) async {
  if (!WebViewPlugin.instance._isInitialized) return jsonEncode({'error': '插件未初始化'});
  return jsonEncode(WebViewPlugin.instance.tabManager.tabs.map((t) => t.toJson()).toList());
}

Future<String> _jsCreateTab(Map<String, dynamic> params) async {
  if (!WebViewPlugin.instance._isInitialized) return jsonEncode({'error': '插件未初始化'});

  final url = params['url'] as String?;
  if (url == null) {
    return jsonEncode({'error': '缺少必需参数: url'});
  }

  try {
    final tab = await WebViewPlugin.instance.tabManager.createTab(
      url: url,
      title: params['title'] as String?,
      setActive: params['setActive'] as bool? ?? true,
    );
    return jsonEncode(tab.toJson());
  } catch (e) {
    return jsonEncode({'error': e.toString()});
  }
}

Future<String> _jsCloseTab(Map<String, dynamic> params) async {
  if (!WebViewPlugin.instance._isInitialized) return jsonEncode({'error': '插件未初始化'});

  final tabId = params['tabId'] as String?;
  if (tabId == null) {
    return jsonEncode({'error': '缺少必需参数: tabId'});
  }

  await WebViewPlugin.instance.tabManager.closeTab(tabId);
  return jsonEncode({'success': true});
}

Future<String> _jsSwitchTab(Map<String, dynamic> params) async {
  if (!WebViewPlugin.instance._isInitialized) return jsonEncode({'error': '插件未初始化'});

  final tabId = params['tabId'] as String?;
  if (tabId == null) {
    return jsonEncode({'error': '缺少必需参数: tabId'});
  }

  await WebViewPlugin.instance.tabManager.switchToTab(tabId);
  return jsonEncode({'success': true});
}

Future<String> _jsNavigate(Map<String, dynamic> params) async {
  if (!WebViewPlugin.instance._isInitialized) return jsonEncode({'error': '插件未初始化'});

  final url = params['url'] as String?;
  if (url == null) {
    return jsonEncode({'error': '缺少必需参数: url'});
  }

  final tabId = WebViewPlugin.instance.tabManager.activeTabId;
  if (tabId == null) {
    return jsonEncode({'error': '没有活动的标签页'});
  }

  await WebViewPlugin.instance.tabManager.navigateTo(tabId, url);
  return jsonEncode({'success': true});
}

Future<String> _jsGoBack(Map<String, dynamic> params) async {
  final tabId = WebViewPlugin.instance.tabManager.activeTabId;
  if (tabId != null) {
    final success = await WebViewPlugin.instance.tabManager.goBack(tabId);
    return jsonEncode({'success': success});
  }
  return jsonEncode({'success': false, 'error': '无法后退'});
}

Future<String> _jsGoForward(Map<String, dynamic> params) async {
  final tabId = WebViewPlugin.instance.tabManager.activeTabId;
  if (tabId != null) {
    final success = await WebViewPlugin.instance.tabManager.goForward(tabId);
    return jsonEncode({'success': success});
  }
  return jsonEncode({'success': false, 'error': '无法前进'});
}

Future<String> _jsReload(Map<String, dynamic> params) async {
  final tabId = WebViewPlugin.instance.tabManager.activeTabId;
  if (tabId != null) {
    await WebViewPlugin.instance.tabManager.reload(tabId);
    return jsonEncode({'success': true});
  }
  return jsonEncode({'success': false, 'error': '没有活动的标签页'});
}

// ==================== 图片选择器 ====================

/// 弹出原生图片选择器（ImagePickerDialog，相册/表情包/拍照/在线URL）
/// @param params.multiple 是否多选 (可选，默认 false)
/// @return {cancelled, images: [{url, thumbUrl?}]}，url 已转为本地 HTTP URL
Future<String> _jsSelectImages(Map<String, dynamic> params) async {
  try {
    final context = Get.context;
    if (context == null) {
      return '{"error": "无可用 UI 上下文，无法打开图片选择器"}';
    }

    final multiple = params['multiple'] == true;
    final result = await ImagePickerDialog.show<dynamic>(
      context,
      multiple: multiple,
    );

    if (result == null) return '{"cancelled": true, "images": []}';

    // 单选返回 Map，多选返回 List<Map>；url/thumbUrl 为
    // './xxx' 相对路径 / asset:// 引用 / http(s) / emoji: 前缀
    final rawList = (result is List ? result : [result])
        .whereType<Map>()
        .toList();

    final images = <Map<String, dynamic>>[];
    for (final e in rawList) {
      final url = await _pickerPathToHttpUrl(e['url']?.toString());
      if (url == null) continue; // emoji: 等无法转为图片 URL 的结果
      final thumbUrl = await _pickerPathToHttpUrl(e['thumbUrl']?.toString());
      images.add({
        'url': url,
        if (thumbUrl != null) 'thumbUrl': thumbUrl,
      });
    }

    return jsonEncode({'cancelled': false, 'images': images});
  } catch (e) {
    debugPrint('Error in selectImages: $e');
    return '{"error": "打开图片选择器失败: $e", "images": []}';
  }
}

/// 弹出日历相册月份选择器（calendar_album.monthPhotos 数据选择器）
/// @param params 无必需参数
/// @return {cancelled, month: 'YYYY-MM', days: {'YYYY-MM-DD': [url, ...]}}
///         每天包含全部照片（已转为本地 HTTP URL），页面默认取每天第一张
Future<String> _jsSelectMonthPhotos(Map<String, dynamic> params) async {
  try {
    final context = Get.context;
    if (context == null) {
      return '{"error": "无可用 UI 上下文，无法打开选择器"}';
    }

    final result = await pluginDataSelectorService.showSelector(
      context,
      'calendar_album.monthPhotos',
      config: const SelectorConfig(title: '选择月份'),
    );

    if (result == null || result.cancelled) {
      return '{"cancelled": true, "days": {}}';
    }

    // 单步选择器：从 path 取选中月份的 rawData {month, days}
    final data = result.getPathRawData<Map>('month') ??
        (result.data is SelectableItem
            ? (result.data as SelectableItem).rawData
            : null);
    if (data is! Map) return '{"cancelled": true, "days": {}}';

    final month = data['month']?.toString() ?? '';
    final rawDays = data['days'];
    final days = <String, List<String>>{};
    if (rawDays is Map) {
      for (final e in rawDays.entries) {
        final urls = <String>[];
        if (e.value is List) {
          for (final p in e.value as List) {
            final url = await _pickerPathToHttpUrl(p?.toString());
            if (url != null) urls.add(url);
          }
        }
        if (urls.isNotEmpty) days[e.key.toString()] = urls;
      }
    }

    return jsonEncode({'cancelled': false, 'month': month, 'days': days});
  } catch (e) {
    debugPrint('Error in selectMonthPhotos: $e');
    return '{"error": "打开月份选择器失败: $e", "days": {}}';
  }
}

/// 选择器返回的媒体路径 → 本地 HTTP 服务器 URL
///
/// 与 chat 插件 _localPathToHttpUrl 同款逻辑：
/// asset:// 资源需物化到缓存目录；'./'/绝对路径按 app_data 根拼接；
/// http(s) 原样返回；emoji: 等非图片引用返回 null
Future<String?> _pickerPathToHttpUrl(String? rawPath) async {
  if (rawPath == null || rawPath.isEmpty) return null;

  final assetId = ImageUtils.sdkAssetId(rawPath);
  if (assetId != null) return _pickerAssetToHttpUrl(assetId);

  if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
    return rawPath;
  }
  if (rawPath.contains('://') && !rawPath.startsWith('file://')) return null;

  try {
    final plugin = WebViewPlugin.instance;
    if (!plugin.localHttpServer.isRunning) return null;

    var rel = rawPath;
    if (!rel.startsWith('./') && !rel.startsWith('file://')) {
      // 绝对路径 → './app_data/xxx'（相对 Documents 目录）
      rel = await FilePathConverter.toRelativePath(rel);
    }
    if (rel.startsWith('./app_data/')) {
      rel = './${rel.substring('./app_data/'.length)}';
    }

    return await LocalHttpServer.convertImageToHttpUrl(
      imagePath: rel,
      httpServerRoot: await plugin.getHttpServerRootDir(),
      port: plugin.localHttpServer.port,
    );
  } catch (e) {
    debugPrint('[_pickerPathToHttpUrl] 转换失败: $rawPath - $e');
    return null;
  }
}

/// asset:// 资源 → 物化字节复制到 webview/.assets_cache/ 后返回 http URL
Future<String?> _pickerAssetToHttpUrl(String assetId) async {
  try {
    final plugin = WebViewPlugin.instance;
    if (!plugin.localHttpServer.isRunning) return null;

    final assets = AboutmeDataService.instance.data.assets;
    final meta = await assets.getMetadata(assetId);
    final handle = await assets.materialize(assetId);
    try {
      final rawExt = meta.fileName.contains('.')
          ? meta.fileName.substring(meta.fileName.lastIndexOf('.'))
          : '';
      final ext = RegExp(r'^\.[a-zA-Z0-9]{1,6}$').hasMatch(rawExt) ? rawExt : '';

      final appData = await StorageManager.appDataDirectory();
      final cacheDir = Directory('${appData.path}/webview/.assets_cache');
      await cacheDir.create(recursive: true);
      await File(handle.path).copy('${cacheDir.path}/$assetId$ext');

      return 'http://localhost:${plugin.localHttpServer.port}'
          '/webview/.assets_cache/$assetId$ext';
    } finally {
      await handle.dispose();
    }
  } catch (e) {
    debugPrint('[_pickerAssetToHttpUrl] 物化失败: $assetId - $e');
    return null;
  }
}
