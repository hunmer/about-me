import 'package:get/get.dart';
import 'dart:async';
import 'dart:io';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
// 添加本地化导入
import 'request_service.dart';
import 'package:aboutme/core/services/toast_service.dart';

class TestService {
  // 用于存储最后一次输入的文本的键
  static const String _lastInputKey = 'last_test_input';

  /// 保存最后一次输入的文本
  static Future<void> saveLastInput(String input) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastInputKey, input);
      debugPrint('已保存最后一次输入的文本');
    } catch (e) {
      debugPrint('保存最后一次输入的文本失败: $e');
    }
  }

  /// 读取最后一次输入的文本
  static Future<String> getLastInput() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastInputKey) ?? '';
    } catch (e) {
      debugPrint('读取最后一次输入的文本失败: $e');
      return '';
    }
  }

  /// 显示长文本输入对话框，支持图片选择，自动加载上次输入的文本
  static Future<Map<String, dynamic>?> showLongTextInputDialog(
    BuildContext context, {
    String? title,
    String? hintText,
    String? initialValue,
    bool enableImagePicker = false,
    AIAgent? testAgent,
    Map<String, dynamic>? formValues,
  }) async {
    // 获取本地化实例

    // 如果没有提供初始值，则尝试加载上次输入的文本
    String loadedInitialValue = initialValue ?? await getLastInput();

    final result = await showDSDialog<Map<String, dynamic>>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      barrierDismissible: true, // 关闭按钮已移除，通过点击外部关闭；状态均有 _isDisposed 守卫
      builder: (BuildContext dialogContext) {
        return _TextInputDialog(
          title: title ?? 'openai_testInput'.tr,
          hintText: hintText ?? 'openai_enterTestText'.tr,
          initialValue: loadedInitialValue,
          enableImagePicker: enableImagePicker,
          testAgent: testAgent,
          formValues: formValues,
        );
      },
    );

    // 如果用户输入了文本并点击了确定，保存这次输入
    if (result != null && result['text'] != null && result['text'].isNotEmpty) {
      await saveLastInput(result['text']);
    }

    return result;
  }

  /// 发送请求并获取响应
  ///
  /// [shouldCancel] 返回 true 时中断流式请求并返回 null（取消）。
  /// 仅 /image 生成分支不支持中断，由调用方放弃等待。
  static Future<String?> processTestRequest(
    String input,
    AIAgent agent, {
    File? imageFile,
    Map<String, dynamic>? formValues,
    bool Function()? shouldCancel,
  }) async {
    // 如果有表单值，创建一个新的agent并合并表单值
    if (formValues != null && formValues.isNotEmpty) {
      agent = agent.copyWith(
        name: formValues['name'] ?? agent.name,
        baseUrl: formValues['baseUrl'] ?? agent.baseUrl,
        model: formValues['model'] ?? agent.model,
        temperature: formValues['temperature']?.toDouble() ?? agent.temperature,
        maxLength: formValues['maxLength'] ?? agent.maxLength,
        topP: formValues['topP']?.toDouble() ?? agent.topP,
        frequencyPenalty:
            formValues['frequencyPenalty']?.toDouble() ??
            agent.frequencyPenalty,
        presencePenalty:
            formValues['presencePenalty']?.toDouble() ?? agent.presencePenalty,
        stop: formValues['stop'] ?? agent.stop,
        serviceProviderId:
            formValues['serviceProviderId'] ?? agent.serviceProviderId,
      );
    }
    // 保存这次输入
    await saveLastInput(input);
    try {
      String response;
      if (input.toLowerCase().startsWith("/image")) {
        // 处理图片生成请求
        final prompt = input.substring(6).trim(); // 移除 "/image "
        if (prompt.isEmpty) {
          return "请在 /image 命令后提供图片描述。";
        }

        final imageUrls = await RequestService.generateImages(prompt, agent);
        response = '''
生成的图片链接:
${imageUrls.map((url) => "- $url").join('\n')}

提示词: $prompt
''';
      } else {
        // 处理聊天请求（流式，支持取消）
        final buffer = StringBuffer();
        String? errorMessage;
        await RequestService.streamResponse(
          agent: agent,
          prompt: input,
          filePath: imageFile?.path,
          shouldCancel: shouldCancel,
          onToken: (token) => buffer.write(token),
          onError: (error) => errorMessage = error,
          onComplete: () {},
        );

        // 已取消
        if (shouldCancel?.call() == true) {
          return null;
        }
        if (errorMessage != null) {
          return '''
错误: 请求处理失败
${'openai_errorDetails'.tr}: $errorMessage

${'openai_checkItems'.tr}:
1. ${'openai_apiKeyConfig'.tr}
2. ${'openai_networkConnection'.tr}
3. ${'openai_serviceEndpoint'.tr}
''';
        }
        response =
            buffer.isEmpty ? 'No response content' : buffer.toString();
      }

      return '''
输入: "${input.length > 50 ? '${input.substring(0, 50)}...' : input}"
    
回应:
$response

---
智能体: ${agent.name} (${agent.serviceProviderId})
API端点: ${agent.baseUrl}
''';
    } catch (e) {
      return '''
错误: 请求处理失败
${'openai_errorDetails'.tr}: ${e.toString()}

${'openai_checkItems'.tr}:
1. ${'openai_apiKeyConfig'.tr}
2. ${'openai_networkConnection'.tr}
3. ${'openai_serviceEndpoint'.tr}
''';
    }
  }

  /// 显示响应结果对话框
  static void showResponseDialog(BuildContext context, String response) {
    // 检查响应是否包含图片URL
    final containsImageUrl =
        response.contains('生成的图片链接:') &&
        (response.contains('http://') || response.contains('https://'));

    // 使用独立的context避免MediaQuery依赖问题
    // 获取本地化实例

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              // SelectableText 需要 Material 祖先
              return Material(
                type: MaterialType.transparency,
                child: JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'openai_testResponse'.tr,
                          textAlign: TextAlign.center,
                          style: DsTypography.title.copyWith(color: theme.text),
                        ),
                        const SizedBox(height: 16),
                        SelectableText(
                          response,
                          style: DsTypography.body.copyWith(color: theme.text),
                        ),
                        if (containsImageUrl) ...[
                          const SizedBox(height: 16),
                          Text(
                            '${'openai_previewImages'.tr}:',
                            style: DsTypography.body.copyWith(
                              color: theme.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildImagePreview(response, context),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: DSButton(
                            label: 'openai_close'.tr,
                            variant: DSButtonVariant.outline,
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 从响应中提取并显示图片
  static Widget _buildImagePreview(String response, BuildContext context) {
    // 提取URL
    final RegExp urlRegex = RegExp(r'https?://\S+');
    final matches = urlRegex.allMatches(response);

    // 获取本地化实例

    if (matches.isEmpty) {
      return const _LoadFailedText();
    }

    // 使用ValueKey生成唯一键以避免重复键问题
    return Column(
      key: ValueKey('image_preview_${DateTime.now().millisecondsSinceEpoch}'),
      children:
          matches.map((match) {
            final url = match.group(0)!;
            // 移除URL末尾可能的标点符号
            final cleanUrl = url.replaceAll(RegExp(r'[,.\s;]$'), '');

            // 为每个图片容器生成唯一键
            final uniqueKey = ValueKey(
              'img_${cleanUrl.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
            );

            return Container(
              key: uniqueKey,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      cleanUrl,
                      // 设置合理的宽度限制
                      width: MediaQuery.of(context).size.width * 0.7,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        final total = loadingProgress.expectedTotalBytes;
                        return Container(
                          width: 300,
                          height: 200,
                          alignment: Alignment.center,
                          child:
                              total != null
                                  ? DSRingProgress(
                                    value:
                                        loadingProgress.cumulativeBytesLoaded /
                                        total,
                                    size: 60,
                                    strokeWidth: 6,
                                    child: const SizedBox.shrink(),
                                  )
                                  : const DSLoadingDots(size: 6),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 300,
                          height: 100,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: DSThemeBridge.resolve(context).surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const _LoadFailedText(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final theme = DSThemeBridge.resolve(context);
                      return SelectableText(
                        cleanUrl,
                        style: DsTypography.caption.copyWith(
                          color: theme.primary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}

/// 图片加载失败文案
class _LoadFailedText extends StatelessWidget {
  const _LoadFailedText();

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Text(
      'openai_imageLoadFailed'.tr,
      style: DsTypography.caption.copyWith(color: theme.textSub),
    );
  }
}

/// 文本输入对话框组件
class _TextInputDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String initialValue;
  final bool enableImagePicker;
  final AIAgent? testAgent;
  final Map<String, dynamic>? formValues;

  const _TextInputDialog({
    required this.title,
    required this.hintText,
    required this.initialValue,
    this.enableImagePicker = false,
    this.testAgent,
    this.formValues,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;
  bool _isDisposed = false;
  bool _isLoading = false;
  File? _selectedImage;
  String? _testResult; // 测试结果
  bool _isTesting = false; // 是否正在测试
  Completer<void>? _cancelCompleter; // 取消测试信号（/image 等不支持中断时的放弃等待）
  bool _cancelRequested = false; // 取消标志（传给底层流式请求以真正中断）

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  /// 加载上次输入的文本
  Future<void> _loadLastInput() async {
    if (_isDisposed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final lastInput = await TestService.getLastInput();
      if (!_isDisposed && lastInput.isNotEmpty) {
        _controller.text = lastInput;
      }
    } catch (e) {
      debugPrint('加载上次输入失败: $e');
      if (!_isDisposed) {
        toastService.showToast('openai_lastInputLoadFailed'.tr);
      }
    } finally {
      if (!_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 选择图片
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null &&
        result.files.isNotEmpty &&
        result.files.first.path != null) {
      setState(() {
        _selectedImage = File(result.files.first.path!);
      });
    }
  }

  /// 执行测试
  Future<void> _runTest() async {
    if (_isDisposed || widget.testAgent == null) return;

    final input = _controller.text.trim();
    if (input.isEmpty) {
      if (!_isDisposed) {
        toastService.showToast('openai_enterTestText'.tr);
      }
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    _cancelRequested = false;
    _cancelCompleter = Completer<void>();

    String? response;
    try {
      // 保存输入
      await TestService.saveLastInput(input);

      // 聊天请求通过 shouldCancel 真正中断；
      // Future.any 兜底放弃等待（覆盖 /image 生成分支）
      response = await Future.any<String?>([
        TestService.processTestRequest(
          input,
          widget.testAgent!,
          imageFile: _selectedImage,
          formValues: widget.formValues,
          shouldCancel: () => _cancelRequested,
        ),
        _cancelCompleter!.future.then((_) => null),
      ]);
    } catch (e) {
      response = '测试失败: $e';
    }

    if (_isDisposed) return;
    setState(() {
      _isTesting = false;
      _cancelCompleter = null;
      _testResult = response ?? 'openai_testCancelled'.tr;
    });
  }

  /// 取消测试
  void _cancelTest() {
    if (_isDisposed || !_isTesting) return;
    _cancelRequested = true;
    _cancelCompleter?.complete();
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          // SelectableText 需要 Material 祖先
          return Material(
            type: MaterialType.transparency,
            child: JellyBox(
              radius: theme.radii.xxl,
              padding: EdgeInsets.all(theme.spacing.xl),
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: DsTypography.title.copyWith(
                              color: theme.text,
                            ),
                          ),
                        ),
                        // 加载上次输入的按钮
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child:
                                _isLoading
                                    ? const DSLoadingDots(size: 4)
                                    : DSIconButton(
                                      icon: DsIconKind.refresh,
                                      size: 36,
                                      color: theme.surfaceAlt,
                                      iconColor: theme.textSub,
                                      tooltip: 'openai_loadLastInput'.tr,
                                      onPressed:
                                          _isLoading ? null : _loadLastInput,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: theme.spacing.md),
                    DSInput(
                      controller: _controller,
                      hint: widget.hintText,
                      maxLines: 10,
                      enabled: !_isTesting, // 测试时禁用输入
                    ),
                    if (widget.enableImagePicker) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          DSButton(
                            onPressed: _pickImage,
                            icon: DsIconKind.image,
                            label: 'openai_selectImage'.tr,
                            size: DSButtonSize.sm,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedImage != null
                                  ? '${'openai_selectedImage'.tr}: ${_selectedImage!.path.split('/').last}'
                                  : 'openai_noImageSelected'.tr,
                              overflow: TextOverflow.ellipsis,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DSButton(
                            onPressed: () {
                              setState(() {
                                _testResult = null;
                              });
                            },
                            label: 'openai_clearOutput'.tr,
                            variant: DSButtonVariant.ghost,
                            size: DSButtonSize.sm,
                          ),
                        ],
                      ),
                      if (_selectedImage != null) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImage!,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ],
                    // 显示测试结果
                    if (_testResult != null) ...[
                      const SizedBox(height: 16),
                      Container(height: 1, color: theme.stroke),
                      const SizedBox(height: 8),
                      Text(
                        'openai_testResponse'.tr,
                        style: DsTypography.heading.copyWith(
                          color: theme.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.stroke),
                        ),
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _testResult!,
                            style: DsTypography.body.copyWith(
                              color: theme.text,
                            ),
                          ),
                        ),
                      ),
                    ],
                    // 显示加载指示器
                    if (_isTesting) ...[
                      const SizedBox(height: 16),
                      Center(child: DSLoadingDots(label: 'openai_testing'.tr)),
                    ],
                    SizedBox(height: theme.spacing.lg),
                    Row(
                      children: [
                        // 测试中合并为取消按钮，空闲时为测试按钮；保存模式显示保存按钮
                        if (widget.testAgent != null) ...[
                          Expanded(
                            child: DSButton(
                              label:
                                  _isTesting
                                      ? 'openai_cancelTest'.tr
                                      : 'openai_testAgent'.tr,
                              variant:
                                  _isTesting
                                      ? DSButtonVariant.outline
                                      : DSButtonVariant.primary,
                              onPressed: _isTesting ? _cancelTest : _runTest,
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: DSButton(
                              label: 'openai_save'.tr,
                              onPressed: () {
                                if (!_isDisposed) {
                                  final text = _controller.text;
                                  Navigator.of(context).pop({
                                    'text': text,
                                    'image': _selectedImage,
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
