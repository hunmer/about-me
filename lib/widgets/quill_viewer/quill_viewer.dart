import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';

import 'package:aboutme/design_system/design_system.dart';

/// Quill 内容查看器（只读模式）
/// 用于显示 Quill Delta 格式的内容
class QuillViewer extends StatelessWidget {
  /// 内容数据，支持 JSON Delta 格式或纯文本
  final String data;

  /// 是否可选择文本
  final bool selectable;

  /// 自定义样式
  final quill.DefaultStyles? customStyles;

  const QuillViewer({
    super.key,
    required this.data,
    this.selectable = true,
    this.customStyles,
  });

  quill.Document _parseDocument() {
    if (data.isEmpty) {
      return quill.Document();
    }

    try {
      // 尝试解析 JSON Delta 格式
      final json = jsonDecode(data);
      return quill.Document.fromJson(json);
    } catch (e) {
      // 如果不是 JSON，作为纯文本处理
      final document = quill.Document();
      document.insert(0, data);
      return document;
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final document = _parseDocument();
      final controller = quill.QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );

      // Quill 的默认文本样式（paragraph/标题/列表等）派生自环境
      // DefaultTextStyle——这里强制合并手写字体，宿主树无论怎么覆盖
      // 都保持手绘风（代码块保留 Quill 内置等宽字体）
      return DefaultTextStyle.merge(
        style: const TextStyle(
          fontFamily: DsTypography.sketchFamily,
          fontFamilyFallback: ['PingFang SC', 'Microsoft YaHei'],
        ),
        child: IntrinsicWidth(
          child: quill.QuillEditor.basic(
            controller: controller,
            config: quill.QuillEditorConfig(
              padding: EdgeInsets.zero,
              customStyles: customStyles,
              embedBuilders: kIsWeb
                  ? FlutterQuillEmbeds.editorWebBuilders()
                  : FlutterQuillEmbeds.editorBuilders(),
            ),
          ),
        ),
      );
    } catch (e) {
      // 如果渲染失败，显示纯文本（同样应用手写字体）
      final fallbackStyle = const TextStyle(
        fontSize: 14,
        fontFamily: DsTypography.sketchFamily,
      );
      if (selectable) {
        return SelectableText(data, style: fallbackStyle);
      } else {
        return Text(
          data,
          style: fallbackStyle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        );
      }
    }
  }
}
