part of 'goods_plugin.dart';

// ==================== JS API 实现 ====================

/// 扁平化工具 schema 会把未用到的参数填成空串，取值时视为未传
String? _nonEmptyStr(Map<String, dynamic> params, String key) {
  final v = params[key];
  return v is String && v.isNotEmpty ? v : null;
}

/// 工具 schema/JS API 契约参数（warehouseId/title/iconCode/colorValue）
/// 与 UseCase 参数（id/name/iconData/iconColor）不同名，调用前需映射
String? _resolveWarehouseId(Map<String, dynamic> params) =>
    _nonEmptyStr(params, 'warehouseId') ?? _nonEmptyStr(params, 'id');

Map<String, dynamic> _mapWarehouseFields(Map<String, dynamic> params) {
  final mapped = Map<String, dynamic>.from(params);
  final title = _nonEmptyStr(params, 'title');
  if (title != null) mapped['name'] = title;
  // 0 是扁平化 schema 的默认填充值，不代表用户指定
  if (params['iconCode'] is num && params['iconCode'] > 0) {
    mapped['iconData'] = (params['iconCode'] as num).toInt();
  }
  if (params['colorValue'] is num && params['colorValue'] > 0) {
    mapped['iconColor'] = (params['colorValue'] as num).toInt();
  }
  return mapped;
}

/// 获取所有仓库列表
/// 支持分页参数: offset, count
/// 返回: JSON数组，包含所有仓库信息（不含物品）
Future<String> _jsGetWarehouses(Map<String, dynamic> params) async {
  try {
    final result = await GoodsPlugin.instance.useCase.getWarehouses(params);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '获取仓库失败: ${e.toString()}'});
  }
}

/// 获取指定仓库的详细信息（包含物品）
Future<String> _jsGetWarehouse(Map<String, dynamic> params) async {
  try {
    final result = await GoodsPlugin.instance.useCase.getWarehouseById({
      'id': _resolveWarehouseId(params),
    });

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    if (result.dataOrNull == null) {
      return jsonEncode({'error': '仓库不存在'});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '获取仓库失败: ${e.toString()}'});
  }
}

/// 创建新仓库
Future<String> _jsCreateWarehouse(Map<String, dynamic> params) async {
  try {
    final args = _mapWarehouseFields(params);
    // 扁平化 schema 默认填空的 id 需剔除，交给 UseCase 生成 UUID
    final customId = _nonEmptyStr(params, 'id');
    if (customId == null) {
      args.remove('id');
    } else {
      args['id'] = customId;
    }
    final result = await GoodsPlugin.instance.useCase.createWarehouse(args);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '创建仓库失败: ${e.toString()}'});
  }
}

/// 更新仓库信息
Future<String> _jsUpdateWarehouse(Map<String, dynamic> params) async {
  try {
    final args = _mapWarehouseFields(params);
    final id = _resolveWarehouseId(params);
    if (id != null) args['id'] = id;
    final result = await GoodsPlugin.instance.useCase.updateWarehouse(args);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '更新仓库失败: ${e.toString()}'});
  }
}

/// 删除仓库
Future<String> _jsDeleteWarehouse(Map<String, dynamic> params) async {
  try {
    final id = _resolveWarehouseId(params);
    final result = await GoodsPlugin.instance.useCase.deleteWarehouse({
      'id': id,
    });

    if (result.isFailure) {
      return jsonEncode({
        'success': false,
        'error': result.errorOrNull?.message,
      });
    }

    return jsonEncode({'success': true, 'warehouseId': id});
  } catch (e) {
    return jsonEncode({'success': false, 'error': e.toString()});
  }
}

/// 清空仓库（删除所有物品）
Future<String> _jsClearWarehouse(Map<String, dynamic> params) async {
  try {
    final warehouseId = _resolveWarehouseId(params);
    if (warehouseId == null) {
      return jsonEncode({'error': '缺少必需参数: warehouseId'});
    }

    await GoodsPlugin.instance.clearWarehouse(warehouseId);
    return jsonEncode({'success': true, 'warehouseId': warehouseId});
  } catch (e) {
    return jsonEncode({'success': false, 'error': e.toString()});
  }
}

/// 获取物品列表
/// 支持分页参数: offset, count
/// 支持 get_http_image 参数：是否将图片路径转换为 HTTP URL
Future<String> _jsGetGoods(Map<String, dynamic> params) async {
  try {
    // 提取图片转换参数
    final getHttpImage = params['get_http_image'] == true;
    params.remove('get_http_image');

    final result = await GoodsPlugin.instance.useCase.getItems(params);

    var items = result.dataOrNull ?? [];

    // 处理图片路径转换（使用简化方法）
    if (getHttpImage) {
      items = await LocalHttpServer.convertImagesWithAutoConfig(
        items: items,
        pluginId: GoodsPlugin.instance.id,
        imageKey: 'imageUrl',
        storageManager: GoodsPlugin.instance.storage,
      );
    }

    return jsonEncode({
      'success': true,
      'data': items,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (e) {
    return jsonEncode({
      'success': false,
      'error': '获取物品失败: ${e.toString()}',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
}

/// 获取指定物品的详细信息
Future<String> _jsGetGoodsItem(Map<String, dynamic> params) async {
  try {
    final result = await GoodsPlugin.instance.useCase.getItemById({
      'id': _nonEmptyStr(params, 'itemId') ?? _nonEmptyStr(params, 'id'),
    });

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    if (result.dataOrNull == null) {
      return jsonEncode({'error': '物品不存在'});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '获取物品失败: ${e.toString()}'});
  }
}

/// 创建新物品
Future<String> _jsCreateGoodsItem(Map<String, dynamic> params) async {
  try {
    // 转换参数格式
    final String? itemDataStr = params['itemData'];
    if (itemDataStr == null || itemDataStr.isEmpty) {
      return jsonEncode({'error': '缺少必需参数: itemData'});
    }

    final data = jsonDecode(itemDataStr) as Map<String, dynamic>;

    // 确保有ID和标题
    if (!data.containsKey('title') || data['title'] == null) {
      return jsonEncode({'error': '物品名称不能为空'});
    }

    // 生成ID（如果没有提供）
    data['id'] = data['id'] ?? const Uuid().v4();

    // 构建 UseCase 需要的参数
    final useCaseParams = {
      'id': data['id'],
      'name': data['title'],
      'description': data['notes'] ?? data['description'],
      'quantity': data['quantity'] ?? 1,
      'category': data['category'],
      'tags': data['tags'] ?? [],
      'customFields': data['customFields'],
      'warehouseId': params['warehouseId'],
    };

    final result = await GoodsPlugin.instance.useCase.createItem(useCaseParams);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '创建物品失败: ${e.toString()}'});
  }
}

/// 更新物品
Future<String> _jsUpdateGoodsItem(Map<String, dynamic> params) async {
  try {
    // 必需参数验证
    final String? itemId = params['itemId'];
    final String? itemDataStr = params['itemData'];

    if (itemId == null || itemId.isEmpty) {
      return jsonEncode({'error': '缺少必需参数: itemId'});
    }
    if (itemDataStr == null || itemDataStr.isEmpty) {
      return jsonEncode({'error': '缺少必需参数: itemData'});
    }

    // 查找物品所在的仓库
    final existingItem = GoodsPlugin.instance.findGoodsItemById(itemId);
    if (existingItem == null) {
      return jsonEncode({'error': '物品不存在', 'itemId': itemId});
    }

    // 解析更新数据
    final updateData = jsonDecode(itemDataStr) as Map<String, dynamic>;

    // 构建 UseCase 需要的参数
    final useCaseParams = {
      'id': itemId,
      'name': updateData['title'],
      'description': updateData['notes'] ?? updateData['description'],
      'quantity': updateData['quantity'],
      'category': updateData['category'],
      'tags': updateData['tags'],
      'customFields': updateData['customFields'],
      'warehouseId': existingItem.warehouseId,
    };

    final result = await GoodsPlugin.instance.useCase.updateItem(useCaseParams);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '更新物品失败: ${e.toString()}'});
  }
}

/// 删除物品
Future<String> _jsDeleteGoodsItem(Map<String, dynamic> params) async {
  try {
    // 查找物品所在的仓库
    final String? itemId = params['itemId'];
    if (itemId == null || itemId.isEmpty) {
      return jsonEncode({'error': '缺少必需参数: itemId'});
    }

    final existingItem = GoodsPlugin.instance.findGoodsItemById(itemId);
    if (existingItem == null) {
      return jsonEncode({'error': '物品不存在', 'itemId': itemId});
    }

    // 构建 UseCase 需要的参数
    final useCaseParams = {
      'id': itemId,
      'warehouseId': existingItem.warehouseId,
    };

    final result = await GoodsPlugin.instance.useCase.deleteItem(useCaseParams);

    if (result.isFailure) {
      return jsonEncode({
        'success': false,
        'error': result.errorOrNull?.message,
      });
    }

    return jsonEncode({
      'success': true,
      'itemId': itemId,
      'warehouseId': existingItem.warehouseId,
    });
  } catch (e) {
    return jsonEncode({'success': false, 'error': e.toString()});
  }
}

/// 添加使用记录
Future<String> _jsAddUsageRecord(Map<String, dynamic> params) async {
  try {
    // 必需参数验证
    final String? itemId = params['itemId'];
    if (itemId == null || itemId.isEmpty) {
      return jsonEncode({'error': '缺少必需参数: itemId'});
    }

    // 可选参数
    final String? dateStr = params['dateStr'];
    final String? note = params['note'];

    // 查找物品
    final result = GoodsPlugin.instance.findGoodsItemById(itemId);
    if (result == null) {
      return jsonEncode({'error': '物品不存在', 'itemId': itemId});
    }

    // 解析日期
    final date = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();

    // 添加使用记录
    final updatedItem = result.item.addUsageRecord(date, note: note);
    await GoodsPlugin.instance.saveGoodsItem(result.warehouseId, updatedItem);

    return jsonEncode(updatedItem.toJson());
  } catch (e) {
    return jsonEncode({'error': '添加使用记录失败: ${e.toString()}'});
  }
}

/// 获取统计信息
/// 返回: 包含总数量、总价值、未使用物品数的统计数据
Future<String> _jsGetStatistics(Map<String, dynamic> params) async {
  try {
    final result = await GoodsPlugin.instance.useCase.getStats(params);

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    return jsonEncode(result.dataOrNull);
  } catch (e) {
    return jsonEncode({'error': '获取统计失败: ${e.toString()}'});
  }
}
