import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/tts/models/tts_service_config.dart';
import 'package:aboutme/plugins/tts/models/tts_service_type.dart';
import 'package:aboutme/plugins/tts/models/tts_voice.dart';
import 'package:aboutme/plugins/tts/services/minimax_tts_service.dart';
import 'package:aboutme/plugins/tts/services/system_tts_service.dart';

/// TTS服务编辑底部弹层（smooth_sheets ModalSheet，支持新建和编辑）
class TtsServiceForm extends StatefulWidget {
  /// 要编辑的服务配置（null表示新建）
  final TTSServiceConfig? service;

  const TtsServiceForm({super.key, this.service});

  /// 以 smooth_sheets 模态底部弹层打开，返回编辑结果（null 表示取消）
  static Future<TTSServiceConfig?> show(
    BuildContext context, {
    TTSServiceConfig? service,
  }) {
    return Navigator.of(context).push<TTSServiceConfig>(
      ModalSheetRoute(
        swipeDismissible: true,
        builder: (context) => TtsServiceForm(service: service),
      ),
    );
  }

  @override
  State<TtsServiceForm> createState() => _TtsServiceFormState();
}

class _TtsServiceFormState extends State<TtsServiceForm> {
  final _sheetController = SheetController();
  bool _expandingForWheel = false;

  // 基础配置
  late TextEditingController _nameController;
  late TTSServiceType _selectedType;
  late bool _isDefault;
  late bool _isEnabled;

  // 通用配置
  late double _pitch;
  late double _speed;
  late double _volume;
  late TextEditingController _voiceController;

  // HTTP 配置
  late TextEditingController _urlController;
  late TextEditingController _headersController;
  late TextEditingController _requestBodyController;
  late TextEditingController _audioFormatController;
  late String _responseType;
  late TextEditingController _audioFieldPathController;
  late bool _audioIsBase64;

  // MiniMax 配置
  late TextEditingController _apiKeyController;
  late TextEditingController _voiceIdController;
  late TextEditingController _emotionController;
  late TextEditingController _modelController;

  // 可用语音列表
  List<TTSVoice> _availableVoices = [];
  bool _loadingVoices = false;

  @override
  void initState() {
    super.initState();

    final service = widget.service;

    _nameController = TextEditingController(text: service?.name ?? '');
    _selectedType = service?.type ?? TTSServiceType.system;
    _isDefault = service?.isDefault ?? false;
    _isEnabled = service?.isEnabled ?? true;

    _pitch = service?.pitch ?? 1.0;
    _speed = service?.speed ?? 1.0;
    _volume = service?.volume ?? 1.0;
    _voiceController = TextEditingController(text: service?.voice ?? 'zh-CN');

    _urlController = TextEditingController(text: service?.url ?? '');
    _headersController = TextEditingController(
      text: service?.headers != null
          ? service!.headers!.entries.map((e) => '${e.key}: ${e.value}').join('\n')
          : '',
    );
    _requestBodyController = TextEditingController(text: service?.requestBody ?? '');
    _audioFormatController = TextEditingController(text: service?.audioFormat ?? 'mp3');
    _responseType = service?.responseType ?? 'audio';
    _audioFieldPathController = TextEditingController(text: service?.audioFieldPath ?? '');
    _audioIsBase64 = service?.audioIsBase64 ?? false;

    _apiKeyController = TextEditingController(text: service?.apiKey ?? '');
    _voiceIdController = TextEditingController(text: service?.voiceId ?? 'female-tianmei');
    _emotionController = TextEditingController(text: service?.emotion ?? '');
    _modelController = TextEditingController(text: service?.model ?? 'speech-2.8-hd');

    if (_selectedType == TTSServiceType.system) {
      _loadAvailableVoices();
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _nameController.dispose();
    _voiceController.dispose();
    _urlController.dispose();
    _headersController.dispose();
    _requestBodyController.dispose();
    _audioFormatController.dispose();
    _audioFieldPathController.dispose();
    _apiKeyController.dispose();
    _voiceIdController.dispose();
    _emotionController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  /// 加载系统TTS可用语音列表
  Future<void> _loadAvailableVoices() async {
    if (_loadingVoices) return;

    setState(() => _loadingVoices = true);
    try {
      final tempConfig = TTSServiceConfig(
        name: 'temp',
        type: TTSServiceType.system,
      );

      final service = SystemTTSService(tempConfig);
      await service.initialize();
      final voices = await service.getAvailableVoices();
      await service.dispose();

      setState(() {
        _availableVoices = voices;
        _loadingVoices = false;

        if (_availableVoices.isNotEmpty &&
            !_availableVoices.any((v) => v.id == _voiceController.text)) {
          _voiceController.text = _availableVoices.first.id;
        }
      });
    } catch (e) {
      setState(() => _loadingVoices = false);
      if (mounted) {
        Toast.error('${'tts_loadVoiceListFailed'.tr}: $e');
      }
    }
  }

  /// 去除重复 ID 的语音列表
  List<TTSVoice> _deduplicatedVoices(List<TTSVoice> voices) {
    final seenIds = <String>{};
    final deduplicated = <TTSVoice>[];
    for (final voice in voices) {
      if (seenIds.add(voice.id)) {
        deduplicated.add(voice);
      }
    }
    return deduplicated;
  }

  /// 解析请求头文本为 Map
  Map<String, String>? _parseHeaders() {
    final text = _headersController.text.trim();
    if (text.isEmpty) return null;

    final headers = <String, String>{};
    for (final line in text.split('\n')) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join(':').trim();
        headers[key] = value;
      }
    }

    return headers.isEmpty ? null : headers;
  }

  /// 保存前校验，返回错误文案（null 表示通过）
  String? _validate() {
    if (_nameController.text.trim().isEmpty) {
      return 'tts_pleaseEnterName'.tr;
    }
    if (_selectedType == TTSServiceType.http) {
      final url = _urlController.text.trim();
      if (url.isEmpty) return 'tts_pleaseEnterApiUrl'.tr;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        return 'tts_urlMustStartWithHttp'.tr;
      }
      if (_responseType == 'json' && _audioFieldPathController.text.trim().isEmpty) {
        return 'tts_pleaseEnterAudioFieldPath'.tr;
      }
    }
    if (_selectedType == TTSServiceType.minimax) {
      if (_apiKeyController.text.trim().isEmpty) return 'tts_pleaseEnterApiKey'.tr;
      if (_voiceIdController.text.trim().isEmpty) return 'tts_pleaseEnterVoiceId'.tr;
    }
    return null;
  }

  /// 保存配置
  Future<void> _saveService() async {
    final error = _validate();
    if (error != null) {
      Toast.error(error);
      return;
    }

    try {
      final service = TTSServiceConfig(
        id: widget.service?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        type: _selectedType,
        isDefault: _isDefault,
        isEnabled: _isEnabled,
        pitch: _pitch,
        speed: _speed,
        volume: _volume,
        voice: (_selectedType == TTSServiceType.system || _selectedType == TTSServiceType.http)
            ? _voiceController.text.trim()
            : null,
        // HTTP 配置
        url: _selectedType == TTSServiceType.http ? _urlController.text.trim() : null,
        headers: _selectedType == TTSServiceType.http ? _parseHeaders() : null,
        requestBody: _selectedType == TTSServiceType.http ? _requestBodyController.text.trim() : null,
        audioFormat: (_selectedType == TTSServiceType.http || _selectedType == TTSServiceType.minimax)
            ? _audioFormatController.text.trim()
            : null,
        responseType: _selectedType == TTSServiceType.http ? _responseType : null,
        audioFieldPath: _selectedType == TTSServiceType.http && _responseType == 'json'
            ? _audioFieldPathController.text.trim()
            : null,
        audioIsBase64: _selectedType == TTSServiceType.http ? _audioIsBase64 : null,
        // MiniMax 配置
        apiKey: _selectedType == TTSServiceType.minimax ? _apiKeyController.text.trim() : null,
        voiceId: _selectedType == TTSServiceType.minimax ? _voiceIdController.text.trim() : null,
        emotion: _selectedType == TTSServiceType.minimax
            ? (_emotionController.text.trim().isEmpty ? null : _emotionController.text.trim())
            : null,
        model: _selectedType == TTSServiceType.minimax ? _modelController.text.trim() : null,
        createdAt: widget.service?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (!service.validate()) {
        Toast.error('tts_configValidationFailed'.tr);
        return;
      }

      if (mounted) {
        Navigator.of(context).pop(service);
      }
    } catch (e) {
      if (mounted) {
        Toast.error('${'tts_saveFailed'.tr}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final isEditing = widget.service != null;

          // 双档吸附：半屏档（视口65%）+ 满屏档；表单不足半屏时
          // SheetOffset(1)（内容全显）像素更小，自动成为最低档
          return Sheet(
            controller: _sheetController,
            // 显式启用联动滚动，让 primary 滚动视图在滚动前先展开弹层。
            scrollConfiguration: const SheetScrollConfiguration(),
            initialOffset: const SheetOffset.proportionalToViewport(0.65),
            snapGrid: const SheetSnapGrid(
              snaps: [SheetOffset.proportionalToViewport(0.65), SheetOffset(1)],
            ),
            child: DsSketchPanel(
              theme: theme,
              width: double.infinity,
              radius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDragHandle(theme),
                  _buildTitleBar(theme, isEditing),
                  Flexible(
                    child: Listener(
                      onPointerSignal: _handleFormPointerSignal,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.depth == 0 &&
                              notification is ScrollEndNotification) {
                            _debugScrollMetrics(notification.metrics);
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          // Join the sheet's coordinated scroll controller so form drags work.
                          primary: true,
                          padding: EdgeInsets.fromLTRB(
                            theme.spacing.xl,
                            theme.spacing.sm,
                            theme.spacing.xl,
                            theme.spacing.lg,
                          ),
                          child: _buildForm(theme),
                        ),
                      ),
                    ),
                  ),
                  _buildBottomBar(theme),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _debugScrollMetrics(ScrollMetrics scroll) {
    assert(() {
      final sheet = _sheetController.metrics;
      debugPrint(
        '[TtsServiceForm] type=$_selectedType '
        'sheetOffset=${sheet?.offset} sheetHeight=${sheet?.contentSize.height} '
        'scroll=${scroll.pixels}/${scroll.maxScrollExtent} '
        'viewport=${scroll.viewportDimension}',
      );
      return true;
    }());
  }

  void _handleFormPointerSignal(PointerSignalEvent event) {
    // smooth_sheets 0.15 的滚轮只滚动内容，不会像触摸拖动一样展开面板。
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dy <= 0 ||
        _expandingForWheel) {
      return;
    }
    final metrics = _sheetController.metrics;
    if (metrics == null ||
        metrics.offset >= const SheetOffset(1).resolve(metrics) - 1) {
      return;
    }
    _expandingForWheel = true;
    // 等滚轮自身的 pointerScroll/goBallistic 完成，避免展开动画被取消。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await _sheetController.animateTo(const SheetOffset(1));
        assert(() {
          debugPrint('[TtsServiceForm] wheel expanded: '
              'sheetOffset=${_sheetController.metrics?.offset}');
          return true;
        }());
      } finally {
        _expandingForWheel = false;
      }
    });
  }

  /// 拖拽把手（与 SmoothBottomSheet 同款手绘样式）
  Widget _buildDragHandle(AppThemeData theme) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: theme.spacing.md),
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: theme.surfaceAlt,
          borderRadius: theme.radii.pill,
          border: Border.all(
            color: theme.ink.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(AppThemeData theme, bool isEditing) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.xl,
        theme.spacing.sm,
        theme.spacing.md,
        theme.spacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isEditing ? 'tts_editService'.tr : 'tts_addService'.tr,
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
          ),
          DSIconButton(
            icon: DsIconKind.close,
            size: 36,
            color: theme.surfaceAlt,
            iconColor: theme.textSub,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.xl,
        theme.spacing.sm,
        theme.spacing.xl,
        theme.spacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: DSButton(
              label: 'tts_cancel'.tr,
              variant: DSButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: DSButton(
              label: 'tts_save'.tr,
              icon: DsIconKind.check,
              onPressed: _saveService,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ===== 基础配置 =====
        _buildSectionTitle(theme, 'tts_basicConfig'.tr),
        SizedBox(height: theme.spacing.md),

        DSInput(
          controller: _nameController,
          label: 'tts_serviceName'.tr,
          prefix: DsIcon(DsIconKind.tag, size: 18, color: theme.textSub),
        ),
        SizedBox(height: theme.spacing.lg),

        _buildFieldLabel(theme, 'tts_serviceType'.tr),
        DSSelect<TTSServiceType>(
          value: _selectedType,
          hint: 'tts_pleaseSelect'.tr,
          items: [
            for (final type in TTSServiceType.values)
              DSSelectItem(value: type, label: _typeLabel(type)),
          ],
          onChanged: (type) => setState(() {
            _selectedType = type;
            if (type == TTSServiceType.system) {
              _loadAvailableVoices();
            }
          }),
        ),
        SizedBox(height: theme.spacing.md),

        _buildSwitchRow(
          theme,
          title: 'tts_enabled'.tr,
          subtitle: _isEnabled ? 'tts_enableThisService'.tr : 'tts_disableThisService'.tr,
          value: _isEnabled,
          onChanged: (value) => setState(() => _isEnabled = value),
        ),
        _buildSwitchRow(
          theme,
          title: 'tts_defaultService'.tr,
          subtitle: 'tts_setAsDefaultTTSService'.tr,
          value: _isDefault,
          onChanged: (value) => setState(() => _isDefault = value),
        ),
        SizedBox(height: theme.spacing.lg),

        // ===== 朗读参数 =====
        _buildSectionTitle(theme, 'tts_readingParameters'.tr),
        SizedBox(height: theme.spacing.md),

        _buildSliderRow(
          theme,
          label: 'tts_pitch'.tr,
          value: _pitch,
          min: 0.5,
          max: 2.0,
          onChanged: (value) => setState(() => _pitch = value),
        ),
        _buildSliderRow(
          theme,
          label: 'tts_speed'.tr,
          value: _speed,
          min: 0.5,
          max: 2.0,
          onChanged: (value) => setState(() => _speed = value),
        ),
        _buildSliderRow(
          theme,
          label: 'tts_volume'.tr,
          value: _volume,
          min: 0.0,
          max: 1.0,
          onChanged: (value) => setState(() => _volume = value),
        ),
        SizedBox(height: theme.spacing.md),

        // 语音/语言
        if (_selectedType == TTSServiceType.system)
          _buildSystemVoiceField(theme)
        else if (_selectedType == TTSServiceType.http)
          DSInput(
            controller: _voiceController,
            label: 'tts_voice'.tr,
            hint: 'tts_fillAccordingToApi'.tr,
          ),

        // ===== HTTP 配置 =====
        if (_selectedType == TTSServiceType.http) ...[
          SizedBox(height: theme.spacing.lg),
          _buildSectionTitle(theme, 'tts_httpConfig'.tr),
          SizedBox(height: theme.spacing.md),

          DSInput(
            controller: _urlController,
            label: 'tts_apiUrl'.tr,
            hint: 'https://api.example.com/tts',
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            'tts_urlPlaceholderHint'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          SizedBox(height: theme.spacing.lg),

          DSInput(
            controller: _headersController,
            label: 'tts_headers'.tr,
            hint: 'Content-Type: application/json\nAuthorization: Bearer token',
            maxLines: 3,
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            'tts_headersHint'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          SizedBox(height: theme.spacing.lg),

          DSInput(
            controller: _requestBodyController,
            label: 'tts_requestBody'.tr,
            hint: '{"text": "{text}", "voice": "{voice}"}',
            maxLines: 5,
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            'tts_requestBodyHint'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          SizedBox(height: theme.spacing.lg),

          _buildFieldLabel(theme, 'tts_responseType'.tr),
          DSSelect<String>(
            value: _responseType,
            items: [
              DSSelectItem(value: 'audio', label: 'tts_directAudioReturn'.tr),
              DSSelectItem(value: 'json', label: 'tts_jsonWrapped'.tr),
            ],
            onChanged: (value) => setState(() => _responseType = value),
          ),
          SizedBox(height: theme.spacing.lg),

          if (_responseType == 'json') ...[
            DSInput(
              controller: _audioFieldPathController,
              label: 'tts_audioFieldPath'.tr,
              hint: 'data.audio / result.audioUrl',
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              'tts_audioFieldPathHint'.tr,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
            SizedBox(height: theme.spacing.lg),

            _buildSwitchRow(
              theme,
              title: 'tts_audioBase64Encoded'.tr,
              subtitle: 'tts_audioIsBase64Encoded'.tr,
              value: _audioIsBase64,
              onChanged: (value) => setState(() => _audioIsBase64 = value),
            ),
            SizedBox(height: theme.spacing.lg),
          ],

          DSInput(
            controller: _audioFormatController,
            label: 'tts_audioFormat'.tr,
            hint: 'mp3, wav, ogg, pcm',
          ),
        ],

        // ===== MiniMax 配置 =====
        if (_selectedType == TTSServiceType.minimax) ...[
          SizedBox(height: theme.spacing.lg),
          _buildSectionTitle(theme, 'tts_minimaxConfig'.tr),
          SizedBox(height: theme.spacing.md),

          DSInput(
            controller: _apiKeyController,
            label: 'tts_apiKey'.tr,
            hint: 'MiniMax API Key',
            obscureText: true,
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            'tts_apiKeyHint'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          SizedBox(height: theme.spacing.lg),

          DSInput(
            controller: _voiceIdController,
            label: 'tts_voiceId'.tr,
            hint: 'female-tianmei, male-qn-qingse, etc.',
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            'tts_voiceIdHint'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          SizedBox(height: theme.spacing.lg),

          _buildFieldLabel(theme, 'tts_model'.tr),
          DSSelect<String>(
            value: MiniMaxTTSService.getAvailableModels().contains(_modelController.text)
                ? _modelController.text
                : MiniMaxTTSService.getAvailableModels().first,
            items: [
              for (final model in MiniMaxTTSService.getAvailableModels())
                DSSelectItem(value: model, label: model),
            ],
            onChanged: (value) => setState(() => _modelController.text = value),
          ),
          SizedBox(height: theme.spacing.lg),

          _buildFieldLabel(theme, 'tts_emotion'.tr),
          DSSelect<String>(
            value: MiniMaxTTSService.getAvailableEmotions().contains(_emotionController.text)
                ? _emotionController.text
                : '',
            items: [
              DSSelectItem(value: '', label: 'tts_auto'.tr),
              for (final emotion in MiniMaxTTSService.getAvailableEmotions())
                DSSelectItem(value: emotion, label: _emotionLabel(emotion)),
            ],
            onChanged: (value) => setState(() => _emotionController.text = value),
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            'tts_emotionHelper'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          SizedBox(height: theme.spacing.lg),

          _buildFieldLabel(theme, 'tts_audioFormat'.tr),
          DSSelect<String>(
            value: ['mp3', 'pcm', 'flac'].contains(_audioFormatController.text)
                ? _audioFormatController.text
                : 'mp3',
            items: const [
              DSSelectItem(value: 'mp3', label: 'MP3'),
              DSSelectItem(value: 'pcm', label: 'PCM'),
              DSSelectItem(value: 'flac', label: 'FLAC'),
            ],
            onChanged: (value) => setState(() => _audioFormatController.text = value),
          ),
        ],
      ],
    );
  }

  /// 系统TTS语音选择（含加载态与手动回退）
  Widget _buildSystemVoiceField(AppThemeData theme) {
    if (_loadingVoices) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DSInput(
            controller: _voiceController,
            label: 'tts_voice'.tr,
            enabled: false,
          ),
          SizedBox(height: theme.spacing.sm),
          Row(
            children: [
              DSLoadingDots(size: 8, color: theme.textSub),
              SizedBox(width: theme.spacing.sm),
              Text(
                'tts_loadingVoiceList'.tr,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ],
          ),
        ],
      );
    }

    final voices = _deduplicatedVoices(_availableVoices);
    if (voices.isEmpty) {
      return DSInput(
        controller: _voiceController,
        label: 'tts_voice'.tr,
        hint: 'zh-CN, en-US, etc.',
      );
    }

    final currentId = voices.any((v) => v.id == _voiceController.text)
        ? _voiceController.text
        : voices.first.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(
          theme,
          'tts_voice'.tr,
          trailing: 'tts_availableVoiceCount'.trParams({'count': '${voices.length}'}),
        ),
        DSSelect<String>(
          value: currentId,
          hint: 'tts_pleaseSelect'.tr,
          items: [
            for (final voice in voices)
              DSSelectItem(value: voice.id, label: _voiceLabel(voice)),
          ],
          onChanged: (id) => setState(() => _voiceController.text = id),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(AppThemeData theme, String title) {
    return Text(
      title,
      style: DsTypography.title.copyWith(color: theme.primary),
    );
  }

  /// 字段标签行（用于无内置 label 的 DSSelect）
  Widget _buildFieldLabel(AppThemeData theme, String label, {String? trailing}) {
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: DsTypography.label.copyWith(color: theme.textSub),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
        ],
      ),
    );
  }

  /// 开关行（标题/副标题 + DSSwitch）
  Widget _buildSwitchRow(
    AppThemeData theme, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DsTypography.body.copyWith(color: theme.text)),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ),
          ),
          DSSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// 滑杆行（DSSlider 归一化 0~1，标签行显示实际值）
  Widget _buildSliderRow(
    AppThemeData theme, {
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: DsTypography.body.copyWith(color: theme.text)),
              Text(
                value.toStringAsFixed(2),
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ],
          ),
          DSSlider(
            value: ((value - min) / (max - min)).clamp(0.0, 1.0),
            onChanged: (v) => onChanged(min + v * (max - min)),
          ),
        ],
      ),
    );
  }

  String _typeLabel(TTSServiceType type) {
    switch (type) {
      case TTSServiceType.system:
        return 'tts_systemTts'.tr;
      case TTSServiceType.http:
        return 'tts_httpService'.tr;
      case TTSServiceType.minimax:
        return 'tts_minimaxService'.tr;
    }
  }

  String _voiceLabel(TTSVoice voice) {
    final gender = voice.gender;
    if (gender == null) return '${voice.name} (${voice.language})';
    return '${voice.name} (${voice.language} · ${_genderLabel(gender)})';
  }

  String _genderLabel(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return 'tts_male'.tr;
      case 'female':
        return 'tts_female'.tr;
      case 'neutral':
        return 'tts_neutral'.tr;
      default:
        return gender;
    }
  }

  String _emotionLabel(String emotion) {
    switch (emotion) {
      case 'happy':
        return 'tts_emotionHappy'.tr;
      case 'sad':
        return 'tts_emotionSad'.tr;
      case 'angry':
        return 'tts_emotionAngry'.tr;
      case 'fearful':
        return 'tts_emotionFearful'.tr;
      case 'disgusted':
        return 'tts_emotionDisgusted'.tr;
      case 'surprised':
        return 'tts_emotionSurprised'.tr;
      case 'calm':
        return 'tts_emotionCalm'.tr;
      case 'fluent':
        return 'tts_emotionFluent'.tr;
      case 'whisper':
        return 'tts_emotionWhisper'.tr;
      default:
        return emotion;
    }
  }
}
