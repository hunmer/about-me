import 'dart:convert';
import 'dart:io';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

/// 超过此大小（字节）的文本只展示开头部分，避免大文件整页卡顿
const int _maxTextBytes = 512 * 1024;

/// 手绘风只读文本文件查看页：轻量顶栏 + 纸面卡片正文（可选中复制）
class TextFileViewer extends StatefulWidget {
  const TextFileViewer({super.key, required this.file});

  final File file;

  @override
  State<TextFileViewer> createState() => _TextFileViewerState();
}

class _TextFileViewerState extends State<TextFileViewer> {
  String? _content;
  bool _truncated = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final truncated = bytes.length > _maxTextBytes;
      final slice = truncated ? bytes.sublist(0, _maxTextBytes) : bytes;
      // utf8 容错解码（allowMalformed 兜底非法字节），极少失败时回退 latin1
      final text = utf8.decode(slice, allowMalformed: true);
      if (!mounted) return;
      setState(() {
        _content = text;
        _truncated = truncated;
      });
    } catch (e) {
      debugPrint('Text file read error: $e');
      if (mounted) {
        setState(() => _error = e.toString());
        Toast.error('data_management_fileReadFailed'.tr);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return Scaffold(
            backgroundColor: dsScaffoldBackground(theme),
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  DSLightHeader(title: path.basename(widget.file.path)),
                  Expanded(child: _buildBody(context, theme)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppThemeData theme) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.xl),
          child: Text(
            'data_management_fileReadFailed'.tr,
            textAlign: TextAlign.center,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ),
      );
    }

    final content = _content;
    if (content == null) {
      return Center(child: DSLoadingDots());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.lg,
        theme.spacing.md,
        theme.spacing.lg,
        theme.spacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: DsSketchPanel(
        theme: theme,
        // 纯纸底 + 墨线框（关闭排线，避免淡彩排线干扰正文阅读）
        hachure: false,
        radius: theme.radii.xl,
        padding: EdgeInsets.all(theme.spacing.lg),
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content,
                style: DsTypography.body.copyWith(
                  color: theme.text,
                  height: 1.6,
                ),
              ),
              if (_truncated) ...[
                SizedBox(height: theme.spacing.md),
                Text(
                  'data_management_textTruncated'.tr,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
