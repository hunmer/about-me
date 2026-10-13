import 'package:aboutme/widgets/picker/avatar_picker.dart';
import 'package:flutter/material.dart';

import 'jelly_status_panel_config.dart';
import 'jelly_configurable_image.dart';

import 'package:get/get.dart';
Future<JellyStatusPanelConfig?> showJellyStatusPanelEditor({
  required BuildContext context,
  required String asset,
  required JellyStatusPanelConfig initial,
  required String userName,
  required String? avatarPath,
  required ValueChanged<String> onAvatarChanged,
}) {
  return showDialog<JellyStatusPanelConfig>(
    context: context,
    builder: (_) => _JellyStatusPanelEditor(
      asset: asset,
      initial: initial,
      userName: userName,
      avatarPath: avatarPath,
      onAvatarChanged: onAvatarChanged,
    ),
  );
}

enum _RegionKind { avatar, experience, itemIcon, itemValue }

class _JellyStatusPanelEditor extends StatefulWidget {
  const _JellyStatusPanelEditor({
    required this.asset,
    required this.initial,
    required this.userName,
    required this.avatarPath,
    required this.onAvatarChanged,
  });

  final String asset;
  final JellyStatusPanelConfig initial;
  final String userName;
  final String? avatarPath;
  final ValueChanged<String> onAvatarChanged;

  @override
  State<_JellyStatusPanelEditor> createState() =>
      _JellyStatusPanelEditorState();
}

class _JellyStatusPanelEditorState extends State<_JellyStatusPanelEditor> {
  late JellyStatusPanelConfig _config = widget.initial;
  _RegionKind _kind = _RegionKind.avatar;
  JellyStatusItemType? _itemType;
  Offset? _start;

  void _select(_RegionKind kind, [JellyStatusItemType? type]) {
    setState(() {
      _kind = kind;
      _itemType = type;
    });
  }

  void _toggleItem(JellyStatusItemType type, bool enabled) {
    final items = [..._config.items];
    if (enabled) {
      if (items.any((item) => item.type == type)) return;
      final slot =
          JellyStatusPanelConfig.itemSlots[items.length.clamp(
            0,
            JellyStatusPanelConfig.itemSlots.length - 1,
          )];
      items.add(
        JellyStatusItemConfig(
          type: type,
          iconRegion: slot.icon,
          valueRegion: slot.value,
        ),
      );
    } else {
      items.removeWhere((item) => item.type == type);
      if (_itemType == type) _select(_RegionKind.avatar);
    }
    setState(() => _config = _config.copyWith(items: items));
  }

  void _updateRegion(DragUpdateDetails details, Size size) {
    final start = _start;
    if (start == null) return;
    final raw = Rect.fromPoints(start, details.localPosition);
    final rect = Rect.fromLTRB(
      (raw.left / size.width).clamp(0.0, 1.0),
      (raw.top / size.height).clamp(0.0, 1.0),
      (raw.right / size.width).clamp(0.0, 1.0),
      (raw.bottom / size.height).clamp(0.0, 1.0),
    );
    if (rect.width < 0.01 || rect.height < 0.01) return;
    setState(() {
      if (_kind == _RegionKind.avatar) {
        _config = _config.copyWith(avatarRegion: rect);
      } else if (_kind == _RegionKind.experience) {
        _config = _config.copyWith(experienceRegion: rect);
      } else {
        final type = _itemType;
        if (type == null) return;
        final items = _config.items.map((item) {
          if (item.type != type) return item;
          return JellyStatusItemConfig(
            type: type,
            iconRegion: _kind == _RegionKind.itemIcon ? rect : item.iconRegion,
            valueRegion: _kind == _RegionKind.itemValue
                ? rect
                : item.valueRegion,
          );
        }).toList();
        _config = _config.copyWith(items: items);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('screens_configureTopPanel'.tr),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarPicker(
                    size: 54,
                    username: widget.userName,
                    currentAvatarPath: widget.avatarPath,
                    defaultAvatarAsset: 'assets/images/default_avatar.jpg',
                    saveDirectory: 'avatars',
                    onAvatarChanged: widget.onAvatarChanged,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('点击头像可上传。选择区域后，在图片上拖拽绘制矩形。')),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('screens_avatarPosition'.tr),
                    selected: _kind == _RegionKind.avatar,
                    onSelected: (_) => _select(_RegionKind.avatar),
                  ),
                  ChoiceChip(
                    label: Text('screens_expBarPosition'.tr),
                    selected: _kind == _RegionKind.experience,
                    onSelected: (_) => _select(_RegionKind.experience),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final type in JellyStatusItemType.values)
                _buildItemControls(type),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    onPanStart: (details) => _start = details.localPosition,
                    onPanUpdate: (details) =>
                        _updateRegion(details, constraints.biggest),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        JellyConfigurableImage(
                          path: widget.asset,
                          fit: BoxFit.fill,
                        ),
                        _regionBox(
                          _config.avatarRegion,
                          constraints.biggest,
                          Colors.red,
                          '头像',
                        ),
                        _regionBox(
                          _config.experienceRegion,
                          constraints.biggest,
                          Colors.blue,
                          '经验',
                        ),
                        for (final item in _config.items) ...[
                          _regionBox(
                            item.iconRegion,
                            constraints.biggest,
                            Colors.green,
                            '${_label(item.type)}图标',
                          ),
                          _regionBox(
                            item.valueRegion,
                            constraints.biggest,
                            Colors.orange,
                            '${_label(item.type)}数值',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('app_cancel'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _config),
          child: Text('app_save'.tr),
        ),
      ],
    );
  }

  Widget _buildItemControls(JellyStatusItemType type) {
    final enabled = _config.items.any((item) => item.type == type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_label(type)),
              value: enabled,
              onChanged: (value) => _toggleItem(type, value ?? false),
            ),
          ),
          OutlinedButton.icon(
            onPressed: enabled
                ? () => _select(_RegionKind.itemIcon, type)
                : null,
            icon: const Icon(Icons.image_outlined, size: 16),
            label: Text('screens_iconPosition'.tr),
          ),
          OutlinedButton.icon(
            onPressed: enabled
                ? () => _select(_RegionKind.itemValue, type)
                : null,
            icon: const Icon(Icons.numbers, size: 16),
            label: Text('screens_valuePosition'.tr),
          ),
        ],
      ),
    );
  }

  Widget _regionBox(Rect rect, Size size, Color color, String label) {
    return Positioned.fromRect(
      rect: Rect.fromLTRB(
        rect.left * size.width,
        rect.top * size.height,
        rect.right * size.width,
        rect.bottom * size.height,
      ),
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            color: color.withValues(alpha: 0.1),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: ColoredBox(
              color: color,
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _label(JellyStatusItemType type) => switch (type) {
  JellyStatusItemType.mood => '情绪',
  JellyStatusItemType.energy => '精力',
  JellyStatusItemType.affection => '好感',
  JellyStatusItemType.companionDays => '陪伴天数',
};
