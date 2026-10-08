import 'package:get/get.dart';
import 'widget_translations_zh.dart';
import 'widget_translations_en.dart';

/// Widget common components internationalization translation
class WidgetTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'zh_CN': zhCN,
        'en_US': enUS,
      };
}
