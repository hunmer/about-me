import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/walk_stack_card.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

import 'controllers/timeline_controller.dart';

/// 时间线「随机漫步」页
///
/// 用时间线控制器当前过滤器（含搜索）的结果生成书摘卡片堆，
/// 随机洗牌后拖拽切卡漫游；消息中的 Markdown 图片与图片消息附件
/// 会被抽离为卡片边角的拍立得贴纸。
class TimelineWalkScreen extends StatefulWidget {
  final TimelineController controller;

  const TimelineWalkScreen({super.key, required this.controller});

  @override
  State<TimelineWalkScreen> createState() => _TimelineWalkScreenState();
}

class _TimelineWalkScreenState extends State<TimelineWalkScreen> {
  List<WalkStackCardData> _cards = [];
  int _seen = 0;

  /// Markdown 图片语法：![alt](path "title")
  static final RegExp _mdImage = RegExp(
    r'!\[[^\]]*\]\(\s*([^)\s]+)[^)]*\)',
  );

  @override
  void initState() {
    super.initState();
    _reshuffle();
  }

  /// 从当前过滤器结果重建卡片堆并随机洗牌
  void _reshuffle() {
    final cards = <WalkStackCardData>[];
    for (final message in widget.controller.filteredMessages) {
      final card = _cardFromMessage(message);
      if (card != null) cards.add(card);
    }
    cards.shuffle(math.Random());
    setState(() {
      _cards = cards;
      _seen = 0;
    });
  }

  WalkStackCardData? _cardFromMessage(Message message) {
    var text = message.content;

    // Quill Delta（JSON 数组）→ 拼接纯文本
    if (text.trimLeft().startsWith('[')) {
      try {
        final json = jsonDecode(text);
        if (json is List) {
          final buffer = StringBuffer();
          for (final op in json) {
            if (op is Map && op['insert'] is String) {
              buffer.write(op['insert'] as String);
            }
          }
          text = buffer.toString();
        }
      } catch (_) {
        // 非 JSON，按纯文本处理
      }
    }

    final images = <String>[];

    // 图片消息附件（fileInfo）→ 抽离为边角图片
    final fileInfo = message.metadata?[Message.metadataKeyFileInfo];
    if (fileInfo is Map) {
      if (fileInfo['type'] == 'image') {
        final path =
            fileInfo['path'] as String? ??
            fileInfo['filePath'] as String?;
        if (path != null && path.isNotEmpty) images.add(path);
      }
    }

    // Markdown 图片语法抽离（http/本地相对路径均可）
    text = text.replaceAllMapped(_mdImage, (match) {
      final url = match.group(1);
      if (url != null && url.isNotEmpty) images.add(url);
      return '';
    });
    text = text.trim();

    if (text.isEmpty && images.isEmpty) return null;

    final isFavorite = message.metadata?['isFavorite'] == true;
    final username = message.user.username;
    final channel = widget.controller.getMessageChannel(message);
    final signature = (username.isNotEmpty && username != 'Unknown User')
        ? username
        : (channel?.title ?? '');

    return WalkStackCardData(
      id: message.id,
      quote: text,
      signature: signature,
      stars: isFavorite ? 5 : 4,
      imagePaths: images,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return DSThemeBridge(
      child: SuperCupertinoNavigationWrapper(
        title: Text('chat_randomWalk'.tr),
        previousPageTitle: 'chat_timelineTab'.tr,
        enableLargeTitle: false,
        actions: [
          // actions 经 Overlay 渲染，DS 组件需自带 DSThemeBridge
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final t = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.refresh,
                  size: 36,
                  color: t.surface,
                  iconColor: t.text,
                  tooltip: 'chat_randomWalkReshuffle'.tr,
                  onPressed: _reshuffle,
                );
              },
            ),
          ),
        ],
        body: _cards.isEmpty
            ? Center(child: Text('chat_randomWalkEmpty'.tr))
            : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: WalkStackCardWidget(
                        cards: _cards,
                        randomMode: true,
                        onCardDismissed: (_) {
                          if (mounted) setState(() => _seen++);
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom + 12,
                    ),
                    child: Text(
                      'chat_randomWalkCount'.trParams({
                        'seen': '$_seen',
                        'total': '${_cards.length}',
                      }),
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
