import 'dart:js_interop';

@JS('window.localStorage.getItem')
external JSString? _read(JSString key);
@JS('window.localStorage.setItem')
external void _write(JSString key, JSString value);
Future<String?> readProgress() async =>
    _read('break_pixel_progress_v1'.toJS)?.toDart;
Future<void> writeProgress(String value) async =>
    _write('break_pixel_progress_v1'.toJS, value.toJS);
