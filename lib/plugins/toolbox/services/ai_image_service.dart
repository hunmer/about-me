import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/data/sdk_media_service.dart';
import 'package:aboutme/core/utils/network.dart';
import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/utils/image_utils.dart';

/// AI 图片生成小工具服务（原 assets/scripts/ai_image 的 Dart 移植版）
///
/// 对接 OpenAI 兼容异步图像 API：
///   提交  POST {baseUrl}/v1/images/generations?async=true（文生图，JSON）
///         POST {baseUrl}/v1/images/edits?async=true（图生图，multipart）
///   查询  GET  {baseUrl}/v1/images/tasks/{task_id}
/// 提交返回 task_id 则轮询到终态（IN_PROGRESS / SUCCESS / FAILURE），
/// 部分服务会直接同步返回 { created, data: [{url|b64_json}] }。
///
/// 生成图片上传为 SDK 资源（历史记录 images 数组存 'asset://...' 引用；
/// 旧本地 PNG 由 ensureLoaded 一次性迁移）。
class AiImageService {
  AiImageService._();

  static final AiImageService instance = AiImageService._();

  /// 旧版本产物目录（相对 app_data，仅作一次性迁移前缀）

  /// 生成历史上限 100 条（存储经 SDK 命令，截断由本服务负责）
  static const historyLimit = 100;

  /// 模型选项（与原脚本一致）
  static const List<String> models = [
    'gpt-image-1',
    'gpt-image-2',
    'gpt-image-2-all',
    'gpt-image-2.5',
    'gpt-image-2.5-sunburst',
    'gpt-image-2.5-flare',
    'sora_image',
    'nano-banana',
    'dall-e-3',
    'flux-pro-1.1',
    'flux-kontext-pro',
    'flux-kontext-max',
  ];

  static const List<String> aspectRatios = [
    '1:1',
    '16:9',
    '9:16',
    '4:3',
    '3:4',
    '3:2',
    '2:3',
  ];

  /// 内置绘画预设（代码内维护，只读）
  static const List<AiImagePreset> builtinPresets = [
    AiImagePreset(
      id: 'builtin_pixar',
      name: '3D 卡通角色',
      emoji: '🧸',
      prompt: '3D Pixar style cartoon character, big expressive eyes, '
          'soft cinematic lighting, vibrant colors, high detail, '
          'clean background',
    ),
    AiImagePreset(
      id: 'builtin_watercolor',
      name: '水彩插画',
      emoji: '🖌️',
      prompt: 'delicate watercolor illustration, soft pastel palette, '
          'loose brush strokes, textured paper, white margin',
    ),
    AiImagePreset(
      id: 'builtin_cyberpunk',
      name: '赛博朋克城市',
      emoji: '🌃',
      prompt: 'cyberpunk megacity at night, neon signs, rain-soaked streets '
          'with reflections, flying cars, cinematic wide shot',
      aspectRatio: '16:9',
    ),
    AiImagePreset(
      id: 'builtin_ghibli',
      name: '吉卜力风景',
      emoji: '🌿',
      prompt: 'Studio Ghibli style anime landscape, lush green hills, '
          'fluffy cumulus clouds, warm sunlight, hand-painted feel',
    ),
    AiImagePreset(
      id: 'builtin_sticker',
      name: '极简贴纸',
      emoji: '✨',
      prompt: 'cute minimalist sticker of the subject, bold clean outline, '
          'flat pastel colors, die-cut white border, plain background',
    ),
    AiImagePreset(
      id: 'builtin_product',
      name: '产品摄影',
      emoji: '📸',
      prompt: 'professional product photography, studio lighting, '
          'soft shadows, minimalist podium, high-end commercial look',
      aspectRatio: '3:4',
    ),
    AiImagePreset(
      id: 'builtin_pixel',
      name: '像素艺术',
      emoji: '👾',
      prompt: '16-bit pixel art, limited retro palette, crisp pixels, '
          'side-scrolling game scene',
    ),
    AiImagePreset(
      id: 'builtin_ink',
      name: '中国水墨',
      emoji: '🏔️',
      prompt: 'traditional Chinese ink wash painting (shui-mo), misty '
          'mountains, pine trees, negative space, subtle brush texture',
      aspectRatio: '3:4',
    ),
  ];

  Map<String, dynamic> _config = {};
  bool _loaded = false;

  Map<String, dynamic> get config => _config;

  List<ToolboxConfigField> get configFields => const [
    ToolboxConfigField(
      name: 'apiKey',
      type: 'password',
      labelText: 'API Key',
      hintText: '图像服务的 Bearer Token（sk-...）',
      required: true,
    ),
    ToolboxConfigField(
      name: 'baseUrl',
      type: 'text',
      labelText: 'API 地址',
      hintText: 'OpenAI 兼容图像 API 基础地址（不含 /v1）',
      initialValue: 'https://ai.comfly.chat',
      required: true,
    ),
    ToolboxConfigField(
      name: 'model',
      type: 'text',
      labelText: '默认模型',
      hintText: 'gpt-image-1 / nano-banana / dall-e-3 ...',
      initialValue: 'gpt-image-2',
    ),
    ToolboxConfigField(
      name: 'aspectRatio',
      type: 'text',
      labelText: '默认宽高比',
      hintText: '1:1 / 16:9 / 9:16 ...',
      initialValue: '1:1',
    ),
    ToolboxConfigField(
      name: 'n',
      type: 'number',
      labelText: '生成数量',
      hintText: '每次生成几张（1-4）',
      initialValue: 1,
    ),
    ToolboxConfigField(
      name: 'proxy',
      type: 'text',
      labelText: '网络代理（可选）',
      hintText: '如 http://127.0.0.1:7890，留空自动使用系统代理',
    ),
  ];

  /// 读取配置（经 SDK 命令，首次自动迁移旧脚本中心配置与旧本地 PNG）
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final res = await AboutmeDataService.instance.call(
        'toolbox',
        'getAiImageConfig',
      );
      final data = res['success'] == true ? res['data'] : null;
      if (data is Map<String, dynamic>) {
        _config = data;
      }
    } catch (e) {
      debugPrint('[toolbox] 读取 ai_image 配置失败: $e');
    }
  }

  Future<void> saveConfig(Map<String, dynamic> config) async {
    _config = config;
    await AboutmeDataService.instance.call('toolbox', 'saveAiImageConfig', {
      'config': config,
    });
  }

  String _cfg(String key, [String fallback = '']) {
    final v = (_config[key] ?? '').toString().trim();
    return v.isEmpty ? fallback : v;
  }

  /// 代理感知的 http.Client（显式 proxy 配置优先，留空走系统代理）
  Future<http.Client> _client() async {
    final proxy = _cfg('proxy');
    return createClientWithSystemProxy(proxyUrl: proxy.isEmpty ? null : proxy);
  }

  /// 生成图片：不选参考图为文生图，选了为图生图（编辑/多图融合）
  ///
  /// [refImages] 本地绝对路径或图片 URL 的混合列表
  /// [onStatus] 进度回调（提交/轮询状态文案）
  /// [returnBytes] 为 true 时结果携带图片字节（界面展示用；后台调用置 false）
  Future<ToolboxToolResult> generate({
    required String prompt,
    List<String> refImages = const [],
    String? model,
    String? aspectRatio,
    int? n,
    void Function(String status)? onStatus,
    bool returnBytes = true,
  }) async {
    await ensureLoaded();
    final p = prompt.trim();
    if (p.isEmpty) return const ToolboxToolResult.fail('缺少图片描述 prompt');

    final apiKey = _cfg('apiKey');
    if (apiKey.isEmpty) return const ToolboxToolResult.fail('未配置 API Key');

    final baseUrl = _cfg(
      'baseUrl',
      'https://ai.comfly.chat',
    ).replaceAll(RegExp(r'/+$'), '');
    final useModel = (model ?? '').trim().isNotEmpty
        ? model!.trim()
        : _cfg('model', 'gpt-image-1');
    final ratio = (aspectRatio ?? '').trim().isNotEmpty
        ? aspectRatio!.trim()
        : _cfg('aspectRatio', '1:1');
    final count = (n ?? _configNum('n', 1)).clamp(1, 4);

    final refs = refImages.where((e) => e.trim().isNotEmpty).toList();
    final isEdit = refs.isNotEmpty;

    try {
      onStatus?.call(isEdit ? '提交图生图任务...' : '提交文生图任务...');
      final submit = isEdit
          ? await _submitEdit(baseUrl, apiKey, p, useModel, ratio, count, refs)
          : await _submitGeneration(baseUrl, apiKey, p, useModel, ratio, count);

      final status = submit['statusCode'] as int;
      if (status >= 400) {
        return ToolboxToolResult.fail(
          'HTTP $status: ${_bodySummary(submit['body'])}',
        );
      }

      // 提取 task_id（comfly 顶层 / closeai 风格 data.task_id / data 为字符串）
      var payload = submit['body'];
      final taskId = _pickTaskId(payload);
      if (taskId.isNotEmpty) {
        payload = await _pollTask(baseUrl, apiKey, taskId, onStatus);
        if (payload == null) {
          return ToolboxToolResult.fail('轮询超时');
        }
        final failure = _taskFailure(payload);
        if (failure != null) {
          return ToolboxToolResult.fail('任务失败: $failure');
        }
      }

      // 异步结果包在 data 中；同步兼容格式 { created, data: [...] }
      final resultRoot = (payload is Map && payload['data'] is List)
          ? payload
          : (payload is Map ? payload['data'] : null);
      final items = (resultRoot is Map && resultRoot['data'] is List)
          ? resultRoot['data'] as List
          : [];
      final images = <({String kind, String value})>[
        for (final item in items)
          if (item is Map)
            if (item['url'] != null)
              (kind: 'url', value: item['url'].toString())
            else if (item['b64_json'] != null)
              (kind: 'base64', value: item['b64_json'].toString()),
      ];
      if (images.isEmpty) {
        return ToolboxToolResult.fail('未获取到图片: ${_bodySummary(payload)}');
      }

      // 上传为 SDK 资源（单张失败不影响主流程）
      final stamp = _timestamp();
      final client = await _client();
      try {
        final saved = <GeneratedImage>[];
        for (var i = 0; i < images.length; i++) {
          final img = images[i];
          try {
            Uint8List? bytes;
            if (img.kind == 'base64') {
              bytes = base64Decode(img.value);
            } else {
              bytes = await _downloadBytes(client, img.value);
              if (bytes == null) continue;
            }
            final asset = await SdkMediaService.uploadBytes(
              bytes,
              'ai_image_${stamp}_${i + 1}.png',
            );
            saved.add(
              GeneratedImage(
                relativePath: asset.reference,
                bytes: returnBytes ? bytes : null,
              ),
            );
          } catch (e) {
            debugPrint('[toolbox] 保存第 ${i + 1} 张失败: $e');
          }
        }
        if (saved.isEmpty) {
          return const ToolboxToolResult.fail('生成成功但图片保存失败');
        }
        // 写入生成历史（失败不影响主流程）
        await _addHistory(
          prompt: p,
          model: useModel,
          aspectRatio: ratio,
          refCount: refs.length,
          images: [for (final s in saved) s.relativePath],
        );
        return ToolboxToolResult(
          success: true,
          message: '生成 ${images.length} 张图片，保存 ${saved.length} 张',
          data: {
            'images': saved,
            'localPaths': [for (final s in saved) s.relativePath],
            'taskId': taskId,
            'model': useModel,
          },
        );
      } finally {
        client.close();
      }
    } catch (e) {
      return ToolboxToolResult.fail('提交失败: $e');
    }
  }

  // ── 提交 ─────────────────────────────────────────────

  /// 文生图：POST /v1/images/generations?async=true（JSON）
  Future<Map<String, dynamic>> _submitGeneration(
    String baseUrl,
    String apiKey,
    String prompt,
    String model,
    String ratio,
    int n,
  ) async {
    final client = await _client();
    try {
      final resp = await client
          .post(
            Uri.parse('$baseUrl/v1/images/generations?async=true'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'prompt': prompt,
              'model': model,
              'aspect_ratio': ratio,
              'n': n,
            }),
          )
          .timeout(const Duration(seconds: 120));
      return {'statusCode': resp.statusCode, 'body': _parseBody(resp.body)};
    } finally {
      client.close();
    }
  }

  /// 图生图：POST /v1/images/edits?async=true（multipart，多图用 image[] 字段名）
  Future<Map<String, dynamic>> _submitEdit(
    String baseUrl,
    String apiKey,
    String prompt,
    String model,
    String ratio,
    int n,
    List<String> refImages,
  ) async {
    final client = await _client();
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/v1/images/edits?async=true'),
      );
      req.headers['Authorization'] = 'Bearer $apiKey';
      final field = refImages.length > 1 ? 'image[]' : 'image';
      for (final ref in refImages) {
        final filename = ref.startsWith(RegExp(r'https?://'))
            ? (ref.split('/').last.split('?').first)
            : path.basename(ref);
        if (ref.startsWith(RegExp(r'https?://'))) {
          // URL 参考图：先下载到临时文件再上传
          final tmp = await _downloadToTemp(client, ref);
          if (tmp != null) {
            req.files.add(
              await http.MultipartFile.fromPath(
                field,
                tmp.path,
                filename: filename,
              ),
            );
          }
        } else if (File(ref).existsSync()) {
          req.files.add(
            await http.MultipartFile.fromPath(field, ref, filename: filename),
          );
        }
      }
      req.fields['prompt'] = prompt;
      req.fields['model'] = model;
      if (ratio.isNotEmpty) req.fields['aspect_ratio'] = ratio;
      req.fields['n'] = n.toString();

      final resp = await client.send(req).timeout(const Duration(seconds: 120));
      final text = await resp.stream.bytesToString();
      return {'statusCode': resp.statusCode, 'body': _parseBody(text)};
    } finally {
      client.close();
    }
  }

  // ── 轮询 ─────────────────────────────────────────────

  /// 轮询任务到终态：返回 SUCCESS 的 data；失败/超时返回 null（错误经 error 回调带出）
  Future<dynamic> _pollTask(
    String baseUrl,
    String apiKey,
    String taskId,
    void Function(String)? onStatus,
  ) async {
    final deadline = DateTime.now().add(const Duration(minutes: 4));
    final client = await _client();
    try {
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 5));
        late http.Response resp;
        try {
          resp = await client
              .get(
                Uri.parse(
                  '$baseUrl/v1/images/tasks/${Uri.encodeComponent(taskId)}',
                ),
                headers: {'Authorization': 'Bearer $apiKey'},
              )
              .timeout(const Duration(seconds: 30));
        } catch (e) {
          debugPrint('[toolbox] 查询任务失败，将重试: $e');
          continue;
        }
        final body = _parseBody(resp.body);
        final data = (body is Map ? body['data'] : null);
        final status = data is Map
            ? data['status']?.toString().toUpperCase() ?? ''
            : '';
        onStatus?.call(
          '任务状态: ${status.isEmpty ? "未知" : status} ${data is Map ? data["progress"] ?? "" : ""}',
        );
        if (status == 'SUCCESS') return data;
        if (status == 'FAILURE' || status == 'FAILED') {
          return {
            'status': 'FAILURE',
            'fail_reason': data is Map ? data['fail_reason'] : null,
          };
        }
      }
      return null;
    } finally {
      client.close();
    }
  }

  String? _taskFailure(dynamic payload) {
    if (payload is! Map) return null;
    if (payload['status']?.toString().toUpperCase() != 'FAILURE') return null;
    return payload['fail_reason']?.toString() ?? '未知错误';
  }

  // ── 工具方法 ─────────────────────────────────────────

  dynamic _parseBody(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  String _bodySummary(dynamic body) {
    final text = body is String ? body : jsonEncode(body);
    return text.length > 200 ? text.substring(0, 200) : text;
  }

  String _pickTaskId(dynamic r) {
    if (r is! Map) return '';
    if (r['task_id'] is String && (r['task_id'] as String).isNotEmpty) {
      return r['task_id'] as String;
    }
    if (r['data'] is String) return r['data'] as String;
    if (r['data'] is Map && r['data']['task_id'] is String) {
      return r['data']['task_id'] as String;
    }
    return '';
  }

  Future<Uint8List?> _downloadBytes(http.Client client, String url) async {
    try {
      final resp = await client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 60));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        return resp.bodyBytes;
      }
    } catch (e) {
      debugPrint('[toolbox] 下载图片失败: $e');
    }
    return null;
  }

  Future<File?> _downloadToTemp(http.Client client, String url) async {
    try {
      final bytes = await _downloadBytes(client, url);
      if (bytes == null) return null;
      final tmp = File(
        path.join(
          Directory.systemTemp.path,
          'toolbox_ref_${DateTime.now().millisecondsSinceEpoch}_${url.hashCode}.png',
        ),
      );
      await tmp.writeAsBytes(bytes);
      return tmp;
    } catch (e) {
      debugPrint('[toolbox] 下载参考图失败: $e');
      return null;
    }
  }

  String _timestamp() {
    final d = DateTime.now();
    String p(int n) => n < 10 ? '0$n' : '$n';
    return '${d.year}${p(d.month)}${p(d.day)}_${p(d.hour)}${p(d.minute)}${p(d.second)}';
  }

  int _configNum(String key, int fallback) {
    final v = _config[key];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  // ── 绘画预设（用户自建，整表读写）─────────────────────

  /// 读取用户预设（新→旧），过滤本地已失效的参考图
  Future<List<AiImagePreset>> getPresets() async {
    try {
      final res = await AboutmeDataService.instance.call(
        'toolbox',
        'getAiImagePresets',
      );
      final list = res['success'] == true && res['data'] is List
          ? res['data'] as List
          : <dynamic>[];
      return [
        for (final e in list.whereType<Map<String, dynamic>>())
          AiImagePreset.fromJson(e),
      ];
    } catch (e) {
      debugPrint('[toolbox] 读取 ai_image 预设失败: $e');
      return [];
    }
  }

  Future<void> savePresets(List<AiImagePreset> presets) async {
    await AboutmeDataService.instance.call('toolbox', 'saveAiImagePresets', {
      'presets': [for (final p in presets) p.toJson()],
    });
  }

  // ── 生成历史 ─────────────────────────────────────────

  /// 读取生成历史（新→旧），过滤掉图片已全部丢失的记录
  ///
  /// 'asset://...' 引用经资源索引校验存在性（list 分页拉取 id 集合，
  /// 避免逐张 getMetadata）；历史遗留的本地路径仍走文件层 existsPath。
  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final res = await AboutmeDataService.instance.call(
        'toolbox',
        'getAiImageHistory',
      );
      final list = res['success'] == true && res['data'] is List
          ? res['data'] as List
          : <dynamic>[];
      if (list.isEmpty) return [];
      // 校验图片存在性，整条失效的剔除
      final assetIds = await _existingAssetIds();
      final valid = <Map<String, dynamic>>[];
      for (final entry in list.whereType<Map<String, dynamic>>()) {
        final images = (entry['images'] as List?)?.cast<String>() ?? [];
        final existing = <String>[];
        for (final rel in images) {
          final id = ImageUtils.sdkAssetId(rel);
          if (id != null) {
            // 资源引用：索引 id 集合中存在即可用
            if (assetIds.contains(id)) existing.add(rel);
          } else {
            // 历史遗留本地路径：仍走文件层存在性检查
            try {
              if (await AboutmeDataService.instance.data.existsPath(rel)) {
                existing.add(rel);
              }
            } catch (_) {}
          }
        }
        if (existing.isEmpty) continue;
        entry['images'] = existing;
        valid.add(entry);
      }
      return valid;
    } catch (_) {
      return [];
    }
  }

  /// 现存全部资源 id 集合（list 分页翻页，每页上限 100）
  Future<Set<String>> _existingAssetIds() async {
    final ids = <String>{};
    try {
      for (var offset = 0; offset < 1000; offset += 100) {
        final page = await AboutmeDataService.instance.data.assets.list(
          offset: offset,
          limit: 100,
        );
        ids.addAll(page.data.map((asset) => asset.id));
        if (!page.hasMore) break;
      }
    } catch (e) {
      debugPrint('[toolbox] 拉取资源索引失败: $e');
    }
    return ids;
  }

  Future<void> _addHistory({
    required String prompt,
    required String model,
    required String aspectRatio,
    required int refCount,
    required List<String> images,
  }) async {
    try {
      final history = await getHistory();
      history.insert(0, {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'prompt': prompt,
        'model': model,
        'aspectRatio': aspectRatio,
        'refCount': refCount,
        'images': images,
      });
      await AboutmeDataService.instance.call(
        'toolbox',
        'saveAiImageHistory',
        {'history': history.take(historyLimit).toList()},
      );
    } catch (e) {
      debugPrint('[toolbox] 写入生成历史失败: $e');
    }
  }

  /// 删除单条历史记录（连同其图片资源/旧文件）
  Future<void> deleteHistoryEntry(Map<String, dynamic> entry) async {
    final images = (entry['images'] as List?)?.cast<String>() ?? [];
    for (final rel in images) {
      // 'asset://...' 引用走资源 remove，历史遗留本地路径走文件删除
      try {
        await ImageUtils.deleteImage(rel);
      } catch (_) {
        /* 单张删除失败继续 */
      }
    }
    final ts = entry['ts'];
    final history = await getHistory();
    history.removeWhere((e) => e['ts'] == ts);
    await AboutmeDataService.instance.call('toolbox', 'saveAiImageHistory', {
      'history': history,
    });
  }

  /// 清空生成历史（连同全部产物图片）
  Future<void> clearHistory() async {
    final history = await getHistory();
    for (final entry in history) {
      await deleteHistoryEntry(entry);
    }
  }
}
