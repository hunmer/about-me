/// 视频宠物可选音频：与精灵帧时间轴同步的音频播放控制。
///
/// 约定（与 [VideoPetAnimation.audio] 对应）：
/// - manifest 动画顶层 `audio` 为可空字符串相对路径（如 `audio/工作加班.m4a`），
///   不是 `sources` 中的项；缺失 / null / 空白 = 该动画无音频。
/// - 音频时间轴与帧时间轴对齐：第 N 帧对应 N / fps 秒；启播按精灵动画
///   实际起点 seek 一次，循环 wrap 回绕时再 seek 回循环起点，绝不逐帧 seek，
///   也不以音频自循环代替帧区间循环（帧时钟是主时钟，音频跟随）。
/// - 音频缺失 / 播放失败一律静默降级，绝不阻塞精灵动画。
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'video_pet_import_stub.dart'
    if (dart.library.io) 'video_pet_import_io.dart'
    as platform;

/// 读取视频宠物音频字节（data / file / http(s) / blob / asset 五类来源）。
///
/// 与 video_pet_player.dart 的 readVideoPetImageBytes 同构；独立实现以保持
/// 音频模块不反向依赖播放器（避免循环 import）。
Future<Uint8List> readVideoPetAudioBytes(Uri uri) async {
  if (uri.scheme == 'data') return uri.data!.contentAsBytes();
  if (uri.scheme == 'file') {
    final bytes = await platform.readFile(uri);
    if (bytes == null) throw StateError('找不到音频文件：$uri');
    return bytes;
  }
  if (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'blob') {
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError('音频下载失败（HTTP ${response.statusCode}）');
    }
    return response.bodyBytes;
  }
  if (uri.hasScheme) throw FormatException('不支持的音频来源：$uri');
  final data = await rootBundle.load(Uri.decodeFull(uri.toString()));
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// 按扩展名推断音频 MIME（BytesSource 在部分平台依赖它选解码器）；
/// data: URI 直接采用其声明的 MIME。
String? videoPetAudioMimeType(Uri uri) {
  if (uri.scheme == 'data') {
    final declared = uri.data?.mimeType;
    if (declared != null && declared != 'text/plain') return declared;
  }
  final path = uri.path.toLowerCase();
  for (final entry in const {
    '.m4a': 'audio/mp4',
    '.mp4': 'audio/mp4',
    '.mp3': 'audio/mpeg',
    '.wav': 'audio/wav',
    '.ogg': 'audio/ogg',
    '.oga': 'audio/ogg',
    '.opus': 'audio/ogg',
    '.aac': 'audio/aac',
    '.flac': 'audio/flac',
  }.entries) {
    if (path.endsWith(entry.key)) return entry.value;
  }
  return null;
}

/// 后端无关的音频来源描述。
sealed class VideoPetAudioSource {
  const VideoPetAudioSource();
}

/// 流式 URL（http / https / blob），交由播放器直接拉流。
class VideoPetAudioUrl extends VideoPetAudioSource {
  const VideoPetAudioUrl(this.url);
  final String url;
}

/// 已加载的字节（asset / file / data 统一读字节，跨平台行为一致）。
class VideoPetAudioBytes extends VideoPetAudioSource {
  const VideoPetAudioBytes(this.bytes, {this.mimeType});
  final Uint8List bytes;
  final String? mimeType;
}

/// 可注入的播放后端（便于单测替换 audioplayers）。
abstract class VideoPetAudioBackend {
  Future<void> setSource(VideoPetAudioSource source);
  Future<void> seek(Duration position);
  Future<void> resume();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

/// audioplayers 6.5.0 实现。
///
/// 播放器实例惰性创建：仅在首次真正加载来源时构造 AudioPlayer。
/// 无音频约定的动画（或纯停止 / 暂停控制）完全不触碰平台通道，
/// 也避免 widget 测试等无插件环境下事件流监听抛 MissingPluginException。
class AudioplayersVideoPetAudioBackend implements VideoPetAudioBackend {
  AudioplayersVideoPetAudioBackend();

  AudioPlayer? _player;

  AudioPlayer get _attached => _player ??= AudioPlayer();

  /// 音频永不自循环（循环由帧 wrap 事件驱动 seek）；stop 模式播完保留
  /// source，wrap seek 后可直接续播。异常兜底避免未处理 Future；
  /// setSource 前等待完成，保证 ReleaseMode 先于任何 source 生效。
  late final Future<void> _ready = _attached
      .setReleaseMode(ReleaseMode.stop)
      .catchError((_) {});

  @override
  Future<void> setSource(VideoPetAudioSource source) async {
    await _ready;
    final player = _attached;
    switch (source) {
      case VideoPetAudioUrl(:final url):
        await player.setSourceUrl(url);
      case VideoPetAudioBytes(:final bytes, :final mimeType):
        await player.setSourceBytes(bytes, mimeType: mimeType);
    }
  }

  /// 实例未创建（从未加载来源）时控制操作均为空操作。
  @override
  Future<void> seek(Duration position) async {
    final player = _player;
    if (player != null) await player.seek(position);
  }

  @override
  Future<void> resume() async {
    final player = _player;
    if (player != null) await player.resume();
  }

  @override
  Future<void> pause() async {
    final player = _player;
    if (player != null) await player.pause();
  }

  @override
  Future<void> stop() async {
    final player = _player;
    if (player != null) await player.stop();
  }

  @override
  Future<void> dispose() async {
    final player = _player;
    _player = null;
    if (player != null) await player.dispose();
  }
}

/// 一次音频播放任务的描述（stop 释放后 resume 重启用）。
class _VideoPetAudioTask {
  const _VideoPetAudioTask({
    required this.generation,
    required this.uri,
    required this.offset,
    required this.autoplay,
  });

  final int generation;
  final Uri uri;

  /// 首次启播位置（精灵动画起点对应的帧时间）。
  final Duration offset;
  final bool autoplay;
}

/// 帧驱动的音频同步控制器：
/// - 单后端实例复用，所有操作串行排队，会话令牌使被取代的旧操作失效，
///   异步旧请求不会串音；
/// - start / onFrame(wrap) / pause / resume / stop / dispose 全事件驱动，
///   任何异常静默吞掉（音频失败不阻塞动画）。
class VideoPetAudioController {
  VideoPetAudioController({VideoPetAudioBackend? backend})
    : _backend = backend ?? AudioplayersVideoPetAudioBackend();

  final VideoPetAudioBackend _backend;

  /// 会话令牌：start / stop / dispose 自增（新任务取代旧任务，使排队中的
  /// 旧操作失效）；pause / resume / 循环事件不自增，跟随当前任务排队，
  /// 避免腰斩进行中的加载导致 resume 时 source 缺失。
  int _session = 0;
  _VideoPetAudioTask? _task;

  /// stop 释放后仍保留任务描述，resume 按帧进度重启。
  bool _stopped = false;

  /// 本轮任务内音频是否已实际播放过：首次实际启播做一次帧时间校准，
  /// 之后的暂停恢复保持音频自身进度（不重复 seek，也不逐帧 seek）。
  bool _everPlayed = false;
  bool _disposed = false;

  /// 当前任务内最近一次帧号：wrap 检测 + resume 重启的 seek 锚点。
  int? _lastFrame;
  double _fps = 0;

  /// 来源缓存：重启（后台恢复）不再重复读盘 / 下载。
  VideoPetAudioSource? _resolved;
  Future<void> _pending = Future.value();

  /// 是否有生效中的音频任务（诊断用）。
  bool get hasTask => _task != null;

  /// 切换 / 重播：先停止旧音频再按 [uri] 启播（新文件加载期间不留旧声音）；
  /// [uri] 为 null 时仅停止。[offset] 为精灵动画起点对应的帧时间；
  /// [autoplay] 为 false 时加载并 seek 后保持暂停，待实际播放回调 resume。
  void start({
    required int generation,
    Uri? uri,
    Duration offset = Duration.zero,
    bool autoplay = true,
  }) {
    if (_disposed) return;
    final session = ++_session;
    _lastFrame = null;
    _resolved = null;
    if (uri == null) {
      _task = null;
      _stopped = true;
      _run(session, _backend.stop);
      return;
    }
    _task = _VideoPetAudioTask(
      generation: generation,
      uri: uri,
      offset: offset,
      autoplay: autoplay,
    );
    _stopped = false;
    _everPlayed = false;
    _run(session, () async {
      // 先停旧音频：加载新文件期间不让旧声音继续响。
      await _step(session, _backend.stop);
      final source = await _resolveSource(session, uri);
      await _step(session, () => _backend.setSource(source));
      if (offset > Duration.zero) {
        await _step(session, () => _backend.seek(offset));
      }
      if (autoplay) {
        await _calibrateFirstPlay(session);
        await _step(session, _backend.resume);
      } else {
        await _step(session, _backend.pause);
      }
    });
  }

  /// 帧推进事件：正常推进不做任何操作（不逐帧 seek）；帧号相对上次回落
  /// = 循环 wrap，按 [loopStartFrame] / [fps] 的帧时间 seek 回循环起点
  /// 并继续播放。
  void onFrame({
    required int generation,
    required int frame,
    required int loopStartFrame,
    required double fps,
  }) {
    if (_disposed) return;
    final task = _task;
    if (task == null || task.generation != generation) return;
    final last = _lastFrame;
    _lastFrame = frame;
    _fps = fps;
    if (last == null || frame >= last || fps <= 0) return;
    final session = _session;
    final position = _frameTime(loopStartFrame, fps);
    _run(session, () async {
      // wrap 即实际播放：标记已播，避免后续启播回调再校准。
      _everPlayed = true;
      await _step(session, () => _backend.seek(position));
      await _step(session, _backend.resume);
    });
  }

  /// 显式循环回绕事件（精灵面帧区间循环 goToFrame 直接回跳、不产生
  /// 帧号回落信号时由播放器触发）：无条件 seek 回 [loopStartFrame] /
  /// [fps] 的帧时间并继续播放。
  void onLoop({
    required int generation,
    required int loopStartFrame,
    required double fps,
  }) {
    if (_disposed || fps <= 0) return;
    final task = _task;
    if (task == null || task.generation != generation) return;
    _lastFrame = loopStartFrame;
    _fps = fps;
    final session = _session;
    final position = _frameTime(loopStartFrame, fps);
    _run(session, () async {
      // 回绕续播即实际播放：标记已播，避免后续启播回调再校准。
      _everPlayed = true;
      await _step(session, () => _backend.seek(position));
      await _step(session, _backend.resume);
    });
  }

  /// 暂停：保持音频与帧的当前进度，不释放资源。不取代进行中的加载
  /// （排队在加载动作之后执行，避免 resume 时 source 缺失永久无声）。
  void pause() {
    if (_disposed || _task == null) return;
    _run(_session, _backend.pause);
  }

  /// 恢复：仍在暂停态则原位续播；此前被 stop 释放（后台 / 资源重载）则
  /// 按最近帧号重启并 seek 到帧时间轴位置（保持进度）。
  void resume() {
    if (_disposed) return;
    final task = _task;
    if (task == null) return;
    final session = _session;
    if (_stopped) {
      _stopped = false;
      // 重启本身按最近帧号 seek（保持进度），即完成对齐。
      _everPlayed = true;
      final offset = _resumeOffset(task);
      _run(session, () async {
        await _backend.stop();
        final source = await _resolveSource(session, task.uri);
        await _step(session, () => _backend.setSource(source));
        if (offset > Duration.zero) {
          await _step(session, () => _backend.seek(offset));
        }
        await _step(session, _backend.resume);
      });
      return;
    }
    _run(session, () async {
      await _calibrateFirstPlay(session);
      await _step(session, _backend.resume);
    });
  }

  /// 停止并释放当前音频（动画自然结束 / 退后台 / 资源包重载）。
  /// 任务描述保留，后续 resume 可按帧进度重启。
  void stop() {
    if (_disposed) return;
    final session = ++_session;
    _stopped = true;
    _run(session, _backend.stop);
  }

  /// 销毁：释放底层播放器；之后所有调用均为空操作。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final session = ++_session;
    _task = null;
    _resolved = null;
    _run(session, _backend.dispose);
  }

  /// 本轮首次实际播放时的一次性校准：音频加载（setSource）慢于画面
  /// 启动时，画面帧已推进，若仍从起始 [VideoPetAudioTask.offset] 播放
  /// 会永久滞后——按最近帧 / fps 对齐到当前帧时间。仅本轮首次启播做
  /// 一次；此后暂停恢复保持音频自身进度，不再额外 seek（也不逐帧 seek）。
  Future<void> _calibrateFirstPlay(int session) async {
    if (_everPlayed) return;
    _everPlayed = true;
    final frame = _lastFrame;
    if (frame == null || _fps <= 0) return;
    await _step(session, () => _backend.seek(_frameTime(frame, _fps)));
  }

  Duration _resumeOffset(_VideoPetAudioTask task) {
    final frame = _lastFrame;
    if (frame == null || _fps <= 0) return task.offset;
    return _frameTime(frame, _fps);
  }

  static Duration _frameTime(int frame, double fps) => Duration(
    microseconds: (frame / fps * Duration.microsecondsPerSecond).round(),
  );

  /// 队列内的一步：会话已失效（被更新操作取代）则跳过，防旧请求串音。
  Future<void> _step(int session, Future<void> Function() op) async {
    if (_disposed || session != _session) return;
    await op();
  }

  /// 所有后端操作串行排队（setSource / seek / resume 不可交错），
  /// 失效会话整体跳过；异常静默（音频失败不阻塞动画）。
  void _run(int session, Future<void> Function() action) {
    _pending = _pending.then((_) async {
      if (session != _session) return;
      try {
        await action();
      } catch (error) {
        debugPrint('[VideoPetAudio] 音频操作失败（已忽略）：$error');
      }
    });
  }

  Future<VideoPetAudioSource> _resolveSource(int session, Uri uri) async {
    final cached = _resolved;
    if (cached != null) return cached;
    final VideoPetAudioSource source;
    if (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'blob') {
      source = VideoPetAudioUrl(uri.toString());
    } else {
      source = VideoPetAudioBytes(
        await readVideoPetAudioBytes(uri),
        mimeType: videoPetAudioMimeType(uri),
      );
    }
    // 读取期间任务被取代：不污染新任务的来源缓存，直接放弃本次动作。
    if (_disposed || session != _session) {
      throw StateError('audio task superseded');
    }
    _resolved = source;
    return source;
  }
}
