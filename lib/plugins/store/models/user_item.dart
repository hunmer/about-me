import 'package:aboutme/plugins/store/models/product.dart';

/// 个人物品：只维护自己的数值数据（剩余次数/到期/购买信息），
/// 商品基础数据（名称/图片/分类/描述）与商店共用一份商品列表，
/// 经 [base] 运行时引用解析，不再整份快照复制。
class UserItem {
  final String id;
  final String productId;
  int remaining;
  final DateTime expireDate;
  final DateTime purchaseDate;
  final int purchasePrice;

  /// 商品基础数据引用：由 StoreController 从商品/归档列表解析注入，
  /// 不参与序列化；为 null 表示商品已被彻底删除（展示回落「已下架商品」）
  Product? base;

  /// 旧数据迁移：历史 product_snapshot（仅 fromJson 读入、不回写），
  /// 商品与归档列表都找不到对应商品时，以其构建临时基础数据
  final Map<String, dynamic>? legacySnapshot;

  UserItem({
    required this.id,
    required this.productId,
    required this.remaining,
    required this.expireDate,
    required this.purchaseDate,
    required this.purchasePrice,
    this.legacySnapshot,
  });

  // 从JSON创建UserItem（兼容旧快照，读入 legacySnapshot）
  factory UserItem.fromJson(Map<String, dynamic> json) {
    return UserItem(
      id: json['id'],
      productId: json['product_id'],
      remaining: json['remaining'],
      expireDate: DateTime.parse(json['expire_date']),
      purchaseDate: DateTime.parse(json['purchase_date']),
      purchasePrice: json['purchase_price'],
      legacySnapshot:
          json['product_snapshot'] is Map
              ? Map<String, dynamic>.from(json['product_snapshot'] as Map)
              : null,
    );
  }

  // 转换为JSON（基础数据不落地，两侧共用商品列表）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'remaining': remaining,
      'expire_date': expireDate.toIso8601String(),
      'purchase_date': purchaseDate.toIso8601String(),
      'purchase_price': purchasePrice,
    };
  }

  // 使用物品
  void use() {
    if (remaining > 0) {
      remaining--;
    }
  }

  // 商品基础数据取值（base 缺失时回落空值，展示层用「已下架商品」占位）
  String get productName => base?.name ?? '';

  String get productImage => base?.image ?? '';

  String? get productCategory => base?.category;

  String get productDescription => base?.description ?? '';
}
