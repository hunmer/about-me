import 'dart:ui';

import 'package:aboutme/plugins/activity/models/activity_record.dart';
import 'package:aboutme/widgets/tags_dialog/models/models.dart';

/// 活动插件示例数据
/// 当插件的JSON文件不存在时，会自动加载这些默认数据
class ActivitySampleData {
  /// 获取默认标签分组
  static List<TagGroupWithTags> get defaultTagGroups => [
    // TagGroupWithTags.fromStringList(name: '工作', tags: ['会议', '编码', '文档', '评审', '规划', '沟通', '培训']),
  ];

  /// 获取默认最近使用的标签
  static List<String> get defaultRecentTags => [
    
  ];

  /// 获取默认最近使用的心情
  static List<String> get defaultRecentMoods => [
    '😊', // 开心
    '😌', // 满足
    '😴', // 疲惫
    '🤔', // 思考
    '😎', // 自信
    '😅', // 轻松
    '🙂', // 微笑
    '🤨', // 疑惑
    '😇', // 愉悦
    '🥱', // 困倦
  ];

  /// 获取示例活动记录（今日）
  /// 这些是用于演示的示例活动，会在用户首次使用时显示
  /// 使用相对日期，基于当前时间动态生成
  static List<ActivityRecord> getSampleActivities() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      // 示例活动1：晨间会议
      ActivityRecord(
        startTime: DateTime(today.year, today.month, today.day, 9, 0),
        endTime: DateTime(today.year, today.month, today.day, 10, 30),
        title: '晨间站会',
        tags: ['工作', '会议'],
        description: '每日团队站会，同步项目进度',
        mood: '😊',
        color: const Color(0xFF2196F3),
      ),
      // 示例活动2：编码工作
      ActivityRecord(
        startTime: DateTime(today.year, today.month, today.day, 10, 30),
        endTime: DateTime(today.year, today.month, today.day, 12, 0),
        title: '功能开发',
        tags: ['工作', '编码'],
        description: '实现用户管理模块的核心功能',
        mood: '😎',
        color: const Color(0xFF4CAF50),
      ),
      // 示例活动3：午餐时间
      ActivityRecord(
        startTime: DateTime(today.year, today.month, today.day, 12, 0),
        endTime: DateTime(today.year, today.month, today.day, 13, 0),
        title: '午餐',
        tags: ['生活', '吃饭'],
        description: '和同事一起在公司餐厅用餐',
        mood: '😌',
        color: const Color(0xFFFF9800),
      ),
      // 示例活动4：下午会议
      ActivityRecord(
        startTime: DateTime(today.year, today.month, today.day, 14, 0),
        endTime: DateTime(today.year, today.month, today.day, 15, 30),
        title: '需求评审会议',
        tags: ['工作', '会议', '评审'],
        description: '评审新版本的需求文档',
        mood: '🤔',
        color: const Color(0xFF2196F3),
      ),
      // 示例活动5：学习时间
      ActivityRecord(
        startTime: DateTime(today.year, today.month, today.day, 16, 0),
        endTime: DateTime(today.year, today.month, today.day, 17, 30),
        title: '学习Flutter新特性',
        tags: ['学习', '编程'],
        description: '学习Flutter 3.7的新功能和最佳实践',
        mood: '🙂',
        color: const Color(0xFF9C27B0),
      ),
      // 示例活动6：运动时间
      ActivityRecord(
        startTime: DateTime(today.year, today.month, today.day, 18, 30),
        endTime: DateTime(today.year, today.month, today.day, 19, 30),
        title: '跑步锻炼',
        tags: ['健康', '运动'],
        description: '在公园慢跑5公里',
        mood: '😅',
        color: const Color(0xFFF44336),
      ),
      // 示例活动7：晚餐
      ActivityRecord(
        startTime: DateTime(today.year, today.month, today.day, 20, 0),
        endTime: DateTime(today.year, today.month, today.day, 21, 0),
        title: '晚餐',
        tags: ['生活', '吃饭'],
        description: '在家做顿简单的晚餐',
        mood: '😌',
        color: const Color(0xFFFF9800),
      ),
      // 示例活动8：阅读
      ActivityRecord(
        startTime: DateTime(today.year, today.month, today.day, 21, 30),
        endTime: DateTime(today.year, today.month, today.day, 22, 30),
        title: '阅读技术书籍',
        tags: ['学习', '阅读'],
        description: '阅读《Flutter实战》第二版',
        mood: '😇',
        color: const Color(0xFF9C27B0),
      ),
    ];
  }

  /// 获取昨日的示例活动（用于演示）
  static List<ActivityRecord> getYesterdaySampleActivities() {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));

    return [
      ActivityRecord(
        startTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 9, 0),
        endTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 10, 0),
        title: '晨间规划',
        tags: ['工作', '规划'],
        description: '制定今日工作计划和目标',
        mood: '🙂',
        color: const Color(0xFF2196F3),
      ),
      ActivityRecord(
        startTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 10, 0),
        endTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 12, 0),
        title: '代码审查',
        tags: ['工作', '评审', '编码'],
        description: '审查团队成员提交的PR',
        mood: '🤨',
        color: const Color(0xFF4CAF50),
      ),
      ActivityRecord(
        startTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 14, 0),
        endTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 16, 0),
        title: '项目开发',
        tags: ['工作', '编码'],
        description: '继续开发用户管理功能',
        mood: '😎',
        color: const Color(0xFF4CAF50),
      ),
      ActivityRecord(
        startTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 19, 0),
        endTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 20, 0),
        title: '健身',
        tags: ['健康', '运动'],
        description: '在家进行力量训练',
        mood: '😅',
        color: const Color(0xFFF44336),
      ),
    ];
  }
}
