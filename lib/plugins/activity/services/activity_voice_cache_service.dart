import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  /// [gap] 每段音频之间的停顿时长（未合并时的逐条播放模式）；[shouldContinue]
  /// 返回 false 时中断。返回 false 表示播放中断或失败。
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

  /// 将多个音频文件（同缓存目录，按顺序）合并为一条完整语音
  ///
  /// WAV 按 fmt 参数精细拼接并插入 [gap] 对应的静音；其它格式（MP3/PCM 等）
  /// 按字节拼接（MP3 剥离非首文件的 ID3v2 标签）。返回 false 表示失败。
  Future<bool> combineFiles(
    List<String> fileNames,
    String outputName, {
    Duration gap = Duration.zero,
  }) async {
    try {
      final dir = await cacheDir();
      final buffers = <List<int>>[];
      for (final name in fileNames) {
        buffers.add(await File('${dir.path}/$name').readAsBytes());
      }
      if (buffers.isEmpty) return false;

      final ext = outputName.split('.').last.toLowerCase();
      final builder = BytesBuilder();
      if (ext == 'wav') {
        final combined = _combineWav(buffers, gap);
        if (combined != null) {
          builder.add(combined);
        } else {
          // 参数不一致等异常情况退化为顺序拼接
          for (final bytes in buffers) {
            builder.add(bytes);
          }
        }
      } else {
        builder.add(buffers.first);
        for (var i = 1; i < buffers.length; i++) {
          builder.add(_stripId3v2(buffers[i]));
        }
      }
      await File('${dir.path}/$outputName').writeAsBytes(
        builder.takeBytes(),
        flush: true,
      );
      return true;
    } catch (e) {
      debugPrint('[ActivityVoiceCache] 合并语音失败: $e');
      return false;
    }
  }

  /// 删除临时音频文件（合并产物与动态段在线合成的临时文件）
  Future<void> cleanupFiles(List<String> names) async {
    final dir = await cacheDir();
    for (final name in names) {
      try {
        final file = File('${dir.path}/$name');
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  /// 剥离 MP3 头部的 ID3v2 标签，避免拼接处出现杂数据
  List<int> _stripId3v2(List<int> bytes) {
    if (bytes.length < 10 ||
        bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) {
      return bytes;
    }
    final size =
        (bytes[6] & 0x7F) << 21 |
        (bytes[7] & 0x7F) << 14 |
        (bytes[8] & 0x7F) << 7 |
        (bytes[9] & 0x7F);
    final start = 10 + size;
    return start < bytes.length ? bytes.sublist(start) : bytes;
  }

  /// WAV 精细拼接：解析各文件 fmt/data chunk，采样参数一致则重写头部拼接，
  /// 段间插入静音；解析失败或参数不一致返回 null。
  List<int>? _combineWav(List<List<int>> buffers, Duration gap) {
    final first = _parseWav(buffers.first);
    if (first == null) return null;

    final data = BytesBuilder();
    data.add(first.data);
    for (var i = 1; i < buffers.length; i++) {
      final info = _parseWav(buffers[i]);
      if (info == null) return null;
      if (!_bytesEquals(info.fmtChunk, first.fmtChunk)) return null;
      if (gap > Duration.zero && first.byteRate > 0) {
        final silenceLength =
            (first.byteRate * gap.inMilliseconds / 1000).round();
        data.add(List<int>.filled(silenceLength, 0));
      }
      data.add(info.data);
    }
    final dataBytes = data.takeBytes();

    final out = BytesBuilder();
    out.add([0x52, 0x49, 0x46, 0x46]); // 'RIFF'
    out.add(_le32(36 + dataBytes.length));
    out.add([0x57, 0x41, 0x56, 0x45]); // 'WAVE'
    out.add([0x66, 0x6D, 0x74, 0x20]); // 'fmt '
    out.add(_le32(first.fmtChunk.length));
    out.add(first.fmtChunk);
    out.add([0x64, 0x61, 0x74, 0x61]); // 'data'
    out.add(_le32(dataBytes.length));
    out.add(dataBytes);
    return out.takeBytes();
  }

  /// 解析 WAV：提取 fmt chunk 与 data 样本
  _WavInfo? _parseWav(List<int> bytes) {
    if (bytes.length < 12) return null;
    if (!_hasTag(bytes, 0, 'RIFF') || !_hasTag(bytes, 8, 'WAVE')) return null;

    List<int>? fmtChunk;
    List<int> data = const [];
    var pos = 12;
    while (pos + 8 <= bytes.length) {
      final size = _le32At(bytes, pos + 4);
      final chunkStart = pos + 8;
      final chunkEnd = chunkStart + size > bytes.length
          ? bytes.length
          : chunkStart + size;
      if (_hasTag(bytes, pos, 'fmt ')) {
        fmtChunk = bytes.sublist(chunkStart, chunkEnd);
      } else if (_hasTag(bytes, pos, 'data')) {
        data = bytes.sublist(chunkStart, chunkEnd);
      }
      pos = chunkStart + size + (size.isOdd ? 1 : 0);
    }
    if (fmtChunk == null || fmtChunk.length < 16 || data.isEmpty) return null;
    // byteRate 位于 fmt chunk 偏移 8（format/channels/sampleRate 之后）
    return _WavInfo(fmtChunk, data, _le32At(fmtChunk, 8));
  }

  bool _hasTag(List<int> bytes, int offset, String tag) {
    for (var i = 0; i < 4; i++) {
      if (bytes[offset + i] != tag.codeUnitAt(i)) return false;
    }
    return true;
  }

  int _le32At(List<int> bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);

  List<int> _le32(int value) => [
        value & 0xFF,
        (value >> 8) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 24) & 0xFF,
      ];

  bool _bytesEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
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

/// WAV 解析结果：fmt chunk、样本数据与字节速率
class _WavInfo {
  final List<int> fmtChunk;
  final List<int> data;
  final int byteRate;

  const _WavInfo(this.fmtChunk, this.data, this.byteRate);
}
