import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'book_cover.dart';
import 'book_detail_page.dart';
import 'demo_books.dart';

/// AI-Picks for You —— 复刻《收藏到 Pins by you》DEMO 首页
///
/// 双列错落封面网格 + 底部悬浮胶囊导航；手绘纸墨风（design.md §9）。
class AiPicksDemoScreen extends StatelessWidget {
  const AiPicksDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = AppTheme.of(context);
          return Scaffold(
            backgroundColor: theme.background,
            body: SafeArea(
              child: Stack(
                children: [
                  _AiPicksHomeContent(theme: theme),
                  const _FloatingNav(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AiPicksHomeContent extends StatelessWidget {
  const _AiPicksHomeContent({required this.theme});

  final AppThemeData theme;

  @override
  Widget build(BuildContext context) {
    // 双列分发，制造错落瀑布流
    final left = <DemoBook>[];
    final right = <DemoBook>[];
    for (var i = 0; i < demoBooks.length; i++) {
      (i.isEven ? left : right).add(demoBooks[i]);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题行：大标题 + 右侧过滤钮
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'AI-Picks for You',
                    style: DsTypography.display.copyWith(color: theme.text),
                  ),
                ),
                DSIconButton(
                  icon: DsIconKind.tune,
                  size: 38,
                  color: theme.surface,
                  iconColor: theme.text,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildColumn(context, left, 0)),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _buildColumn(context, right, 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColumn(BuildContext context, List<DemoBook> books, int column) {
    return Column(
      children: [
        for (var i = 0; i < books.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _BookCard(
              book: books[i],
              seed: column * 31 + i + 1,
              rotation: ((column + i) % 2 == 0) ? -0.025 : 0.02,
              onTap: () => BookDetailPage.open(context, books[i]),
            ),
          ),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.seed,
    required this.rotation,
    required this.onTap,
  });

  final DemoBook book;
  final int seed;
  final double rotation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedScale(
          scale: pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          child: Transform.rotate(
            angle: rotation,
            child: Container(
              decoration: dsSketchDecoration(
                theme: theme,
                radius: DsRadii.md,
                seed: seed,
              ),
              child: ClipRRect(
                borderRadius: DsRadii.md,
                child: AspectRatio(
                  aspectRatio: 1 / book.aspect,
                  child: BookCover(style: book.cover),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 底部悬浮胶囊导航：墨底胶囊（首页/书库/我的）+ 圆形搜索钮
class _FloatingNav extends StatelessWidget {
  const _FloatingNav();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Positioned(
      left: 26,
      right: 26,
      bottom: MediaQuery.paddingOf(context).bottom + 8,
      child: Row(
        children: [
          JellyBox(
            color: theme.text,
            radius: DsRadii.pill,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Row(
              children: [
                DsIcon(DsIconKind.home, size: 22, color: theme.surface),
                const SizedBox(width: 26),
                DsIcon(DsIconKind.book, size: 22, color: theme.surface),
                const SizedBox(width: 26),
                DsIcon(DsIconKind.user, size: 22, color: theme.surface),
              ],
            ),
          ),
          const Spacer(),
          JellyBox(
            color: theme.text,
            radius: DsRadii.circle,
            width: 54,
            height: 54,
            alignment: Alignment.center,
            child: DsIcon(DsIconKind.search, size: 22, color: theme.surface),
          ),
        ],
      ),
    );
  }
}
