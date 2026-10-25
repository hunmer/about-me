import 'package:flutter/material.dart';

import 'wave_data.dart';

/// 深色语音备忘录卡片（demo 与 chat 音频消息共用）
class VoiceMemoCard extends StatelessWidget {
  /// 标题行左侧灰字（如发送者名）
  final String title;

  /// 标题行白色描述；null 时只显示 title
  final String? subtitle;

  /// 波形每根音柱高度
  final List<int> waveHeights;

  /// 已播放的音柱根数（0 ~ waveHeights.length）
  final int progress;

  /// true 显示暂停图标（播放中），false 显示播放图标
  final bool showPause;

  final bool bookmarked;

  final VoidCallback? onTogglePlay;

  /// null 时隐藏书签按钮
  final VoidCallback? onToggleBookmark;

  /// 点击波形按根数跳转
  final ValueChanged<int>? onSeek;

  const VoiceMemoCard({
    super.key,
    required this.title,
    this.subtitle,
    this.waveHeights = audioUiWaveHeights,
    required this.progress,
    required this.showPause,
    this.bookmarked = false,
    this.onTogglePlay,
    this.onToggleBookmark,
    this.onSeek,
  });

  void _handleSeek(TapDownDetails details, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final ratio = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
    onSeek?.call((ratio * waveHeights.length).round());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2D),
        borderRadius: BorderRadius.circular(21),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 14.5, color: Color(0xFF98989D))),
              if (subtitle != null) ...[
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, color: Color(0xFFF2F2F7)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (waveContext, constraints) {
                    // 自然宽度 = 70 * 2 + 69 * 2.2，窄屏时等比缩小防止溢出
                    final naturalWidth = waveHeights.length * 2.0 + (waveHeights.length - 1) * 2.2;
                    final scale = constraints.maxWidth >= naturalWidth
                        ? 1.0
                        : constraints.maxWidth / naturalWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: onSeek == null ? null : (d) => _handleSeek(d, waveContext),
                      child: SizedBox(
                        height: 28,
                        child: Row(
                          children: [
                            for (var i = 0; i < waveHeights.length; i++) ...[
                              if (i > 0) SizedBox(width: 2.2 * scale),
                              Container(
                                width: 2 * scale,
                                height: waveHeights[i].toDouble(),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: i < progress ? Colors.white : const Color(0xFF6E6E73),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (onToggleBookmark != null) ...[
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: onToggleBookmark,
                  child: Icon(
                    bookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 18,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
              ],
              const SizedBox(width: 18),
              GestureDetector(
                onTap: onTogglePlay,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Icon(
                    showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
