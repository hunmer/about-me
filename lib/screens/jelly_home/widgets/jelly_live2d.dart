import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:live2d_flutter/live2d_flutter.dart';

class JellyLive2D extends StatefulWidget {
  const JellyLive2D({super.key});

  @override
  State<JellyLive2D> createState() => _JellyLive2DState();
}

class _JellyLive2DState extends State<JellyLive2D> {
  final Live2DViewController _controller = Live2DViewController();
  _Live2DModel _selectedModel = _models.first;

  @override
  void initState() {
    super.initState();
    _loadModel(_selectedModel);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadModel(_Live2DModel model) async {
    try {
      await _controller.whenAttached;
      if (!mounted) return;
      await _controller.loadModel(
        modelDir: model.assetFolder,
        modelFileName: model.modelFile,
      );
    } on Live2DException {
      // The controller exposes the detailed error through Live2DViewState.
    }
  }

  Future<void> _selectModel(_Live2DModel model) async {
    if (model == _selectedModel || _controller.value.isLoadingModel) return;
    setState(() => _selectedModel = model);
    await _loadModel(model);
  }

  void _showControls() {
    assert(() {
      debugPrint(
        '[JellyLive2D] open controls model=${_selectedModel.label} '
        'attached=${_controller.value.isAttached} '
        'loaded=${_controller.value.isLoaded}',
      );
      return true;
    }());
    showDSBottomSheet<void>(
      context: context,
      title: 'Live2D',
      builder: (sheetContext) {
        final theme = AppTheme.of(sheetContext);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            theme.spacing.xl,
            0,
            theme.spacing.xl,
            theme.spacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '切换模型',
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.sm),
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: [
                  for (final model in _models)
                    DSChip(
                      label: model.label,
                      selected: model == _selectedModel,
                      onSelected: (_) {
                        Navigator.of(sheetContext).pop();
                        _selectModel(model);
                      },
                    ),
                ],
              ),
              SizedBox(height: theme.spacing.xl),
              Text(
                '动作列表',
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.sm),
              if (_selectedModel.motions.isEmpty)
                Text(
                  '当前模型没有可用动作',
                  style: DsTypography.body.copyWith(color: theme.textSub),
                )
              else
                for (final motion in _selectedModel.motions) ...[
                  DSListItem(
                    title: motion.label,
                    leading: DsIcon(
                      DsIconKind.play,
                      size: 18,
                      color: theme.primary,
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _controller.startMotion(
                        group: motion.group,
                        index: motion.index,
                      );
                    },
                  ),
                  SizedBox(height: theme.spacing.sm),
                ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return SizedBox(
      width: 280,
      height: 280,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: _showControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Live2DView(controller: _controller),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: ValueListenableBuilder<Live2DViewState>(
                  valueListenable: _controller,
                  builder: (context, state, child) {
                    final error = state.lastError;
                    final label =
                        error == null
                            ? _selectedModel.label
                            : '加载失败：${error.message}';
                    return Container(
                      constraints: const BoxConstraints(maxWidth: 260),
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacing.md,
                        vertical: theme.spacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: (error == null ? theme.surface : theme.danger)
                            .withValues(alpha: 0.88),
                        borderRadius: theme.radii.pill,
                        boxShadow: theme.shadows.soft,
                      ),
                      child: Text(
                        state.isLoadingModel
                            ? '正在加载 ${_selectedModel.label}'
                            : label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsTypography.caption.copyWith(
                          color: error == null ? theme.text : theme.onDanger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Live2DModel {
  const _Live2DModel({
    required this.label,
    required this.assetFolder,
    required this.modelFile,
    required this.motions,
  });

  final String label;
  final String assetFolder;
  final String modelFile;
  final List<_Live2DMotion> motions;
}

class _Live2DMotion {
  const _Live2DMotion(this.group, this.index, this.label);

  final String group;
  final int index;
  final String label;
}

const List<_Live2DModel> _models = [
  _Live2DModel(
    label: 'Mao',
    assetFolder: 'assets/models/mao/',
    modelFile: 'mao_pro.model3.json',
    motions: [
      _Live2DMotion('Idle', 0, '待机'),
      _Live2DMotion('', 0, '动作 1'),
      _Live2DMotion('', 1, '动作 2'),
      _Live2DMotion('', 2, '动作 3'),
      _Live2DMotion('', 3, '特殊动作 1'),
      _Live2DMotion('', 4, '特殊动作 2'),
      _Live2DMotion('', 5, '特殊动作 3'),
    ],
  ),
  _Live2DModel(
    label: 'IceGirl',
    assetFolder: 'assets/models/icegirl/',
    modelFile: 'IceGirl.model3.json',
    motions: [],
  ),
  _Live2DModel(
    label: 'Ren',
    assetFolder: 'assets/models/ren/',
    modelFile: 'ren.model3.json',
    motions: [
      _Live2DMotion('Idle', 0, '待机'),
      _Live2DMotion('', 0, '动作 1'),
      _Live2DMotion('', 1, '动作 2'),
    ],
  ),
];
