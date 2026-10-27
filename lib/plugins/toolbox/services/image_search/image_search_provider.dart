import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/image_search_context.dart';

/// 关键词搜图的统一入参（不支持的字段由各 provider 自行忽略）
class ImageSearchQuery {
  const ImageSearchQuery({
    required this.query,
    this.provider = '',
    this.perPage,
    this.page = 1,
    this.imageType = 'photo',
    this.orientation = 'any',
    this.sort = 'relevant',
  });

  final String query;

  /// 图源名（serp 系多个引擎共用一个实现，需靠它区分 engine）
  final String provider;
  final int? perPage;
  final int page;
  final String imageType;
  final String orientation;
  final String sort;
}

/// 图源实现接口（每个图源一个文件，由 ImageSearchService 分发）
abstract class ImageSearchProvider {
  const ImageSearchProvider();

  /// 配置缺失校验，返回错误文案；null 表示通过
  String? validate(ImageSearchContext ctx);

  Future<ToolboxToolResult> search(ImageSearchContext ctx, ImageSearchQuery q);
}
