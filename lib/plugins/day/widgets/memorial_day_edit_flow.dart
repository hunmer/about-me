/// 纪念日编辑流程（供主页日卡与快速新建共用）
library;

import 'package:flutter/material.dart';
import 'package:aboutme/plugins/day/controllers/day_controller.dart';
import 'package:aboutme/plugins/day/models/memorial_day.dart';
import 'package:aboutme/plugins/day/widgets/edit_memorial_day_dialog.dart';

/// 共享的纪念日控制器
///
/// DayController 各实例独立从存储加载数据（与插件页做法一致），
/// 这里持有一个模块级实例，配合 reloadData 保持数据新鲜。
DayController? _sharedController;

DayController sharedDayController() => _sharedController ??= DayController();

/// 打开纪念日编辑页并处理保存/删除结果（与插件页 _showEditDialog 一致）
///
/// - [existing] 非空：编辑现有纪念日（保存→更新，删除→删除）
/// - [prefilled]：新建时的预填对象（如快速新建预置目标日期）
Future<void> openMemorialDayEditor(
  BuildContext context, {
  MemorialDay? existing,
  MemorialDay? prefilled,
}) async {
  final result = await Navigator.push<DialogResult>(
    context,
    MaterialPageRoute(
      builder: (context) =>
          EditMemorialDayPage(memorialDay: existing ?? prefilled),
    ),
  );
  if (result == null) return;

  final controller = sharedDayController();
  switch (result.action) {
    case DialogAction.save:
      if (result.memorialDay != null) {
        if (existing != null) {
          await controller.updateMemorialDay(result.memorialDay!);
        } else {
          await controller.addMemorialDay(result.memorialDay!);
        }
      }
      break;
    case DialogAction.delete:
      if (existing != null) {
        await controller.deleteMemorialDay(existing.id);
      }
      break;
    case DialogAction.cancel:
      break;
  }
}
