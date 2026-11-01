import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:break_pixel/core/audio_service.dart';
import 'package:break_pixel/core/progress_store.dart';
import 'package:break_pixel/game/game_engine.dart';
import 'package:break_pixel/models/character.dart';
import 'package:break_pixel/models/ecs.dart';
import 'package:break_pixel/models/game_entities.dart';
import 'package:break_pixel/models/pixel_art_data.dart';
import 'package:break_pixel/models/upgrade.dart';
import 'package:break_pixel/screens/level_select_screen.dart';
import 'package:break_pixel/screens/level_up_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    AudioService.soundEnabled = false;
    ProgressStore.instance = ProgressStore();
  });
  tearDown(() => AudioService.soundEnabled = true);
  GameEngine create({int index = 0, bool endless = false}) => GameEngine(
    role: RoleInfo.allRoles.first,
    race: RaceInfo.allRaces.first,
    level: MemeLevel.allLevels[index],
    isEndless: endless,
    randomSeed: 42,
  )..resize(const Size(400, 600));

  test(
    'Campaign unlocks exactly one new element per first completion in order',
    () {
      final store = ProgressStore();
      expect(store.highestUnlockedIndex, 0);
      expect(store.unlockedElements, isEmpty);
      expect(store.completeLevel(2), isNull);
      expect(store.completedLevels, isEmpty);
      for (int i = 1; i <= 8; i++) {
        expect(store.completeLevel(i), ProgressStore.rewardOrder[i - 1]);
        expect(store.unlockedElements.length, i);
        expect(store.completeLevel(i), isNull);
        expect(store.unlockedElements.length, i);
      }
      expect(store.yetiUnlocked, isFalse);
      store.completeLevel(9);
      expect(store.yetiUnlocked, isTrue);
    },
  );
  test(
    'Profile, independent run slots and unlocks survive a new store instance',
    () async {
      String? disk;
      final store = ProgressStore(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      await store.initialize();
      store.completeLevel(1);
      store.completeLevel(2);
      final story = create()..gold = 731;
      final endless = create(endless: true)..gold = 84;
      store.storyRun = story.exportSnapshot();
      store.storyBuild = story.exportBuild();
      store.endlessRun = endless.exportSnapshot();
      await store.save();
      final reloaded = ProgressStore(
        read: () async => disk,
        write: (value) async => disk = value,
      );
      await reloaded.initialize();
      expect(reloaded.completedLevels, {1, 2});
      expect(reloaded.highestUnlockedIndex, 2);
      expect(reloaded.unlockedElements, {ElementType.fire, ElementType.water});
      expect((reloaded.storyRun!['build'] as Map)['gold'], 731);
      expect((reloaded.endlessRun!['build'] as Map)['gold'], 84);
      expect(reloaded.storageError, isNull);
      story.dispose();
      endless.dispose();
    },
  );
  test(
    'Corrupt or blocked storage reports an error and writes can recover',
    () async {
      bool blocked = true;
      String? disk = '{bad json';
      final store = ProgressStore(
        read: () async => disk,
        write: (value) async {
          if (blocked) throw StateError('blocked');
          disk = value;
        },
      );
      await store.initialize();
      expect(store.storageError, isNotNull);
      store.completeLevel(1);
      await store.save();
      expect(store.storageError, isNotNull);
      blocked = false;
      await store.save();
      expect(store.storageError, isNull);
      expect((jsonDecode(disk!) as Map)['completed'], [1]);
    },
  );
  test(
    'Queued autosaves cannot overwrite the latest state with an older write',
    () async {
      String? disk;
      final store = ProgressStore(
        read: () async => null,
        write: (value) async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
          disk = value;
        },
      );
      await store.initialize();
      store.completeLevel(1);
      final first = store.save();
      store.completeLevel(2);
      final second = store.save();
      await Future.wait([first, second]);
      expect((jsonDecode(disk!) as Map)['completed'], [1, 2]);
    },
  );
  test('Snapshot restores blocks, upgrades, elemental effects, loot and spirit hit timer', () {
    final source = create()
      ..gold = 421
      ..totalDestroyedBlocks = 130;
    source.grantUpgrade(UpgradeType.damage);
    source.grantUpgrade(UpgradeType.fusionCooldown);
    source.addElement(ElementType.fire);
    source.addElement(ElementType.water);
    source.fuseElements(ElementType.fire, ElementType.water);
    source.summonSpirit();
    source.spirits.single.hitCooldown = 0.4;
    final block = source.blocks.first;
    block.health!.takeDamage(20);
    block.isCorroded = true;
    block.elementAffinity!.applyPoison(3, 7);
    source.blocks[1].health!.takeDamage(1e9);
    source.blocks[1].isRevealed = true;
    source.drops.add(
      DropItem(
        id: 'gold',
        transform: TransformComponent(x: 120, y: 200),
        type: DropType.gold,
        value: 35,
      ),
    );
    final data = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(source.exportSnapshot())) as Map,
    );
    final restored = create()..restoreSnapshot(data);
    expect(restored.gold, 421);
    expect(restored.damageUpgradeLevel, 1);
    expect(restored.fusionCooldownDuration, 9);
    expect(restored.totalDestroyedBlocks, 130);
    expect(restored.ownedElements, source.ownedElements);
    expect(restored.selectedFusion, ElementType.mist);
    expect(restored.blocks.first.health!.currentHp, block.health!.currentHp);
    expect(restored.blocks.first.isCorroded, isTrue);
    expect(restored.blocks.first.elementAffinity!.poisonDps, 7);
    expect(restored.blocks[1].isRevealed, isTrue);
    expect(restored.spirits.single.hitCooldown, 0.4);
    expect(restored.drops.single.value, 35);
    restored.resize(const Size(600, 800));
    restored.update(1 / 60);
    expect(restored.gold, greaterThanOrEqualTo(421));
    source.dispose();
    restored.dispose();
  });
  test('Endless resume keeps its wave and a bounded live board', () {
    final source = create(endless: true);
    final data = source.exportSnapshot();
    data['wave'] = 2;
    final wave = GameEngine(
      role: source.role,
      race: source.race,
      level: source.level,
      isEndless: true,
    );
    // Use an actual wave transition to generate a matching grid.
    for (final b in source.blocks) {
      if (!b.health!.isDestroyed) b.elementAffinity!.applyPoison(1, 1e9);
    }
    source.update(1 / 60);
    while (source.endlessWave < 2) {
      source.update(0.1);
    }
    wave.restoreSnapshot(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(source.exportSnapshot())) as Map,
      ),
    );
    expect(wave.endlessWave, 2);
    expect(wave.level.cols, 32);
    expect(wave.blocks.length, 1024);
    source.dispose();
    wave.dispose();
  });
  test('Every campaign stage increases total block health without unbounded grid growth', () {
    double previous = 0;
    for (int i = 0; i < MemeLevel.allLevels.length; i++) {
      final engine = create(index: i);
      final total = engine.blocks.fold<double>(
        0,
        (sum, b) => sum + b.health!.maxHp,
      );
      expect(total, greaterThan(previous));
      previous = total;
      expect(engine.blocks.length, lessThanOrEqualTo(36 * 36));
      engine.dispose();
    }
  });
  testWidgets('Level selection locks future stages and shows their rewards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LevelSelectScreen(
          role: RoleInfo.allRoles.first,
          race: RaceInfo.allRaces.first,
        ),
      ),
    );
    expect(find.text('CHỌN MÀN CHƠI'), findsOneWidget);
    expect(find.text('HOÀN THÀNH MÀN TRƯỚC ĐỂ MỞ'), findsWidgets);
    final enter = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('VÀO MÀN'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(enter.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Level up never offers a new element outside campaign completion',
    (tester) async {
      final engine = create();
      await tester.pumpWidget(
        MaterialApp(
          home: LevelUpModal(engine: engine, onOptionSelected: () {}),
        ),
      );
      expect(find.text('MỚI'), findsNothing);
      expect(find.text('+1 BẬC'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      engine.dispose();
    },
  );
}
