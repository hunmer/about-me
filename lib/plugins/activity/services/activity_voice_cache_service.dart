import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';

/// 播报模板片段类型
enum VoiceSegmentType { fixed, unrecordedTime, dynamic }

/// 播报模板片段
///
/// - fixed: 纯固定文本（可预生成语音缓存）
/// - unrecordedTime: {unrecorded_time}（数字 + 单位本地拼接）
/// - dynamic: 其它动态占位符（播放时在线合成）
class VoiceSegment {
  final VoiceSegmentType type;

  /// fixed: 固定文本；dynamic: 占位符字符串（如 {date}）
  final String text;

  const VoiceSegment._(this.type, this.text);

  factory VoiceSegment.fixed(String text) =>
      VoiceSegment._(VoiceSegmentType.fixed, text);

  factory VoiceSegment.unrecordedTime() =>
      const VoiceSegment._(VoiceSegmentType.unrecordedTime, '{unrecorded_time}');

  factory VoiceSegment.dynamic(String placeholder) =>
      VoiceSegment._(VoiceSegmentType.dynamic, placeholder);
}

/// 活动播报语音缓存服务
///
/// 预生成数字（0-10）、时间单位及模板固定文本的语音文件，
/// 播报时本地智能拼接播放，{unrecorded_time} 无需在线合成。
class ActivityVoiceCacheService {
  ActivityVoiceCacheService({required this.ttsPlugin});

  final TTSPlugin ttsPlugin;

  /// 数字 0-10 的合成文本
  static const List<String> numberTexts = [
    '零', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十',
  ];

  /// 数字进位"百"的文件名与合成文本
  static const String hundredName = 'hundred';
  static const String hundredText = '百';

  /// 时间单位：文件名标识 -> 合成文本
  static const Map<String, String> unitTexts = {
    'month': '月',
    'day': '天',
    'hour': '小时',
    'minute': '分钟',
    'second': '秒',
  };

  /// 模板中支持的占位符
  static final RegExp _placeholderRe = RegExp(
    r'\{(unrecorded_time|date|time|weekday|last_activity)\}',
  );

  final AudioPlayer _player = AudioPlayer();
  Completer<void>? _stopSignal;
  Map<String, dynamic>? _manifestCache;

  /// 缓存目录：app_data/activity/voice_cache
  Future<Directory> cacheDir() async {
    final base = await StorageManager.appDataDirectory();
    return Directory('${base.path}/activity/voice_cache');
  }

  /// 读取缓存清单
  Future<Map<String, dynamic>?> loadManifest({bool forceReload = false}) async {
    if (kIsWeb) return null;
    if (!forceReload && _manifestCache != null) return _manifestCache;
    try {
      final dir = await cacheDir();
      final file = File('${dir.path}/manifest.json');
      if (!await file.exists()) return null;
      _manifestCache = jsonDecode(await file.readAsString())
          as Map<String, dynamic>;
      return _manifestCache;
    } catch (e) {
      debugPrint('[ActivityVoiceCache] 读取缓存清单失败: $e');
      return null;
    }
  }

  /// 缓存是否可用（模板与服务匹配，且音频文件齐全）
  Future<bool> isCacheReady(String template, String? serviceId) async {
    if (kIsWeb) return false;
    final manifest = await loadManifest();
    if (manifest == null) return false;

    final id = serviceId ??
        (await ttsPlugin.managerService.getDefaultService())?.id;
    if (manifest['serviceId'] != id) return false;
    if (manifest['template'] != template) return false;
    final ext = manifest['ext'] as String?;
    if (ext == null) return false;

    final names = <String>[
      for (var i = 0; i < numberTexts.length; i++) 'num_$i',
      hundredName,
      for (final unit in unitTexts.keys) 'unit_$unit',
      for (var i = 0; i < (manifest['segmentCount'] as int? ?? 0); i++)
        'seg_$i',
    ];
    final dir = await cacheDir();
    for (final name in names) {
      if (!await File('${dir.path}/$name.$ext').exists()) return false;
    }
    return true;
  }

  /// 解析模板为片段序列（固定文本 / 未记录时间 / 动态占位符）
  List<VoiceSegment> parseTemplate(String template) {
    final segments = <VoiceSegment>[];
    var last = 0;
    for (final match in _placeholderRe.allMatches(template)) {
      if (match.start > last) {
        final text = template.substring(last, match.start);
        if (text.trim().isNotEmpty) segments.add(VoiceSegment.fixed(text));
      }
      final name = match.group(1)!;
      segments.add(
        name == 'unrecorded_time'
            ? VoiceSegment.unrecordedTime()
            : VoiceSegment.dynamic(name == 'unrecorded_time'
                  ? ''
                  : '{$name}'),
      );
      last = match.end;
    }
    if (last < template.length) {
      final text = template.substring(last);
      if (text.trim().isNotEmpty) segments.add(VoiceSegment.fixed(text));
    }
    return segments;
  }

  /// 一键生成语音缓存
  ///
  /// 返回 null 表示成功，否则返回错误信息。
  Future<String?> generate({
    required String template,
    String? serviceId,
    void Function(int done, int total)? onProgress,
  }) async {
    if (kIsWeb) return '当前平台不支持语音缓存';

    final config = serviceId != null
        ? await ttsPlugin.managerService.getServiceById(serviceId)
        : await ttsPlugin.managerService.getDefaultService();
    if (config == null) return '未找到可用的 TTS 服务';
    final ext = (config.audioFormat == null || config.audioFormat!.isEmpty)
        ? 'mp3'
        : config.audioFormat!;

    // 组装合成清单：文件名（不含扩展名）-> 合成文本
    final items = <String, String>{
      for (var i = 0; i < numberTexts.length; i++) 'num_$i': numberTexts[i],
      hundredName: hundredText,
      for (final entry in unitTexts.entries)
        'unit_${entry.key}': entry.value,
    };
    var segmentCount = 0;
    for (final segment in parseTemplate(template)) {
      if (segment.type == VoiceSegmentType.fixed) {
        items['seg_${segmentCount++}'] = segment.text;
      }
    }

    // 重建缓存目录，避免残留旧文件
    final dir = await cacheDir();
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    var done = 0;
    final total = items.length;
    onProgress?.call(done, total);
    for (final entry in items.entries) {
      final filePath = '${dir.path}/${entry.key}.$ext';
      final result = await ttsPlugin.synthesizeToFile(
        entry.value,
        serviceId: serviceId,
        filePath: filePath,
      );
      if (result == null) {
        return '合成失败："${entry.value}"（所选 TTS 服务可能不支持导出语音文件，请使用 HTTP/MiniMax 服务）';
      }
      done++;
      onProgress?.call(done, total);
    }

    _manifestCache = {
      'version': 2,
      'serviceId': serviceId ?? config.id,
      'template': template,
      'ext': ext,
      'segmentCount': segmentCount,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await File('${dir.path}/manifest.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(_manifestCache),
    );
    debugPrint('[ActivityVoiceCache] 语音缓存生成完成: $done 条');
    return null;
  }

  /// 数字拆解为数字音频文件名序列（中文拼读：23 -> 二/十/三，123 -> 一/百/二/十/三）
  ///
  /// 不小于 1000 时无法拆解，返回 null。
  List<String>? _numberNames(int n) {
    if (n < 0 || n >= 1000) return null;
    if (n <= 10) return ['num_$n'];
    if (n < 20) return ['num_10', 'num_${n - 10}'];
    if (n < 100) {
      final tens = n ~/ 10;
      final ones = n % 10;
      return ones == 0
          ? ['num_$tens', 'num_10']
          : ['num_$tens', 'num_10', 'num_$ones'];
    }
    // 100-999：X百[Y][零Z / Y十Z]
    final hundreds = n ~/ 100;
    final rest = n % 100;
    final names = ['num_$hundreds', hundredName];
    if (rest == 0) return names;
    if (rest < 10) {
      // 一百零X
      names..add('num_0')..add('num_$rest');
      return names;
    }
    // 一百二十三 / 一百一十
    final restNames = _numberNames(rest);
    if (restNames == null) return null;
    names.addAll(restNames);
    return names;
  }

  /// 未记录分钟数 -> 数字 + 单位的音频文件序列（与播报文本格式一致）
  ///
  /// 层级：分钟 -> 小时（满 60 分）-> 天（满 24 时）-> 月（满 30 天）。
  /// 返回 null 表示无法拼出（数字达到 1000）。
  List<String>? unrecordedTimeFileParts(int minutes, String ext) {
    bool addNumber(List<String> names, int n) {
      final parts = _numberNames(n);
      if (parts == null) return false;
      names.addAll(parts);
      return true;
    }

    final names = <String>[];
    if (minutes < 60) {
      if (!addNumber(names, minutes)) return null;
      names.add('unit_minute');
    } else if (minutes < 60 * 24) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (!addNumber(names, hours)) return null;
      names.add('unit_hour');
      if (mins > 0) {
        if (!addNumber(names, mins)) return null;
        names.add('unit_minute');
      }
    } else {
      final totalDays = minutes ~/ (60 * 24);
      if (totalDays < 30) {
        final hours = (minutes % (60 * 24)) ~/ 60;
        if (!addNumber(names, totalDays)) return null;
        names.add('unit_day');
        if (hours > 0) {
          if (!addNumber(names, hours)) return null;
          names.add('unit_hour');
        }
      } else {
        final months = totalDays ~/ 30;
        final days = totalDays % 30;
        if (!addNumber(names, months)) return null;
        names.add('unit_month');
        if (days > 0) {
          if (!addNumber(names, days)) return null;
          names.add('unit_day');
        }
      }
    }
    return [for (final name in names) '$name.$ext'];
  }

  /// 顺序播放音频文件序列（相对于缓存目录）
  ///
  /// [gap] 每段音频之间的停顿时长，让拼接更自然；[shouldContinue] 返回
  /// false 时中断。返回 false 表示播放中断或失败。
  Future<bool> playFiles(
    List<String> fileNames, {
    Duration gap = const Duration(milliseconds: 150),
    bool Function()? shouldContinue,
  }) async {
    final dir = await cacheDir();
    for (final name in fileNames) {
      if (shouldContinue != null && !shouldContinue()) return false;
      final stopSignal = _stopSignal = Completer<void>();
      try {
        await _player.play(DeviceFileSource('${dir.path}/$name'));
      } catch (e) {
        debugPrint('[ActivityVoiceCache] 播放失败: $name, $e');
        return false;
      }
      await Future.any([
        _player.onPlayerComplete.first,
        stopSignal.future,
      ]);
      if (gap > Duration.zero) {
        await Future.any([
          Future.delayed(gap),
          stopSignal.future,
        ]);
      }
    }
    return true;
  }

  /// 停止拼接播放
  Future<void> stopPlayback() async {
    _stopSignal?.complete();
    _stopSignal = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// 释放资源
  Future<void> dispose() async {
    await stopPlayback();
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
