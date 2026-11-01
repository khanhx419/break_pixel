String? _value;
Future<String?> readProgress() async => _value;
Future<void> writeProgress(String value) async {
  _value = value;
}
