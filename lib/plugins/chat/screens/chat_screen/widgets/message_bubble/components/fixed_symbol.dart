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

/// 气泡角落的固定符号角标，点击弹出编辑弹层（onTap 由父级注入）
class FixedSymbolWidget extends StatelessWidget {
  final String symbol;

  /// 点击角标回调（null 时不可点击）
  final VoidCallback? onTap;

  /// 角标边长（父级 Stack 以其一半作偏移实现半进半出）
  static const double badgeSize = 45;

  const FixedSymbolWidget({
    super.key,
    required this.symbol,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.amber.shade200),
        ),
        alignment: Alignment.center,
        child: buildFixedSymbolChild(
          symbol,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.amber.shade800,
          ),
          imageSize: 33,
        ),
      ),
    );
  }
}
