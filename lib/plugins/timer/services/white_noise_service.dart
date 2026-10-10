import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// 预设白噪音条目：本地 asset 与网络 url 二选一
class WhiteNoisePreset {
  final String id;
  final String asset; // 本地 asset 路径（与 url 互斥）
  final String url; // 在线音源 URL（与 asset 互斥）
  final String nameKey; // i18n key
  final IconData icon;

  const WhiteNoisePreset.local({
    required this.id,
    required this.asset,
    required this.nameKey,
    required this.icon,
  }) : url = '';

  const WhiteNoisePreset.online({
    required this.id,
    required this.url,
    required this.nameKey,
    required this.icon,
  }) : asset = '';

  bool get isOnline => url.isNotEmpty;
}

/// 白噪音播放服务：单实例循环播放。
/// 本地音源来自 wnoise.org 预设（压缩 48k mono，仅个人使用），
/// 其余音源走 CDN 网络 URL 流式加载。
class WhiteNoiseService {
  WhiteNoiseService._();

  static final WhiteNoiseService instance = WhiteNoiseService._();

  static const String _cdnBase = 'https://cdn.wnoise.org/audios/';

  static const List<WhiteNoisePreset> localPresets = [
    WhiteNoisePreset.local(
      id: 'rain',
      asset: 'assets/audio/white_noise/rain.mp3',
      nameKey: 'timer_noise_rain',
      icon: Icons.water_drop_outlined,
    ),
    WhiteNoisePreset.local(
      id: 'ocean',
      asset: 'assets/audio/white_noise/ocean.mp3',
      nameKey: 'timer_noise_ocean',
      icon: Icons.waves_outlined,
    ),
    WhiteNoisePreset.local(
      id: 'stream',
      asset: 'assets/audio/white_noise/stream.mp3',
      nameKey: 'timer_noise_stream',
      icon: Icons.forest_outlined,
    ),
    WhiteNoisePreset.local(
      id: 'storm',
      asset: 'assets/audio/white_noise/storm.mp3',
      nameKey: 'timer_noise_storm',
      icon: Icons.thunderstorm_outlined,
    ),
    WhiteNoisePreset.local(
      id: 'fan',
      asset: 'assets/audio/white_noise/fan.mp3',
      nameKey: 'timer_noise_fan',
      icon: Icons.air_outlined,
    ),
    WhiteNoisePreset.local(
      id: 'pink_noise',
      asset: 'assets/audio/white_noise/pink_noise.mp3',
      nameKey: 'timer_noise_pink',
      icon: Icons.blur_on_outlined,
    ),
  ];

  static const List<WhiteNoisePreset> onlinePresets = [
    WhiteNoisePreset.online(
      id: 'rain_light',
      url: '${_cdnBase}09-Rain.mp3',
      nameKey: 'timer_noise_rain_light',
      icon: Icons.grain_outlined,
    ),
    WhiteNoisePreset.online(
      id: 'beach',
      url: '${_cdnBase}45-Waves.mp3',
      nameKey: 'timer_noise_beach',
      icon: Icons.beach_access_outlined,
    ),
    WhiteNoisePreset.online(
      id: 'waterfall',
      url: '${_cdnBase}32-Waterfall.mp3',
      nameKey: 'timer_noise_waterfall',
      icon: Icons.landscape_outlined,
    ),
    WhiteNoisePreset.online(
      id: 'water',
      url: '${_cdnBase}10-Water.mp3',
      nameKey: 'timer_noise_water',
      icon: Icons.water_outlined,
    ),
    WhiteNoisePreset.online(
      id: 'train',
      url: '${_cdnBase}36-Train.mp3',
      nameKey: 'timer_noise_train',
      icon: Icons.train_outlined,
    ),
    WhiteNoisePreset.online(
      id: 'shower',
      url: '${_cdnBase}27-Shower.mp3',
      nameKey: 'timer_noise_shower',
      icon: Icons.shower_outlined,
    ),
    WhiteNoisePreset.online(
      id: 'heater',
      url: '${_cdnBase}21-Heater.mp3',
      nameKey: 'timer_noise_heater',
      icon: Icons.fireplace_outlined,
    ),
    WhiteNoisePreset.online(
      id: 'vacuum',
      url: '${_cdnBase}28-Vacuum.mp3',
      nameKey: 'timer_noise_vacuum',
      icon: Icons.cleaning_services_outlined,
    ),
    WhiteNoisePreset.online(
      id: 'white_noise',
      url: '${_cdnBase}01-White-Noise.mp3',
      nameKey: 'timer_noise_white',
      icon: Icons.blur_circular_outlined,
    ),
    WhiteNoisePreset.online(
      id: 'rainforest',
      url: '${_cdnBase}56-Rainforest-pubdom.mp3',
      nameKey: 'timer_noise_rainforest',
      icon: Icons.park_outlined,
    ),
    WhiteNoisePreset.online(
      id: 'crickets',
      url: '${_cdnBase}61-Crickets-pubdom.mp3',
      nameKey: 'timer_noise_crickets',
      icon: Icons.nights_stay_outlined,
    ),
    WhiteNoisePreset.online(
      id: 'windchime',
      url: '${_cdnBase}66-Windchimes.mp3',
      nameKey: 'timer_noise_windchime',
      icon: Icons.music_note_outlined,
    ),
  ];

  static List<WhiteNoisePreset> get presets =>
      [...localPresets, ...onlinePresets];

  AudioPlayer? _player;

  /// 当前正在播放的白噪音 id，null 表示关闭
  final ValueNotifier<String?> currentId = ValueNotifier<String?>(null);

  /// 正在加载的在线音源 id（网络拉流有延迟）
  final ValueNotifier<String?> loadingId = ValueNotifier<String?>(null);

  /// 播放/加载失败的提示（i18n key），由 UI 消费后清理
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  bool get isPlaying => currentId.value != null;

  WhiteNoisePreset? get currentPreset {
    final id = currentId.value;
    if (id == null) return null;
    return presets.firstWhereOrNull(id);
  }

  /// 点击某个预设：正在播放则停止，否则切换播放
  Future<void> toggle(String id) async {
    if (currentId.value == id) {
      await stop();
      return;
    }
    final preset = presets.firstWhereOrNull(id);
    if (preset == null) return;

    loadingId.value = id;
    try {
      _player ??= _createPlayer();
      await _player!.stop();
      final source = preset.isOnline
          ? UrlSource(preset.url)
          : AssetSource(preset.asset.replaceFirst('assets/', ''));
      // 在线拉流可能因网络挂起，加超时兜底
      if (preset.isOnline) {
        await _player!
            .play(source)
            .timeout(const Duration(seconds: 15));
      } else {
        await _player!.play(source);
      }
      currentId.value = id;
    } catch (e) {
      debugPrint('[WhiteNoise] 播放失败: $e');
      error.value = 'timer_noise_loadFail';
      await stop();
      await _releasePlayer();
    } finally {
      loadingId.value = null;
    }
  }

  AudioPlayer _createPlayer() {
    return AudioPlayer()..setReleaseMode(ReleaseMode.loop);
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
    currentId.value = null;
  }

  /// 释放播放器（错误后下一次 toggle 会重建）
  Future<void> _releasePlayer() async {
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }

  Future<void> dispose() async {
    await _releasePlayer();
    currentId.value = null;
  }
}

extension _FirstWhereOrNull on List<WhiteNoisePreset> {
  WhiteNoisePreset? firstWhereOrNull(String id) {
    for (final p in this) {
      if (p.id == id) return p;
    }
    return null;
  }
}
