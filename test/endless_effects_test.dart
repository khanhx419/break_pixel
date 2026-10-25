import 'dart:io';
import 'dart:ui' as ui;

import 'package:break_pixel/core/audio_service.dart';
import 'package:break_pixel/core/bounded_list.dart';
import 'package:break_pixel/game/game_engine.dart';
import 'package:break_pixel/game/game_painter.dart';
import 'package:break_pixel/models/character.dart';
import 'package:break_pixel/models/ecs.dart';
import 'package:break_pixel/models/game_entities.dart';
import 'package:break_pixel/models/pixel_art_data.dart';
import 'package:break_pixel/screens/character_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AudioService.soundEnabled = false);
  tearDown(() => AudioService.soundEnabled = true);
  GameEngine create({bool endless = true}) => GameEngine(
    role: RoleInfo.allRoles.first,
    race: RaceInfo.allRaces.first,
    level: MemeLevel.allLevels.first,
    isEndless: endless,
  )..resize(const Size(640, 680));
  void clearBoard(GameEngine engine) {
    for (final block in engine.blocks) {
      if (!block.health!.isDestroyed)
        block.elementAffinity!.applyPoison(1, 1e9);
    }
    engine.update(1 / 60);
  }

  void finishTransition(GameEngine engine) {
    final before = engine.endlessWave;
    for (int i = 0; i < 20 && engine.endlessWave == before; i++) {
      engine.update(0.1);
    }
  }

  test('Effect buffers stay bounded during a burst and expire without losing rewards', () {
    final buffer = BoundedList<int>(4)..addAll(List.generate(1000, (i) => i));
    expect(buffer, [996, 997, 998, 999]);
    buffer.removeWhere((value) => value.isEven);
    expect(buffer, [997, 999]);
    buffer.clear();
    expect(buffer, isEmpty);
    final engine = create();
    clearBoard(engine);
    expect(engine.debris.length, lessThanOrEqualTo(28));
    expect(engine.shockwaves.length, lessThanOrEqualTo(2));
    expect(
      engine.floatingTexts.length,
      lessThanOrEqualTo(GameEngine.maxFloatingTexts),
    );
    expect(engine.drops.length, lessThanOrEqualTo(GameEngine.maxDrops));
    final gold = engine.drops
        .where((d) => d.type == DropType.gold)
        .fold<double>(0, (sum, drop) => sum + drop.value);
    expect(gold + engine.gold, engine.totalBlocksCount * 10);
    for (int i = 0; i < 10; i++) {
      engine.update(0.1);
    }
    expect(engine.debris, isEmpty);
    expect(engine.shockwaves, isEmpty);
    engine.dispose();
  });
  test('Endless expands automatically and keeps upgrades', () {
    final engine = create()
      ..gold = 111
      ..damageUpgradeLevel = 3;
    engine.addElement(ElementType.fire);
    engine.summonSpirit();
    final firstSize = engine.gridBlockSize;
    var victories = 0;
    engine.onVictory = () => victories++;
    clearBoard(engine);
    expect(engine.isExpanding, isTrue);
    expect(engine.completionPercent, 1);
    finishTransition(engine);
    expect(engine.endlessWave, 2);
    expect(engine.level.cols, 32);
    expect(engine.gridBlockSize, lessThan(firstSize));
    expect(engine.cameraScale, greaterThan(1));
    expect(engine.isLevelCompleted, isFalse);
    expect(engine.blocks.where((b) => b.isRevealed).length, 4);
    expect(engine.damageUpgradeLevel, 3);
    expect(engine.ownedElements, contains(ElementType.fire));
    expect(engine.spirits.length, 1);
    expect(engine.gold, greaterThanOrEqualTo(111));
    expect(engine.debris, isEmpty);
    expect(engine.lightningArcs, isEmpty);
    expect(victories, 0);
    engine.dispose();
  });
  test('Long endless runs retain only one board of at most 2304 tiles', () {
    final engine = create();
    for (int i = 0; i < 12; i++) {
      clearBoard(engine);
      finishTransition(engine);
      expect(engine.blocks.length, lessThanOrEqualTo(48 * 48));
      expect(engine.drops, isEmpty);
      expect(engine.debris, isEmpty);
      expect(engine.vortexZones, isEmpty);
      expect(engine.blocks.where((b) => b.isRevealed).length, 4);
    }
    expect(engine.endlessWave, 13);
    expect(engine.level.cols, 48);
    engine.dispose();
  });
  test('All elements and fusions stay within budgets in sustained combat', () {
    final engine = create();
    engine.ownedElements.addAll(ElementType.values.skip(1).take(8));
    engine.equippedElements.addAll([
      ElementType.fire,
      ElementType.frost,
      ElementType.lightning,
    ]);
    engine.activeFusions.addAll(ElementType.values.skip(9));
    for (int i = 0; i < 5; i++) {
      engine.summonSpirit();
    }
    expect(engine.spirits.length, 4);
    for (int frame = 0; frame < 1800; frame++) {
      engine.update(1 / 60);
      expect(engine.debris.length, lessThanOrEqualTo(GameEngine.maxDebris));
      expect(
        engine.lightningArcs.length,
        lessThanOrEqualTo(GameEngine.maxLightningArcs),
      );
      expect(
        engine.shockwaves.length,
        lessThanOrEqualTo(GameEngine.maxShockwaves),
      );
      expect(
        engine.floatingTexts.length,
        lessThanOrEqualTo(GameEngine.maxFloatingTexts),
      );
      expect(engine.drops.length, lessThanOrEqualTo(GameEngine.maxDrops));
      expect(engine.impacts.length, lessThanOrEqualTo(GameEngine.maxImpacts));
      expect(engine.mistZones.length, lessThanOrEqualTo(3));
      expect(engine.vortexZones.length, lessThanOrEqualTo(2));
    }
    engine.dispose();
  });
  test(
    'Render elemental materials and gameplay for visual inspection',
    () async {
      final folder = Directory('build/previews')..createSync(recursive: true);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFF101B2A), BlendMode.src);
      for (int i = 0; i < 6; i++) {
        final block = PixelBlock(
          id: 'preview_$i',
          col: i,
          row: 0,
          transform: TransformComponent(
            x: 64 + i * 104,
            y: 66,
            width: 72,
            height: 72,
          ),
          health: HealthComponent(maxHp: 100),
          elementAffinity: ElementAffinityComponent(),
          render: RenderComponent(primaryColor: Colors.grey),
          memeColor: Colors.red,
        );
        switch (i) {
          case 1:
            block.elementAffinity!.applyFire(3, 1);
          case 2:
            block.elementAffinity!.applyFrost(3);
          case 3:
            block.elementAffinity!.applyPoison(3, 1);
          case 4:
            block.elementAffinity!.applyWater(3);
          case 5:
            block.elementAffinity!.applyShock(3);
        }
        block.draw(canvas, Paint(), time: 0.8);
        ElementImpact(
            center: block.transform.position,
            element: [
              ElementType.none,
              ElementType.fire,
              ElementType.frost,
              ElementType.poison,
              ElementType.water,
              ElementType.lightning,
            ][i],
            radius: 44,
          )
          ..age = 0.12
          ..draw(canvas, Paint());
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(656, 132);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${folder.path}/element_materials.png')
          .writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      final engine = create(endless: false);
      for (final block in engine.blocks) {
        final d = Offset(block.col - 13.5, block.row - 13.5).distance;
        if (d < 5) {
          block.health!.takeDamage(1e9);
        } else if (d < 6.8) {
          if (block.col < 14 && block.row < 14) {
            block.elementAffinity!.applyFire(4, 1);
          } else if (block.row < 14) {
            block.elementAffinity!.applyFrost(4);
          } else if (block.col < 14) {
            block.elementAffinity!.applyPoison(4, 1);
          } else {
            block.elementAffinity!.applyWater(4);
            block.elementAffinity!.applyShock(4);
          }
        }
      }
      final gameRecorder = ui.PictureRecorder();
      GamePainter(engine: engine)
          .paint(Canvas(gameRecorder), const Size(640, 680));
      final gamePicture = gameRecorder.endRecording();
      final gameImage = await gamePicture.toImage(640, 680);
      final gamePng = await gameImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      await File('${folder.path}/gameplay.png')
          .writeAsBytes(gamePng!.buffer.asUint8List());
      gameImage.dispose();
      gamePicture.dispose();
      engine.dispose();
    },
  );
  testWidgets('Endless can be selected and launched from the menu', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CharacterSelectScreen()));
    await tester.tap(find.text('Vô tận'));
    await tester.pump();
    expect(
      find.text('Hết khối → bản đồ lớn hơn. Giữ nguyên vàng và nâng cấp.'),
      findsOneWidget,
    );
    await tester.tap(find.text('BẮT ĐẦU PHÁ KHỐI'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Vô tận · Đợt 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
