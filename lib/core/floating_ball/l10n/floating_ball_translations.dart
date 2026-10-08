import 'package:get/get.dart';
import 'floating_ball_translations_zh.dart';
import 'floating_ball_translations_en.dart';

/// FloatingBall GetX translation class
class FloatingBallTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'zh_CN': floatingBallTranslationsZh,
        'en_US': floatingBallTranslationsEn,
      };
}
