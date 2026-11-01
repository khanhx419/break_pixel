import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/ecs.dart';
import '../models/pixel_art_data.dart';
import 'storage/progress_stub.dart'
    if (dart.library.io) 'storage/progress_io.dart'
    if (dart.library.js_interop) 'storage/progress_web.dart'
    as storage;

class ProgressStore extends ChangeNotifier {
  static ProgressStore instance = ProgressStore();
  static const rewardOrder = [
    ElementType.fire,
    ElementType.water,
    ElementType.wind,
    ElementType.frost,
    ElementType.lightning,
    ElementType.earth,
    ElementType.poison,
    ElementType.voidDark,
  ];
  final Set<int> completedLevels = {};
  Map<String, dynamic>? storyRun;
  Map<String, dynamic>? endlessRun;
  Map<String, dynamic>? storyBuild;
  String? storageError;
  DateTime? savedAt;
  bool _initialized = false;
  Future<void> _pending = Future.value();
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  ProgressStore({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  }) : _read = read ?? storage.readProgress,
       _write = write ?? storage.writeProgress;
  int get highestUnlockedIndex {
    int index = 0;
    while (completedLevels.contains(index + 1) &&
        index < MemeLevel.allLevels.length - 1) {
      index++;
    }
    return index;
  }

  bool get yetiUnlocked => completedLevels.contains(MemeLevel.allLevels.length);
  bool get hasProgress =>
      completedLevels.isNotEmpty || storyRun != null || endlessRun != null;
  Set<ElementType> get unlockedElements => {
    for (int i = 0; i < rewardOrder.length; i++)
      if (completedLevels.contains(i + 1)) rewardOrder[i],
  };
  ElementType? completeLevel(int levelId) {
    if (levelId < 1 ||
        levelId > highestUnlockedIndex + 1 ||
        !completedLevels.add(levelId)) {
      return null;
    }
    notifyListeners();
    return levelId <= rewardOrder.length ? rewardOrder[levelId - 1] : null;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'completed': completedLevels.toList(),
    'storyRun': storyRun,
    'endlessRun': endlessRun,
    'storyBuild': storyBuild,
  };
  Future<void> initialize() async {
    try {
      final value = await _read();
      if (value != null) {
        final data = jsonDecode(value) as Map<String, dynamic>;
        if (data['version'] != 1) {
          throw const FormatException('Unknown save version');
        }
        final completed = (data['completed'] as List).whereType<int>().toSet();
        for (
          int id = 1;
          id <= MemeLevel.allLevels.length && completed.contains(id);
          id++
        ) {
          completedLevels.add(id);
        }
        storyRun = data['storyRun'] as Map<String, dynamic>?;
        endlessRun = data['endlessRun'] as Map<String, dynamic>?;
        storyBuild = data['storyBuild'] as Map<String, dynamic>?;
      }
    } catch (_) {
      storageError =
          'Không đọc được bản lưu. Tiến trình mới sẽ được lưu khi chơi.';
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> save() {
    if (!_initialized) return Future.value();
    final value = jsonEncode(toJson());
    _pending = _pending.then((_) async {
      try {
        await _write(value);
        storageError = null;
        savedAt = DateTime.now();
      } catch (_) {
        storageError = 'Chưa lưu được. Kiểm tra quyền lưu trữ của trình duyệt hoặc thiết bị.';
      }
      notifyListeners();
    });
    return _pending;
  }
}
