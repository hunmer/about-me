import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'models/route_context.dart';

/// 路由解析器
///
/// 负责将路由信息转换为人类可读的上下文描述
class RouteParser {
  /// 路由解释模板映射表
  ///
  /// 键：路由名称
  /// 值：解释文本模板，支持 {参数名} 占位符
  static const Map<String, String> _routeTemplates = {
    // 核心路由
    '/': '用户位于首页',
    '/settings': '用户正在设置页面',

    // 日记插件
    '/diary': '用户正在查看日记列表',
    '/diary_detail': '用户正在查看 {date} 的日记',
    '/diary_edit': '用户正在编辑 {date} 的日记',

    // 待办插件
    '/todo': '用户正在查看待办事项',
    '/todo_list': '用户正在查看待办事项列表（{taskCount} 个任务，{viewMode} 视图）',
    '/todo_list_search': '用户正在搜索待办事项：{searchQuery}（找到 {resultCount} 个结果）',
    '/todo_history': '用户正在查看已完成的待办历史记录（共 {completedCount} 个）',
    '/todo_detail': '用户正在查看待办任务：{taskTitle}（ID: {taskId}，状态: {taskStatus}）',
    '/todo_form_new': '用户正在新建待办任务',
    '/todo_form_edit': '用户正在编辑待办任务：{taskTitle}（ID: {taskId}）',

    // 账单插件
    '/bill': '用户正在查看账单',
    '/bill_list': '用户正在查看 {date} 的账单列表',
    '/bill_stats': '用户正在分析 {month} 的账单统计',
    '/bill_create': '用户正在新建账单',
    '/bill_edit': '用户正在编辑账单 {billId}',
    '/bill_subscriptions': '用户正在管理订阅服务',
    '/bill_subscription_create': '用户正在新建订阅',
    '/bill_subscription_edit': '用户正在编辑订阅 {subscriptionId}',
    '/bill_accounts': '用户正在管理账单账户',

    // 日历插件
    '/calendar': '用户正在查看日历',
    '/calendar_main': '用户正在查看日历 - {viewMode}（{timeRange}）',
    '/calendar_event_list': '用户正在查看所有日历事件（共 {totalCount} 个事件）',
    '/calendar_event_detail': '用户正在查看事件详情：{eventTitle}（ID: {eventId}，日期: {startDate}）',
    '/calendar_event_new': '用户正在新建日历事件',
    '/calendar_event_edit': '用户正在编辑日历事件：{eventTitle}（ID: {eventId}）',

    // AI插件
    '/agent_chat': '用户正在使用AI对话',
    '/openai': '用户正在管理AI助手',

    // 活动插件
    '/activity': '用户正在查看活动记录',
    '/activity_timeline': '用户正在查看 {date} 的活动时间轴',

    // 其他插件
    '/tracker': '用户正在查看目标追踪',
    '/habits': '用户正在查看习惯管理',
    '/habits_list': '用户正在查看习惯列表',
    '/skills_list': '用户正在查看技能列表',
    '/habit_form': '用户正在{mode}习惯（{habitTitle}）',
    '/skill_form': '用户正在{mode}技能（{skillTitle}）',
    '/habit_timer': '用户正在为习惯 {habitTitle} 计时',
    '/skill_detail': '用户正在查看技能 {skillTitle} 的{tab}',
    '/notes': '用户正在查看笔记',
    '/notes_list': '用户正在查看笔记列表 - {folderName}',
    '/note_edit': '用户正在编辑笔记 {noteTitle}',
    '/checkin': '用户正在查看打卡记录',
    '/checkin_list': '用户正在查看 {group} 分组的打卡列表',
    '/checkin_stats': '用户正在查看打卡统计',
    '/checkin_form_new': '用户正在新建打卡项目',
    '/checkin_form_edit': '用户正在编辑打卡项目 {itemName}',
    '/checkin_record': '用户正在查看 {itemName} 的打卡记录',
    '/contact': '用户正在查看联系人',
    '/goods': '用户正在查看商品管理',
    '/goods/warehouses': '用户正在查看所有仓库列表',
    '/goods/warehouse_detail': '用户正在查看仓库: {warehouseName}',
    '/goods/items_all': '用户正在查看所有物品列表',
    '/goods/items_filtered': '用户正在查看仓库 {warehouseName} 的物品列表',
    '/goods/item_history': '用户正在查看物品 {itemName} 的使用记录',
    '/goods/item_form': '用户正在编辑物品: {itemName}',
    '/goods/item_dialog_edit': '用户正在编辑物品: {itemName}',
    '/goods/item_dialog_new': '用户正在创建新物品',
    '/media_log': '用户正在查看媒体记录（共 {itemCount} 条）',
    '/media_log/detail': '用户正在查看媒体详情：{title}（{kind}，评分: {rating}）',
    '/chat': '用户正在查看聊天',
    '/chat/channels': '用户正在查看聊天频道列表',
    '/chat/timeline': '用户正在查看聊天时间线',
    '/chat/tags': '用户正在查看聊天标签',
    '/chat/channel': '用户正在 {channelName} 频道中聊天',
    '/chat/stats': '用户正在查看聊天统计',
    '/chat/timeline_walk': '用户正在随机漫游聊天时间线',
    '/calendar_album': '用户正在查看日历相册',
    '/calendar_album_calendar': '用户正在查看 {date} 的日历日记',
    '/calendar_album_entry_detail': '用户正在查看 {date} 的日记：{title}（ID: {entryId}）',
    '/calendar_album_tags': '用户正在查看标签管理（已选择 {tagCount} 个标签：{tags}）',
    '/calendar_album_album': '用户正在浏览相册（共 {photoCount} 张照片）',
    '/calendar_album_entry_editor': '用户正在{mode}日记：{title}（日期: {date}）',
    '/database': '用户正在查看自定义数据库',
    '/day': '用户正在查看日计划',
    '/day_list': '用户正在查看纪念日列表（共 {count} 个）',
    '/day_detail': '用户正在查看纪念日详情 - {title}（日期: {date}）',
    '/day_new': '用户正在新建纪念日',
    '/nodes': '用户正在查看知识库',
    '/scripts_center': '用户正在查看脚本中心',
    '/store': '用户正在查看商店',
    '/store/my_items': '用户正在查看我的物品（{itemCount} 件）',
    '/store/points_history': '用户正在查看积分历史（当前积分：{points}）',
    '/timer': '用户正在查看计时器',
    '/timer_main': '用户正在查看 {group} 分组的计时器列表',
    '/timer_details': '用户正在查看计时器任务 {taskName} 的详情（当前计时器: {currentTimerName}，状态: {isRunning}）',
    '/timer_edit': '用户正在{mode}计时器: {taskName}',
    '/tts': '用户正在设置文本转语音',
    '/rich_editor': '用户正在编辑富文本内容（{title}）',
    '/webview': '用户正在使用内置浏览器',
    '/nfc': '用户正在使用NFC功能',
  };

  /// 路由开场白映射表
  ///
  /// 键：路由名称（与 [_routeTemplates] 对齐）
  /// 值：该路由下打开聊天时的快捷开场白按钮列表
  static const Map<String, List<String>> _routeOpeningPrompts = {
    // 核心路由
    '/': ['总结一下我今天的整体情况', '今天有什么重要的事？'],

    // 日记插件
    '/diary': ['帮我写今天的日记', '分析我最近的日记心情'],
    '/diary_detail': ['总结这篇日记的要点', '帮我润色这篇日记'],
    '/diary_edit': ['帮我润色这篇日记', '给我的日记起个标题'],

    // 待办插件
    '/todo': ['总结我今天的待办情况', '帮我规划今天的任务'],
    '/todo_list': ['总结待办列表的完成情况', '帮我安排任务优先级'],
    '/todo_history': ['分析我已完成的任务', '总结我的任务完成效率'],
    '/todo_detail': ['帮我拆解这个任务', '分析这个任务的完成情况'],
    '/todo_form_new': ['帮我想想这个任务怎么拆解', '给这个任务设置个合理的截止时间'],

    // 账单插件
    '/bill': ['分析我最近的消费情况', '帮我记录一笔账单'],
    '/bill_list': ['分析这个月的账单明细', '找出可以节省的开销'],
    '/bill_stats': ['总结这个月的消费结构', '对比最近几个月的消费趋势'],
    '/bill_subscriptions': ['分析我的订阅支出', '哪些订阅可以取消？'],

    // 日历插件
    '/calendar': ['我今天有什么日程？', '帮我创建一个日程'],
    '/calendar_main': ['总结我近期的日程安排', '帮我规划本周的时间'],
    '/calendar_event_list': ['总结我所有的日程事件', '帮我找出空闲时间段'],
    '/calendar_event_detail': ['提醒我活动前的准备事项', '帮我分析这个日程安排是否合理'],

    // 活动插件
    '/activity': ['分析我今天的活动情况', '帮我记录新活动'],
    '/activity_timeline': ['分析这天的活动时间轴', '总结这天的活动分布'],

    // 其他插件
    '/tracker': ['分析我的目标进度', '帮我调整目标计划'],
    '/habits': ['分析我的习惯完成情况', '帮我制定习惯计划'],
    '/habits_list': ['总结习惯的坚持情况', '哪些习惯需要重点关注？'],
    '/skills_list': ['总结我的技能练习情况', '帮我制定练习计划'],
    '/skill_detail': ['分析这个技能的练习记录', '帮我规划下一步练习'],
    '/notes': ['帮我整理笔记', '总结我最近的笔记'],
    '/notes_list': ['总结这个文件夹的笔记', '帮我归类整理这些笔记'],
    '/note_edit': ['帮我润色这篇笔记', '给这篇笔记提炼要点'],
    '/checkin': ['分析我的打卡情况', '总结最近打卡的规律'],
    '/checkin_list': ['分析这个分组的打卡情况', '哪些项目容易忘记打卡？'],
    '/checkin_stats': ['分析打卡统计数据', '总结我的打卡趋势'],
    '/checkin_record': ['分析这个项目的打卡记录', '给我一些坚持打卡的建议'],
    '/contact': ['帮我整理联系人', '总结我的联系人构成'],
    '/goods': ['帮我盘点物品', '分析物品的使用频率'],
    '/goods/warehouses': ['总结各仓库的物品情况', '哪些物品需要补货？'],
    '/goods/items_all': ['分析物品的使用记录', '帮我清理闲置物品'],
    '/chat': ['总结最近的聊天记录', '帮我回顾重要对话'],
    '/chat/timeline': ['总结最近聊了什么', '帮我回顾聊天时间线'],
    '/chat/channel': ['总结这个频道的聊天内容', '帮我回顾重要消息'],
    '/chat/stats': ['总结我的聊天数据', '哪个频道最活跃？'],
    '/chat/timeline_walk': ['帮我回顾刚漫游到的消息', '总结这段聊天内容'],
    '/calendar_album': ['总结最近的日记相册', '帮我回顾这个月的记录'],
    '/calendar_album_calendar': ['分析这天的日记内容', '帮我回顾这天的记录'],
    '/calendar_album_album': ['帮我回顾相册里的照片', '总结照片记录的生活'],
    '/database': ['帮我分析数据库数据', '总结数据的整体情况'],
    '/day': ['总结最近的日计划完成情况', '帮我规划明天'],
    '/day_list': ['整理一下我的纪念日', '最近有什么纪念日要到了？'],
    '/day_detail': ['帮我回顾这个纪念日的意义', '为这个纪念日想句祝福'],
    '/nodes': ['总结我的知识库内容', '帮我梳理知识结构'],
    '/store': ['我还有多少积分？', '推荐一些值得兑换的商品'],
    '/store/my_items': ['总结一下我有哪些物品', '帮我看看哪些物品该用了'],
    '/store/points_history': ['分析我的积分收支', '最近积分变化大吗？'],
    '/rich_editor': ['帮我润色正在编辑的内容', '帮这段内容起个标题'],
    '/media_log': ['总结我的阅读观影记录', '推荐我下一部看/读什么'],
    '/media_log/detail': ['帮我写一条短评', '总结这条记录的点评'],
    '/timer': ['分析我的计时使用情况', '帮我总结时间开销'],
    '/timer_main': ['总结这组计时器的使用情况', '分析我的时间分配'],
    '/timer_details': ['分析这个任务的计时情况', '总结这个任务的时间开销'],
  };

  /// 解析当前路由
  ///
  /// 从BuildContext中提取路由信息并转换为RouteContext对象
  /// 优先级：RouteHistoryManager（手动设置） > GetX 路由 > Flutter 原生路由
  static RouteContext parseRoute(BuildContext context) {
    try {
      String? routeName;
      dynamic arguments;

      // 最高优先级：使用 RouteHistoryManager 中手动设置的当前上下文
      // 这允许页面在不刷新的情况下更新上下文信息
      final currentContext = RouteHistoryManager.getCurrentContext();
      if (currentContext != null) {
        routeName = currentContext.pageId;
        arguments = currentContext.params;
        debugPrint('RouteParser: 使用 RouteHistoryManager 上下文 - route: $routeName, args: $arguments');
      }

      // 第二优先级：使用 GetX 路由信息
      if (routeName == null || routeName.isEmpty || routeName == '/') {
        if (Get.routing.current.isNotEmpty) {
          routeName = Get.routing.current;
          // GetX 的路由参数通过 Get.arguments 获取
          arguments = Get.arguments;
          debugPrint('RouteParser: 使用 GetX 路由信息 - route: $routeName, args: $arguments');
        }
      }

      // 第三优先级：回退到 Flutter 原生路由
      if (routeName == null || routeName.isEmpty || routeName == '/') {
        final route = ModalRoute.of(context)?.settings;
        final fallbackRouteName = route?.name;
        final fallbackArguments = route?.arguments;

        // 只有当找到了有效的路由时才覆盖
        if (fallbackRouteName != null && fallbackRouteName.isNotEmpty) {
          routeName = fallbackRouteName;
          arguments ??= fallbackArguments;
          debugPrint('RouteParser: 回退到原生路由 - route: $routeName, args: $arguments');
        }
      }

      // 确保至少有一个有效的路由名称
      routeName ??= '/';

      // /plugin/{id} 形式的路由（openPlugin 推入，如 /plugin/store）
      // 去掉前缀后按子路由模板匹配（/plugin/store → /store）
      if (!_routeTemplates.containsKey(routeName) &&
          routeName.startsWith('/plugin/')) {
        final subRoute = '/${routeName.substring('/plugin/'.length)}';
        if (_routeTemplates.containsKey(subRoute)) {
          routeName = subRoute;
        }
      }

      // 获取路由模板
      String description = _routeTemplates[routeName] ?? '用户正在查看：$routeName';

      // 处理参数替换
      if (arguments != null && arguments is Map<String, dynamic>) {
        description = _replaceParameters(description, arguments);
      }

      return RouteContext(
        routeName: routeName,
        arguments: arguments,
        description: description,
      );
    } catch (e) {
      // 解析失败时返回默认描述
      debugPrint('路由解析失败: $e');
      return const RouteContext(routeName: '/', description: '用户正在使用应用');
    }
  }

  /// 替换描述文本中的参数占位符
  ///
  /// 将 {参数名} 替换为实际值，如果参数不存在则替换为 [未知]
  static String _replaceParameters(
    String template,
    Map<String, dynamic> arguments,
  ) {
    String result = template;

    // 提取所有占位符 {xxx}
    final placeholderPattern = RegExp(r'\{(\w+)\}');
    final matches = placeholderPattern.allMatches(template);

    for (final match in matches) {
      final paramName = match.group(1)!;
      final paramValue = arguments[paramName];

      if (paramValue != null) {
        result = result.replaceAll('{$paramName}', paramValue.toString());
      } else {
        // 参数不存在，使用友好提示
        result = result.replaceAll('{$paramName}', '[未知]');
      }
    }

    return result;
  }

  /// 检查路由是否已注册
  static bool isRouteRegistered(String routeName) {
    return _routeTemplates.containsKey(routeName);
  }

  /// 获取路由对应的开场白列表
  ///
  /// 兼容 `/plugin/{id}` 形式的路由（如 `/plugin/activity` 会尝试匹配 `/activity`）。
  /// 未匹配时返回空列表。
  static List<String> getOpeningPrompts(String routeName) {
    final prompts = _routeOpeningPrompts[routeName];
    if (prompts != null) {
      return prompts;
    }

    // /plugin/{pluginId} 形式的路由，去掉前缀后再匹配
    if (routeName.startsWith('/plugin/')) {
      final subRoute = '/${routeName.substring('/plugin/'.length)}';
      return _routeOpeningPrompts[subRoute] ?? const [];
    }

    return const [];
  }
}
