import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:break_pixel/core/audio_service.dart';
import 'package:break_pixel/game/game_engine.dart';
import 'package:break_pixel/models/character.dart';
import 'package:break_pixel/models/pixel_art_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Role balance simulation: 45 seconds at identical seeds', () {
    AudioService.soundEnabled = false;
    final scores = <String, double>{};
    for (final role in RoleInfo.allRoles) {
      double score = 0;
      for (final seed in [42, 207, 619]) {
        final engine = GameEngine(
          role: role,
          race: RaceInfo.allRaces.first,
          level: MemeLevel.allLevels.first,
          randomSeed: seed,
        )..resize(const Size(400, 600));
        for (int frame = 0; frame < 45 * 60; frame++) {
          engine.update(1 / 60);
        }
        score += engine.blocks
            .where((b) => !b.isCenterEmpty)
            .fold<double>(
              0,
              (total, block) => total + 1 - block.health!.hpPercent,
            );
        engine.dispose();
      }
      scores[role.name] = score / 3;
    }
    // Equivalent destroyed tiles includes partial damage, making the comparison useful early on.
    debugPrint('ROLE_SCORE_45S: $scores');
    expect(
      scores.values.reduce(max) / scores.values.reduce(min),
      lessThan(2.0),
    );
    AudioService.soundEnabled = true;
  });
}
