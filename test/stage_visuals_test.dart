import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:break_pixel/game/game_engine.dart';
import 'package:break_pixel/game/game_painter.dart';
import 'package:break_pixel/models/character.dart';
import 'package:break_pixel/models/ecs.dart';
import 'package:break_pixel/models/game_entities.dart';
import 'package:break_pixel/models/pixel_art_data.dart';
import 'package:break_pixel/models/stage_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GameEngine create(int index) => GameEngine(
    role: RoleInfo.allRoles.first,
    race: RaceInfo.allRaces.first,
    level: MemeLevel.allLevels[index],
    randomSeed: 42,
  )..resize(const Size(960, 640));

  test('Campaign and endless use all nine scenes without changing artwork or collision geometry', () {
    final levels = MemeLevel.allLevels;
    expect(levels.map((level) => level.theme.name).toSet().length, 9);
    for (int i = 0; i < 9; i++) {
      expect(levels[i].theme, StageTheme.all[i]);
      expect(MemeLevel.endlessWave(i + 1).theme, StageTheme.all[i]);
    }
    expect(MemeLevel.endlessWave(10).theme, StageTheme.all.first);
  });
  test('Only one backdrop is cached; frames reuse it, changes rebuild it and dispose releases it', () {
    final engine = create(0);
    final painter = GamePainter(engine: engine);
    void frame() {
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(960, 640));
      recorder.endRecording().dispose();
    }

    for (int i = 0; i < 60; i++) {
      engine.elapsedTime = i / 60;
      frame();
    }
    expect(engine.backdrop.generationCount, 1);
    engine.level = MemeLevel.allLevels[1];
    frame();
    expect(engine.backdrop.generationCount, 2);
    engine.resize(const Size(800, 640));
    frame();
    expect(engine.backdrop.generationCount, 3);
    expect(engine.backdrop.isCached, isTrue);
    engine.dispose();
    expect(engine.backdrop.isCached, isFalse);
  });
  test('Intact material cannot leak the hidden image color', () async {
    Future<List<int>> render(Color secret) async {
      final block = PixelBlock(
        id: 'tile',
        col: 3,
        row: 4,
        memeColor: secret,
        transform: TransformComponent(x: 20, y: 20, width: 32, height: 32),
        health: HealthComponent(maxHp: 50),
        elementAffinity: ElementAffinityComponent(),
        render: RenderComponent(primaryColor: Colors.grey),
      );
      final recorder = ui.PictureRecorder();
      block.draw(Canvas(recorder), Paint(), theme: StageTheme.all[2]);
      final picture = recorder.endRecording();
      final image = await picture.toImage(40, 40);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final result = bytes!.buffer.asUint8List().toList();
      image.dispose();
      picture.dispose();
      return result;
    }

    expect(await render(Colors.red), await render(Colors.blue));
  });
  test('Revealed tile keeps its exact original artwork color', () async {
    final engine = create(0);
    final block = engine.blocks.first;
    block.health!.takeDamage(1e9);
    final recorder = ui.PictureRecorder();
    GamePainter(engine: engine).paint(Canvas(recorder), const Size(960, 640));
    final picture = recorder.endRecording();
    final image = await picture.toImage(960, 640);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final offset =
        (block.transform.y.floor() * 960 + block.transform.x.floor()) * 4;
    final rgba = bytes!.buffer.asUint8List();
    final color = block.memeColor.toARGB32();
    expect(rgba.sublist(offset, offset + 4), [
      (color >> 16) & 255,
      (color >> 8) & 255,
      color & 255,
      255,
    ]);
    image.dispose();
    picture.dispose();
    engine.dispose();
  });
  test('Render every theme and a contact sheet for visual review', () async {
    final folder = Directory('build/previews')..createSync(recursive: true);
    final sheetRecorder = ui.PictureRecorder();
    final sheet = Canvas(sheetRecorder);
    for (int i = 0; i < 9; i++) {
      final engine = create(i);
      final center = (engine.level.cols - 1) / 2;
      for (final block in engine.blocks) {
        final distance = Offset(
          block.col - center,
          block.row - center,
        ).distance;
        if (distance < 4.5) {
          block.health!.takeDamage(1e9);
        } else if (distance < 5.8 && (block.col + block.row) % 3 == 0) {
          block.health!.takeDamage(block.health!.maxHp * 0.65);
        }
      }
      engine.elapsedTime = 2;
      engine.player.weaponAngle = -0.6;
      final recorder = ui.PictureRecorder();
      GamePainter(engine: engine).paint(Canvas(recorder), const Size(960, 640));
      final picture = recorder.endRecording();
      final image = await picture.toImage(960, 640);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${folder.path}/stage_${i + 1}.png')
          .writeAsBytes(png!.buffer.asUint8List());
      sheet.drawImageRect(
        image,
        const Rect.fromLTWH(0, 0, 960, 640),
        Rect.fromLTWH((i % 3) * 480.0, (i ~/ 3) * 320.0, 480, 320),
        Paint(),
      );
      image.dispose();
      picture.dispose();
      engine.dispose();
    }
    final picture = sheetRecorder.endRecording();
    final image = await picture.toImage(1440, 960);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${folder.path}/stage_themes.png')
        .writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
