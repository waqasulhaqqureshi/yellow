import 'package:flutter/services.dart';

/// Zero-dependency sound + haptic feedback.
///
/// Flutter's framework-level [SystemSound] (click / alert) and haptics need
/// no plugin and no assets, so the existing in-game Sound toggle gets real
/// audible/tactile feedback on every device. Swapping to recorded samples
/// later only means replacing the bodies below with an audioplayers call —
/// every call-site already goes through this class.
class SoundFx {
  SoundFx._();

  /// Mirrors the in-game "Sound" setting.
  static bool enabled = true;

  static void move() {
    if (!enabled) return;
    SystemSound.play(SystemSoundType.click);
  }

  static void capture() {
    if (!enabled) return;
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();
  }

  static void check() {
    if (!enabled) return;
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.lightImpact();
  }

  static void win() {
    if (!enabled) return;
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (enabled) SystemSound.play(SystemSoundType.alert);
    });
  }

  static void lose() {
    if (!enabled) return;
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  }

  static void draw() {
    if (!enabled) return;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.mediumImpact();
  }
}
