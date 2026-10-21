import 'package:flutter/widgets.dart';

/// 设计令牌：动效（时长 × 缓动）
///
/// 手绘体系的墨线（RoughBoxDecoration）不可补间，动效一律作用在
/// Transform / Opacity / 纯色容器等可补间层上，墨线保持静止。
/// 新组件的动效只从本 token 取值；存量组件在触碰时逐步收敛到这里。
abstract final class DsMotion {
  /// 快速反馈（按压、hover、勾选描画）
  static const Duration fast = Duration(milliseconds: 150);

  /// 标准过渡（浮层进出、选中切换、气泡弹出）
  static const Duration base = Duration(milliseconds: 250);

  /// 从容过渡（对话框、大面板、数值补间）
  static const Duration slow = Duration(milliseconds: 350);

  /// 标准缓动（ease 家族统一近似，禁散落各处的裸 ease）
  static const Curve curve = Curves.easeOutCubic;

  /// 弹性入场（贴纸感 pop-in：scale 越过 1 再回落）
  static const Curve enter = Curves.easeOutBack;

  /// 果冻回弹（squash & stretch 家族）
  static const Curve jelly = Curves.elasticOut;
}

/// 动效减弱：系统/用户要求减少动画时的统一短路入口
extension DsMotionContextX on BuildContext {
  /// 为 true 时循环动画（摆动/闪烁/旋转）与装饰性入场应退化为静态，
  /// 必要的功能性过渡可保留但缩短。
  bool get dsAnimationsDisabled => MediaQuery.disableAnimationsOf(this);
}
