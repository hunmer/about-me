import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_audio.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';

const _sheet = VideoPetSpritesheet(
  frameWidth: 192,
  frameHeight: 108,
  columns: 10,
  rows: 13,
  frameCount: 121,
  fps: 12,
);

VideoPetAnimation _animation({String? audio}) => VideoPetAnimation(
  id: 'idle',
  name: '待机',
  sources: const {'png': 'spritesheet/待机.png'},
  spritesheet: _sheet,
  audio: audio,
);

const _baseUri = 'assets/live2d/video/dsh_pet/manifest.json';

/// 纯 Dart 可测的字节音频（data: URI 不经过平台通道 / 文件系统）。
final Uri _dataUri = Uri.parse('data:audio/mp4;base64,AAAA');

class _FakeBackend implements VideoPetAudioBackend {
  final calls = <String>[];
  final sources = <VideoPetAudioSource>[];
  final seeks = <Duration>[];
  Completer<void>? gate;

  Future<void> _gated() => gate?.future ?? Future<void>.value();

  @override
  Future<void> setSource(VideoPetAudioSource source) async {
    await _gated();
    sources.add(source);
    calls.add('setSource');
  }

  @override
  Future<void> seek(Duration position) async {
    await _gated();
    seeks.add(position);
    calls.add('seek');
  }

  @override
  Future<void> resume() async {
    await _gated();
    calls.add('resume');
  }

  @override
  Future<void> pause() async {
    await _gated();
    calls.add('pause');
  }

  @override
  Future<void> stop() async {
    await _gated();
    calls.add('stop');
  }

  @override
  Future<void> dispose() async {
    await _gated();
    calls.add('dispose');
  }
}

/// 冲刷控制器内部串行队列（微任务若干轮）。
Future<void> _drain([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('manifest audio 字段', () {
    test('fromJson：无 audio 键 / null / 空串 / 空白 均归一化为 null', () {
      Map<String, dynamic> json({Object? audio = _sentinel}) => {
        'id': 'idle',
        'name': '待机',
        'sources': {'png': 'a.png'},
        if (audio != _sentinel) 'audio': audio,
      };

      expect(VideoPetAnimation.fromJson(json()).audio, isNull);
      expect(VideoPetAnimation.fromJson(json(audio: null)).audio, isNull);
      expect(VideoPetAnimation.fromJson(json(audio: '')).audio, isNull);
      expect(VideoPetAnimation.fromJson(json(audio: '   ')).audio, isNull);
    });

    test('fromJson：正常相对路径保留（trim）', () {
      final animation = VideoPetAnimation.fromJson({
        'id': 'idle',
        'name': '待机',
        'sources': {'png': 'a.png'},
        'audio': '  audio/工作加班.m4a  ',
      });
      expect(animation.audio, 'audio/工作加班.m4a');
    });

    test('fromJson：audio 非字符串抛 FormatException', () {
      expect(
        () => VideoPetAnimation.fromJson({
          'id': 'idle',
          'name': '待机',
          'sources': {'png': 'a.png'},
          'audio': 123,
        }),
        throwsFormatException,
      );
    });

    test('toJson：无音频省略键，有音频写出', () {
      expect(_animation().toJson().containsKey('audio'), isFalse);
      expect(_animation(audio: 'audio/a.m4a').toJson()['audio'], 'audio/a.m4a');
    });

    test('copyWith：不传保持 / 传值覆盖 / 传 null 清空', () {
      final base = _animation(audio: 'audio/a.m4a');
      expect(base.copyWith().audio, 'audio/a.m4a');
      expect(base.copyWith(audio: 'audio/b.m4a').audio, 'audio/b.m4a');
      expect(base.copyWith(audio: null).audio, isNull);
      expect(_animation().copyWith().audio, isNull);
    });

    test('validate：相对路径与 http/file/data/blob 绝对引用通过', () {
      _animation(audio: 'audio/a.m4a').validate();
      _animation(audio: null).validate();
      _animation(audio: '/abs/a.m4a').validate();
      _animation(audio: 'http://example.com/a.m4a').validate();
      _animation(audio: 'https://example.com/a.m4a').validate();
      _animation(audio: 'file:///store/x/a.m4a').validate();
      _animation(audio: 'data:audio/mp4;base64,AAAA').validate();
      _animation(audio: 'blob:native-uuid').validate();
    });

    test('validate：空白 / 控制字符 / 未知 scheme 抛 FormatException', () {
      expect(() => _animation(audio: ' ').validate(), throwsFormatException);
      expect(() => _animation(audio: 'a\tb').validate(), throwsFormatException);
      expect(
        () => _animation(audio: 'ftp://example.com/a.m4a').validate(),
        throwsFormatException,
      );
      expect(
        () => _animation(audio: 'javascript:alert(1)').validate(),
        throwsFormatException,
      );
    });

    test(
      'resolveAudio：相对解析（percent-encode）+ resolvedSources 覆盖 + 无音频 null',
      () {
        final animation = _animation(audio: 'audio/工作加班.m4a');
        // Uri.resolve 对非 ASCII 做 percent-encode。
        final resolved = Uri.parse(
          _baseUri,
        ).resolve('audio/工作加班.m4a').toString();
        expect(animation.resolveAudio(_baseUri), resolved);
        expect(resolved, contains(Uri.encodeComponent('工作加班')));
        expect(
          animation.resolveAudio(_baseUri, {resolved: 'file:///store/x/a.m4a'}),
          'file:///store/x/a.m4a',
        );
        expect(_animation().resolveAudio(_baseUri), isNull);
      },
    );
  });

  group('MIME 推断', () {
    test('按扩展名映射，大小写不敏感，未知为 null', () {
      expect(videoPetAudioMimeType(Uri.parse('file:///a/b.m4a')), 'audio/mp4');
      expect(videoPetAudioMimeType(Uri.parse('file:///a/b.MP3')), 'audio/mpeg');
      expect(videoPetAudioMimeType(Uri.parse('file:///a/b.opus')), 'audio/ogg');
      expect(videoPetAudioMimeType(Uri.parse('file:///a/b')), isNull);
    });

    test('data: URI 直接采用声明的 MIME，未声明走扩展推断', () {
      expect(
        videoPetAudioMimeType(Uri.parse('data:application/octet-stream,xx')),
        'application/octet-stream',
      );
      // data: 默认 text/plain 视为未声明 → 扩展推断（无扩展 → null）。
      expect(videoPetAudioMimeType(Uri.parse('data:,xx')), isNull);
    });
  });

  group('VideoPetAudioController', () {
    test('start(uri: null) 只停止，不加载来源', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(generation: 1, uri: null);
      await _drain();
      expect(backend.calls, ['stop']);
      expect(controller.hasTask, isFalse);
      controller.dispose();
    });

    test('start：setSource → seek(offset) → resume 顺序，字节来源带 MIME', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(
        generation: 3,
        uri: _dataUri,
        offset: const Duration(milliseconds: 250),
      );
      await _drain();
      // 新任务先停旧音再加载，杜绝切换瞬间新旧串音。
      expect(backend.calls, ['stop', 'setSource', 'seek', 'resume']);
      expect(backend.seeks, [const Duration(milliseconds: 250)]);
      final source = backend.sources.single;
      expect(source, isA<VideoPetAudioBytes>());
      expect((source as VideoPetAudioBytes).mimeType, 'audio/mp4');
      expect(source.bytes, _dataUri.data!.contentAsBytes());
      controller.dispose();
    });

    test('start(offset 为 0) 跳过 seek', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(generation: 1, uri: _dataUri);
      await _drain();
      expect(backend.calls, ['stop', 'setSource', 'resume']);
      controller.dispose();
    });

    test('start(autoplay: false) 加载后保持暂停', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(
        generation: 1,
        uri: _dataUri,
        offset: const Duration(seconds: 1),
        autoplay: false,
      );
      await _drain();
      expect(backend.calls, ['stop', 'setSource', 'seek', 'pause']);
      controller.dispose();
    });

    test('http 来源走流式 URL，不读字节', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(
        generation: 1,
        uri: Uri.parse('https://example.com/a.m4a'),
      );
      await _drain();
      expect(backend.sources.single, isA<VideoPetAudioUrl>());
      controller.dispose();
    });

    test('正常帧推进不逐帧 seek', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(generation: 5, uri: _dataUri);
      await _drain();
      backend.calls.clear();
      for (var frame = 0; frame < 10; frame++) {
        controller.onFrame(
          generation: 5,
          frame: frame,
          loopStartFrame: 0,
          fps: 12,
        );
      }
      await _drain();
      expect(backend.calls, isEmpty);
      controller.dispose();
    });

    test('帧号回落（wrap）按循环起点 seek 并续播', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(generation: 5, uri: _dataUri);
      await _drain();
      backend.calls.clear();

      controller.onFrame(generation: 5, frame: 30, loopStartFrame: 0, fps: 12);
      // 帧区间循环：回落到区间起点 12（=1s）。
      controller.onFrame(generation: 5, frame: 12, loopStartFrame: 12, fps: 12);
      await _drain();
      expect(backend.calls, ['seek', 'resume']);
      expect(backend.seeks.single, const Duration(seconds: 1));
      controller.dispose();
    });

    test('整段循环 wrap 回到 0（loopStart=0）', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(generation: 2, uri: _dataUri);
      await _drain();
      backend.calls.clear();
      controller.onFrame(generation: 2, frame: 120, loopStartFrame: 0, fps: 12);
      controller.onFrame(generation: 2, frame: 0, loopStartFrame: 0, fps: 12);
      await _drain();
      expect(backend.seeks.single, Duration.zero);
      controller.dispose();
    });

    test('onLoop：显式回绕 seek 循环起点并续播，重设帧锚点', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(generation: 7, uri: _dataUri);
      await _drain();
      backend.calls.clear();

      controller.onFrame(generation: 7, frame: 20, loopStartFrame: 0, fps: 12);
      controller.onLoop(generation: 7, loopStartFrame: 12, fps: 12);
      // 回绕锚点重设为 12：后续帧号 13 > 12，不再触发 wrap seek。
      controller.onFrame(generation: 7, frame: 13, loopStartFrame: 12, fps: 12);
      await _drain();
      expect(backend.calls, ['seek', 'resume']);
      expect(backend.seeks.single, const Duration(seconds: 1));
      controller.dispose();
    });

    test('onLoop：generation 不匹配或 fps 非法时忽略', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(generation: 7, uri: _dataUri);
      await _drain();
      backend.calls.clear();

      controller.onLoop(generation: 99, loopStartFrame: 0, fps: 12);
      controller.onLoop(generation: 7, loopStartFrame: 0, fps: 0);
      await _drain();
      expect(backend.calls, isEmpty);
      controller.dispose();
    });

    test('generation 不匹配的帧事件被忽略', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(generation: 2, uri: _dataUri);
      await _drain();
      backend.calls.clear();
      controller.onFrame(generation: 99, frame: 5, loopStartFrame: 0, fps: 12);
      controller.onFrame(generation: 1, frame: 0, loopStartFrame: 0, fps: 12);
      await _drain();
      expect(backend.calls, isEmpty);
      controller.dispose();
    });

    test('pause 保进度，resume 原位续播（不重载来源）', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(generation: 1, uri: _dataUri);
      await _drain();
      backend.calls.clear();
      controller.pause();
      await _drain();
      controller.resume();
      await _drain();
      expect(backend.calls, ['pause', 'resume']);
      controller.dispose();
    });

    test('stop 释放，resume 按最近帧号重启并 seek 保持进度', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(generation: 4, uri: _dataUri);
      await _drain();
      controller.onFrame(generation: 4, frame: 36, loopStartFrame: 0, fps: 12);
      await _drain();
      backend.calls.clear();

      controller.stop();
      await _drain();
      expect(backend.calls, ['stop']);

      controller.resume();
      await _drain();
      // 重启前先停残留，再按帧进度（36 帧 / 12 fps = 3s）重载并 seek。
      expect(backend.calls, ['stop', 'stop', 'setSource', 'seek', 'resume']);
      expect(backend.seeks.single, const Duration(seconds: 3));
      controller.dispose();
    });

    test('慢加载下新请求取代旧请求：旧动作剩余步骤被跳过，无串音', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      final gate = Completer<void>();
      backend.gate = gate;

      controller.start(
        generation: 1,
        uri: _dataUri,
        offset: const Duration(seconds: 9),
      );
      // 慢 setSource 挂起期间新请求到达并取代旧请求。
      await _drain();
      controller.start(
        generation: 2,
        uri: Uri.parse('data:audio/mpeg;base64,BBBB'),
        offset: const Duration(seconds: 2),
      );
      gate.complete();
      await _drain();

      // 旧请求挂在 gate 上的动作放行后被会话令牌拦截（stop 已过闸无害，
      // 来源读取被拦下，setSource 从未执行）；最终只有新请求的来源生效。
      expect(backend.sources, hasLength(1));
      expect(
        (backend.sources.single as VideoPetAudioBytes).mimeType,
        'audio/mpeg',
      );
      expect(backend.seeks, [const Duration(seconds: 2)]);
      expect(backend.calls.where((c) => c == 'resume'), ['resume']);
      expect(backend.calls.last, 'resume');
      controller.dispose();
      await _drain();
    });

    test('暂停不腰斩进行中的加载：pause/resume 排队跟随，最终可出声', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      final gate = Completer<void>();
      backend.gate = gate;

      controller.start(generation: 1, uri: _dataUri);
      await _drain();
      // setSource 挂起期间暂停又恢复：不取代任务，动作排队在其后。
      controller.pause();
      controller.resume();
      gate.complete();
      await _drain();

      // 加载完成 → 排队的 pause → resume，最终处于播放态（有声）。
      expect(backend.calls.last, 'resume');
      expect(backend.sources, hasLength(1));
      controller.dispose();
      await _drain();
    });

    test('慢加载期间帧已推进：首次实际 resume 校准到最新帧时间', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      final gate = Completer<void>();
      backend.gate = gate;

      controller.start(generation: 1, uri: _dataUri, autoplay: false);
      await _drain();
      // setSource 挂起期间画面已推进到 36 帧（12 fps → 3s）。
      controller.onFrame(generation: 1, frame: 36, loopStartFrame: 0, fps: 12);
      // 精灵面实际启播回调：resume 排队，在加载完成后才执行。
      controller.resume();
      gate.complete();
      await _drain();

      // 预加载 pause 之后紧跟一次性校准 seek（对齐 3s）再续播。
      expect(backend.calls, ['stop', 'setSource', 'pause', 'seek', 'resume']);
      expect(backend.seeks.single, const Duration(seconds: 3));
      controller.dispose();
    });

    test('帧未推进：首次 resume 不做校准 seek，仍从起始 offset 播', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(
        generation: 1,
        uri: _dataUri,
        offset: const Duration(milliseconds: 250),
        autoplay: false,
      );
      await _drain();
      controller.resume();
      await _drain();
      // 唯一的 seek 是初始 offset，无额外校准。
      expect(backend.calls, ['stop', 'setSource', 'seek', 'pause', 'resume']);
      expect(backend.seeks.single, const Duration(milliseconds: 250));
      controller.dispose();
    });

    test('首次校准后暂停恢复不再重复 seek', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      final gate = Completer<void>();
      backend.gate = gate;

      controller.start(generation: 1, uri: _dataUri, autoplay: false);
      await _drain();
      controller.onFrame(generation: 1, frame: 12, loopStartFrame: 0, fps: 12);
      controller.resume();
      gate.complete();
      await _drain();
      expect(backend.seeks.single, const Duration(seconds: 1));

      // 正常暂停 / 恢复：保持音频自身进度，无新 seek。
      backend.calls.clear();
      controller.pause();
      await _drain();
      controller.resume();
      await _drain();
      expect(backend.calls, ['pause', 'resume']);
      expect(backend.seeks, hasLength(1));
      controller.dispose();
    });

    test('音频读取失败静默降级，不阻塞动画', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(
        generation: 1,
        uri: Uri.file('D:/definitely-missing/video-pet-audio.m4a'),
      );
      await _drain();
      // 前置 stop 已执行，读取在 setSource 之前失败被静默吞掉，不抛出。
      expect(backend.calls, ['stop']);
      expect(controller.hasTask, isTrue);

      // 失败后控制器仍可用。
      controller.start(generation: 2, uri: _dataUri);
      await _drain();
      expect(backend.calls, ['stop', 'stop', 'setSource', 'resume']);
      controller.dispose();
    });

    test('dispose 后所有调用为空操作', () async {
      final backend = _FakeBackend();
      final controller = VideoPetAudioController(backend: backend);
      controller.start(generation: 1, uri: _dataUri);
      await _drain();
      controller.dispose();
      await _drain();
      expect(backend.calls.last, 'dispose');

      backend.calls.clear();
      controller.start(generation: 2, uri: _dataUri);
      controller.onFrame(generation: 2, frame: 0, loopStartFrame: 0, fps: 12);
      controller.pause();
      controller.resume();
      controller.stop();
      controller.dispose();
      await _drain();
      expect(backend.calls, isEmpty);
    });
  });
}

const _sentinel = Object();
