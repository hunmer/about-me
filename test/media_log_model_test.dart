import 'package:aboutme/plugins/media_log/models/media_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// 媒体记录数据模型：JSON 序列化 / copyWith 冒烟
void main() {
  test('MediaItem toJson/fromJson 往返一致', () {
    final item = MediaItem(
      id: 'a1',
      kind: MediaKind.watching,
      title: 'Norwegian Wood',
      author: 'Tran Anh Hung',
      coverImage: 'media_log/covers/demo.jpg',
      cover: CoverStyle.norwegianWood,
      aspect: 1.5,
      rating: 3.8,
      overview: 'A nostalgic story.',
      tags: const ['Romance', 'Drama'],
      finishedAt: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 9, 20),
      reviews: [
        MediaReview(
          id: 'r1',
          text: '画面很美',
          timestamp: DateTime(2026, 10, 1, 21, 30),
          rating: 4,
          author: 'Aoi',
          avatar: 'media_log/avatars/aoi.jpg',
        ),
      ],
    );

    final restored = MediaItem.fromJson(item.toJson());

    expect(restored.id, 'a1');
    expect(restored.kind, MediaKind.watching);
    expect(restored.title, 'Norwegian Wood');
    expect(restored.author, 'Tran Anh Hung');
    expect(restored.coverImage, 'media_log/covers/demo.jpg');
    expect(restored.cover, CoverStyle.norwegianWood);
    expect(restored.aspect, 1.5);
    expect(restored.rating, 3.8);
    expect(restored.tags, ['Romance', 'Drama']);
    expect(restored.finishedAt, DateTime(2026, 10, 1));
    expect(restored.reviews.single.text, '画面很美');
    expect(restored.reviews.single.timestamp, DateTime(2026, 10, 1, 21, 30));
    expect(restored.reviews.single.rating, 4);
    expect(restored.reviews.single.author, 'Aoi');
    expect(restored.reviews.single.avatar, 'media_log/avatars/aoi.jpg');
  });

  test('电影感封面样式可序列化解析', () {
    for (final style in [
      CoverStyle.filmReel,
      CoverStyle.clapper,
      CoverStyle.ticket,
      CoverStyle.popcorn,
    ]) {
      final item = MediaItem(
        id: 'x',
        kind: MediaKind.watching,
        title: 't',
        cover: style,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(MediaItem.fromJson(item.toJson()).cover, style);
    }
  });

  test('MediaItem 可空字段缺省解析', () {
    final restored = MediaItem.fromJson({'id': 'a2', 'title': 'On the Road'});

    expect(restored.kind, MediaKind.reading);
    expect(restored.cover, CoverStyle.sheep);
    expect(restored.author, isNull);
    expect(restored.rating, isNull);
    expect(restored.finishedAt, isNull);
    expect(restored.tags, isEmpty);
    expect(restored.reviews, isEmpty);
    expect(restored.isFinished, isFalse);
  });

  test('copyWith 支持替换 id 与字段', () {
    final item = MediaItem(
      id: 'a1',
      kind: MediaKind.reading,
      title: '旧标题',
      cover: CoverStyle.ring,
      createdAt: DateTime(2026, 1, 1),
      reviews: const [],
    );
    final updated = item.copyWith(
      id: 'a2',
      title: '新标题',
      rating: 4.5,
      finishedAt: DateTime(2026, 3, 1),
      reviews: [
        MediaReview(id: 'r1', text: '不错', timestamp: DateTime(2026, 3, 1)),
      ],
    );

    expect(updated.id, 'a2');
    expect(updated.title, '新标题');
    expect(updated.rating, 4.5);
    expect(updated.isFinished, isTrue);
    expect(updated.reviews.length, 1);
    // 未变更字段保留
    expect(updated.kind, MediaKind.reading);
    expect(updated.cover, CoverStyle.ring);
    expect(updated.createdAt, DateTime(2026, 1, 1));
  });

  test('MediaReview copyWith 替换 id 与内容', () {
    final review = MediaReview(
      id: 'r1',
      text: '旧点评',
      timestamp: DateTime(2026, 1, 1),
      rating: 3,
      author: 'Me',
    );
    final updated = review.copyWith(
      id: 'r2',
      text: '新点评',
      timestamp: DateTime(2026, 2, 1, 8, 5),
      avatar: 'media_log/avatars/me.jpg',
    );

    expect(updated.id, 'r2');
    expect(updated.text, '新点评');
    expect(updated.timestamp, DateTime(2026, 2, 1, 8, 5));
    expect(updated.rating, 3);
    expect(updated.author, 'Me');
    expect(updated.avatar, 'media_log/avatars/me.jpg');
  });
}
