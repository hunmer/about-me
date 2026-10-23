import 'package:aboutme_data_sdk/examples.dart' as templates;
import 'models/diary_entry.dart';

// 兼容纯数据模板消费者；示例初始化通过 SDK seedExamples 执行。
class DiarySampleData {
  static List<DiaryEntry> getSampleDiaryEntries() => templates.DiarySampleData.getSampleDiaryEntries()
      .map((entry) => DiaryEntry.fromJson(entry.toJson())).toList();
}
