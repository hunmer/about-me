import 'models/media_item.dart';

/// 首次使用的示例数据：迁移自 ai_picks_demo 的演示书籍 + 观影示例
class MediaSampleData {
  static List<MediaItem> build() {
    final now = DateTime.now();
    return [
      MediaItem(
        id: 'demo-book-1',
        kind: MediaKind.reading,
        title: 'A Wild Sheep Chase',
        author: 'Haruki Murakami',
        cover: CoverStyle.sheep,
        aspect: 1.46,
        rating: 4.3,
        overview:
            'An unnamed protagonist embarks on a bizarre journey across Japan to find a mystical sheep with a star-shaped birthmark.',
        tags: const ['Fiction', 'Magical Realism', 'Mystery'],
        finishedAt: now.subtract(const Duration(days: 30)),
        createdAt: now.subtract(const Duration(days: 45)),
        reviews: [
          MediaReview(
            id: 'demo-review-1',
            text:
                "It was such a strange and fascinating read. Murakami's writing is so effortlessly cool, blending reality and the surreal in a way that just pulls you in.",
            timestamp: now.subtract(const Duration(days: 29)),
            rating: 4,
            author: 'Margo',
          ),
        ],
      ),
      MediaItem(
        id: 'demo-book-2',
        kind: MediaKind.reading,
        title: 'On the Road',
        author: 'Jack Kerouac',
        cover: CoverStyle.ring,
        aspect: 1.44,
        rating: 4.1,
        overview:
            'A defining novel of the Beat Generation, following Sal Paradise and Dean Moriarty across the American landscape.',
        tags: const ['Classic', 'Beat Generation', 'Travel'],
        finishedAt: now.subtract(const Duration(days: 12)),
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      MediaItem(
        id: 'demo-book-3',
        kind: MediaKind.reading,
        title: 'The Bell Jar',
        author: 'Sylvia Plath',
        cover: CoverStyle.bellJar,
        aspect: 1.34,
        rating: 4.1,
        overview:
            'Semi-autobiographical novel that follows Esther Greenwood, a talented young woman struggling with depression and societal expectations in 1950s America.',
        tags: const ['Psychological', 'Autobiographical', 'Coming-of-Age'],
        finishedAt: now.subtract(const Duration(days: 60)),
        createdAt: now.subtract(const Duration(days: 70)),
        reviews: [
          MediaReview(
            id: 'demo-review-2',
            text:
                "Sylvia Plath's writing is so vivid and honest, it's like you're right there with Esther as she spirals into darkness.",
            timestamp: now.subtract(const Duration(days: 59)),
            rating: 4.5,
            author: 'Daniel',
          ),
        ],
      ),
      MediaItem(
        id: 'demo-book-4',
        kind: MediaKind.reading,
        title: 'The Master and Margarita',
        author: 'Mikhail Bulgakov',
        cover: CoverStyle.collage,
        aspect: 1.42,
        rating: 4.4,
        overview:
            'A wild satirical tale in which the Devil visits Soviet Moscow, woven together with a retelling of the Pontius Pilate story.',
        tags: const ['Satire', 'Fantasy', 'Classic'],
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      MediaItem(
        id: 'demo-book-5',
        kind: MediaKind.reading,
        title: 'Siddhartha',
        author: 'Hermann Hesse',
        cover: CoverStyle.siddhartha,
        aspect: 1.3,
        rating: 4.2,
        overview:
            "A philosophical novel following a man's spiritual journey of self-discovery during the time of Gautama Buddha.",
        tags: const ['Philosophical', 'Spiritual', 'Classic'],
        finishedAt: now.subtract(const Duration(days: 90)),
        createdAt: now.subtract(const Duration(days: 100)),
      ),
      MediaItem(
        id: 'demo-film-1',
        kind: MediaKind.watching,
        title: 'Norwegian Wood',
        author: 'Tran Anh Hung',
        cover: CoverStyle.norwegianWood,
        aspect: 1.5,
        rating: 3.8,
        overview:
            'A nostalgic story of loss and sexuality, following Toru Watanabe and his relationships with two very different women.',
        tags: const ['Romance', 'Drama', 'Coming-of-Age'],
        finishedAt: now.subtract(const Duration(days: 7)),
        createdAt: now.subtract(const Duration(days: 7)),
        reviews: [
          MediaReview(
            id: 'demo-review-3',
            text: '画面很美，节奏偏慢，结尾的情绪留白很妙。',
            timestamp: now.subtract(const Duration(days: 6)),
            rating: 4,
          ),
        ],
      ),
      MediaItem(
        id: 'demo-film-2',
        kind: MediaKind.watching,
        title: 'Kafka on the Shore',
        author: 'Lev Ivanov',
        cover: CoverStyle.filmReel,
        aspect: 1.42,
        rating: 4.4,
        overview:
            'A mind-bending tale of a runaway teenager and an aging simpleton, connected by a surreal fate across modern Japan.',
        tags: const ['Fantasy', 'Magical Realism', 'Mystery'],
        createdAt: now.subtract(const Duration(days: 2)),
        reviews: [
          MediaReview(
            id: 'demo-review-4',
            text: '胶片质感的画面配上海边的风声，像做了一场清醒的梦。',
            timestamp: now.subtract(const Duration(days: 1)),
            rating: 4.5,
            author: 'Aoi',
          ),
        ],
      ),
      MediaItem(
        id: 'demo-film-3',
        kind: MediaKind.watching,
        title: 'History of Beauty',
        author: 'Umberto Eco',
        cover: CoverStyle.ticket,
        aspect: 1.34,
        rating: 4.0,
        overview:
            'A lavishly illustrated journey through the history of beauty in Western art and culture, from antiquity to the modern age.',
        tags: const ['Art', 'Essay', 'History'],
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      MediaItem(
        id: 'demo-film-4',
        kind: MediaKind.watching,
        title: 'Midnight Screening',
        author: 'Clara Bell',
        cover: CoverStyle.popcorn,
        aspect: 1.38,
        rating: 3.6,
        overview:
            'A warm documentary about a small cinema that only opens after midnight, and the regulars who call it home.',
        tags: const ['Documentary', 'Cozy'],
        createdAt: now.subtract(const Duration(hours: 10)),
      ),
    ];
  }
}
