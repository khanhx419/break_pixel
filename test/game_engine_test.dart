import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:break_pixel/game/game_engine.dart';
import 'package:break_pixel/game/game_painter.dart';
import 'package:break_pixel/models/character.dart';
import 'package:break_pixel/models/ecs.dart';
import 'package:break_pixel/models/pixel_art_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GameEngine create() => GameEngine(
    role: RoleInfo.allRoles.first,
    race: RaceInfo.allRaces.first,
    level: MemeLevel.allLevels.first,
  );

  test(
    'Small viewport fits the artwork and reveals exactly four center cells',
    () {
      final engine = create()..resize(const Size(240, 360));
      expect(engine.level.cols, 28);
      expect(engine.blocks.where((b) => b.isRevealed).length, 4);
      expect(engine.gridStartX, greaterThanOrEqualTo(0));
      expect(
        engine.gridStartX + engine.level.cols * engine.gridBlockSize,
        lessThanOrEqualTo(240),
      );
      final baseHp = 50.0;
      expect(
        engine.blocks.every((b) => b.health!.maxHp <= baseHp * 2.5),
        isTrue,
      );
      expect(engine.blocks.first.health!.maxHp, closeTo(baseHp * 2.5, 0.001));
    },
  );

  test('Fusion requires owned ingredients and cannot be bought twice', () {
    final engine = create();
    expect(engine.fuseElements(ElementType.fire, ElementType.water), isFalse);
    engine.addElement(ElementType.fire);
    engine.addElement(ElementType.water);
    expect(engine.spirits, isEmpty);
    expect(engine.fuseElements(ElementType.fire, ElementType.water), isTrue);
    expect(engine.fuseElements(ElementType.fire, ElementType.water), isFalse);
  });

  test('Bounce upgrade immediately changes velocity', () {
    final engine = create()..gold = 1000;
    final before = engine.player.transform;
    final speed = Offset(before.vx, before.vy).distance;
    expect(engine.upgradeBounce(), isTrue);
    expect(Offset(before.vx, before.vy).distance, greaterThan(speed));
  });

  test('Completion fires once even when update is called again', () {
    final engine = create()..resize(const Size(400, 600));
    var victories = 0;
    engine.onVictory = () => victories++;
    for (final block in engine.blocks) {
      block.health!.takeDamage(100000);
    }
    engine.update(1 / 60);
    engine.update(1 / 60);
    expect(engine.completionPercent, 1);
    expect(victories, 1);
  });
  testWidgets('All five weapon painters render with the fine pixel grid', (
    tester,
  ) async {
    for (final role in RoleInfo.allRoles) {
      final engine = GameEngine(
        role: role,
        race: RaceInfo.allRaces.first,
        level: MemeLevel.allLevels.first,
      )..resize(const Size(400, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: CustomPaint(painter: GamePainter(engine: engine)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
