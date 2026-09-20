import 'package:flutter/services.dart';

class AudioService {
  static bool soundEnabled = true;

  /// Phát âm thanh khi khối vỡ hoàn toàn (chỉ phát khi khối thực sự vỡ tan)
  static void playBlockBreak() {
    if (!soundEnabled) return;
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Phát âm thanh khi nhặt Vàng hoặc EXP
  static void playCoinCollect() {
    if (!soundEnabled) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Phát âm thanh khi Thăng cấp (Level Up)
  static void playLevelUp() {
    if (!soundEnabled) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Phát âm thanh khi Hoàn thành Màn chơi (Victory)
  static void playVictory() {
    if (!soundEnabled) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}
