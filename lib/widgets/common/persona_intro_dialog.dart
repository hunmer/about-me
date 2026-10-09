import 'package:flutter/material.dart';

/// 人设介绍对话框卡片
///
/// 白色拍立得相框样式：照片透过相框窗口显示，底部蓝色波浪线分隔，
/// 上方角标、下方标题 + 副标题 + 主操作按钮。
class PersonaIntroCard extends StatelessWidget {
  const PersonaIntroCard({
    super.key,
    required this.image,
    required this.title,
    this.badgeText = '✨ 全新上线 ✨',
    this.subtitle,
    this.buttonText = '知道了',
    this.onButtonPressed,
    this.width = 320,
  });

  /// 窗口内显示的照片
  final ImageProvider image;

  /// 角标文字（相框顶部白色区域）
  final String badgeText;

  /// 主标题
  final String title;

  /// 副标题
  final String? subtitle;

  /// 按钮文字
  final String buttonText;

  /// 按钮点击回调，为空时仅关闭对话框
  final VoidCallback? onButtonPressed;

  /// 卡片宽度
  final double width;

  /// 相框素材宽高比（裁剪后 1098x1504）
  static const double frameAspectRatio = 1098 / 1504;

  /// 照片窗口在相框中的位置（占相框宽/高的比例），底部延伸到波浪下方
  static const Rect _window = Rect.fromLTRB(0.130, 0.076, 0.870, 0.600);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: frameAspectRatio,
        child: LayoutBuilder(builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final window = Rect.fromLTWH(
            _window.left * size.width,
            _window.top * size.height,
            (_window.right - _window.left) * size.width,
            (_window.bottom - _window.top) * size.height,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              // 照片垫底，从相框窗口透出
              Positioned.fromRect(
                rect: window,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(size.width * 0.035),
                  ),
                  child: Image(image: image, fit: BoxFit.cover),
                ),
              ),
              // 相框（窗口已镂空，底部为白色卡底，承载文案）
              const Positioned.fill(
                child: Image(
                  image: AssetImage('assets/images/persona_dialog_frame.webp'),
                  fit: BoxFit.fill,
                ),
              ),
              // 角标
              Positioned(
                top: size.height * 0.006,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: size.width * 0.052,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4A55E0),
                    ),
                  ),
                ),
              ),
              // 文案区：叠在相框底部白色卡底上
              Positioned(
                left: size.width * 0.09,
                right: size.width * 0.09,
                bottom: size.height * 0.05,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: size.width * 0.058,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: size.width * 0.044,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                    SizedBox(height: size.height * 0.045),
                    SizedBox(
                      width: double.infinity,
                      height: size.width * 0.155,
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
                            fontSize: size.width * 0.05,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// 弹出人设介绍对话框（卡片下方带关闭按钮）
Future<T?> showPersonaIntroDialog<T>({
  required BuildContext context,
  required ImageProvider image,
  required String title,
  String badgeText = '✨ 全新上线 ✨',
  String? subtitle,
  String buttonText = '知道了',
  VoidCallback? onButtonPressed,
  double width = 320,
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
