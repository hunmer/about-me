import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 滚动按钮数据项
class MarqueeButtonItemData {
  /// 按钮文字
  final String label;

  /// 按钮图标，为 null 时只显示文字
  final IconData? icon;

  /// 主题色（图标与胶囊底色）
  final Color color;

  /// 自定义数据，点击回调原样带回
  final dynamic payload;

  const MarqueeButtonItemData({
    required this.label,
    this.icon,
    this.color = const Color(0xFF9FB6E8),
    this.payload,
  });
}

/// 无限水平滚动按钮列表卡片
///
/// 多行胶囊按钮水平无限循环缓缓滚动（默认奇偶行方向相反），
/// 可定义行数 [rows] 与滚动速度 [speed]，通过 [onItemTap] 接收点击回调，
/// 通过 [itemBuilder] 传入完全自定义的元素，鼠标悬浮时暂停滚动。
class MarqueeButtonListCardWidget extends StatefulWidget {
  /// 按钮数据
  final List<MarqueeButtonItemData> items;

  /// 滚动行数（数据按 index % rows 分配到各行）
  final int rows;

  /// 滚动速度（像素/秒）
  final double speed;

  /// 奇偶行是否反向滚动
  final bool alternateDirection;

  /// 鼠标悬浮时是否暂停
  final bool pauseOnHover;

  /// 点击按钮回调（item 为数据，index 为原始下标）
  final void Function(MarqueeButtonItemData item, int index)? onItemTap;

  /// 自定义元素构建器（为 null 时使用默认胶囊按钮）
  final Widget Function(BuildContext context, MarqueeButtonItemData item)?
  itemBuilder;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const MarqueeButtonListCardWidget({
    super.key,
    required this.items,
    this.rows = 2,
    this.speed = 24,
    this.alternateDirection = true,
    this.pauseOnHover = true,
    this.onItemTap,
    this.itemBuilder,
    this.inline = false,
    this.size = const Wide2Size(),
  });

  /// 从 props 创建实例
  factory MarqueeButtonListCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    Color parseColor(dynamic colorValue) {
      if (colorValue == null) return const Color(0xFF9FB6E8);
      if (colorValue is Color) return colorValue;
      if (colorValue is int) return Color(colorValue);
      if (colorValue is String) {
        try {
          if (colorValue.startsWith('#')) {
            return Color(
              int.parse(colorValue.substring(1), radix: 16) + 0xFF000000,
            );
          }
          if (colorValue.startsWith('0x')) {
            return Color(int.parse(colorValue.substring(2), radix: 16));
          }
        } catch (_) {}
      }
      return const Color(0xFF9FB6E8);
    }

    IconData? parseIcon(dynamic iconValue) {
      if (iconValue == null) return null;
      if (iconValue is IconData) return iconValue;
      if (iconValue is int) return dynamicIconData(iconValue);
      if (iconValue is Map) {
        final codePoint = iconValue['codePoint'] as int?;
        if (codePoint == null) return null;
        return dynamicIconData(
          codePoint,
          fontFamily: iconValue['fontFamily'] as String?,
          fontPackage: iconValue['fontPackage'] as String?,
        );
      }
      return null;
    }

    List<MarqueeButtonItemData> parseItems(dynamic itemsData) {
      if (itemsData is! List) return const [];
      return [
        for (final e in itemsData)
          if (e is Map<String, dynamic>)
            MarqueeButtonItemData(
              label: e['label'] as String? ?? '',
              icon: parseIcon(e['icon']),
              color: parseColor(e['color']),
              payload: e['payload'],
            ),
      ];
    }

    return MarqueeButtonListCardWidget(
      items: parseItems(props['items']),
      rows: (props['rows'] as num?)?.toInt() ?? 2,
      speed: (props['speed'] as num?)?.toDouble() ?? 24,
      alternateDirection: props['alternateDirection'] as bool? ?? true,
      pauseOnHover: props['pauseOnHover'] as bool? ?? true,
      itemBuilder: props['itemBuilder'] as Widget Function(
        BuildContext,
        MarqueeButtonItemData,
      )?,
      onItemTap: props['onItemTap'] as void Function(
        MarqueeButtonItemData,
        int,
      )?,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<MarqueeButtonListCardWidget> createState() =>
      _MarqueeButtonListCardWidgetState();
}

class _MarqueeButtonListCardWidgetState
    extends State<MarqueeButtonListCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  final ValueNotifier<bool> _paused = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _paused.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = widget.size.scale;
    final rowCount = math.max(1, math.min(widget.rows, widget.items.length));
    final rowHeight = 40 * scale;
    final rowSpacing = 10 * scale;

    Widget card = MouseRegion(
      onEnter: widget.pauseOnHover ? (_) => _paused.value = true : null,
      onExit: widget.pauseOnHover ? (_) => _paused.value = false : null,
      child: Container(
        width: widget.inline ? double.maxFinite : 384 * scale,
        padding: EdgeInsets.all(16 * scale),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF7F3EB),
          borderRadius: BorderRadius.circular(24 * scale),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < rowCount; r++)
              Padding(
                padding: EdgeInsets.only(top: r > 0 ? rowSpacing : 0),
                child: SizedBox(
                  height: rowHeight,
                  child: _MarqueeRow(
                    // 按 index % rows 分配，相邻元素落到不同行；携带原始下标供回调
                    items: [
                      for (var i = r; i < widget.items.length; i += rowCount)
                        (widget.items[i], i),
                    ],
                    reverse: widget.alternateDirection && r.isOdd,
                    speed: widget.speed,
                    gap: 10 * scale,
                    scale: scale,
                    isDark: isDark,
                    itemBuilder: widget.itemBuilder,
                    onItemTap: widget.onItemTap,
                    pausedListenable: _paused,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return FadeTransition(
      opacity: CurvedAnimation(parent: _entrance, curve: Curves.easeOut),
      child: AnimatedBuilder(
        animation: _entrance,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, 14 * (1 - _entrance.value)),
          child: child,
        ),
        child: card,
      ),
    );
  }
}

/// 单行无限滚动条
///
/// 用无限 itemCount 的 ListView + 下标取模实现循环，
/// 每帧 jumpTo 递增 offset 实现匀速滚动；
/// 反向行通过整体水平翻转 + 元素再翻转实现，offset 始终递增。
class _MarqueeRow extends StatefulWidget {
  /// 本行元素与原始下标
  final List<(MarqueeButtonItemData, int)> items;
  final bool reverse;
  final double speed;
  final double gap;
  final double scale;
  final bool isDark;
  final Widget Function(BuildContext, MarqueeButtonItemData)? itemBuilder;
  final void Function(MarqueeButtonItemData, int)? onItemTap;
  final ValueListenable<bool> pausedListenable;

  const _MarqueeRow({
    required this.items,
    required this.reverse,
    required this.speed,
    required this.gap,
    required this.scale,
    required this.isDark,
    required this.itemBuilder,
    required this.onItemTap,
    required this.pausedListenable,
  });

  @override
  State<_MarqueeRow> createState() => _MarqueeRowState();
}

class _MarqueeRowState extends State<_MarqueeRow>
    with SingleTickerProviderStateMixin {
  final ScrollController _controller = ScrollController();
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _paused = widget.pausedListenable.value;
    widget.pausedListenable.addListener(_onPausedChanged);
    _ticker = createTicker(_onTick)..start();
  }

  void _onPausedChanged() {
    setState(() => _paused = widget.pausedListenable.value);
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    // 恢复滚动时 dt 可能很大，限幅避免跳变
    if (_paused || dt <= 0 || dt > 0.05 || !_controller.hasClients) return;
    _controller.jumpTo(_controller.offset + dt * widget.speed);
  }

  @override
  void dispose() {
    widget.pausedListenable.removeListener(_onPausedChanged);
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget list = ListView.builder(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      // 无限 itemCount + 取模实现循环
      itemCount: null,
      itemBuilder: (context, index) {
        final (item, itemIndex) = widget.items[index % widget.items.length];
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.gap / 2),
          child: _buildItem(context, item, itemIndex),
        );
      },
    );

    if (widget.reverse) {
      // 整体翻转后元素再翻转，文字方向不变、滚动方向相反
      list = Transform.flip(flipX: true, child: list);
    }

    return ClipRect(child: list);
  }

  Widget _buildItem(
    BuildContext context,
    MarqueeButtonItemData item,
    int itemIndex,
  ) {
    Widget child = widget.itemBuilder != null
        ? widget.itemBuilder!(context, item)
        : _DefaultPill(
            item: item,
            scale: widget.scale,
            isDark: widget.isDark,
            onTap: widget.onItemTap == null
                ? null
                : () => widget.onItemTap!(item, itemIndex),
          );

    if (widget.reverse) {
      child = Transform.flip(flipX: true, child: child);
    }
    return Center(child: child);
  }
}

/// 默认胶囊按钮
class _DefaultPill extends StatelessWidget {
  final MarqueeButtonItemData item;
  final double scale;
  final bool isDark;
  final VoidCallback? onTap;

  const _DefaultPill({
    required this.item,
    required this.scale,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 8 * scale,
          ),
          decoration: BoxDecoration(
            color: item.color.withOpacity(isDark ? 0.22 : 0.13),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: item.color.withOpacity(isDark ? 0.5 : 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 16 * scale, color: item.color),
                SizedBox(width: 6 * scale),
              ],
              Flexible(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF211D15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
