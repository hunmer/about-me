/// 商店插件示例数据
/// 当 JSON 文件不存在时，使用此文件中的数据作为默认值
library;

import 'models/product.dart';
import 'models/user_item.dart';
import 'models/points_log.dart';
import 'models/used_item.dart';

/// 获取默认商店商品数据
List<Product> getDefaultProducts() {
  final now = DateTime.now();
  final oneYearFromNow = DateTime(now.year + 1, now.month, now.day);

  return [
    Product(
      id: '1705123456789',
      name: '免作业卡',
      description: '可免除一次作业任务',
      image: 'assets/svg/items/easy_love-letter.svg',
      stock: 10,
      price: 50,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 30,
    ),
    Product(
      id: '1705123456790',
      name: '专注力提升剂',
      description: '提高30分钟专注力，学习效率倍增',
      image: 'assets/svg/items/tech_headphones.svg',
      stock: 20,
      price: 80,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 1,
    ),
    Product(
      id: '1705123456791',
      name: '知识胶囊',
      description: '快速掌握一个知识点的精华内容',
      image: 'assets/svg/items/easy_books.svg',
      stock: 15,
      price: 120,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 7,
    ),
    Product(
      id: '1705123456792',
      name: '元气草莓',
      description: '咬一口就恢复元气的甜草莓',
      image: 'assets/svg/items/fruits_strawberry.svg',
      stock: 30,
      price: 15,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 1,
    ),
    Product(
      id: '1705123456793',
      name: '蜜桃气泡水',
      description: '冰镇蜜桃味，清凉一夏',
      image: 'assets/svg/items/fruits_sweet-peach.svg',
      stock: 25,
      price: 25,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 1,
    ),
    Product(
      id: '1705123456794',
      name: '西瓜冰沙券',
      description: '兑换一杯现榨西瓜冰沙',
      image: 'assets/svg/items/fruits_watermelon.svg',
      stock: 20,
      price: 30,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 1,
    ),
    Product(
      id: '1705123456795',
      name: '芒果布丁',
      description: 'Q弹香浓的午后甜点',
      image: 'assets/svg/items/fruits_mango-pudding.svg',
      stock: 20,
      price: 20,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 1,
    ),
    Product(
      id: '1705123456796',
      name: '精美果篮',
      description: '装满当季水果的大礼包',
      image: 'assets/svg/items/fruits_fruit-basket.svg',
      stock: 8,
      price: 100,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 3,
    ),
    Product(
      id: '1705123456797',
      name: '小熊连帽衫',
      description: '戴上耳朵的可爱保暖神器',
      image: 'assets/svg/items/clothes_bear-hoodie.svg',
      stock: 12,
      price: 90,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 30,
    ),
    Product(
      id: '1705123456798',
      name: '蜡笔小手套',
      description: '五彩蜡笔配色的小手套',
      image: 'assets/svg/items/clothes_crayon-mittens.svg',
      stock: 15,
      price: 45,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 30,
    ),
    Product(
      id: '1705123456799',
      name: '兔子居家拖鞋',
      description: '毛绒绒的居家好伙伴',
      image: 'assets/svg/items/clothes_bunny-slippers.svg',
      stock: 15,
      price: 35,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 60,
    ),
    Product(
      id: '1705123456800',
      name: '甜美小围裙',
      description: '烘焙日专用装备',
      image: 'assets/svg/items/clothes_sweet-apron.svg',
      stock: 10,
      price: 60,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 30,
    ),
    Product(
      id: '1705123456801',
      name: '牛角扣大衣',
      description: '冬日出门的温暖选择',
      image: 'assets/svg/items/clothes_duffle-coat.svg',
      stock: 6,
      price: 150,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 90,
    ),
    Product(
      id: '1705123456802',
      name: '星星睡衣套装',
      description: '穿着入睡会有好梦',
      image: 'assets/svg/items/clothes_sleepy-pajamas.svg',
      stock: 12,
      price: 70,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 30,
    ),
    Product(
      id: '1705123456803',
      name: '文艺贝雷帽',
      description: '一秒变文艺的小道具',
      image: 'assets/svg/items/clothes_beret-hat.svg',
      stock: 14,
      price: 55,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 30,
    ),
    Product(
      id: '1705123456804',
      name: '暖烘烘围巾',
      description: '围上就不想摘的软围巾',
      image: 'assets/svg/items/clothes_warm-scarf.svg',
      stock: 10,
      price: 65,
      exchangeStart: now,
      exchangeEnd: oneYearFromNow,
      useDuration: 60,
    ),
  ];
}

/// 获取默认用户物品数据
List<UserItem> getDefaultUserItems() {
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));
  final threeDaysAgo = now.subtract(const Duration(days: 3));
  final fiveDaysAgo = now.subtract(const Duration(days: 5));

  // 获取示例商品数据
  final products = getDefaultProducts();

  // 便捷构造：按商品下标生成物品（默认剩余 1 次、5 天前购买）
  UserItem make(
    int productIndex,
    String id, {
    required int expiresInDays,
    int purchasedDaysAgo = 5,
    int remaining = 1,
  }) {
    final product = products[productIndex];
    return UserItem(
      id: id,
      productId: product.id,
      remaining: remaining,
      expireDate: now.add(Duration(days: expiresInDays)),
      purchaseDate: now.subtract(Duration(days: purchasedDaysAgo)),
      purchasePrice: product.price,
      productSnapshot: product.toJson(),
    );
  }

  return [
    // 已过期但仍保留的物品（用于演示）
    UserItem(
      id: '1705130000001',
      productId: products[0].id,
      remaining: 0,
      expireDate: yesterday,
      purchaseDate: fiveDaysAgo,
      purchasePrice: 50,
      productSnapshot: products[0].toJson(),
    ),

    // 即将过期的物品
    UserItem(
      id: '1705130000002',
      productId: products[1].id,
      remaining: 1,
      expireDate: now.add(const Duration(days: 2)),
      purchaseDate: now.subtract(const Duration(days: 5)),
      purchasePrice: 80,
      productSnapshot: products[1].toJson(),
    ),

    // 正常使用中的物品
    UserItem(
      id: '1705130000003',
      productId: products[2].id,
      remaining: 1,
      expireDate: now.add(const Duration(days: 30)),
      purchaseDate: threeDaysAgo,
      purchasePrice: 120,
      productSnapshot: products[2].toJson(),
    ),

    // ===== 更多示例物品（合计 16 组，正好铺满收集册 4 层货架）=====
    // 数量徽章：元气草莓 ×3（分批过期，使用时优先消耗最早过期的）
    for (var i = 0; i < 3; i++)
      make(3, '17051300001${i + 4}', expiresInDays: 20 + i * 5),
    make(4, '1705130000104', expiresInDays: -1), // 蜜桃气泡水（过期剪影）
    make(5, '1705130000105', expiresInDays: 3), // 西瓜冰沙券（即将过期）
    make(6, '1705130000106', expiresInDays: 5), // 芒果布丁（即将过期）
    make(7, '1705130000107', expiresInDays: 45), // 精美果篮
    make(8, '1705130000108', expiresInDays: 60), // 小熊连帽衫
    make(9, '1705130000109', expiresInDays: -2), // 蜡笔小手套（过期剪影）
    make(10, '1705130000110', expiresInDays: 7), // 兔子居家拖鞋（即将过期）
    make(11, '1705130000111', expiresInDays: 30), // 甜美小围裙
    make(12, '1705130000112', expiresInDays: 90), // 牛角扣大衣
    make(13, '1705130000113', expiresInDays: 40), // 星星睡衣套装
    make(14, '1705130000114', expiresInDays: -3), // 文艺贝雷帽（过期剪影）
    make(15, '1705130000115', expiresInDays: 25), // 暖烘烘围巾
    make(15, '1705130000116', expiresInDays: 50), // 暖烘烘围巾（第 2 件 → ×2 徽章）
  ];
}

/// 获取示例积分记录
List<PointsLog> getDefaultPointsLogs() {
  final now = DateTime.now();

  return [
    PointsLog(
      id: '1705140000001',
      type: '获得',
      value: 10,
      reason: '完成签到奖励',
      timestamp: now.subtract(const Duration(hours: 2)),
    ),
    PointsLog(
      id: '1705140000002',
      type: '获得',
      value: 3,
      reason: '添加活动记录',
      timestamp: now.subtract(const Duration(hours: 3)),
    ),
    PointsLog(
      id: '1705140000003',
      type: '获得',
      value: 20,
      reason: '完成任务奖励',
      timestamp: now.subtract(const Duration(hours: 5)),
    ),
    PointsLog(
      id: '1705140000004',
      type: '消耗',
      value: 50,
      reason: '兑换商品: 免作业卡',
      timestamp: now.subtract(const Duration(days: 1)),
    ),
    PointsLog(
      id: '1705140000005',
      type: '获得',
      value: 5,
      reason: '添加日记奖励',
      timestamp: now.subtract(const Duration(days: 1, hours: 6)),
    ),
    PointsLog(
      id: '1705140000006',
      type: '获得',
      value: 10,
      reason: '添加笔记奖励',
      timestamp: now.subtract(const Duration(days: 2)),
    ),
    PointsLog(
      id: '1705140000007',
      type: '获得',
      value: 1,
      reason: '发送消息奖励',
      timestamp: now.subtract(const Duration(days: 2, hours: 3)),
    ),
    PointsLog(
      id: '1705140000008',
      type: '获得',
      value: 10,
      reason: '添加账单奖励',
      timestamp: now.subtract(const Duration(days: 3)),
    ),
    PointsLog(
      id: '1705140000009',
      type: '获得',
      value: 5,
      reason: '添加物品奖励',
      timestamp: now.subtract(const Duration(days: 4)),
    ),
  ];
}

/// 获取示例已使用物品记录
List<UsedItem> getDefaultUsedItems() {
  final now = DateTime.now();
  final products = getDefaultProducts();

  return [
    UsedItem(
      id: '1705150000001',
      productId: products[0].id,
      useDate: now.subtract(const Duration(days: 1)),
      productSnapshot: products[0].toJson(),
    ),
    UsedItem(
      id: '1705150000002',
      productId: products[1].id,
      useDate: now.subtract(const Duration(days: 2)),
      productSnapshot: products[1].toJson(),
    ),
  ];
}

/// 获取默认积分余额
int getDefaultPointsBalance() {
  return 47; // 根据积分记录计算得出
}

/// 初始化默认数据的完整结构
class StoreDefaultData {
  /// 获取包含所有默认数据的Map
  static Map<String, dynamic> getAllData() {
    return {
      'products': {
        'products': getDefaultProducts().map((p) => p.toJson()).toList(),
      },
      'archived_products': {'products': []},
      'points': {
        'value': getDefaultPointsBalance(),
        'logs': getDefaultPointsLogs().map((log) => log.toJson()).toList(),
      },
      'user_items': {
        'items': getDefaultUserItems().map((item) => item.toJson()).toList(),
      },
      'used_items': {
        'items': getDefaultUsedItems().map((item) => item.toJson()).toList(),
      },
    };
  }
}
