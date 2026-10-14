import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// LLM 提供商品牌 logo（SVG 来自 models.dev/logos，描画用 currentColor，
/// 明暗主题自动跟随文字颜色）
///
/// 资产文件名统一为本地提供商/分组 id；coding plan 类与主品牌共用同一图标。
class ProviderLogo extends StatelessWidget {
  /// 提供商 id（ServiceProvider.id）或模型分组 id（LLMModelGroup.id）
  final String id;
  final double size;

  const ProviderLogo({super.key, required this.id, this.size = 16});

  static const String _assetDir = 'assets/icons/providers';

  /// 本地 id → 资产文件名（未收录的 id 无图标，调用方自行回退）
  static const Map<String, String> _assets = {
    'openai': 'openai',
    'anthropic': 'anthropic',
    'google': 'google',
    'azure': 'azure',
    'deepseek': 'deepseek',
    'ollama': 'ollama',
    'alibaba': 'alibaba',
    'alibaba-qwen': 'alibaba',
    'zhipu': 'zhipu',
    'glm-codingplan': 'zhipu',
    'moonshot': 'moonshot',
    'openrouter': 'openrouter',
    'together': 'together',
    'groq': 'groq',
    'cohere': 'cohere',
    'perplexity': 'perplexity',
    'xai': 'xai',
    'mistral': 'mistral',
    'minimax': 'minimax',
    'minimax-codingplan': 'minimax',
  };

  /// 是否收录了该 id 的图标
  static bool hasLogo(String id) => _assets.containsKey(id);

  @override
  Widget build(BuildContext context) {
    final file = _assets[id];
    if (file == null) return const SizedBox.shrink();
    return SvgPicture.asset(
      '$_assetDir/$file.svg',
      width: size,
      height: size,
    );
  }
}
