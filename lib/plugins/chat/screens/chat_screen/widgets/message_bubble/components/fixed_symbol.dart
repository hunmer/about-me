import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:aboutme/widgets/emoji_picker/emoji_picker.dart';

/// 固定符号内容：内置资源值（kBuiltInEmojiPrefix 前缀）渲染为图像，否则按文本渲染
Widget buildFixedSymbolChild(
  String value, {
  TextStyle? style,
  double imageSize = 16,
}) {
  if (value.startsWith(kBuiltInEmojiPrefix)) {
    final asset = value.substring(kBuiltInEmojiPrefix.length);
    if (asset.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        width: imageSize,
        height: imageSize,
        fit: BoxFit.contain,
      );
    }
    return Image.asset(
      asset,
      width: imageSize,
      height: imageSize,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
  return Text(value, style: style);
}

class FixedSymbolWidget extends StatelessWidget {
  final String symbol;

  const FixedSymbolWidget({
    super.key,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: buildFixedSymbolChild(
        symbol,
        style: TextStyle(
          fontSize: 12,
          color: Colors.amber.shade800,
        ),
      ),
    );
  }
}
