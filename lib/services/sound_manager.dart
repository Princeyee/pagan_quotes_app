// lib/services/sound_manager.dart
import 'package:just_audio/just_audio.dart';
import '../utils/custom_cache.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  final Map<String, AudioPlayer> _players = {};
  bool _isMuted = false;
  final CustomCachePrefs _cache = CustomCache.prefs;

  // Инициализация - загружаем настройки
  Future<void> init() async {
    _isMuted = await _cache.getSetting<bool>('global_sound_muted') ?? false;
  }

  // Получить состояние звука
  bool get isMuted => _isMuted;

  // Установить глобальное отключение звука
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    await _cache.setSetting('global_sound_muted', muted);
    
    if (muted) {
      // Останавливаем все звуки
      await stopAll();
    }
  }

  // Воспроизвести звук
  Future<void> playSound(String key, String assetPath, {bool loop = false}) async {
  if (_isMuted) return;

  try {
    await stopSound(key);

    final player = AudioPlayer();
    _players[key] = player;

    await player.setAsset(assetPath);
    if (loop) {
      player.setLoopMode(LoopMode.one);
      player.play(); // 🔄 НЕ await — потому что звук бесконечный
    } else {
      await player.play(); // ✅ Только ждем, если он не зациклен
    }
  } catch (e) {
    print('Error playing sound $key: $e');
  }
}

  // Остановить конкретный звук
  Future<void> stopSound(String key) async {
    final player = _players[key];
    if (player != null) {
      try {
        await player.stop();
        await player.dispose();
      } catch (e) {
        print('Error stopping sound $key: $e');
      }
      _players.remove(key);
    }
  }

  // Остановить все звуки
  Future<void> stopAll() async {
    final keys = _players.keys.toList();
    for (final key in keys) {
      await stopSound(key);
    }
  }

  // Приостановить все звуки (для сворачивания приложения)
  Future<void> pauseAll() async {
    for (final player in _players.values) {
      try {
        if (player.playing) {
          await player.pause();
        }
      } catch (e) {
        print('Error pausing sound: $e');
      }
    }
  }

  // Возобновить все звуки (для разворачивания приложения)
  Future<void> resumeAll() async {
    if (_isMuted) return;
    
    for (final player in _players.values) {
      try {
        await player.play();
      } catch (e) {
        print('Error resuming sound: $e');
      }
    }
  }

  // Плавное затухание звука
  Future<void> fadeOut(String key, {Duration duration = const Duration(milliseconds: 500)}) async {
    final player = _players[key];
    if (player == null) return;

    try {
      final steps = 10;
      final stepDuration = duration.inMilliseconds ~/ steps;
      
      for (int i = steps; i >= 0; i--) {
        await player.setVolume(i / steps);
        await Future.delayed(Duration(milliseconds: stepDuration));
      }
      
      await stopSound(key);
    } catch (e) {
      print('Error fading out sound $key: $e');
    }
  }

  // Плавное нарастание звука
  Future<void> fadeIn(String key, String assetPath, {Duration duration = const Duration(milliseconds: 500), bool loop = false}) async {
    if (_isMuted) return;

    try {
      await stopSound(key);

      final player = AudioPlayer();
      _players[key] = player;

      await player.setAsset(assetPath);
      await player.setVolume(0.0);
      if (loop) {
        player.setLoopMode(LoopMode.one);
      }
      
      player.play();

      final steps = 10;
      final stepDuration = duration.inMilliseconds ~/ steps;
      
      for (int i = 0; i <= steps; i++) {
        await player.setVolume(i / steps);
        await Future.delayed(Duration(milliseconds: stepDuration));
      }
    } catch (e) {
      print('Error fading in sound $key: $e');
    }
  }

  // Очистка ресурсов
  Future<void> dispose() async {
    await stopAll();
  }
}
