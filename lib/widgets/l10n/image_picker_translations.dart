import 'package:get/get.dart';
import 'image_picker_translations_zh.dart';
import 'image_picker_translations_en.dart';

/// ImagePicker component GetX translation class
class ImagePickerTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'zh_CN': imagePickerTranslationsZh,
        'en_US': imagePickerTranslationsEn,
      };
}
