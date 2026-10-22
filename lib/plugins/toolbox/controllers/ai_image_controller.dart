import 'package:flutter/foundation.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/services/ai_image_service.dart';
import 'package:aboutme/utils/image_utils.dart';

/// AI 图片生成小工具控制器（ChangeNotifier，独立界面持有）
class AiImageController extends ChangeNotifier {
  final AiImageService _service = AiImageService.instance;

  // ── 表单状态 ──
  String prompt = '';
  /// 模型（空 = 用配置中的默认模型）
  String model = '';
  /// 宽高比（空 = 用配置中的默认比例）
  String aspectRatio = '';
  int n = 1;

  /// 参考图列表：本地绝对路径或图片 URL（空 = 文生图；有值 = 图生图）
  List<String> refImages = [];

  // ── 结果状态 ──
  bool generating = false;
  String? status;
  String? error;
  List<GeneratedImage> results = [];
  String lastMessage = '';

  bool get isEdit => refImages.isNotEmpty;

  void setPrompt(String value) {
    prompt = value;
    notifyListeners();
  }

  void setModel(String value) {
    model = value;
    notifyListeners();
  }

  void setAspectRatio(String value) {
    aspectRatio = value;
    notifyListeners();
  }

  void setN(int value) {
    n = value.clamp(1, 4);
    notifyListeners();
  }

  /// 添加参考图（支持 './app_images/xxx.png' 相对路径 / 绝对路径 / URL，
  /// 相对路径经 ImageUtils 解析为绝对路径，远端存储会物化到临时文件）
  Future<void> addRefImage(String p) async {
    final v = p.trim();
    if (v.isEmpty) return;
    String resolved;
    if (v.startsWith(RegExp(r'https?://'))) {
      resolved = v;
    } else {
      resolved = await ImageUtils.getAbsolutePath(v);
      if (resolved.isEmpty) {
        Toast.warning('参考图路径无效');
        return;
      }
    }
    if (refImages.contains(resolved)) return;
    refImages.add(resolved);
    notifyListeners();
  }

  void removeRefImage(int index) {
    if (index < 0 || index >= refImages.length) return;
    refImages.removeAt(index);
    notifyListeners();
  }

  /// 提交生成任务并轮询到终态
  Future<void> generate() async {
    if (generating) return;
    if (prompt.trim().isEmpty) {
      Toast.warning('请输入图片描述');
      return;
    }

    generating = true;
    error = null;
    status = isEdit ? '提交图生图任务...' : '提交文生图任务...';
    notifyListeners();
    try {
      final result = await _service.generate(
        prompt: prompt,
        refImages: refImages,
        model: model.isEmpty ? null : model,
        aspectRatio: aspectRatio.isEmpty ? null : aspectRatio,
        n: n,
        returnBytes: true,
        onStatus: (s) {
          status = s;
          notifyListeners();
        },
      );
      if (!result.success) {
        error = result.error ?? '生成失败';
        results = [];
        Toast.error(error!);
      } else {
        results = List<GeneratedImage>.from((result.data?['images'] ?? []));
        lastMessage = result.message ?? '';
        Toast.success(lastMessage);
      }
    } catch (e) {
      error = e.toString();
      Toast.error(error!);
    } finally {
      generating = false;
      status = null;
      notifyListeners();
    }
  }
}
