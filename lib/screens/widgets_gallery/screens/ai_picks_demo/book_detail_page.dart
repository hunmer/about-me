import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'book_cover.dart';
import 'demo_books.dart';

/// 书籍详情页 —— 复刻《收藏到 Pins by you》DEMO 详情
///
/// 封面 + 标题/作者 + 页数/时长/评分 + Book Overview + 标签
/// + Books by This Author 横滑 + Reviews + 底部 Save / Start Reading。
class BookDetailPage extends StatelessWidget {
  const BookDetailPage({super.key, required this.book});

  final DemoBook book;

  /// 淡入 + 轻微缩放打开（对齐参考视频的过渡观感）
  static void open(BuildContext context, DemoBook book) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, _) => BookDetailPage(book: book),
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(curved), child: child),
          );
        },
      ),
    );
  }

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
                  _DetailScrollView(book: book, theme: theme),
                  const _TopBar(),
                  _BottomActions(theme: theme),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _RoundBtn(icon: DsIconKind.close, onPressed: () => Navigator.of(context).maybePop()),
          _RoundBtn(icon: DsIconKind.share, onPressed: () {}),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onPressed});

  final DsIconKind icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Pressable(
      onPressed: onPressed,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedScale(
          scale: pressed ? 0.9 : 1,
          duration: const Duration(milliseconds: 120),
          child: JellyBox(
            color: theme.surface,
            radius: DsRadii.circle,
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: DsIcon(icon, size: 18, color: theme.text),
          ),
        );
      },
    );
  }
}

class _DetailScrollView extends StatelessWidget {
  const _DetailScrollView({required this.book, required this.theme});

  final DemoBook book;
  final AppThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 120),
      child: Column(
        children: [
          // 封面
          Transform.rotate(
            angle: -0.02,
            child: Container(
              decoration: dsSketchDecoration(theme: theme, radius: DsRadii.md, seed: 7),
              child: ClipRRect(
                borderRadius: DsRadii.md,
                child: SizedBox(
                  width: 168,
                  child: AspectRatio(
                    aspectRatio: 1 / book.aspect,
                    child: BookCover(style: book.cover),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(book.title, textAlign: TextAlign.center, style: DsTypography.title.copyWith(color: theme.text)),
          const SizedBox(height: 4),
          Text(book.author, style: DsTypography.body.copyWith(color: theme.textSub)),
          const SizedBox(height: 18),
          const SizedBox(height: 18) /* _StatsRow(book: book, theme: theme) */,
          const SizedBox(height: 24),
          _Section(title: 'Book Overview'),
          const SizedBox(height: 8),
          Text(book.overview, style: DsTypography.body.copyWith(color: theme.textSub)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final g in book.genres) DSChip(label: g)],
          ),
          if (book.authorBooks.isNotEmpty) ...[
            const SizedBox(height: 24),
            _Section(title: 'Books by This Author'),
            const SizedBox(height: 12),
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: book.authorBooks.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final b = book.authorBooks[i];
                  return Transform.rotate(
                    angle: i.isEven ? -0.02 : 0.02,
                    child: Container(
                      decoration: dsSketchDecoration(theme: theme, radius: DsRadii.sm, seed: i + 3),
                      child: ClipRRect(
                        borderRadius: DsRadii.sm,
                        child: SizedBox(
                          width: 92,
                          child: AspectRatio(aspectRatio: 1 / b.aspect, child: BookCover(style: b.cover)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (book.review != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                _Section(title: 'Reviews'),
                const SizedBox(width: 6),
                Text('${book.review!.count}', style: DsTypography.body.copyWith(color: theme.textSub)),
              ],
            ),
            const SizedBox(height: 12),
            _ReviewCard(review: book.review!, theme: theme),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.book, required this.theme});

  final DemoBook book;
  final AppThemeData theme;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (DsIconKind.book, 'Pages', '${book.pages}'),
      (DsIconKind.clock, 'Reading Time', '${book.readingHours} hours'),
      (DsIconKind.star, 'Rating', '${book.rating}/5'),
    ];
    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(width: 1, color: theme.stroke),
              ),
            Column(
              children: [
                DsIcon(stats[i].$1, size: 16, color: theme.textSub),
                const SizedBox(height: 4),
                Text(stats[i].$2, style: DsTypography.caption.copyWith(color: theme.textSub)),
                const SizedBox(height: 2),
                Text(stats[i].$3, style: DsTypography.heading.copyWith(color: theme.text)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: DsTypography.title.copyWith(fontSize: 16, color: theme.text)),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.theme});

  final DemoReview review;
  final AppThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DsSketchPanel(
      theme: theme,
      radius: DsRadii.lg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              JellyBox(
                color: theme.surfaceAlt,
                radius: DsRadii.circle,
                width: 34,
                height: 34,
                alignment: Alignment.center,
                child: Text(
                  review.name[0],
                  style: DsTypography.heading.copyWith(color: theme.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${review.name}, ${review.location}', style: DsTypography.heading.copyWith(fontSize: 13, color: theme.text)),
                    Text(review.date, style: DsTypography.caption.copyWith(color: theme.textSub)),
                  ],
                ),
              ),
              DSRating(value: review.rating, size: 13),
            ],
          ),
          const SizedBox(height: 10),
          Text(review.text, style: DsTypography.body.copyWith(color: theme.textSub)),
        ],
      ),
    );
  }
}

/// 底部操作条：Save（描边）+ Start Reading（主色）
class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.theme});

  final AppThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: MediaQuery.paddingOf(context).bottom + 8,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DSButton(
              label: 'Save',
              icon: DsIconKind.pin,
              variant: DSButtonVariant.outline,
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: DSButton(
              label: 'Start Reading',
              icon: DsIconKind.play,
              variant: DSButtonVariant.primary,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}
