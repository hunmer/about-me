import 'package:flutter/material.dart';

/// 快速创建项定义
///
/// 插件注册后，用户在主页底部 ＋ 按钮弹出的对话框中选择对应项，
/// 即可打开该插件的编辑界面新建数据（日期预填主页当前选中日期）。
class QuickCreateItem {
  /// 唯一标识（格式建议：pluginId_itemName）
  final String id;

  /// 所属插件ID
  final String pluginId;

  /// 显示名称
  final String name;

  /// 图标
  final IconData icon;

  /// 主题色（可选，默认使用插件颜色）
  final Color? color;

  /// 创建回调：打开对应编辑界面
  ///
  /// [date] 为主页当前选中的日期，编辑界面应将其作为新数据的默认日期
  final void Function(BuildContext context, DateTime date) onCreate;

  const QuickCreateItem({
    required this.id,
    required this.pluginId,
    required this.name,
    required this.icon,
    this.color,
    required this.onCreate,
  });
}

/// 快速创建注册中心（单例）
///
/// 管理所有插件注册的可快速创建的数据类型，
/// 供主页底部的快速新建按钮使用。
class QuickCreateRegistry {
  // 单例模式
  static final QuickCreateRegistry _instance = QuickCreateRegistry._internal();
  factory QuickCreateRegistry() => _instance;
  QuickCreateRegistry._internal();

  /// 所有已注册的快速创建项（key: item.id）
  final Map<String, QuickCreateItem> _items = {};

  /// 注册一个快速创建项
  ///
  /// 如果已存在同ID的项，会覆盖
  void register(QuickCreateItem item) {
    _items[item.id] = item;
  }

  /// 注销一个快速创建项
  void unregister(String id) {
    _items.remove(id);
  }

  /// 获取所有快速创建项（按注册顺序）
  List<QuickCreateItem> get items => _items.values.toList(growable: false);

  /// 按插件ID获取
  List<QuickCreateItem> getByPlugin(String pluginId) {
    return _items.values.where((item) => item.pluginId == pluginId).toList();
  }

  /// 获取注册数量
  int get count => _items.length;
}
