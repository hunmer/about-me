/// AI-Picks for You DEMO 的 mock 数据
///
/// 数据复刻参考视频《收藏到 Pins by you》：书籍封面 / 详情 / 评论。
library;

/// 封面绘制风格（程序化绘制，替代真实封面图）
enum CoverStyle {
  sheep,
  ring,
  bellJar,
  collage,
  siddhartha,
  beauty,
  norwegianWood,
  kafka,
  tsukuru,
  journals,
  poems,
  pinball,
}

/// 书籍条目
class DemoBook {
  const DemoBook({
    required this.title,
    required this.author,
    required this.cover,
    required this.aspect,
    required this.pages,
    required this.readingHours,
    required this.rating,
    required this.overview,
    required this.genres,
    this.authorBooks = const [],
    this.review,
  });

  final String title;
  final String author;
  final CoverStyle cover;

  /// 高 / 宽 比（制造瀑布流错落）
  final double aspect;

  final int pages;
  final double readingHours;
  final double rating;
  final String overview;
  final List<String> genres;

  /// 「Books by This Author」横滑条目
  final List<DemoBook> authorBooks;

  /// 首条评论（null = 无评论区块）
  final DemoReview? review;
}

/// 评论条目
class DemoReview {
  const DemoReview({
    required this.name,
    required this.location,
    required this.date,
    required this.rating,
    required this.text,
    required this.count,
  });

  final String name;
  final String location;
  final String date;
  final double rating;
  final String text;
  final int count;
}

/// 首页网格书籍（与视频一致的 6 本 + 追加填充使列表可滚动）
final List<DemoBook> demoBooks = [
  _wildSheepChase,
  _onTheRoad,
  _bellJar,
  _masterAndMargarita,
  _siddhartha,
  _historyOfBeauty,
  _norwegianWood,
  _kafkaOnTheShore,
];

final DemoBook _wildSheepChase = DemoBook(
  title: 'A Wild Sheep Chase',
  author: 'Haruki Murakami',
  cover: CoverStyle.sheep,
  aspect: 1.46,
  pages: 320,
  readingHours: 6,
  rating: 4.3,
  overview:
      'An unnamed protagonist embarks on a bizarre journey across Japan to find a mystical sheep with a star-shaped birthmark.',
  genres: const ['Fiction', 'Magical Realism', 'Mistery'],
  authorBooks: const [
    DemoBook(
      title: 'Norwegian Wood',
      author: 'Haruki Murakami',
      cover: CoverStyle.norwegianWood,
      aspect: 1.5,
      pages: 296,
      readingHours: 5.5,
      rating: 4.2,
      overview: '',
      genres: [],
    ),
    DemoBook(
      title: 'Kafka on the Shore',
      author: 'Haruki Murakami',
      cover: CoverStyle.kafka,
      aspect: 1.42,
      pages: 467,
      readingHours: 8,
      rating: 4.4,
      overview: '',
      genres: [],
    ),
    DemoBook(
      title: 'Colorless Tsukuru',
      author: 'Haruki Murakami',
      cover: CoverStyle.tsukuru,
      aspect: 1.36,
      pages: 386,
      readingHours: 7,
      rating: 4.0,
      overview: '',
      genres: [],
    ),
  ],
  review: const DemoReview(
    name: 'Margo',
    location: 'Berlin',
    date: 'Jan 23',
    rating: 4,
    text:
        "It was such a strange and fascinating read. Murakami's writing is so effortlessly cool, blending reality and the surreal in a way that just pulls you in.",
    count: 207,
  ),
);

final DemoBook _onTheRoad = DemoBook(
  title: 'On the Road',
  author: 'Jack Kerouac',
  cover: CoverStyle.ring,
  aspect: 1.44,
  pages: 320,
  readingHours: 6,
  rating: 4.1,
  overview:
      'A defining novel of the Beat Generation, following Sal Paradise and Dean Moriarty across the American landscape.',
  genres: const ['Classic', 'Beat Generation', 'Travel'],
);

final DemoBook _bellJar = DemoBook(
  title: 'The Bell Jar',
  author: 'Sylvia Plath',
  cover: CoverStyle.bellJar,
  aspect: 1.34,
  pages: 240,
  readingHours: 5.5,
  rating: 4.1,
  overview:
      'Semi-autobiographical novel that follows Esther Greenwood, a talented young woman struggling with depression and societal expectations in 1950s America.',
  genres: const ['Psychological', 'Autobiographical', 'Coming-of-Age'],
  authorBooks: const [
    DemoBook(
      title: 'The Unabridged Journals',
      author: 'Sylvia Plath',
      cover: CoverStyle.journals,
      aspect: 1.3,
      pages: 768,
      readingHours: 14,
      rating: 4.5,
      overview: '',
      genres: [],
    ),
    DemoBook(
      title: 'Selected Poems',
      author: 'Sylvia Plath',
      cover: CoverStyle.poems,
      aspect: 1.28,
      pages: 112,
      readingHours: 2.5,
      rating: 4.6,
      overview: '',
      genres: [],
    ),
  ],
  review: const DemoReview(
    name: 'Daniel',
    location: 'London',
    date: 'Feb 11',
    rating: 4.5,
    text:
        "Sylvia Plath's writing is so vivid and honest, it's like you're right there with Esther as she spirals into darkness. It's heartbreaking but also strangely beautiful in how raw and real it feels.",
    count: 232,
  ),
);

final DemoBook _masterAndMargarita = DemoBook(
  title: 'The Master and Margarita',
  author: 'Mikhail Bulgakov',
  cover: CoverStyle.collage,
  aspect: 1.42,
  pages: 384,
  readingHours: 7,
  rating: 4.4,
  overview:
      'A wild satirical tale in which the Devil visits Soviet Moscow, woven together with a retelling of the Pontius Pilate story.',
  genres: const ['Satire', 'Fantasy', 'Classic'],
);

final DemoBook _siddhartha = DemoBook(
  title: 'Siddhartha',
  author: 'Hermann Hesse',
  cover: CoverStyle.siddhartha,
  aspect: 1.3,
  pages: 176,
  readingHours: 3.5,
  rating: 4.2,
  overview:
      'A philosophical novel following a man\'s spiritual journey of self-discovery during the time of Gautama Buddha.',
  genres: const ['Philosophical', 'Spiritual', 'Classic'],
);

final DemoBook _historyOfBeauty = DemoBook(
  title: 'History of Beauty',
  author: 'Umberto Eco',
  cover: CoverStyle.beauty,
  aspect: 1.34,
  pages: 438,
  readingHours: 9,
  rating: 4.0,
  overview:
      'A lavishly illustrated journey through the history of beauty in Western art and culture, from antiquity to the modern age.',
  genres: const ['Art', 'Essay', 'History'],
);

final DemoBook _norwegianWood = DemoBook(
  title: 'Norwegian Wood',
  author: 'Haruki Murakami',
  cover: CoverStyle.norwegianWood,
  aspect: 1.5,
  pages: 296,
  readingHours: 5.5,
  rating: 4.2,
  overview:
      'A nostalgic story of loss and sexuality, following Toru Watanabe and his relationships with two very different women.',
  genres: const ['Fiction', 'Romance', 'Coming-of-Age'],
);

final DemoBook _kafkaOnTheShore = DemoBook(
  title: 'Kafka on the Shore',
  author: 'Haruki Murakami',
  cover: CoverStyle.kafka,
  aspect: 1.42,
  pages: 467,
  readingHours: 8,
  rating: 4.4,
  overview:
      'A mind-bending tale of a runaway teenager and an aging simpleton, connected by a surreal fate across modern Japan.',
  genres: const ['Fantasy', 'Magical Realism', 'Mystery'],
);
