import 'package:flutter/widgets.dart';

/// Cascading permission for decorative ink motion.
///
/// A disabled ancestor or the platform's reduced-motion preference always wins.
/// This controls skribble ink; it does not disable consumer-owned animations.
class WiredMotion extends InheritedWidget {
  /// Creates a motion boundary. Use false to settle all ink in this subtree.
  const WiredMotion({
    super.key,
    this.enabled = true,
    this.drawDuration,
    required super.child,
  });

  /// Whether this boundary permits ink motion.
  final bool enabled;

  /// Pen entrance duration cascaded to descendant [WiredDraw] widgets that do
  /// not pass their own duration. Null (default) keeps [WiredDraw]'s default.
  final Duration? drawDuration;

  /// Resolves every ancestor and the platform accessibility preference.
  static bool enabledOf(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
    var enabled = true;
    context.visitAncestorElements((element) {
      if (element is InheritedElement && element.widget is WiredMotion) {
        context.dependOnInheritedElement(element);
        enabled = enabled && (element.widget as WiredMotion).enabled;
      }
      return enabled;
    });

    return enabled;
  }

  /// Duration set by the nearest ancestor boundary; null when no ancestor
  /// configures one (callers fall back to their own default).
  static Duration? drawDurationOf(BuildContext context) {
    Duration? duration;
    context.visitAncestorElements((element) {
      if (element is InheritedElement && element.widget is WiredMotion) {
        context.dependOnInheritedElement(element);
        duration ??= (element.widget as WiredMotion).drawDuration;
      }
      return duration == null;
    });

    return duration;
  }

  @override
  bool updateShouldNotify(WiredMotion oldWidget) =>
      enabled != oldWidget.enabled || drawDuration != oldWidget.drawDuration;
}
