import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'tts_base_service.dart';
import 'system_tts_service.dart';
import 'http_tts_service.dart';
import 'minimax_tts_service.dart';
import 'package:aboutme/plugins/tts/models/tts_service_config.dart';
import 'package:aboutme/plugins/tts/models/tts_service_type.dart';
import 'package:aboutme/plugins/tts/models/tts_queue_item.dart';

/// TTS管理器服务 - 负责服务管理和队列管理
class TTSManagerService extends ChangeNotifier {
  static final _log = Logger('TTSManagerService');

  /// 存储键前缀
  final String storagePrefix;

  /// 读取存储的回调
  final Future<Map<String, dynamic>> Function(String key) readStorage;

  /// 写入存储的回调
  final Future<void> Function(String key, Map<String, dynamic> data)
  writeStorage;

  /// 当前正在使用的服务实例
  TTSBaseService? _currentService;

  /// 朗读队列
  final List<TTSQueueItem> _queue = [];

  /// 当前队列项
  TTSQueueItem? _currentQueueItem;

  /// 是否正在处理队列
  bool _isProcessingQueue = false;

  /// 队列是否暂停
  bool _isQueuePaused = false;

  TTSManagerService({
    required this.storagePrefix,
    required this.readStorage,
    required this.writeStorage,
  });

  /// 获取所有服务配置
  Future<List<TTSServiceConfig>> getAllServices() async {
    try {
      final data = await readStorage('$storagePrefix/services.json');

      if (data.isEmpty || !data.containsKey('services')) {
        return [];
      }

      final list = data['services'] as List;
      return list
          .map((e) => TTSServiceConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log.warning('获取服务列表失败: $e');
      return [];
    }
  }

  /// 获取默认服务
  Future<TTSServiceConfig?> getDefaultService() async {
    try {
      final services = await getAllServices();

      // 优先返回标记为默认的已启用服务
      final defaultService = services
          .where((s) => s.isDefault && s.isEnabled)
          .firstOrNull;
      if (defaultService != null) {
        return defaultService;
      }

      // 没有默认服务,返回第一个已启用的服务
      return services.where((s) => s.isEnabled).firstOrNull;
    } catch (e) {
      _log.warning('获取默认服务失败: $e');
      return null;
    }
  }

  /// 根据ID获取服务
  Future<TTSServiceConfig?> getServiceById(String id) async {
    try {
      final services = await getAllServices();
      return services.where((s) => s.id == id).firstOrNull;
    } catch (e) {
      _log.warning('获取服务失败: $e');
      return null;
    }
  }

  /// 保存服务配置
  Future<void> saveService(TTSServiceConfig config) async {
    try {
      final services = await getAllServices();
      final index = services.indexWhere((s) => s.id == config.id);

      // 如果新服务设置为默认,取消其他服务的默认状态
      if (config.isDefault) {
        for (var s in services) {
          if (s.id != config.id) {
            s.isDefault = false;
          }
        }
      }

      if (index >= 0) {
        services[index] = config;
        _log.info('更新服务配置: ${config.name}');
      } else {
        services.add(config);
        _log.info('新增服务配置: ${config.name}');
      }

      await writeStorage('$storagePrefix/services.json', {
        'services': services.map((s) => s.toJson()).toList(),
      });

      notifyListeners();
    } catch (e) {
      _log.severe('保存服务配置失败: $e');
      rethrow;
    }
  }

  /// 删除服务
  Future<void> deleteService(String id) async {
    try {
      final services = await getAllServices();
      final originalLength = services.length;

      services.removeWhere((s) => s.id == id);

      if (services.length < originalLength) {
        await writeStorage('$storagePrefix/services.json', {
          'services': services.map((s) => s.toJson()).toList(),
        });

        _log.info('删除服务: $id');
        notifyListeners();
      }
    } catch (e) {
      _log.severe('删除服务失败: $e');
      rethrow;
    }
  }

  /// 创建服务实例
  TTSBaseService _createService(TTSServiceConfig config) {
    switch (config.type) {
      case TTSServiceType.system:
        return SystemTTSService(config);
      case TTSServiceType.http:
        return HttpTTSService(config);
      case TTSServiceType.minimax:
        return MiniMaxTTSService(config);
    }
  }

  /// 单次朗读(不使用队列)
  Future<void> speak(
    String text, {
    String? serviceId,
    TTSCallback? onStart,
    TTSCallback? onComplete,
    TTSErrorCallback? onError,
    TTSAudioDataCallback? onAudioData,
  }) async {
    try {
      // 获取服务配置
      TTSServiceConfig? config;
      if (serviceId != null) {
        config = await getServiceById(serviceId);
      } else {
        config = await getDefaultService();
      }

      if (config == null) {
        final error = '未找到可用的 TTS 服务';
        _log.warning(error);
        onError?.call(error);
        return;
      }

      // 停止当前服务
      if (_currentService != null) {
        await _currentService!.stop();
        await _currentService!.dispose();
      }

      // 创建并初始化新服务
      _currentService = _createService(config);
      await _currentService!.initialize();

      // 按配置去除括号文本（角色扮演动作描述等）
      final textToSpeak = _stripParenthesesIfEnabled(text, config);
      if (textToSpeak.isEmpty) {
        _log.info('括号过滤后无剩余文本，跳过朗读: ${config.name}');
        onComplete?.call();
        return;
      }

      // 朗读
      await _currentService!.speak(
        textToSpeak,
        onStart: onStart,
        onComplete: onComplete,
        onError: onError,
        onAudioData: onAudioData,
      );

      _log.info('朗读完成: ${config.name}');
    } catch (e) {
      _log.severe('朗读失败: $e');
      onError?.call(e.toString());
    }
  }

  /// 配置开启去除括号时，正则去除中英文括号 () （） 及其内容（支持简单嵌套）
  String _stripParenthesesIfEnabled(String text, TTSServiceConfig config) {
    if (config.stripParentheses != true) return text;
    // 循环替换以处理一层嵌套括号
    var result = text;
    final pattern = RegExp(r'[（(][^()（）]*[)）]');
    while (true) {
      final next = result.replaceAll(pattern, '');
      if (next == result) break;
      result = next;
    }
    return result.trim();
  }

  /// 合成语音写入指定文件（语音消息场景，不播放）。
  /// 返回文件路径；服务不支持或失败时返回 null。
  Future<String?> synthesizeToFile(
    String text, {
    String? serviceId,
    required String filePath,
  }) async {
    try {
      final config = serviceId != null
          ? await getServiceById(serviceId)
          : await getDefaultService();
      if (config == null) {
        _log.warning('未找到可用的 TTS 服务');
        return null;
      }

      final service = _createService(config);
      await service.initialize();
      try {
        return await service.synthesizeToFile(text, filePath);
      } finally {
        await service.dispose();
      }
    } catch (e) {
      _log.severe('合成语音文件失败: $e');
      return null;
    }
  }

  // ============ 队列管理 ============

  /// 获取队列副本
  List<TTSQueueItem> get queue => List.unmodifiable(_queue);

  /// 当前队列项
  TTSQueueItem? get currentQueueItem => _currentQueueItem;

  /// 是否正在处理队列
  bool get isProcessingQueue => _isProcessingQueue;

  /// 队列是否暂停
  bool get isQueuePaused => _isQueuePaused;

  /// 添加到队列
  void addToQueue(String text, {String? serviceId}) {
    final item = TTSQueueItem(text: text, serviceId: serviceId);

    _queue.add(item);
    _log.info('添加到队列: ${item.id}, 队列长度: ${_queue.length}');
    notifyListeners();

    // 如果队列未在处理,开始处理
    if (!_isProcessingQueue) {
      _processQueue();
    }
  }

  /// 批量添加到队列
  void addBatchToQueue(List<String> texts, {String? serviceId}) {
    for (final text in texts) {
      final item = TTSQueueItem(text: text, serviceId: serviceId);
      _queue.add(item);
    }

    _log.info('批量添加到队列: ${texts.length} 项');
    notifyListeners();

    if (!_isProcessingQueue) {
      _processQueue();
    }
  }

  /// 处理队列
  Future<void> _processQueue() async {
    if (_isProcessingQueue) {
      return;
    }

    _isProcessingQueue = true;
    _log.info('开始处理队列, 队列长度: ${_queue.length}');

    while (_queue.isNotEmpty) {
      // 检查是否暂停
      while (_isQueuePaused) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 获取队列第一项
      _currentQueueItem = _queue.first;
      _currentQueueItem!.status = TTSQueueItemStatus.playing;
      notifyListeners();

      _log.info('处理队列项: ${_currentQueueItem!.id}');

      // 执行朗读
      final completer = Completer<void>();

      await speak(
        _currentQueueItem!.text,
        serviceId: _currentQueueItem!.serviceId,
        onStart: () {
          _log.info('队列项开始朗读: ${_currentQueueItem!.id}');
        },
        onComplete: () {
          _currentQueueItem!.status = TTSQueueItemStatus.completed;
          _log.info('队列项朗读完成: ${_currentQueueItem!.id}');
          completer.complete();
        },
        onError: (error) {
          _currentQueueItem!.status = TTSQueueItemStatus.error;
          _currentQueueItem!.error = error;
          _log.warning('队列项朗读失败: ${_currentQueueItem!.id}, 错误: $error');
          completer.complete();
        },
      );

      // 等待朗读完成
      await completer.future;

      // 移除队列第一项
      _queue.removeAt(0);
      _currentQueueItem = null;
      notifyListeners();
    }

    _isProcessingQueue = false;
    _log.info('队列处理完成');
    notifyListeners();
  }

  /// 暂停队列
  Future<void> pauseQueue() async {
    if (!_isProcessingQueue || _isQueuePaused) {
      return;
    }

    _isQueuePaused = true;
    await _currentService?.pause();
    _log.info('队列已暂停');
    notifyListeners();
  }

  /// 继续队列
  Future<void> resumeQueue() async {
    if (!_isProcessingQueue || !_isQueuePaused) {
      return;
    }

    _isQueuePaused = false;
    await _currentService?.resume();
    _log.info('队列已继续');
    notifyListeners();
  }

  /// 停止队列
  Future<void> stopQueue() async {
    _isQueuePaused = false;

    await _currentService?.stop();

    // 清空队列
    _queue.clear();
    _currentQueueItem = null;
    _isProcessingQueue = false;

    _log.info('队列已停止并清空');
    notifyListeners();
  }

  /// 跳过当前项
  Future<void> skipCurrent() async {
    if (_currentQueueItem == null) {
      return;
    }

    await _currentService?.stop();
    _log.info('跳过当前项: ${_currentQueueItem!.id}');

    // 移除当前项会触发队列继续处理
  }

  /// 清空队列(不停止当前朗读)
  void clearQueue() {
    _queue.clear();
    _log.info('队列已清空');
    notifyListeners();
  }

  /// 移除队列项
  void removeQueueItem(String id) {
    _queue.removeWhere((item) => item.id == id);
    _log.info('移除队列项: $id');
    notifyListeners();
  }

  // ============ 基础控制 ============

  /// 停止朗读
  Future<void> stop() async {
    await _currentService?.stop();
  }

  /// 暂停朗读
  Future<void> pause() async {
    await _currentService?.pause();
  }

  /// 继续朗读
  Future<void> resume() async {
    await _currentService?.resume();
  }

  /// 释放资源
  @override
  Future<void> dispose() async {
    await _currentService?.dispose();
    _currentService = null;
    _queue.clear();
    _currentQueueItem = null;
    _isProcessingQueue = false;
    super.dispose();
  }
}
