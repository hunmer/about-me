import 'package:flutter/material.dart';
import 'package:aboutme/plugins/achievement/models/achievement_definition.dart';

/// 成就展览五大分类（对应设计文档一~五）
const List<AchievementCategory> kAchievementCategories = [
  AchievementCategory(id: 'ai', nameKey: 'achievement_category_ai', icon: Icons.smart_toy_outlined),
  AchievementCategory(id: 'life', nameKey: 'achievement_category_life', icon: Icons.edit_note),
  AchievementCategory(id: 'asset', nameKey: 'achievement_category_asset', icon: Icons.inventory_2_outlined),
  AchievementCategory(id: 'tool', nameKey: 'achievement_category_tool', icon: Icons.construction_outlined),
  AchievementCategory(id: 'overall', nameKey: 'achievement_category_overall', icon: Icons.emoji_events_outlined),
];

/// 74 个成就系列定义，数据与 docs/ACHIEVEMENT_SYSTEM_PLAN.md V3 表格一一对应。
/// [event] 非空的成就已接入事件总线实时计数；为 null 的成就等待后续数据源接入。
const List<AchievementDefinition> kAchievementDefinitions = [
  // ========== 一、AI 类 ==========
  AchievementDefinition(id: 'A01', name: '千言万语', category: 'ai', condition: '累计发送频道消息', unit: '条', thresholds: [100, 1000, 10000, 50000, 100000], event: 'chat_message_sent'),
  AchievementDefinition(id: 'A02', name: '频道缔造者', category: 'ai', condition: '累计创建频道', unit: '个', thresholds: [1, 5, 10, 20, 50]),
  AchievementDefinition(id: 'A03', name: '标签管理员', category: 'ai', condition: '累计使用标签整理消息', unit: '次', thresholds: [10, 50, 200, 500]),
  AchievementDefinition(id: 'A04', name: '单频深耕', category: 'ai', condition: '单个频道累计消息', unit: '条', thresholds: [100, 500, 2000, 5000]),
  AchievementDefinition(id: 'A05', name: '促膝长谈', category: 'ai', condition: '累计 AI 对话轮数', unit: '轮', thresholds: [10, 100, 500, 2000, 10000]),
  AchievementDefinition(id: 'A06', name: '声临其境', category: 'ai', condition: '累计语音通话', unit: '次', thresholds: [1, 10, 50, 200]),
  AchievementDefinition(id: 'A07', name: '工具大师', category: 'ai', condition: '累计触发工具调用', unit: '次', thresholds: [10, 100, 500, 2000]),
  AchievementDefinition(id: 'A08', name: '点将台', category: 'ai', condition: '累计创建 AIAgent', unit: '个', thresholds: [1, 5, 10, 30]),
  AchievementDefinition(id: 'A09', name: '预设玩家', category: 'ai', condition: '累计创建 PromptPreset', unit: '个', thresholds: [3, 10, 30, 50]),
  AchievementDefinition(id: 'A10', name: '朋友圈原住民', category: 'ai', condition: '累计发布 moments 动态', unit: '条', thresholds: [1, 10, 100, 500]),
  AchievementDefinition(id: 'A11', name: '赛博知己', category: 'ai', condition: '累计收到 AI 主动消息', unit: '条', thresholds: [1, 50, 500, 2000], hidden: true),
  AchievementDefinition(id: 'A12', name: '伙伴收藏家', category: 'ai', condition: '收藏 Live2D 模型', unit: '个', thresholds: [1, 3, 5, 10]),
  AchievementDefinition(id: 'A13', name: '播报员', category: 'ai', condition: 'Live2D 气泡 TTS 播报', unit: '次', thresholds: [10, 100, 500]),

  // ========== 二、记录与生活类 ==========
  AchievementDefinition(id: 'A14', name: '笔耕不辍', category: 'life', condition: '累计写日记', unit: '篇', thresholds: [1, 7, 30, 100, 365], event: 'diary_entry_created'),
  AchievementDefinition(id: 'A15', name: '习惯成自然', category: 'life', condition: '最长连续写日记', unit: '天', thresholds: [3, 7, 30, 100, 365]),
  AchievementDefinition(id: 'A16', name: '长篇大论', category: 'life', condition: '单篇日记最长字数', unit: '字', thresholds: [500, 1000, 2000, 5000]),
  AchievementDefinition(id: 'A17', name: '时间记录者', category: 'life', condition: '累计记录活动', unit: '个', thresholds: [1, 50, 200, 1000], event: 'activity_added'),
  AchievementDefinition(id: 'A18', name: '千时如梭', category: 'life', condition: '累计活动记录时长', unit: '小时', thresholds: [10, 100, 1000, 5000]),
  AchievementDefinition(id: 'A19', name: '标签收藏家', category: 'life', condition: '使用过的不同活动标签', unit: '个', thresholds: [5, 10, 30, 50]),
  AchievementDefinition(id: 'A20', name: '习惯成瘾', category: 'life', condition: '单个习惯最长连续打卡', unit: '天', thresholds: [7, 30, 100, 365]),
  AchievementDefinition(id: 'A21', name: '技能点满', category: 'life', condition: '累计获得技能点', unit: '点', thresholds: [10, 100, 500, 2000]),
  AchievementDefinition(id: 'A22', name: '多线操作', category: 'life', condition: '同时活跃的习惯', unit: '个', thresholds: [3, 5, 10, 20]),
  AchievementDefinition(id: 'A23', name: '百炼成钢', category: 'life', condition: '累计打卡', unit: '次', thresholds: [10, 100, 500, 1000, 5000], event: 'checkin_completed'),
  AchievementDefinition(id: 'A24', name: '全勤奖', category: 'life', condition: '单日完成全部打卡项', unit: '天', thresholds: [1, 10, 50, 100]),
  AchievementDefinition(id: 'A25', name: '建制完成', category: 'life', condition: '创建打卡项', unit: '个', thresholds: [3, 5, 10, 20]),
  AchievementDefinition(id: 'A26', name: '效率专家', category: 'life', condition: '累计完成任务', unit: '个', thresholds: [10, 100, 500, 2000, 10000], event: 'task_completed'),
  AchievementDefinition(id: 'A27', name: '今日事今日毕', category: 'life', condition: '单日完成任务数峰值', unit: '项', thresholds: [5, 10, 20]),
  AchievementDefinition(id: 'A28', name: '立志者', category: 'life', condition: '累计创建任务', unit: '个', thresholds: [50, 500, 2000]),
  AchievementDefinition(id: 'A29', name: '灵感收割机', category: 'life', condition: '累计创建笔记', unit: '篇', thresholds: [1, 50, 200, 1000], event: 'note_added'),
  AchievementDefinition(id: 'A30', name: '分门别类', category: 'life', condition: '创建笔记文件夹', unit: '个', thresholds: [3, 10, 20, 50]),
  AchievementDefinition(id: 'A31', name: '知识之树', category: 'life', condition: '累计创建节点', unit: '个', thresholds: [10, 100, 500, 2000]),
  AchievementDefinition(id: 'A32', name: '闭环完成', category: 'life', condition: '累计置为 done 的节点', unit: '个', thresholds: [10, 100, 500, 2000]),
  AchievementDefinition(id: 'A33', name: '富文本玩家', category: 'life', condition: '使用 Quill 富文本编辑', unit: '次', thresholds: [10, 100, 500]),
  AchievementDefinition(id: 'A34', name: '人生刻度', category: 'life', condition: '创建纪念日', unit: '个', thresholds: [1, 5, 10, 20]),
  AchievementDefinition(id: 'A35', name: '倒计时开始', category: 'life', condition: '纪念日进入 7 天倒计时', unit: '次', thresholds: [1, 10, 50]),
  AchievementDefinition(id: 'A36', name: '行程满档', category: 'life', condition: '累计创建日程事件', unit: '个', thresholds: [1, 50, 200, 1000]),
  AchievementDefinition(id: 'A37', name: '忙碌一周', category: 'life', condition: '单周日程事件数峰值', unit: '个', thresholds: [5, 10, 20, 30]),
  AchievementDefinition(id: 'A38', name: '定格瞬间', category: 'life', condition: '累计上传照片', unit: '张', thresholds: [1, 100, 500, 1000, 5000]),
  AchievementDefinition(id: 'A39', name: '标签相册', category: 'life', condition: '使用的不同照片标签', unit: '种', thresholds: [3, 10, 20]),
  AchievementDefinition(id: 'A40', name: '不再遗忘', category: 'life', condition: '创建提醒', unit: '个', thresholds: [1, 10, 30, 100]),
  AchievementDefinition(id: 'A41', name: '守时主义', category: 'life', condition: '按时处理的提醒', unit: '次', thresholds: [10, 50, 200]),

  // ========== 三、物品与账务类 ==========
  AchievementDefinition(id: 'A42', name: '持家有道', category: 'asset', condition: '累计记账', unit: '笔', thresholds: [1, 100, 1000, 5000], event: 'bill_added'),
  AchievementDefinition(id: 'A43', name: '连续记账', category: 'asset', condition: '最长连续记账', unit: '天', thresholds: [7, 30, 100, 365]),
  AchievementDefinition(id: 'A44', name: '多账户玩家', category: 'asset', condition: '创建账户', unit: '个', thresholds: [2, 5, 10]),
  AchievementDefinition(id: 'A45', name: '百物图鉴', category: 'asset', condition: '累计登记物品', unit: '件', thresholds: [1, 100, 500, 1000, 5000], event: 'goods_item_added'),
  AchievementDefinition(id: 'A46', name: '分仓管理', category: 'asset', condition: '创建仓库', unit: '个', thresholds: [2, 3, 5, 10]),
  AchievementDefinition(id: 'A47', name: '物尽其用', category: 'asset', condition: '累计记录物品使用', unit: '次', thresholds: [10, 50, 200, 500]),
  AchievementDefinition(id: 'A48', name: '第一桶金', category: 'asset', condition: '累计获得积分总数', unit: '分', thresholds: [1000, 10000, 100000, 1000000]),
  AchievementDefinition(id: 'A49', name: '血拼达人', category: 'asset', condition: '累计兑换商品', unit: '次', thresholds: [1, 5, 20, 100]),
  AchievementDefinition(id: 'A50', name: '兑换图鉴', category: 'asset', condition: '兑换过的不同商品', unit: '种', thresholds: [5, 10, 20]),
  AchievementDefinition(id: 'A51', name: '高朋满座', category: 'asset', condition: '添加联系人', unit: '人', thresholds: [1, 50, 100, 300]),
  AchievementDefinition(id: 'A52', name: '保持联络', category: 'asset', condition: '累计记录互动', unit: '次', thresholds: [10, 50, 200, 1000]),
  AchievementDefinition(id: 'A53', name: '社交蝴蝶', category: 'asset', condition: '单个联系人累计互动', unit: '次', thresholds: [50, 100, 500], hidden: true),
  AchievementDefinition(id: 'A54', name: '旗开得胜', category: 'asset', condition: '完成（进度100%）的 Goal', unit: '个', thresholds: [1, 5, 10, 30]),
  AchievementDefinition(id: 'A55', name: '记录点滴', category: 'asset', condition: '累计添加 Record', unit: '条', thresholds: [10, 100, 500, 2000], event: 'onRecordAdded'),

  // ========== 四、工具与系统类 ==========
  AchievementDefinition(id: 'A56', name: '建库师', category: 'tool', condition: '创建数据库', unit: '个', thresholds: [1, 3, 5, 10]),
  AchievementDefinition(id: 'A57', name: '万条数据', category: 'tool', condition: '累计数据记录', unit: '条', thresholds: [100, 1000, 10000, 100000]),
  AchievementDefinition(id: 'A58', name: '全字段控', category: 'tool', condition: '单库使用的字段类型种数（共11种）', unit: '种', thresholds: [4, 8, 11]),
  AchievementDefinition(id: 'A59', name: '开始计时', category: 'tool', condition: '累计完成计时', unit: '次', thresholds: [1, 50, 200, 1000]),
  AchievementDefinition(id: 'A60', name: '万分钟专注', category: 'tool', condition: '累计计时时长', unit: '分钟', thresholds: [100, 1000, 10000, 50000]),
  AchievementDefinition(id: 'A61', name: '播音员', category: 'tool', condition: '累计 TTS 朗读', unit: '次', thresholds: [1, 50, 200, 1000]),
  AchievementDefinition(id: 'A62', name: '三通道玩家', category: 'tool', condition: '使用过的 TTS 通道', unit: '种', thresholds: [1, 2, 3]),
  AchievementDefinition(id: 'A63', name: '一触即发', category: 'tool', condition: '累计 NFC 刷卡触发', unit: '次', thresholds: [1, 50, 200, 1000]),
  AchievementDefinition(id: 'A64', name: '标签工程师', category: 'tool', condition: '累计写入 NFC 标签', unit: '张', thresholds: [1, 5, 10, 20]),
  AchievementDefinition(id: 'A65', name: '冲浪起点', category: 'tool', condition: '累计访问网页', unit: '页', thresholds: [1, 100, 1000]),
  AchievementDefinition(id: 'A66', name: '网址收藏夹', category: 'tool', condition: '保存网址卡片', unit: '张', thresholds: [5, 20, 50]),
  AchievementDefinition(id: 'A67', name: '多线程浏览', category: 'tool', condition: '同时打开标签页数峰值', unit: '个', thresholds: [2, 5, 8]),
  AchievementDefinition(id: 'A68', name: 'Hello World', category: 'tool', condition: '累计运行脚本', unit: '次', thresholds: [1, 50, 200, 1000]),
  AchievementDefinition(id: 'A69', name: '脚本作者', category: 'tool', condition: '保存自制脚本', unit: '个', thresholds: [1, 5, 10, 30]),
  AchievementDefinition(id: 'A70', name: '效率革命', category: 'tool', condition: '单个脚本累计运行', unit: '次', thresholds: [50, 100, 500]),

  // ========== 五、跨插件综合 ==========
  AchievementDefinition(id: 'A71', name: '全能启动', category: 'overall', condition: '使用过（产生过数据）的插件', unit: '个', thresholds: [5, 10, 20, 26]),
  AchievementDefinition(id: 'A72', name: '全方位记录', category: 'overall', condition: '同一天产生日记+账单+待办+打卡四类记录', unit: '天', thresholds: [1, 10, 50]),
  AchievementDefinition(id: 'A73', name: '百日筑基', category: 'overall', condition: '连续产生任一记录', unit: '天', thresholds: [7, 30, 100, 365]),
  AchievementDefinition(id: 'A74', name: '深度玩家', category: 'overall', condition: '累计解锁的成就级数', unit: '级', thresholds: [10, 50, 100, 300]),
];

/// 按编号索引
final Map<String, AchievementDefinition> kAchievementById = {
  for (final def in kAchievementDefinitions) def.id: def,
};
