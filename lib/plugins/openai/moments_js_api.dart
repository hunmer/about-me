part of 'openai_plugin.dart';

// 朋友圈/资产图/生图 工具 JS API（LLM 工具调用）

/// 解析当前 agentId（优先级：显式参数 > 会话上下文 > 活人感当前 agent）
String? _resolveAgentId(Map<String, dynamic> params) {
  return (params['agentId'] as String?) ??
      MomentsService.instance.currentAgentId ??
      MemoryService.instance.currentAgentId;
}

/// AI 生图工具：文生图 / 图生图（引用自己的资产图保持形象一致）
///
/// params: prompt(必填), refAssetNames(数组,可选), aspectRatio(可选), n(可选), sendToChat(默认true)
Future<String> _jsGenerateImage(Map<String, dynamic> params) async {
  final prompt = (params['prompt'] as String?)?.trim();
  if (prompt == null || prompt.isEmpty) {
    return jsonEncode({'error': '缺少必需参数: prompt'});
  }
  final agentId = _resolveAgentId(params);
  final sendToChat =
      params['sendToChat'] == null ? true : params['sendToChat'] == true;

  try {
    // 参考图：按资产名引用（图生图）
    final refPaths = <String>[];
    final refNames = (params['refAssetNames'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    if (refNames.isNotEmpty) {
      if (agentId == null) {
        return jsonEncode({'error': '引用资产图需要 agentId'});
      }
      final assets = await AgentAssetsService.instance.getAssets(agentId);
      for (final name in refNames) {
        final matched = AgentAssetsService.instance.findByName(
          agentId,
          name,
        );
        final ready = matched.where((a) => a.hasImage).toList();
        if (ready.isEmpty) {
          final existing = assets.where((a) => a.name.contains(name));
          return jsonEncode({
            'error':
                '资产 "$name" 尚未生成图片，请提醒用户先在资产图库中生成'
                '${existing.isEmpty ? '（资产不存在）' : ''}',
          });
        }
        for (final a in ready) {
          refPaths.add(await ImageUtils.getAbsolutePath(a.path));
        }
      }
    }

    final images = await ImageGenService.instance.generate(
      prompt: prompt,
      refImageAbsolutePaths: refPaths,
      aspectRatio: params['aspectRatio'] as String?,
      n: int.tryParse('${params['n'] ?? 1}') ?? 1,
    );

    var sent = false;
    if (sendToChat) {
      final absPaths = <String>[];
      for (final rel in images) {
        absPaths.add(await ImageUtils.getAbsolutePath(rel));
      }
      sent = await MomentsService.instance.sendImageToChat(
        agentId: agentId ?? '',
        imageAbsolutePaths: absPaths,
      );
    }
    return jsonEncode({
      'success': true,
      'images': images,
      'sentToChat': sent,
      'message': sent ? '图片已生成并发送到聊天' : '图片已生成（未发送到聊天）',
    });
  } catch (e) {
    return jsonEncode({'error': e.toString()});
  }
}

/// 发朋友圈工具：发布一条动态，可选自动生图配图
///
/// params: text(必填), imagePrompt(可选,生图配图), refAssetNames(可选), sendToChat(可选,配图同时发到聊天)
Future<String> _jsPostMoment(Map<String, dynamic> params) async {
  final text = (params['text'] as String?)?.trim() ?? '';
  if (text.isEmpty && params['imagePrompt'] == null) {
    return jsonEncode({'error': '缺少必需参数: text（或至少提供 imagePrompt）'});
  }
  final agentId = _resolveAgentId(params);
  if (agentId == null) {
    return jsonEncode({'error': '无法确定发动态的 agent'});
  }

  try {
    final images = <String>[];
    final imagePrompt = (params['imagePrompt'] as String?)?.trim();
    if (imagePrompt != null && imagePrompt.isNotEmpty) {
      // 与 generate_image 相同的资产引用逻辑
      final refPaths = <String>[];
      final refNames = (params['refAssetNames'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      for (final name in refNames) {
        final matched = AgentAssetsService.instance
            .findByName(agentId, name);
        for (final a in matched) {
          refPaths.add(await ImageUtils.getAbsolutePath(a.path));
        }
      }
      images.addAll(
        await ImageGenService.instance.generate(
          prompt: imagePrompt,
          refImageAbsolutePaths: refPaths,
          aspectRatio: params['aspectRatio'] as String?,
        ),
      );
      // 可选：配图同时发到聊天
      if (params['sendToChat'] == true && images.isNotEmpty) {
        final absPaths = <String>[];
        for (final rel in images) {
          absPaths.add(await ImageUtils.getAbsolutePath(rel));
        }
        await MomentsService.instance.sendImageToChat(
          agentId: agentId,
          imageAbsolutePaths: absPaths,
        );
      }
    }
    final post = await MomentsService.instance.addPost(
      agentId: agentId,
      text: text,
      images: images,
    );
    return jsonEncode({
      'success': true,
      'message': '动态已发布到朋友圈',
      'post': post.toToolJson(),
    });
  } catch (e) {
    return jsonEncode({'error': e.toString()});
  }
}

/// 查询自己的资产图列表（生图配图时用 refAssetNames 引用）
Future<String> _jsListAgentAssets(Map<String, dynamic> params) async {
  final agentId = _resolveAgentId(params);
  if (agentId == null) {
    return jsonEncode({'error': '无法确定查询的 agent'});
  }
  try {
    final assets = await AgentAssetsService.instance.getAssets(agentId);
    return jsonEncode([
      for (final a in assets)
        {'name': a.name, 'hasImage': a.hasImage},
    ]);
  } catch (e) {
    return jsonEncode({'error': e.toString()});
  }
}
