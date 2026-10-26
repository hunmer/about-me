import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/plugins/bill/models/subscription.dart';

void main() {
  group('Subscription.fromJson 数字类型兼容', () {
    Map<String, dynamic> baseJson(num totalAmount, num days) => {
      'id': 'sub-1',
      'name': 'Netflix',
      'totalAmount': totalAmount,
      'days': days,
      'category': '订阅',
      'startDate': '2026-10-26T00:00:00.000',
      'endDate': null,
      'isActive': true,
      'note': null,
      'icon': 58726,
      'iconColor': 4280391411,
      'createdAt': '2026-10-26T00:00:00.000',
      'terminatedAt': null,
    };

    test('整数形态（HTTP/JS JSON 边界 30.0 会变 30）不抛错', () {
      final sub = Subscription.fromJson(baseJson(30, 30));
      expect(sub.totalAmount, 30.0);
      expect(sub.dailyAmount, 1.0);
      expect(sub.days, 30);
    });

    test('小数形态保持不变', () {
      final sub = Subscription.fromJson(baseJson(29.9, 30));
      expect(sub.totalAmount, 29.9);
      expect(sub.dailyAmount, closeTo(0.9966, 0.0001));
    });
  });
}
