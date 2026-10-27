import 'package:flutter/material.dart';

/// 报纸卡片外壳：后方层叠纸边 + 主纸面 + 纸张纹理 + 中央折痕 + 顶部卷边高光
///
/// 提取自 newspaper_stand_demo 的报纸卡片，内容区由 [child] 提供，
/// 宽高可调（demo 原版为 286x188 折叠报纸）。
class NewspaperSheet extends StatelessWidget {
  const NewspaperSheet({
    super.key,
    this.width = 286,
    this.height = 188,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 后方层叠纸边
          Positioned(
            left: -2.5,
            right: -2.5,
            top: 2,
            bottom: 1,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFDCDAD4),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                  bottomLeft: Radius.circular(3),
                  bottomRight: Radius.circular(3),
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0xFFC8C6C0), offset: Offset(-1.5, 1)),
                  BoxShadow(color: Color(0xFFCFCDC7), offset: Offset(1.5, 1)),
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // 主纸面
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEAE8E3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
                bottomLeft: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 纸张纹理
                  const Opacity(
                    opacity: 0.18,
                    child: _NetImage(
                      'https://images.unsplash.com/photo-1586075010923-2dd4570fb338?auto=format&fit=crop&w=600&q=80',
                      fit: BoxFit.cover,
                    ),
                  ),
                  // 内容区
                  Padding(
                    padding: const EdgeInsets.fromLTRB(11, 8, 11, 0),
                    child: child,
                  ),
                  // 中央竖向折痕
                  Center(
                    child: Container(
                      width: 16,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          stops: [0, 0.42, 0.55, 1],
                          colors: [
                            Color(0x00000000),
                            Color(0x06000000),
                            Color(0x38FFFFFF),
                            Color(0x00000000),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 顶部卷边高光 + 两侧弧度光影
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.035, 0.07, 0.15, 0.88, 1],
                        colors: [
                          Color(0xA6FFFFFF),
                          Color(0x40FFFFFF),
                          Color(0x08000000),
                          Color(0x00000000),
                          Color(0x05000000),
                          Color(0x24000000),
                        ],
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        stops: [0, 0.025, 0.08, 0.92, 0.975, 1],
                        colors: [
                          Color(0x1C000000),
                          Color(0x2EFFFFFF),
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0x24FFFFFF),
                          Color(0x21000000),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetImage extends StatelessWidget {
  const _NetImage(this.url, {this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          Container(color: const Color(0xFFD4D4D4)),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(color: const Color(0xFFDCDAD4));
      },
    );
  }
}
