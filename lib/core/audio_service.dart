import 'package:flutter/services.dart';
import 'sound_stub.dart' if (dart.library.js_interop) 'sound_web.dart';

class AudioService {
  static bool soundEnabled = true;

  /// Phát âm thanh khi khối vỡ hoàn toàn
  static void playBlockBreak() {
    if (!soundEnabled) return;
    try {
      playPlatformSound('break');
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Phát âm thanh khi va chạm nhẹ
  static void playHit() {
    if (!soundEnabled) return;
    try {
      playPlatformSound('hit');
    } catch (_) {}
  }

  /// Phát âm thanh khi nhặt Vàng hoặc EXP
  static void playCoinCollect() {
    if (!soundEnabled) return;
    try {
      playPlatformSound('coin');
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Phát âm thanh khi Thăng cấp (Level Up)
  static void playLevelUp() {
    if (!soundEnabled) return;
    try {
      playPlatformSound('levelup');
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Phát âm thanh khi Hoàn thành Màn chơi (Victory)
  static void playVictory() {
    if (!soundEnabled) return;
    try {
      playPlatformSound('victory');
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Phát âm thanh khi giật sét
  static void playLightning() {
    if (!soundEnabled) return;
    try {
      playPlatformSound('lightning');
    } catch (_) {}
  }
}
