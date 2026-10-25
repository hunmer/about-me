import 'dart:convert';

import 'package:aboutme/plugins/chat/models/file_message.dart';
import 'package:aboutme/plugins/chat/models/message.dart';

/// 消息内容解析工具：Quill/纯文本/Markdown 识别与列表预览占位
class MessageContentUtils {
  /// 剥离模型内联输出的 `<think>` 思考块，仅保留可见正文。
  static String stripThinkContent(String content) {
    final thinkPattern = RegExp(
      r'<think>[\s\S]*?(?:</think>|$)',
      caseSensitive: false,
    );
    return content.replaceAll(thinkPattern, '').trim();
  }

  /// 内容解析结果缓存：key 为原始 content，
  /// 避免气泡/列表每次重建（如选中态切换）都重复 jsonDecode 与正则检测
  static final Map<String, (bool, String, bool)> _resolveCache = {};
  static const int _maxCacheEntries = 300;

  /// 返回 (是否纯文本, 提取的文本, 是否含 Markdown)
  static (bool, String, bool) resolveContent(String content) {
    final visibleContent = stripThinkContent(content);
    final cached = _resolveCache[visibleContent];
    if (cached != null) return cached;

    final isPlain = _isPlainText(visibleContent);
    final text = _extractPlainText(visibleContent);
    final result = (isPlain, text, isPlain && containsMarkdown(text));

    if (_resolveCache.length >= _maxCacheEntries) {
      _resolveCache.remove(_resolveCache.keys.first);
    }
    _resolveCache[visibleContent] = result;
    return result;
  }

  /// 判断内容是否为纯文本（没有任何 Quill 格式）
  static bool _isPlainText(String content) {
    if (content.isEmpty) return true;

    try {
      // 尝试解析为 JSON
      final json = jsonDecode(content);

      // 检查是否为 Quill Delta 格式
      if (json is! List) return true;

      // 遍历所有操作
      for (var op in json) {
        if (op is! Map<String, dynamic>) continue;

        // 检查是否有格式属性
        if (op.containsKey('attributes')) {
          final attributes = op['attributes'];
          if (attributes != null &&
              attributes is Map &&
              attributes.isNotEmpty) {
            return false; // 包含格式属性，不是纯文本
          }
        }

        // 检查 insert 的内容类型
        if (op.containsKey('insert')) {
          final insert = op['insert'];
          // 如果 insert 是 Map（如嵌入的图片、视频等），不是纯文本
          if (insert is Map) {
            return false;
          }
        }
      }

      return true; // 没有任何格式属性，是纯文本
    } catch (e) {
      // JSON 解析失败，说明是纯文本
      return true;
    }
  }

  /// 从 Quill Delta 格式中提取纯文本内容（非 JSON 内容原样返回）
  static String _extractPlainText(String content) {
    try {
      final json = jsonDecode(content);
      if (json is! List) return content;

      final buffer = StringBuffer();
      for (var op in json) {
        if (op is Map<String, dynamic> && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          }
        }
      }

      return buffer.toString();
    } catch (e) {
      return content;
    }
  }

  /// 常见 Markdown 语法的正则表达式（只编译一次）
  static final List<RegExp> _markdownPatterns = [
    RegExp(r'^#{1,6}\s', multiLine: true), // 标题: # ## ###
    RegExp(r'\*\*[^*]+\*\*'), // 粗体: **text**
    RegExp(r'__[^_]+__'), // 粗体: __text__
    RegExp(r'(?<!\*)\*(?!\*)[^*]+\*(?!\*)'), // 斜体: *text*
    RegExp(r'(?<!_)_(?!_)[^_]+_(?!_)'), // 斜体: _text_
    RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), // 链接: [text](url)
    RegExp(r'!\[([^\]]*)\]\(([^)]+)\)'), // 图片: ![alt](url)
    RegExp(r'`[^`]+`'), // 行内代码: `code`
    RegExp(r'```[\s\S]*?```', multiLine: true), // 代码块: ```code```
    RegExp(r'^>\s', multiLine: true), // 引用: > text
    RegExp(r'^[-*+]\s', multiLine: true), // 无序列表: - * +
    RegExp(r'^\d+\.\s', multiLine: true), // 有序列表: 1. 2.
    RegExp(r'^---+$', multiLine: true), // 水平线: ---
    RegExp(r'^\*\*\*+$', multiLine: true), // 水平线: ***
  ];

  /// 检测文本是否包含 Markdown 语法
  static bool containsMarkdown(String text) {
    for (final pattern in _markdownPatterns) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }

  /// 会话列表最后一条消息预览：
  /// 图片/音频/视频按类型占位，Markdown 前置标记，其余显示纯文本
  static String previewText(Message message) {
    final raw = message.metadata?[Message.metadataKeyFileInfo];
    if (raw != null) {
      switch (FileMessage.fromJson(Map<String, dynamic>.from(raw)).type) {
        case FileMessageType.image:
          return '[图片]';
        case FileMessageType.audio:
          return '[音频]';
        case FileMessageType.video:
          return '[视频]';
        case FileMessageType.document:
        case FileMessageType.other:
          return '[文件]';
      }
    }

    final (_, text, hasMarkdown) = resolveContent(message.content);
    return hasMarkdown ? '[markdown] $text' : text;
  }
}
