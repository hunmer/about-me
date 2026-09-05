import 'package:get/get.dart';
import 'live2d_translations_zh.dart';
import 'live2d_translations_en.dart';
import 'live2d_translations_jp.dart';

/// Live2D插件GetX翻译类
class Live2DTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'zh_CN': live2dTranslationsZh,
        'en_US': live2dTranslationsEn,
        'ja_JP': live2dTranslationsJp,
      };
}
