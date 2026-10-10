import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/plugins/diary/models/diary_entry.dart';
import 'package:aboutme/plugins/diary/utils/diary_utils.dart';
import 'package:aboutme/plugins/diary/widgets/diary_mood_face.dart';

/// 搜索结果列表项：左侧心情圆 + 日期/标题/摘要/标签，
/// 与阅读态一致的主题色风格，点击进入日记
class DiarySearchResultTile extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;

  const DiarySearchResultTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 结果列表可能由搜索浮层渲染在主题树之外，用 resolve 永不抛错地取令牌
    final theme = DSThemeBridge.resolve(context);
    final dateStr = DateFormat.yMMMMd(
      Localizations.localeOf(context).toString(),
    ).format(entry.date);
    final plainText = DiaryUtils.contentToPlainText(entry.content).trim();
    final summary =
        plainText.isEmpty ? 'diary_emptyContent'.tr : plainText;
    final spec =
        entry.mood != null ? diaryMoodSpecOf(entry.mood!) : neutralMoodSpec;

    return Material(
      color: theme.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 心情圆（无心情为中性脸）
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 12),
                child: DiaryMoodFaceCircle(spec: spec, size: 40),
              ),

              // 日期 / 标题 / 摘要 / 标签
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: theme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.title.trim().isEmpty
                          ? 'diary_untitled'.tr
                          : entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: theme.textSub,
                      ),
                    ),
                    if (entry.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final tag in entry.tags.take(4))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme.surfaceAlt,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: theme.stroke),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.textSub,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // 字数徽标
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text(
                  '${plainText.length}${'diary_wordUnit'.tr}',
                  style: TextStyle(fontSize: 11, color: theme.textSub),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
