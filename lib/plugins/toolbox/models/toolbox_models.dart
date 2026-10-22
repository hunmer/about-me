import 'dart:typed_data';

/// 工具箱通用执行结果（与原 JS 脚本返回结构对齐：
/// `{success, message?, error?, data: {...}}`，便于上层与 JS API 复用）
class ToolboxToolResult {
  final bool success;
  final String? message;
  final String? error;
  final Map<String, dynamic>? data;

  const ToolboxToolResult({
    required this.success,
    this.message,
    this.error,
    this.data,
  });

  const ToolboxToolResult.fail(this.error)
    : success = false,
      message = null,
      data = null;

  Map<String, dynamic> toMap() => {
    'success': success,
    if (message != null) 'message': message,
    if (error != null) 'error': error,
    if (data != null) 'data': data,
  };
}

/// 图片搜索命中的单张图片
///
/// 字段与原 image_search 脚本返回一致：
/// url=展示图 large=原图(pixabay) pageUrl=落地页
class SearchedImage {
  final String url;
  final String thumb;
  final String large;
  final String user;
  final String profileUrl;
  final String pageUrl;
  final String description;
  final int? width;
  final int? height;
  final String source;

  const SearchedImage({
    required this.url,
    this.thumb = '',
    this.large = '',
    this.user = '',
    this.profileUrl = '',
    this.pageUrl = '',
    this.description = '',
    this.width,
    this.height,
    required this.source,
  });

  /// 署名文案（Unsplash 条款要求署名摄影师）
  String get credit {
    if (source == 'unsplash') {
      return user.isEmpty ? '' : 'Photo by $user on Unsplash';
    }
    if (source == 'pixabay') return user.isEmpty ? '' : 'by $user';
    return user.isEmpty ? '' : '来源: $user';
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'thumb': thumb,
    'large': large,
    'user': user,
    'profileUrl': profileUrl,
    'pageUrl': pageUrl,
    'description': description,
    'width': width,
    'height': height,
    'source': source,
  };
}

/// AI 图片生成的单张产物
class GeneratedImage {
  /// 本地相对路径（相对 app_data；Web 平台可能为空）
  final String relativePath;

  /// 本地绝对路径（Web 平台为空）
  final String absolutePath;

  /// 图片字节（界面展示用；后台调用可能为空）
  final Uint8List? bytes;

  const GeneratedImage({
    this.relativePath = '',
    this.absolutePath = '',
    this.bytes,
  });
}

/// 工具配置表单字段（对应原脚本 metadata 的 configFormFields）
class ToolboxConfigField {
  final String name;
  final String type; // text | password | number | switchField
  final String labelText;
  final String hintText;
  final dynamic initialValue;
  final bool required;

  const ToolboxConfigField({
    required this.name,
    required this.type,
    required this.labelText,
    this.hintText = '',
    this.initialValue,
    this.required = false,
  });
}
