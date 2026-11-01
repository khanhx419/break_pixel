import 'dart:io';

File get _file {
  final root =
      Platform.environment['APPDATA'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  return File(
    '$root${Platform.pathSeparator}BreakPixel${Platform.pathSeparator}progress.json',
  );
}

Future<String?> readProgress() async =>
    await _file.exists() ? await _file.readAsString() : null;
Future<void> writeProgress(String value) async {
  final file = _file;
  await file.parent.create(recursive: true);
  await file.writeAsString(value, flush: true);
}
