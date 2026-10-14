import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 四角星图标（角标两侧）
const String _starSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path d="M12 1L14.8 9.2L23 12L14.8 14.8L12 23L9.2 14.8L1 12L9.2 9.2L12 1Z" fill="#4D67FF"/>
</svg>
''';

/// 人像区左上浅蓝涂鸦
const String _doodleLeftSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 32">
  <path d="M4 18L24 28L10 10Z" fill="#9EC3FF" opacity="0.85"/>
  <path d="M26 4L33 17L30 3Z" fill="#9EC3FF" opacity="0.85"/>
</svg>
''';

/// 人像区右侧黄色螺旋涂鸦
const String _doodleRightSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 34" fill="none">
  <path d="M6 25C16 27 34 22 33 10C32 3 24 4 23 10C22 16 29 20 35 16" stroke="#FFEE38" stroke-width="3.5" stroke-linecap="round"/>
</svg>
''';

/// 相框底部蓝白双层波浪飘带
const String _waveSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 270 46" fill="none">
  <path d="M4 22 Q 25 22, 36 30 T 62 26 T 92 27 T 122 26 T 156 29 C 185 20, 225 14, 266 20" stroke="#FFFFFF" stroke-width="14" stroke-linecap="square" stroke-linejoin="round"/>
  <path d="M6 17 Q 25 17, 36 25 T 62 21 T 92 22 T 122 21 T 156 24 C 185 15, 225 9, 264 15" stroke="#4D67FF" stroke-width="9.5" stroke-linecap="square" stroke-linejoin="round"/>
</svg>
''';


/// 人设介绍对话框卡片
///
/// 纯矢量绘制（参考设计稿）：顶部淡紫蓝渐变圆角卡片，突出的微倾斜拍立得相框
/// （角标四角星 + 吊牌穿孔 + 图片人像 + 涂鸦装饰），底部蓝白波浪飘带分隔，
/// 下方标题 + 副标题 + 主操作按钮，不依赖相框图片资源。
class PersonaIntroCard extends StatelessWidget {
  const PersonaIntroCard({
    super.key,
    required this.image,
    required this.title,
    this.badgeText = '全新上线',
    this.subtitle,
    this.buttonText = '知道了',
    this.onButtonPressed,
    this.width = 326,
  });

  /// 相框内显示的人像图片
  final ImageProvider image;

  /// 角标文字（相框顶部，两侧自动配四角星图标）
  final String badgeText;

  /// 主标题
  final String title;

  /// 副标题
  final String? subtitle;

  /// 按钮文字
  final String buttonText;

  /// 按钮点击回调，为空时仅关闭对话框
  final VoidCallback? onButtonPressed;

  /// 卡片宽度（设计稿基准 326，所有尺寸按此等比缩放）
  final double width;

  @override
  Widget build(BuildContext context) {
    final s = width / 326;
    return SizedBox(
      width: width,
      // 为顶部突出相框预留空间
      child: Padding(
        padding: EdgeInsets.only(top: 52 * s),
        child: Container(
          padding: EdgeInsets.fromLTRB(24 * s, 0, 24 * s, 24 * s),
          decoration: BoxDecoration(
            // 顶部淡紫蓝色渐变过渡到纯白
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFBDC7FC),
                Color(0xFFDAE0FF),
                Colors.white,
                Colors.white,
              ],
              stops: [0, 0.32, 0.5, 1],
            ),
            // 左上角常规圆角，右上角大圆角
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28 * s),
              topRight: Radius.circular(68 * s),
              bottomLeft: Radius.circular(28 * s),
              bottomRight: Radius.circular(28 * s),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: Offset(0, 16 * s),
                blurRadius: 40 * s,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部微倾斜拍立得相框 + 波浪飘带（向上突出卡片）
              Transform.translate(
                offset: Offset(0, -52 * s),
                child: _buildPolaroid(s),
              ),
              // 文案区
              Padding(
                padding: EdgeInsets.fromLTRB(4 * s, 12 * s, 4 * s, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22 * s,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF141414),
                        height: 1.35,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 8 * s),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 14.5 * s,
                          color: const Color(0xFF8C8C8C),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 28 * s),
              // 主操作按钮
              SizedBox(
                width: double.infinity,
                height: 52 * s,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: onButtonPressed,
                  child: Text(
                    buttonText,
                    style: TextStyle(
                      fontSize: 16 * s,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 拍立得相框 + 底部波浪飘带
  Widget _buildPolaroid(double s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 白色倾斜相框本体
        Transform.rotate(
          angle: -2.2 * math.pi / 180,
          child: Container(
            width: 240 * s,
            padding: EdgeInsets.fromLTRB(11 * s, 10 * s, 11 * s, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(26 * s),
                bottom: Radius.circular(8 * s),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F67FF).withValues(alpha: 0.08),
                  offset: Offset(0, 4 * s),
                  blurRadius: 16 * s,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(s),
                _buildPortrait(s),
              ],
            ),
          ),
        ),
        // 波浪飘带：上移叠在相框底部，布局只占 20px（44px 高 - 24px 重叠）
        SizedBox(
          width: 268 * s,
          height: 20 * s,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -24 * s,
                left: 0,
                child: SizedBox(
                  width: 268 * s,
                  height: 44 * s,
                  child: SvgPicture.string(_waveSvg, fit: BoxFit.fill),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 相框顶部标题栏：✦ 全新上线 ✦ + 右上角吊牌穿孔
  Widget _buildHeader(double s) {
    final star = SizedBox(
      width: 13 * s,
      height: 13 * s,
      child: SvgPicture.string(_starSvg),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: 6 * s),
      child: SizedBox(
        height: 28 * s,
        child: Stack(
          children: [
            Center(
              child: Transform(
                transform: Matrix4.skewX(-6 * math.pi / 180),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    star,
                    SizedBox(width: 6 * s),
                    Flexible(
                      child: Text(
                        badgeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17 * s,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4D67FF),
                          letterSpacing: 1 * s,
                        ),
                      ),
                    ),
                    SizedBox(width: 6 * s),
                    star,
                  ],
                ),
              ),
            ),
            // 右上角吊牌穿孔
            Positioned(
              right: 2 * s,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 20 * s,
                  height: 20 * s,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFDCDCDC),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 10 * s,
                    height: 10 * s,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF595757),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 相框内部灰色人像区：传入图片 + 涂鸦装饰（图片底部渐隐融入背景）
  Widget _buildPortrait(double s) {
    return Container(
      width: double.infinity,
      height: 215 * s,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD5D5D5), Color(0xFFE2E2E2), Colors.white],
          stops: [0, 0.75, 1],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18 * s)),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 人像图片，底部渐隐融入背景
          Positioned.fill(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.82, 1],
              ).createShader(bounds),
              child: Image(image: image, fit: BoxFit.cover),
            ),
          ),
          // 左上浅蓝涂鸦
          Positioned(
            top: 26 * s,
            left: 16 * s,
            width: 36 * s,
            height: 28 * s,
            child: SvgPicture.string(_doodleLeftSvg),
          ),
          // 右侧黄色螺旋涂鸦
          Positioned(
            bottom: 52 * s,
            right: 12 * s,
            width: 36 * s,
            height: 32 * s,
            child: SvgPicture.string(_doodleRightSvg),
          ),
        ],
      ),
    );
  }
}

/// 弹出人设介绍对话框（卡片下方带关闭按钮）
Future<T?> showPersonaIntroDialog<T>({
  required BuildContext context,
  required ImageProvider image,
  required String title,
  String badgeText = '全新上线',
  String? subtitle,
  String buttonText = '知道了',
  VoidCallback? onButtonPressed,
  double width = 326,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black54,
    builder: (context) {
      final card = PersonaIntroCard(
        image: image,
        title: title,
        badgeText: badgeText,
        subtitle: subtitle,
        buttonText: buttonText,
        onButtonPressed: onButtonPressed ?? () => Navigator.of(context).pop(),
        width: width,
      );
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              card,
              const SizedBox(height: 24),
              // 关闭按钮
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
