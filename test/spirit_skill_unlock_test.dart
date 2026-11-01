import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:break_pixel/core/audio_service.dart';
import 'package:break_pixel/game/game_engine.dart';
import 'package:break_pixel/models/character.dart';
import 'package:break_pixel/models/ecs.dart';
import 'package:break_pixel/models/game_entities.dart';
import 'package:break_pixel/models/pixel_art_data.dart';
import 'package:break_pixel/models/upgrade.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AudioService.soundEnabled = false);
  tearDown(() => AudioService.soundEnabled = true);
  GameEngine create() => GameEngine(
    role: RoleInfo.allRoles.firstWhere((r) => r.type == RoleType.archer),
    race: RaceInfo.allRaces.first,
    level: MemeLevel.allLevels.first,
    randomSeed: 42,
  )..resize(const Size(400, 600));
  void destroy(GameEngine engine, int count) {
    for (final block
        in engine.blocks.reversed
            .where((b) => !b.health!.isDestroyed)
            .take(count)) {
      block.elementAffinity!.applyPoison(1, 1e9);
    }
    engine.update(1 / 60);
  }

  test(
    '99 kills stay locked; the 100th permanently unlocks casting across levels',
    () {
      final engine = create();
      for (final b in engine.blocks) {
        if (!b.health!.isDestroyed) {
          b.health!.maxHp = b.health!.currentHp = 1e6;
        }
      }
      engine.addElement(ElementType.fire);
      engine.addElement(ElementType.water);
      engine.fuseElements(ElementType.fire, ElementType.water);
      expect(engine.totalDestroyedBlocks, 0);
      destroy(engine, 99);
      expect(engine.totalDestroyedBlocks, 99);
      expect(engine.canCastFusion, isFalse);
      expect(engine.purchaseUpgrade(UpgradeType.fusionCooldown), isFalse);
      destroy(engine, 1);
      expect(engine.totalDestroyedBlocks, 100);
      expect(engine.canCastFusion, isTrue);
      expect(engine.castFusion(), isTrue);
      expect(engine.fusionCooldown, 10);
      for (int i = 0; i < 4; i++) {
        engine.update(0.1);
      }
      expect(engine.isFusionUnlocked, isTrue);
      destroy(engine, engine.blocks.length);
      expect(engine.isLevelCompleted, isTrue);
      final kills = engine.totalDestroyedBlocks;
      expect(engine.startStoryLevel(MemeLevel.allLevels[1]), isTrue);
      expect(engine.totalDestroyedBlocks, kills);
      expect(engine.isFusionUnlocked, isTrue);
      engine.dispose();
    },
  );
  test(
    'Cooldown upgrades reach 10, 9, 8, 7 seconds and cannot pass the cap',
    () {
      final engine = create()
        ..totalDestroyedBlocks = 100
        ..gold = 10000;
      expect(engine.fusionCooldownDuration, 10);
      for (final seconds in [9, 8, 7]) {
        expect(engine.purchaseUpgrade(UpgradeType.fusionCooldown), isTrue);
        expect(engine.fusionCooldownDuration, seconds);
      }
      final gold = engine.gold;
      expect(engine.purchaseUpgrade(UpgradeType.fusionCooldown), isFalse);
      expect(engine.grantUpgrade(UpgradeType.fusionCooldown), isFalse);
      expect(engine.gold, gold);
      engine.addElement(ElementType.fire);
      engine.addElement(ElementType.water);
      engine.fuseElements(ElementType.fire, ElementType.water);
      expect(engine.castFusion(), isTrue);
      expect(engine.fusionCooldown, 7);
      engine.dispose();
    },
  );
  test('Spirit contact damage is fixed per hit and identical at 30, 60 and 120 FPS', () {
    for (final fps in [30, 60, 120]) {
      final engine = create();
      final target = engine.blocks.firstWhere(
        (b) => b.col == 16 && b.row == 14,
      );
      for (final block in engine.blocks) {
        if (block != target) {
          block.health!.takeDamage(1e9);
        }
      }
      target.health!.maxHp = target.health!.currentHp = 10000;
      engine.player.transform.position =
          target.transform.position - const Offset(30, 0);
      engine.player.transform.vx = engine.player.transform.vy = 0;
      engine.player.attackCooldown = 10000;
      engine.summonSpirit();
      final spirit = engine.spirits.single;
      spirit.orbitRadius = 30;
      spirit.orbitSpeed = 0;
      spirit.angle = 0;
      for (int i = 0; i < fps; i++) {
        engine.update(1 / fps);
      }
      expect(
        10000 - target.health!.currentHp,
        closeTo(engine.totalDamage * OrbitingSpirit.damageRatio * 2, 1e-6),
        reason: '$fps FPS',
      );
      engine.dispose();
    }
  });
}
