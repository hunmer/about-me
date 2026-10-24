# media_log 数据模型与存储

> 所属：lib/plugins/media_log · [返回索引](../CLAUDE.md)

## 模型（models/media_item.dart）

### MediaItem（13 个字段）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | UUID v4（`MediaLogPlugin.newId()`） |
| `kind` | MediaKind | `reading` / `watching` |
| `title` | String | 标题 |
| `author` | String? | 作者 / 主创 |
| `coverImage` | String? | 用户上传封面（相对路径或 URL），非空时优先于程序化封面 |
| `cover` | CoverStyle | 程序化封面风格，缺省 sheep |
| `aspect` | double | 封面高/宽比（默认 1.42，瀑布流错落） |
| `rating` | double? | 总评分 0~5，null = 未评分 |
| `overview` | String? | 简介 |
| `tags` | List\<String\> | 标签（供过滤栏与表单快捷 chips） |
| `finishedAt` | DateTime? | 读完/看完时间；null = 进行中（`isFinished` getter） |
| `createdAt` | DateTime | 创建时间（默认排序键，倒序） |
| `reviews` | List\<MediaReview\> | 点评（可多条） |

派生：`isFinished`、`coverHeroTag`（`media_cover_$id`，Hero 动画两端共用）。`copyWith` 为"null 保持原值"语义（创建于 createdAt 不可变）。

### MediaReview（6 个字段）

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | UUID |
| `text` | String | 点评内容 |
| `timestamp` | DateTime | 时间戳（存储按此倒序） |
| `rating` | double? | 本条评分 0~5 |
| `author` | String? | 点评人昵称（null = 默认"我"；预留给 AI 评论） |
| `avatar` | String? | 头像（相对路径或 URL，null = 首字母圆） |

### 枚举

- `MediaKind`：`reading` / `watching`。
- `CoverStyle`（16 款）：书籍风 12 款（sheep、ring、bellJar、collage、siddhartha、beauty、norwegianWood、kafka、tsukuru、journals、poems、pinball）+ 电影感 4 款（filmReel、clapper、ticket、popcorn）。未知名字解析时回退 sheep。

## 存储

| 路径 | 内容 |
|------|------|
| `media_log/items.json` | `{'items': [MediaItem.toJson() ...]}`，经 AboutmeDataService 读写（同步到自建服务器）；用户在 onboarding 选择示例数据后写入 9 条示例（sample_data.dart，5 阅读 + 4 观影） |

toJson 序列化规则：必填字段恒输出；`author/coverImage/rating/overview/finishedAt` 仅非 null 输出；时间用 ISO8601 字符串。

## 统计口径（列表页）

- 过滤：kind 单选 / tags 多选任一命中 / rating 下限（3+、4+）/ finishedAt 日期范围（无 finishedAt 的条目被日期过滤排除）。
- 搜索：title / author / tags 模糊匹配（不区分大小写）。
- 排序：default（createdAt 倒序）/ title / rating 倒序 / finished 倒序。
