import 'package:shared_models/shared_models.dart';
class UsedItem {
  final String id;
  final String productId;
  final DateTime useDate;
  final Map<String, dynamic> productSnapshot;

  UsedItem({
    required this.id,
    required this.productId,
    required this.useDate,
    required this.productSnapshot,
  });

  factory UsedItem.fromJson(Map<String, dynamic> json) {
    return UsedItem(
      id: json['id'],
      productId: json['product_id'],
      useDate: parseIsoDateTime(json['use_date']),
      productSnapshot: Map<String, dynamic>.from(json['product_snapshot']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'use_date': useDate.toIso8601String(),
      'product_snapshot': productSnapshot,
    };
  }
}
