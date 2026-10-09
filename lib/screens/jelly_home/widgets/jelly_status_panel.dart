import 'package:aboutme/screens/jelly_home/companion_controller.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:flutter/material.dart';

import 'jelly_status_panel_config.dart';
import 'jelly_status_panel_settings.dart';
import 'jelly_configurable_image.dart';

class JellyStatusPanel extends StatefulWidget {
  const JellyStatusPanel({super.key, required this.controller});

  final CompanionController controller;

  @override
  State<JellyStatusPanel> createState() => _JellyStatusPanelState();
}

class _JellyStatusPanelState extends State<JellyStatusPanel> {
  static const _level = 17;
  static const _experience = 568;
  static const _experienceMax = 1250;

  final _settings = JellyStatusPanelSettings.instance;

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 900,
          maxHeight: JellyStatusPanelSettings.maxDisplayHeight,
        ),
        child: AnimatedBuilder(
          animation: _settings,
          builder: (context, _) => AspectRatio(
            aspectRatio: _settings.selectedStyle.visibleAspectRatio,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPress: () => _settings.edit(context),
              child: LayoutBuilder(
                builder: (context, constraints) => AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      _CroppedStatusPanelImage(style: _settings.selectedStyle),
                      _positioned(
                        _mapRegion(_settings.config.avatarRegion),
                        constraints.biggest,
                        ClipOval(
                          child: _settings.avatarPath == null
                              ? Image.asset(
                                  'assets/images/default_avatar.jpg',
                                  fit: BoxFit.cover,
                                )
                              : AdaptiveImage(
                                  imagePath: _settings.avatarPath,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      _positioned(
                        _mapRegion(_settings.config.experienceRegion),
                        constraints.biggest,
                        _ExperienceBar(
                          level: _level,
                          value: _experience,
                          max: _experienceMax,
                        ),
                      ),
                      for (final item in _settings.config.items) ...[
                        _positioned(
                          _mapRegion(item.iconRegion),
                          constraints.biggest,
                          Image.asset(
                            _iconAsset(item.type),
                            width: _iconSize(
                              item.iconRegion,
                              constraints.biggest,
                            ),
                            height: _iconSize(
                              item.iconRegion,
                              constraints.biggest,
                            ),
                            fit: BoxFit.contain,
                          ),
                        ),
                        _positioned(
                          _mapRegion(item.valueRegion),
                          constraints.biggest,
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _value(item.type),
                              maxLines: 1,
                              style: const TextStyle(
                                color: Color(0xFF695B58),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Rect _mapRegion(Rect source) => _settings.selectedStyle.mapToVisible(source);

  Widget _positioned(Rect rect, Size size, Widget child) {
    return Positioned.fromRect(
      rect: Rect.fromLTRB(
        rect.left * size.width,
        rect.top * size.height,
        rect.right * size.width,
        rect.bottom * size.height,
      ),
      child: Center(child: child),
    );
  }

  double _iconSize(Rect rect, Size size) =>
      (rect.width * size.width).clamp(14.0, 34.0);

  String _value(JellyStatusItemType type) => switch (type) {
    JellyStatusItemType.mood => '${widget.controller.mood}',
    JellyStatusItemType.energy => '${widget.controller.energy}',
    JellyStatusItemType.affection => '${widget.controller.affection}',
    JellyStatusItemType.companionDays =>
      '${widget.controller.totalCompanionDays}天',
  };
}

class _CroppedStatusPanelImage extends StatelessWidget {
  const _CroppedStatusPanelImage({required this.style});

  final JellyStatusPanelStyle style;

  @override
  Widget build(BuildContext context) {
    final bounds = style.visibleBounds;
    return ClipRect(
      child: FractionalTranslation(
        translation: Offset(
          -bounds.left / bounds.width,
          -bounds.top / bounds.height,
        ),
        child: FractionallySizedBox(
          widthFactor: 1 / bounds.width,
          heightFactor: 1 / bounds.height,
          alignment: Alignment.topLeft,
          child: JellyConfigurableImage(path: style.asset, fit: BoxFit.fill),
        ),
      ),
    );
  }
}

class _ExperienceBar extends StatelessWidget {
  const _ExperienceBar({
    required this.level,
    required this.value,
    required this.max,
  });

  final int level;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                'Lv.$level',
                style: const TextStyle(
                  color: Color(0xFF695B58),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value / max,
                    minHeight: 8,
                    backgroundColor: const Color(0x66FFFFFF),
                    color: const Color(0xFFF4A9B9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$value/$max',
                style: const TextStyle(
                  color: Color(0xFF806F6A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 心情在源图里没有对应表情，取最接近的星星；如需换用其它图标改这里即可
//（素材目录 assets/jelly_icons/，共 30 枚，见 docs/jelly_icons/split_icons.py）。
String _iconAsset(JellyStatusItemType type) => switch (type) {
  JellyStatusItemType.mood => 'assets/jelly_icons/star.webp',
  JellyStatusItemType.energy => 'assets/jelly_icons/lightning.webp',
  JellyStatusItemType.affection => 'assets/jelly_icons/heart.webp',
  JellyStatusItemType.companionDays => 'assets/jelly_icons/calendar.webp',
};
