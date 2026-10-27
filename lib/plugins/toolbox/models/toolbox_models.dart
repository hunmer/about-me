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

/// AI 绘画预设：绘画表单参数的快照，表单与预设库共用该结构
///
/// 内置预设（builtin=true）代码内维护，不可编辑删除；
/// 用户预设经 SDK 命令持久化到 `toolbox/ai_image/presets.json`。
class AiImagePreset {
  final String id;

  /// 预设名（列表展示）
  final String name;

  /// 卡片占位 emoji（无参考图时展示）
  final String emoji;

  /// 提示词模板
  final String prompt;

  /// 模型（空 = 跟随默认配置）
  final String model;

  /// 宽高比（空 = 跟随默认配置）
  final String aspectRatio;
  final int n;

  /// 参考图列表：本地绝对路径或图片 URL
  final List<String> refImages;
  final bool builtin;

  const AiImagePreset({
    required this.id,
    required this.name,
    this.emoji = '🎨',
    this.prompt = '',
    this.model = '',
    this.aspectRatio = '',
    this.n = 1,
    this.refImages = const [],
    this.builtin = false,
  });

  AiImagePreset copyWith({
    String? name,
    String? emoji,
    String? prompt,
    String? model,
    String? aspectRatio,
    int? n,
    List<String>? refImages,
  }) => AiImagePreset(
    id: id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    prompt: prompt ?? this.prompt,
    model: model ?? this.model,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    n: n ?? this.n,
    refImages: refImages ?? this.refImages,
    builtin: builtin,
  );

  factory AiImagePreset.fromJson(Map<String, dynamic> json) => AiImagePreset(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    emoji: json['emoji']?.toString() ?? '🎨',
    prompt: json['prompt']?.toString() ?? '',
    model: json['model']?.toString() ?? '',
    aspectRatio: json['aspectRatio']?.toString() ?? '',
    n: int.tryParse(json['n']?.toString() ?? '') ?? 1,
    refImages: (json['refImages'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    builtin: json['builtin'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'prompt': prompt,
    'model': model,
    'aspectRatio': aspectRatio,
    'n': n,
    'refImages': refImages,
    'builtin': builtin,
  };
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
