import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:break_pixel/core/audio_service.dart';
import 'package:break_pixel/game/game_engine.dart';
import 'package:break_pixel/models/character.dart';
import 'package:break_pixel/models/ecs.dart';
import 'package:break_pixel/models/game_entities.dart';
import 'package:break_pixel/models/pixel_art_data.dart';
import 'package:break_pixel/models/upgrade.dart';
import 'package:break_pixel/screens/forge_modal.dart';
import 'package:break_pixel/screens/level_up_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AudioService.soundEnabled = false);
  tearDown(() => AudioService.soundEnabled = true);
  GameEngine create({RaceInfo? race}) => GameEngine(
    role: RoleInfo.allRoles.first,
    race: race ?? RaceInfo.allRaces.first,
    level: MemeLevel.allLevels.first,
    randomSeed: 42,
  )..resize(const Size(400, 600));

  test(
    'Paid and free upgrades use the same stats and all ranks have a hard cap',
    () {
      for (final spec in UpgradeSpec.all) {
        final paid = create()..gold = 100000;
        final free = create();
        expect(paid.purchaseUpgrade(spec.type), isTrue);
        expect(free.grantUpgrade(spec.type), isTrue);
        expect(paid.upgradeRank(spec.type), free.upgradeRank(spec.type));
        expect(paid.totalDamage, free.totalDamage);
        expect(paid.totalAttackSpeed, free.totalAttackSpeed);
        expect(paid.normalBallSpeed, free.normalBallSpeed);
        while (paid.canImprove(spec.type)) {
          paid.purchaseUpgrade(spec.type);
        }
        final gold = paid.gold;
        expect(paid.upgradeRank(spec.type), spec.maxRank);
        expect(paid.purchaseUpgrade(spec.type), isFalse);
        expect(paid.grantUpgrade(spec.type), isFalse);
        expect(paid.gold, gold);
        paid.dispose();
        free.dispose();
      }
    },
  );
  test(
    'All forge costs including spirits and resonance receive dwarf discount',
    () {
      final human = create();
      final dwarf = create(
        race: RaceInfo.allRaces.firstWhere((r) => r.type == RaceType.dwarf),
      );
      for (final spec in UpgradeSpec.all) {
        expect(
          dwarf.upgradeCost(spec.type),
          (human.upgradeCost(spec.type) * 0.75).round(),
        );
      }
      human.dispose();
      dwarf.dispose();
    },
  );
  test('Element loadout allows only three and changing it changes wind immediately', () {
    final engine = create();
    for (final type in [
      ElementType.fire,
      ElementType.frost,
      ElementType.poison,
      ElementType.wind,
    ]) {
      engine.addElement(type);
    }
    expect(engine.equippedElements.length, 3);
    expect(engine.toggleElement(ElementType.wind), isFalse);
    expect(engine.toggleElement(ElementType.poison), isTrue);
    final spin = engine.weaponSpinSpeedMultiplier;
    expect(engine.toggleElement(ElementType.wind), isTrue);
    expect(engine.weaponSpinSpeedMultiplier, greaterThan(spin));
    expect(engine.toggleElement(ElementType.earth), isFalse);
    engine.dispose();
  });
  test('Dash has cooldown and settles back toward normal movement speed', () {
    final engine = create();
    expect(engine.boostBall(const Offset(500, 0)), isTrue);
    expect(engine.boostBall(const Offset(0, 500)), isFalse);
    expect(
      Offset(engine.player.transform.vx, engine.player.transform.vy).distance,
      lessThanOrEqualTo(360),
    );
    for (int i = 0; i < 120; i++) {
      engine.update(1 / 60);
    }
    expect(engine.dashCooldown, 0);
    expect(
      Offset(engine.player.transform.vx, engine.player.transform.vy).distance,
      closeTo(engine.normalBallSpeed, 1),
    );
    expect(engine.boostBall(const Offset(0, 500)), isTrue);
    engine.dispose();
  });
  test(
    'Statuses add vulnerability and weaker DoT cannot replace stronger DoT',
    () {
      final status = ElementAffinityComponent()
        ..applyFrost(4)
        ..applyShock(2);
      expect(status.damageMultiplier, 1.75);
      status.applyPoison(5, 20);
      status.applyPoison(2, 2);
      expect(status.poisonDps, 20);
      expect(status.poisonTimer, 5);
      status.applyFire(4, 16);
      status.applyFire(1, 1);
      expect(status.burnDps, 16);
      expect(status.burnTimer, 4);
    },
  );
  test(
    'Story progression preserves equipment, currency and purchased stats',
    () {
      final engine = create()..gold = 1000;
      engine.purchaseUpgrade(UpgradeType.damage);
      engine.addElement(ElementType.fire);
      final gold = engine.gold;
      final damage = engine.totalDamage;
      for (final block in engine.blocks) {
        block.health!.takeDamage(1e9);
      }
      engine.update(1 / 60);
      expect(engine.startStoryLevel(MemeLevel.allLevels[1]), isTrue);
      expect(engine.level.id, 2);
      expect(engine.totalDamage, damage);
      expect(engine.gold, gold);
      expect(engine.equippedElements, contains(ElementType.fire));
      expect(engine.blocks.where((b) => b.isRevealed).length, 4);
      engine.dispose();
    },
  );
  test('Elemental impacts expire and retain only the fixed effect budget', () {
    final engine = create();
    for (int i = 0; i < 100; i++) {
      engine.impacts.add(
        ElementImpact(center: Offset.zero, element: ElementType.fire),
      );
    }
    expect(engine.impacts.length, GameEngine.maxImpacts);
    for (int i = 0; i < 60; i++) {
      engine.update(1 / 60);
    }
    // Physical hits may add a few new impacts, but old instances must be released.
    expect(
      engine.impacts.every((impact) => impact.age < impact.duration),
      isTrue,
    );
    engine.dispose();
  });
  testWidgets('Forge fits a small screen and disables maxed purchases', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = create()..gold = 10000;
    while (engine.canImprove(UpgradeType.damage)) {
      engine.grantUpgrade(UpgradeType.damage);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ForgeModal(engine: engine)),
      ),
    );
    expect(find.text('TỐI ĐA'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    engine.dispose();
  });
  testWidgets(
    'Level up options remain stable across rebuilds and reroll charges once',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = create()..gold = 1000;
      Widget app() => MaterialApp(
        home: Scaffold(
          body: LevelUpModal(engine: engine, onOptionSelected: () {}),
        ),
      );
      await tester.pumpWidget(app());
      final before = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      await tester.pumpWidget(app());
      final after = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      expect(after, before);
      final reroll = find.text('Đổi lựa chọn · 30 G');
      await tester.ensureVisible(reroll);
      await tester.tap(reroll);
      await tester.pump();
      expect(engine.gold, 970);
      expect(find.text('Đã đổi lựa chọn'), findsOneWidget);
      await tester.tap(find.text('Đã đổi lựa chọn'));
      await tester.pump();
      expect(engine.gold, 970);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      engine.dispose();
    },
  );
  test(
    'Resonance changes elemental power without changing physical damage',
    () {
      final engine = create();
      final physical = engine.totalDamage;
      engine.grantUpgrade(UpgradeType.resonance);
      expect(engine.totalDamage, physical);
      expect(engine.elementDamage, closeTo(physical * 1.1, 1e-6));
      engine.dispose();
    },
  );
  test('Archer range upgrades change pierce count and projectile lifetime', () {
    final engine = GameEngine(
      role: RoleInfo.allRoles.firstWhere((r) => r.type == RoleType.archer),
      race: RaceInfo.allRaces.first,
      level: MemeLevel.allLevels.first,
      randomSeed: 42,
    )..resize(const Size(400, 600));
    for (int i = 0; i < 4; i++) {
      engine.grantUpgrade(UpgradeType.range);
    }
    engine.update(1 / 60);
    expect(engine.arrows.first.pierceCount, 5);
    expect(engine.arrows.first.lifeTime, greaterThan(1.6));
    expect(engine.projectileAimAngle, isNotNull);
    engine.dispose();
  });
}
