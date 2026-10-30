import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';

import 'package:aboutme/design_system/design_system.dart';

/// 自定义字间距属性 key（quill 无内置字间距，Delta 中以数字值记录）
const String kQuillLetterSpacingKey = 'letter-spacing';

/// quill 自定义样式映射：把字间距属性转成 TextStyle.letterSpacing，
/// 其余属性返回空样式（合并不影响原样式）。
/// 编辑器（rich_editor_screen）与只读查看器（QuillViewer）共用，
/// 保证编辑态所见与保存后阅读态一致。
TextStyle quillCustomStyleBuilder(quill.Attribute attribute) {
  if (attribute.key == kQuillLetterSpacingKey && attribute.value is num) {
    return TextStyle(letterSpacing: (attribute.value as num).toDouble());
  }
  return const TextStyle();
}

/// Quill 内容查看器（只读模式）
/// 用于显示 Quill Delta 格式的内容
class QuillViewer extends StatefulWidget {
  /// 内容数据，支持 JSON Delta 格式或纯文本
  final String data;

  /// 是否可选择文本
  final bool selectable;

  /// 自定义样式
  final quill.DefaultStyles? customStyles;

  /// 复选框勾选变化回调，参数为勾选后最新的 Delta JSON；
  /// 非 null 时复选框可点击切换（其余内容仍只读）
  final void Function(String data)? onCheckboxToggle;

  const QuillViewer({
    super.key,
    required this.data,
    this.selectable = true,
    this.customStyles,
    this.onCheckboxToggle,
  });

  @override
  State<QuillViewer> createState() => _QuillViewerState();
}

class _QuillViewerState extends State<QuillViewer> {
  quill.QuillController? _controller;
  StreamSubscription? _checkboxToggleSub;

  @override
  void initState() {
    super.initState();
    _controller = _buildController(widget.data);
    _listenCheckboxToggle();
  }

  @override
  void didUpdateWidget(covariant QuillViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onCheckboxToggle != oldWidget.onCheckboxToggle) {
      _listenCheckboxToggle();
    }
    if (widget.data != oldWidget.data) {
      _replaceDocument(widget.data);
    }
  }

  @override
  void dispose() {
    _checkboxToggleSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  quill.QuillController _buildController(String data) {
    try {
      final document = data.isEmpty
          ? quill.Document()
          : quill.Document.fromJson(jsonDecode(data));
      return quill.QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } catch (e) {
      // 如果不是 JSON，作为纯文本处理
      final document = quill.Document()..insert(0, data);
      return quill.QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    }
  }

  /// 勾选回写：只读编辑器里文档变更只可能来自复选框切换
  void _listenCheckboxToggle() {
    _checkboxToggleSub?.cancel();
    _checkboxToggleSub = null;
    final onToggle = widget.onCheckboxToggle;
    final controller = _controller;
    if (onToggle == null || controller == null) return;
    _checkboxToggleSub = controller.document.changes.listen((_) {
      onToggle(jsonEncode(controller.document.toDelta().toJson()));
    });
  }

  /// 外部数据更新时替换文档；内容未变化（如勾选回写后的同值重建）则跳过，
  /// 避免不必要的光标/滚动重置
  void _replaceDocument(String data) {
    final controller = _controller;
    if (controller == null) return;
    try {
      final document = quill.Document.fromJson(jsonDecode(data));
      final unchanged = jsonEncode(document.toDelta().toJson()) ==
          jsonEncode(controller.document.toDelta().toJson());
      if (!unchanged) {
        controller.document = document;
        // 变更流挂在 Document 实例上，换文档后需重新订阅勾选回写
        _listenCheckboxToggle();
      }
    } catch (e) {
      controller.document = quill.Document()..insert(0, data);
      _listenCheckboxToggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final controller = _controller;
      if (controller == null) {
        throw StateError('QuillViewer controller is not ready');
      }

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
              customStyles: widget.customStyles,
              // 渲染自定义字间距属性（与编辑态一致）
              customStyleBuilder: quillCustomStyleBuilder,
              // 只读查看器不显示输入光标
              showCursor: false,
              // 提供勾选回调时允许点击复选框（其余内容仍只读）
              checkBoxReadOnly: widget.onCheckboxToggle == null ? null : false,
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
      if (widget.selectable) {
        return SelectableText(widget.data, style: fallbackStyle);
      } else {
        return Text(
          widget.data,
          style: fallbackStyle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        );
      }
    }
  }
}
