import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:break_pixel/core/audio_service.dart';
import 'package:break_pixel/game/game_engine.dart';
import 'package:break_pixel/models/character.dart';
import 'package:break_pixel/models/ecs.dart';
import 'package:break_pixel/models/element.dart';
import 'package:break_pixel/models/fusion_cast.dart';
import 'package:break_pixel/models/pixel_art_data.dart';
import 'package:break_pixel/screens/fusion_lab_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AudioService.soundEnabled = false);
  tearDown(() => AudioService.soundEnabled = true);
  GameEngine create(ElementData recipe) {
    final engine = GameEngine(
      role: RoleInfo.allRoles.first,
      race: RaceInfo.allRaces.first,
      level: MemeLevel.allLevels.first,
      randomSeed: 42,
    )..resize(const Size(400, 600));
    engine.player.transform.vx = engine.player.transform.vy = 0;
    for (final block in engine.blocks) {
      if (!block.health!.isDestroyed) {
        block.health!.maxHp = block.health!.currentHp = 1e6;
      }
    }
    for (final element in recipe.ingredients!) {
      engine.addElement(element);
    }
    expect(
      engine.fuseElements(recipe.ingredients![0], recipe.ingredients![1]),
      isTrue,
    );
    return engine;
  }

  void breakBlocks(GameEngine engine, int count) {
    for (final block
        in engine.blocks.reversed
            .where((b) => !b.health!.isDestroyed)
            .take(count)) {
      block.elementAffinity!.applyPoison(1, 1e9);
    }
    engine.update(1 / 60);
  }

  void charge(GameEngine engine) {
    final missing = GameEngine.fusionUnlockBlocks - engine.totalDestroyedBlocks;
    if (missing > 0) breakBlocks(engine, missing);
    while (engine.fusionCooldown > 0) {
      engine.update(0.1);
    }
    expect(engine.fusionEnergy, 100);
  }

  test(
    'Destroying 100 blocks permanently unlocks cooldown-based manual casting',
    () {
      final engine = create(ElementData.fusionElements.first);
      engine.update(1 / 60);
      expect(engine.fusionEnergy, lessThanOrEqualTo(12 / 60));
      expect(engine.castFusion(), isFalse);
      charge(engine);
      expect(engine.mistZones, isEmpty);
      expect(engine.castFusion(), isTrue);
      expect(engine.fusionEnergy, 100);
      expect(engine.mistZones, isEmpty);
      expect(engine.pendingFusion, isNotNull);
      expect(engine.castFusion(), isFalse);
      for (int i = 0; i < 4; i++) {
        engine.update(0.1);
      }
      expect(engine.pendingFusion, isNull);
      expect(engine.mistZones.length, 1);
      expect(engine.fusionCooldown, greaterThan(9));
      engine.dispose();
    },
  );
  test('Invalid setup or distant targets never spend a ready charge', () {
    final engine = create(
      ElementData.fusionElements.firstWhere(
        (d) => d.type == ElementType.chainLightning,
      ),
    );
    charge(engine);
    expect(engine.castFusion(const Offset(-1000, -1000)), isFalse);
    for (final block in engine.blocks) {
      block.elementAffinity!.isSoaked = false;
    }
    expect(engine.castFusion(), isFalse);
    expect(engine.fusionEnergy, 100);
    engine.dispose();
  });
  test('Switching recipes preserves unlock progress and shared cooldown', () {
    final engine = create(ElementData.fusionElements.first);
    breakBlocks(engine, 40);
    expect(engine.fusionEnergy, 40);
    engine.addElement(ElementType.wind);
    engine.fuseElements(ElementType.fire, ElementType.wind);
    engine.selectFusion(ElementType.firestorm);
    expect(engine.fusionEnergy, 40);
    engine.selectFusion(ElementType.mist);
    expect(engine.fusionEnergy, 40);
    breakBlocks(engine, 60);
    expect(engine.canCastFusion, isTrue);
    expect(engine.castFusion(), isTrue);
    for (int i = 0; i < 4; i++) {
      engine.update(0.1);
    }
    final cooldown = engine.fusionCooldown;
    engine.selectFusion(ElementType.firestorm);
    expect(engine.fusionEnergy, 100);
    expect(engine.fusionCooldown, cooldown);
    expect(engine.canCastFusion, isFalse);
    while (engine.fusionCooldown > 0) {
      engine.update(0.1);
    }
    expect(engine.canCastFusion, isTrue);
    expect(engine.castFusion(), isTrue);
    engine.dispose();
  });
  for (final recipe in ElementData.fusionElements) {
    test(
      '${recipe.type.name} can be charged and produces its gameplay effect',
      () {
        final engine = create(recipe);
        charge(engine);
        expect(engine.castFusion(), isTrue);
        final target = engine.pendingFusion!.targetId;
        expect(engine.selectFusion(recipe.type), isFalse);
        for (int i = 0; i < 4; i++) {
          engine.update(0.1);
        }
        expect(engine.pendingFusion, isNull);
        expect(engine.fusionCasts.length, 1);
        switch (recipe.type) {
          case ElementType.mist:
            expect(engine.mistZones, isNotEmpty);
          case ElementType.firestorm:
            expect(engine.isFirestormActive, isTrue);
          case ElementType.voidVortex:
            expect(engine.vortexZones, isNotEmpty);
          case ElementType.acidMelt:
            final block = engine.blocks.firstWhere((b) => b.id == target);
            expect(block.isCorroded, isTrue);
            expect(block.health!.maxHp, 750000);
            charge(engine);
            expect(engine.castFusion(), isTrue);
            for (int i = 0; i < 4; i++) {
              engine.update(0.1);
            }
            expect(
              block.health!.maxHp,
              750000,
              reason: 'A second acid cast must not stack max-HP corrosion',
            );
          case ElementType.permafrost:
            expect(
              engine.blocks.any((b) => b.elementAffinity!.frozenTimer > 5),
              isTrue,
            );
          case ElementType.chainLightning || ElementType.superconductor:
            expect(engine.lightningArcs, isNotEmpty);
          default:
            expect(engine.shockwaves, isNotEmpty);
        }
        expect(engine.impacts.length, lessThanOrEqualTo(GameEngine.maxImpacts));
        engine.dispose();
      },
    );
  }
  testWidgets('Recipe catalog fits a small screen and explains requirements', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = create(ElementData.fusionElements.first);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FusionLabModal(engine: engine)),
      ),
    );
    expect(find.text('DUNG HỢP CHIẾN THUẬT'), findsOneWidget);
    expect(find.text('ĐANG TRANG BỊ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    engine.dispose();
  });
  test('Render bounded fusion cast gallery', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFF101C2A), BlendMode.src);
    for (int i = 0; i < 10; i++) {
      final center = Offset(120 + (i % 2) * 240.0, 100 + (i ~/ 2) * 190.0);
      final data = ElementData.fusionElements[i];
      FusionCast(
          type: data.type,
          center: center,
          color: data.color,
          targetId: '',
          board: Rect.fromCenter(center: center, width: 210, height: 170),
        )
        ..age = 0.62
        ..draw(canvas, Paint());
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(480, 960);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('build/previews')..createSync(recursive: true);
    await File('${folder.path}/fusion_casts.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
