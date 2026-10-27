import 'package:flutter/material.dart';

/// iPhone 手机壳 Mock 组件
/// 深色边框 + 灵动岛状态栏 + Home 指示条 + 侧边硬件按键
/// [child] 为屏幕内容，尺寸默认 380x790，外层自行用 FittedBox 适配
class PhoneMock extends StatelessWidget {
  const PhoneMock({
    super.key,
    required this.child,
    this.width = 380,
    this.height = 790,
    this.padding = 11,
    this.onTap,
    this.showStatusBar = true,
    this.showHomeIndicator = true,
  });

  final Widget child;
  final double width;
  final double height;
  final double padding;
  final VoidCallback? onTap;
  final bool showStatusBar;
  final bool showHomeIndicator;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1C),
              borderRadius: BorderRadius.circular(56),
              boxShadow: const [
                BoxShadow(color: Color(0xFF404044), spreadRadius: 2),
                BoxShadow(color: Color(0xFF18181B), spreadRadius: 4),
                BoxShadow(
                  color: Color(0x610F172A),
                  blurRadius: 70,
                  offset: Offset(0, 30),
                  spreadRadius: -15,
                ),
                BoxShadow(
                  color: Color(0x330F172A),
                  blurRadius: 25,
                  offset: Offset(0, 10),
                  spreadRadius: -5,
                ),
              ],
            ),
            padding: EdgeInsets.all(padding),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(45),
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  color: Colors.white,
                  child: Stack(
                    children: [
                      child,
                      if (showStatusBar) _buildStatusBar(),
                      if (showHomeIndicator) _buildHomeIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _hwButton(left: -6, top: 145, height: 28),
          _hwButton(left: -6, top: 195, height: 52),
          _hwButton(left: -6, top: 260, height: 52),
          _hwButton(right: -6, top: 215, height: 76),
        ],
      ),
    );
  }

  Widget _hwButton({
    double? left,
    double? right,
    required double top,
    required double height,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: Container(
        width: 3,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3F3F46), Color(0xFF18181B), Color(0xFF3F3F46)],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    const dark = Color(0xFF0F172A);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 48,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Stack(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '9:41',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: dark,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 112,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF121324),
                        border: Border.all(color: const Color(0xFF1F243D)),
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _signalBars(),
                    const SizedBox(width: 6),
                    const Icon(Icons.wifi, size: 15, color: dark),
                    const SizedBox(width: 6),
                    _battery(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _signalBars() {
    const heights = [4.5, 6.5, 9.0, 11.5];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final h in heights)
          Container(
            width: 3,
            height: h,
            margin: const EdgeInsets.only(right: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }

  Widget _battery() {
    return Row(
      children: [
        Container(
          width: 22,
          height: 11,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3.5),
            border: Border.all(color: const Color(0x660F172A)),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
        const SizedBox(width: 1),
        Container(
          width: 1.5,
          height: 4,
          decoration: const BoxDecoration(
            color: Color(0x660F172A),
            borderRadius: BorderRadius.horizontal(right: Radius.circular(2)),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeIndicator() {
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: 134,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ),
      ),
    );
  }
}
