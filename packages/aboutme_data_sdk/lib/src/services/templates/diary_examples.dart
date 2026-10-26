import 'package:shared_models/shared_models.dart';

/// 日记插件的示例数据
class DiarySampleData {
  /// 获取示例日记条目
  static List<DiaryEntryDto> getSampleDiaryEntries() {
    final now = DateTime.now();

    return [
      DiaryEntryDto(
        date: DiaryCodec.formatDate(now.subtract(const Duration(days: 7))),
        title: '美好的一天',
        content: '''今天天气真好，阳光明媚。

早上起床后，我去公园晨跑。清新的空气让我感到神清气爽。跑完步后，在公园的长椅上坐了一会儿，看着来来往往的人们。

下午去了图书馆，看了一本很有趣的书。《人类简史》真的让我对历史有了新的认识。

晚上和朋友一起吃了晚餐，聊了很多有趣的话题。真是充实的一天！''',
        mood: 'happy', // 心情 id，取值见 shared_models 的 kDiaryMoodIds
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(days: 7)),
      ),
      DiaryEntryDto(
        date: DiaryCodec.formatDate(now.subtract(const Duration(days: 3))),
        title: '工作感想',
        content: '''今天项目终于上线了！

虽然过程很辛苦，但是看到成品运行起来，所有的努力都是值得的。团队里的每个人都付出了很多，我们互相支持、互相鼓励。

特别感谢我的导师，在这个项目中给了我很多指导。

明天要开始新的项目了，期待新的挑战！''',
        mood: 'excited',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      DiaryEntryDto(
        date: DiaryCodec.formatDate(now.subtract(const Duration(days: 1))),
        title: '雨天思绪',
        content: '''外面下着雨，淅淅沥沥的。

雨天总是让人变得多愁善感。泡了一杯热茶，坐在窗前看着雨滴。想起了很多往事。

有时候觉得，生活就像这雨，有时急有时缓。但不管怎样，雨后总会有彩虹。

希望明天是个好天气。''',
        mood: 'thinking',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      DiaryEntryDto(
        date: DiaryCodec.formatDate(now.subtract(const Duration(days: 5))),
        title: '周末聚会',
        content: '''今天是周末，和大学同学聚会。

大家聊起了过去的点点滴滴，仿佛又回到了那些年。时间过得真快，转眼间我们已经毕业五年了。

虽然大家都走上了不同的道路，但友谊依然如初。这大概就是最珍贵的财富吧。

期待下次的相聚！''',
        mood: 'hysterical',
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      DiaryEntryDto(
        date: DiaryCodec.formatDate(now.subtract(const Duration(days: 2))),
        title: '学习新技能',
        content: '''开始学习Flutter开发。

虽然是全新的领域，但很有挑战性。跟着教程一步一步来，慢慢理解了StatefulWidget和StatelessWidget的区别。

今天完成了第一个小应用，虽然很简单，但很有成就感。

继续加油！''',
        mood: 'cool',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}
