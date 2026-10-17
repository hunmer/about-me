import 'package:get/get.dart';

/// 商店商品分类：预设键集合，展示文案走 l10n（`store_categoryXxx`）
abstract final class StoreCategories {
  static const food = 'food';
  static const clothes = 'clothes';
  static const tech = 'tech';
  static const furniture = 'furniture';
  static const other = 'other';

  /// 预设分类键（编辑表单下拉选项顺序）
  static const List<String> preset = [
    food,
    clothes,
    tech,
    furniture,
    other,
  ];

  /// 分类键 → 展示文案（未知键原样返回）
  static String labelOf(String key) => switch (key) {
    food => 'store_categoryFood'.tr,
    clothes => 'store_categoryClothes'.tr,
    tech => 'store_categoryTech'.tr,
    furniture => 'store_categoryFurniture'.tr,
    other => 'store_categoryOther'.tr,
    _ => key,
  };

  /// 未分类文案
  static String get uncategorizedLabel => 'store_categoryUncategorized'.tr;
}
