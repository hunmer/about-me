import 'package:flutter/material.dart';

/// 笔记样式选择结果（标记色 / 背景风格 / 水印图标），
/// 供创建与编辑链路统一传递
class NoteStyleSelection {
  /// 标记色，null = 默认（跟随主题）
  Color? color;

  /// 背景填充风格（DsSketchFill 下标）
  int bgStyle;

  /// 右上角水印图标（DsIconKind 枚举名），null = 无
  String? icon;

  NoteStyleSelection({this.color, this.bgStyle = 0, this.icon});

  factory NoteStyleSelection.fromNote({
    required Color? color,
    required int bgStyle,
    required String? icon,
  }) {
    return NoteStyleSelection(color: color, bgStyle: bgStyle, icon: icon);
  }
}
