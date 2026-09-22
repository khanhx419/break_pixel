import 'dart:js_interop';

@JS('playRetroSound')
external void _playRetroSound(JSString type);

void playPlatformSound(String sound) {
  try {
    _playRetroSound(sound.toJS);
  } catch (_) {}
}
