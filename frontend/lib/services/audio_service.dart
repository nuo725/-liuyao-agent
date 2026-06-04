import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void _dlog(String message) {
  assert(() {
    debugPrint(message);
    return true;
  }());
}

/// 全局音频服务（纯 Dart 单例原生架构）
class AudioService {
  // 原生单例模式
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _init();
  }

  final AudioPlayer _ambientPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _typingSfxPlayer = AudioPlayer();

  final ValueNotifier<bool> isMutedNotifier = ValueNotifier<bool>(false);

  void _init() {
    _ambientPlayer.setReleaseMode(ReleaseMode.loop);
    _ambientPlayer.setVolume(0.3);
    _sfxPlayer.setVolume(0.8);
    _typingSfxPlayer.setVolume(0.5);
  }

  bool get isMuted => isMutedNotifier.value;

  Future<void> playAmbient() async {
    if (isMuted) return;
    try {
      await _ambientPlayer.play(AssetSource('audio/bg_ambient.mp3'));
      await _ambientPlayer.setVolume(0);
      _fadeInAmbient();
    } catch (e) {
      _dlog('[AudioService] playAmbient failed: $e');
    }
  }

  Future<void> _fadeInAmbient() async {
    for (double v = 0; v <= 0.3; v += 0.05) {
      if (isMuted) break;
      await _ambientPlayer.setVolume(v);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> fadeOutAmbient() async {
    for (double v = _ambientPlayer.volume; v >= 0; v -= 0.05) {
      await _ambientPlayer.setVolume(v.clamp(0.0, 1.0));
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await _ambientPlayer.pause();
  }

  Future<void> playChargingSound() async {
    if (isMuted) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/sfx_charging.mp3'));
    } catch (e) {
      _dlog('[AudioService] playChargingSound failed: $e');
    }
  }

  Future<void> stopChargingSound() async {
    await _sfxPlayer.stop();
  }

  Future<void> playDropSound() async {
    if (isMuted) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/sfx_drop.mp3'));
    } catch (e) {
      _dlog('[AudioService] playDropSound failed: $e');
    }
  }

  /// 播放打字音效（若隐若现）
  Future<void> playTypingSound() async {
    if (isMuted) return;
    try {
      await _typingSfxPlayer.play(AssetSource('audio/sfx_typing.mp3'));
    } catch (e) {
      _dlog('[AudioService] playTypingSound failed: $e');
    }
  }

  Future<void> pauseAll() async {
    await fadeOutAmbient();
    await _sfxPlayer.stop();
  }

  Future<void> resume() async {
    if (!isMuted) {
      await _ambientPlayer.resume();
    }
  }

  Future<void> stop() async {
    await _ambientPlayer.stop();
    await _sfxPlayer.stop();
  }

  void toggleMute() {
    isMutedNotifier.value = !isMutedNotifier.value;
    if (isMutedNotifier.value) {
      _ambientPlayer.pause();
      _sfxPlayer.stop();
    } else {
      _ambientPlayer.resume();
    }
  }

  void dispose() {
    _ambientPlayer.dispose();
    _sfxPlayer.dispose();
    _typingSfxPlayer.dispose();
    isMutedNotifier.dispose();
  }
}

final audioService = AudioService();
