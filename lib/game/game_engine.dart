import 'dart:math';
import 'package:flutter/material.dart';
import '../models/ecs.dart';
import '../models/character.dart';
import '../models/element.dart';
import '../models/pixel_art_data.dart';
import '../models/game_entities.dart';
import '../core/audio_service.dart';

class GameEngine extends ChangeNotifier {
  late PlayerBall player;
  RoleInfo role;
  RaceInfo race;
  MemeLevel level;
  Size arenaSize = const Size(400, 600);

  List<PixelBlock> blocks = [];
  List<ArrowEntity> arrows = [];
  List<HookEntity> hooks = [];
  List<DropItem> drops = [];
  List<PixelDebris> debris = [];
  List<FloatingText> floatingTexts = [];
  List<MistZone> mistZones = [];
  List<ShockwaveRing> shockwaves = [];
  List<OrbitingSpirit> spirits = [];
  List<LightningArc> lightningArcs = [];

  // Hiệu ứng Rung lắc màn hình (Screen Shake)
  double screenShake = 0.0;
  Offset shakeOffset = Offset.zero;

  // Hệ thống nguyên tố sở hữu
  final Set<ElementType> ownedElements = {};
  final Set<ElementType> activeFusions = {};

  // Kinh tế & Tiến trình
  int gold = 0;
  double exp = 0;
  double expToNextLevel = 100;
  int characterLevel = 1;
  int totalBlocksCount = 1;
  int brokenBlocksCount = 0;
  double completionPercent = 0.0;
  bool isLevelCompleted = false;

  // Cấp độ nâng cấp tại Lò rèn & Thăng cấp
  int damageUpgradeLevel = 0;
  int speedUpgradeLevel = 0;
  int rangeUpgradeLevel = 0;
  int bounceUpgradeLevel = 0;
  int magnetUpgradeLevel = 0;
  int spinUpgradeLevel = 0;
  int spiritUpgradeLevel = 0;

  double get weaponSpinSpeedMultiplier => 1.0 + (spinUpgradeLevel * 0.4);

  // Lực hút nam châm cơ bản
  double get magnetRange => 80.0 + (magnetUpgradeLevel * 25.0);

  // Sát thương tổng thể
  double get totalDamage {
    final base = (role.baseDamage + damageUpgradeLevel * 4.0) * race.damageMultiplier;
    return base;
  }

  // Tốc độ đánh tổng thể
  double get totalAttackSpeed {
    return role.attackSpeed * race.speedMultiplier * (1.0 + speedUpgradeLevel * 0.15);
  }

  // Tầm với vũ khí
  double get totalWeaponRange {
    return (role.weaponRange + rangeUpgradeLevel * 8.0);
  }

  // Callbacks
  VoidCallback? onLevelUp;
  VoidCallback? onVictory;
  VoidCallback? onBlockDestroyedEffect;

  GameEngine({
    required this.role,
    required this.race,
    required this.level,
  }) {
    _initEngine();
  }

  double gridStartX = 0;
  double gridStartY = 0;
  double gridBlockSize = 28;

  bool isGridBuilt = false;

  void _initEngine() {
    // Tốc độ nảy cơ bản
    double speed = 220.0 * (1.0 + race.bounceBonus + bounceUpgradeLevel * 0.1);
    final randomAngle = Random().nextDouble() * 2 * pi; // Bất kỳ góc nào 360 độ
    final vx = speed * cos(randomAngle);
    final vy = speed * sin(randomAngle);

    player = PlayerBall(
      id: 'player',
      transform: TransformComponent(
        x: arenaSize.width / 2,
        y: arenaSize.height / 2,
        vx: vx,
        vy: vy,
        width: 32,
        height: 32,
      ),
      role: role,
      race: race,
    );

    // Khởi tạo 1 Tinh Linh Hộ Vệ cơ bản ban đầu đồng hành cùng người chơi
    spirits.add(OrbitingSpirit(
      id: 'starter_spirit',
      element: ElementType.fire,
      orbitRadius: 48.0,
      angle: 0.0,
      orbitSpeed: 3.8,
      color: Colors.deepOrangeAccent,
      size: 8.0,
    ));
  }

  void resize(Size newSize) {
    if (arenaSize == newSize && isGridBuilt) return;
    final isFirstSetup = !isGridBuilt;
    final oldWidth = level.cols * gridBlockSize;
    final oldHeight = level.rows * gridBlockSize;
    final oldCenter = Offset(gridStartX + oldWidth / 2, gridStartY + oldHeight / 2);
    arenaSize = newSize;

    if (isFirstSetup) {
      isGridBuilt = true;
      _buildPixelGrid();
    } else {
      // Điều chỉnh lại vị trí grid khi thay đổi kích thước mà vẫn giữ nguyên vị trí bóng trong không gian
      final cols = level.cols;
      final rows = level.rows;
      const padding = 16.0;
      final availableWidth = arenaSize.width - padding * 2;
      const topOffset = 50.0;
      final availableHeight = (arenaSize.height - topOffset - 65.0).clamp(100.0, 2000.0);
      final blockSizeByWidth = availableWidth / cols;
      final blockSizeByHeight = availableHeight / rows;
      final blockSize = min(blockSizeByWidth, blockSizeByHeight).clamp(20.0, 48.0);
      gridBlockSize = blockSize;
      final gridWidth = cols * blockSize;
      final gridHeight = rows * blockSize;
      gridStartX = (arenaSize.width - gridWidth) / 2;
      gridStartY = topOffset + (availableHeight - gridHeight) / 2;

      final newCenter = Offset(gridStartX + gridWidth / 2, gridStartY + gridHeight / 2);
      final offsetFromCenter = player.transform.position - oldCenter;
      player.transform.position = newCenter + offsetFromCenter;
      player.radius = (blockSize * 0.38).clamp(9.0, 15.0);

      for (final block in blocks) {
        block.transform.x = gridStartX + block.col * blockSize + blockSize / 2;
        block.transform.y = gridStartY + block.row * blockSize + blockSize / 2;
        block.transform.width = blockSize;
        block.transform.height = blockSize;
      }
    }
    notifyListeners();
  }

  void _buildPixelGrid() {
    blocks.clear();
    final cols = level.cols;
    final rows = level.rows;

    const padding = 16.0;
    final availableWidth = arenaSize.width - padding * 2;
    const topOffset = 50.0;
    final availableHeight = (arenaSize.height - topOffset - 65.0).clamp(100.0, 2000.0);

    final blockSizeByWidth = availableWidth / cols;
    final blockSizeByHeight = availableHeight / rows;
    final blockSize = min(blockSizeByWidth, blockSizeByHeight).clamp(20.0, 48.0);
    gridBlockSize = blockSize;

    final gridWidth = cols * blockSize;
    final gridHeight = rows * blockSize;
    gridStartX = (arenaSize.width - gridWidth) / 2;
    gridStartY = topOffset + (availableHeight - gridHeight) / 2;

    // Đặt vị trí Quả cầu xuất phát chính xác tại TÂM của buồng rỗng 2x2
    final gridCenterX = gridStartX + gridWidth / 2;
    final gridCenterY = gridStartY + gridHeight / 2;
    player.transform.x = gridCenterX;
    player.transform.y = gridCenterY;
    player.radius = (blockSize * 0.38).clamp(9.0, 15.0);

    // Xác định 4 ô trống trung tâm (như ví dụ 2:2, 2:3, 3:2, 3:3)
    final centerCol1 = cols ~/ 2 - 1;
    final centerCol2 = cols ~/ 2;
    final centerRow1 = rows ~/ 2 - 1;
    final centerRow2 = rows ~/ 2;

    int breakableCount = 0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final memeColor = level.colorGrid[r][c];
        final bx = gridStartX + c * blockSize + blockSize / 2;
        final by = gridStartY + r * blockSize + blockSize / 2;

        final isCenterEmpty = (r == centerRow1 || r == centerRow2) &&
                              (c == centerCol1 || c == centerCol2);

        final block = PixelBlock(
          id: 'block_${r}_$c',
          transform: TransformComponent(
            x: bx,
            y: by,
            width: blockSize,
            height: blockSize,
          ),
          health: HealthComponent(maxHp: 20.0 + (level.id - 1) * 12.0),
          elementAffinity: ElementAffinityComponent(),
          render: RenderComponent(primaryColor: const Color(0xFF4A5568)),
          col: c,
          row: r,
          memeColor: memeColor,
        );

        if (isCenterEmpty) {
          // Ô trung tâm: Lớp vỏ đã bị phá từ trước, HÌNH ẢNH ẨN BÊN DƯỚI ĐƯỢC HIỆN RA
          block.health!.currentHp = 0;
          block.health!.isDestroyed = true;
          block.isRevealed = true;
        } else {
          breakableCount++;
        }

        blocks.add(block);
      }
    }

    totalBlocksCount = breakableCount > 0 ? breakableCount : 1;
    brokenBlocksCount = 0;
    completionPercent = 0.0;
  }


  void update(double dt) {
    if (isLevelCompleted) return;

    // Giảm dần độ rung màn hình rất nhanh (Screen Shake decay)
    if (screenShake > 0) {
      screenShake = max(0.0, screenShake - dt * 38.0);
      final rng = Random();
      shakeOffset = Offset(
        (rng.nextDouble() - 0.5) * 2 * screenShake,
        (rng.nextDouble() - 0.5) * 2 * screenShake,
      );
    } else {
      shakeOffset = Offset.zero;
    }

    // Cập nhật các vòng sóng xung kích (Shockwaves)
    shockwaves.removeWhere((sw) => sw.update(dt));

    // Cập nhật các tia sét giật chuỗi (Lightning Arcs)
    lightningArcs.removeWhere((arc) => arc.update(dt));

    // 1. Cập nhật Nhân vật (Vị trí & Góc vũ khí)
    player.spinMultiplier = weaponSpinSpeedMultiplier;
    player.update(dt);
    _handleBallBorderCollision();
    _handleBallBlockCollision();

    // 2. Cập nhật Tinh Linh Hộ Vệ xoay quanh bóng
    final pCenter = player.transform.position;
    for (final spirit in spirits) {
      spirit.update(dt, pCenter);
      final sPos = spirit.getPosition(pCenter);
      for (final b in blocks) {
        if (b.health!.isDestroyed) continue;
        if (b.transform.rect.contains(sPos)) {
          _damageBlock(b, totalDamage * 0.8 * dt * 5.0, 'TINH LINH');
          if (spirit.element == ElementType.fire) {
            b.elementAffinity?.applyFire(2.5, totalDamage * 0.25);
          } else if (spirit.element == ElementType.frost) {
            b.elementAffinity?.applyFrost(3.0);
          } else if (spirit.element == ElementType.lightning) {
            b.elementAffinity?.applyShock(1.2);
          } else if (spirit.element == ElementType.poison) {
            b.elementAffinity?.applyPoison(3.0, totalDamage * 0.2);
          }
        }
      }
    }

    // 3. Cơ chế Vũ khí theo Role
    _handleWeaponAttacks(dt);

    // 4. Cập nhật Mũi tên & Móc câu
    _updateProjectiles(dt);

    // 5. Cập nhật Hiệu ứng Nguyên tố & Sương mù (Mist)
    _updateMistZones(dt);

    // 6. Cập nhật các khối Pixel
    for (final b in blocks) {
      if (!b.health!.isDestroyed) {
        b.update(dt);
      }
    }

    // 7. Cập nhật Vật phẩm rơi & Lực hút Nam châm
    _updateDrops(dt);

    // 8. Cập nhật Hạt vỡ & Chữ bay
    debris.removeWhere((p) => p.update(dt));
    floatingTexts.removeWhere((t) => t.update(dt));

    notifyListeners();
  }

  void _handleBallBorderCollision() {
    final t = player.transform;
    final r = player.radius;

    // Giữ quả cầu chỉ nảy bên trong giới hạn của bức ảnh Pixel (không bay ra ngoài)
    final double minX;
    final double maxX;
    final double minY;
    final double maxY;

    if (isGridBuilt) {
      minX = gridStartX + r;
      maxX = gridStartX + level.cols * gridBlockSize - r;
      minY = gridStartY + r;
      maxY = gridStartY + level.rows * gridBlockSize - r;
    } else {
      minX = r;
      maxX = arenaSize.width - r;
      minY = 45 + r;
      maxY = arenaSize.height - 10 - r;
    }

    if (t.x <= minX) {
      t.x = minX;
      t.vx = t.vx.abs();
    } else if (t.x >= maxX) {
      t.x = maxX;
      t.vx = -t.vx.abs();
    }

    if (t.y <= minY) {
      t.y = minY;
      t.vy = t.vy.abs();
    } else if (t.y >= maxY) {
      t.y = maxY;
      t.vy = -t.vy.abs();
    }
  }

  void _handleBallBlockCollision() {
    final pt = player.transform;
    final r = player.radius;

    for (final block in blocks) {
      if (block.health!.isDestroyed) continue;

      final rect = block.transform.rect;
      // Tìm điểm gần nhất trên hình chữ nhật tới tâm quả bóng
      final nearestX = pt.x.clamp(rect.left, rect.right);
      final nearestY = pt.y.clamp(rect.top, rect.bottom);

      final dx = pt.x - nearestX;
      final dy = pt.y - nearestY;
      final distSq = dx * dx + dy * dy;

      if (distSq < r * r) {
        // Có va chạm với khối block tường!
        final overlapX = (r - dx.abs()).clamp(0.0, r);
        final overlapY = (r - dy.abs()).clamp(0.0, r);

        if (overlapX < overlapY) {
          // Va chạm theo phương ngang (Trái hoặc Phải)
          if (dx < 0) {
            // Bóng ở bên trái khối, đập vào mặt trái -> nảy sang trái
            pt.vx = -pt.vx.abs();
            pt.x = rect.left - r - 0.1;
          } else {
            // Bóng ở bên phải khối, đập vào mặt phải -> nảy sang phải
            pt.vx = pt.vx.abs();
            pt.x = rect.right + r + 0.1;
          }
        } else {
          // Va chạm theo phương dọc (Trên hoặc Dưới)
          if (dy < 0) {
            // Bóng ở phía trên khối, đập vào mặt trên -> nảy lên trên
            pt.vy = -pt.vy.abs();
            pt.y = rect.top - r - 0.1;
          } else {
            // Bóng ở phía dưới khối, đập vào mặt dưới -> nảy xuống dưới
            pt.vy = pt.vy.abs();
            pt.y = rect.bottom + r + 0.1;
          }
        }

        // Gây sát thương va chạm
        double collisionDmg = totalDamage * 0.8;
        if (race.type == RaceType.yeti) {
          block.elementAffinity?.applyFrost(3.0);
          collisionDmg *= 1.35;
        }
        _damageBlock(block, collisionDmg, 'VA CHẠM');
        break; // Mỗi frame xử lý 1 va chạm chính
      }
    }
  }

  void _handleWeaponAttacks(double dt) {
    final center = player.transform.position;
    final wAngle = player.weaponAngle;
    final wRange = totalWeaponRange;

    switch (role.type) {
      case RoleType.warrior:
        // Đại kiếm xoay quanh khối cầu
        final swordTip = Offset(
          center.dx + cos(wAngle) * wRange,
          center.dy + sin(wAngle) * wRange,
        );
        _checkMeleeLineCollision(center, swordTip, totalDamage, dt, 'CHÉM');
        break;

      case RoleType.farmer:
        // Liềm gặt quét cung rộng
        final scytheTip = Offset(
          center.dx + cos(wAngle) * wRange,
          center.dy + sin(wAngle) * wRange,
        );
        _checkMeleeLineCollision(center, scytheTip, totalDamage * 0.9, dt, 'GẶT');
        break;

      case RoleType.lumberjack:
        // Rìu bổ nặng theo chu kỳ
        final axeTip = Offset(
          center.dx + cos(wAngle) * wRange,
          center.dy + sin(wAngle) * wRange,
        );
        _checkMeleeLineCollision(center, axeTip, totalDamage * 1.6, dt, 'BỔ RÌU');
        break;

      case RoleType.archer:
        // Cung thủ tự bắn mũi tên theo nhịp
        if (player.attackCooldown <= 0) {
          player.attackCooldown = 1.0 / totalAttackSpeed;
          final arrowVx = cos(wAngle) * 380.0;
          final arrowVy = sin(wAngle) * 380.0;
          arrows.add(ArrowEntity(
            id: 'arrow_${DateTime.now().millisecondsSinceEpoch}',
            transform: TransformComponent(
              x: center.dx,
              y: center.dy,
              vx: arrowVx,
              vy: arrowVy,
              width: 14,
              height: 14,
            ),
            damage: totalDamage * 0.85,
          ));
        }
        break;

      case RoleType.fisherman:
        // Người đánh cá phóng cần câu giật kéo
        if (player.attackCooldown <= 0) {
          player.attackCooldown = 1.2 / totalAttackSpeed;
          final hookVx = cos(wAngle) * 320.0;
          final hookVy = sin(wAngle) * 320.0;
          hooks.add(HookEntity(
            id: 'hook_${DateTime.now().millisecondsSinceEpoch}',
            transform: TransformComponent(
              x: center.dx,
              y: center.dy,
              vx: hookVx,
              vy: hookVy,
              width: 12,
              height: 12,
            ),
            damage: totalDamage * 1.1,
            origin: center,
          ));
        }
        break;
    }
  }

  void _checkMeleeLineCollision(
      Offset start, Offset end, double dmg, double dt, String hitLabel) {
    for (final block in blocks) {
      if (block.health!.isDestroyed) continue;
      final rect = block.transform.rect;
      if (_lineIntersectsRect(start, end, rect)) {
        _damageBlock(block, dmg * dt * 4.0, hitLabel);
      }
    }
  }

  bool _lineIntersectsRect(Offset p1, Offset p2, Rect rect) {
    if (rect.contains(p1) || rect.contains(p2)) return true;
    // Kiểm tra tâm rect cách đường thẳng bao xa
    final center = rect.center;
    final d = _distToSegment(center, p1, p2);
    return d <= rect.width / 2;
  }

  double _distToSegment(Offset p, Offset v, Offset w) {
    final l2 = (v.dx - w.dx) * (v.dx - w.dx) + (v.dy - w.dy) * (v.dy - w.dy);
    if (l2 == 0) return (p - v).distance;
    final t = (((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2)
        .clamp(0.0, 1.0);
    final projection = Offset(v.dx + t * (w.dx - v.dx), v.dy + t * (w.dy - v.dy));
    return (p - projection).distance;
  }

  void _updateProjectiles(double dt) {
    final double minX = isGridBuilt ? gridStartX : 0;
    final double maxX = isGridBuilt ? gridStartX + level.cols * gridBlockSize : arenaSize.width;
    final double minY = isGridBuilt ? gridStartY : 45;
    final double maxY = isGridBuilt ? gridStartY + level.rows * gridBlockSize : arenaSize.height;

    // Cập nhật tên bắn
    for (int i = arrows.length - 1; i >= 0; i--) {
      final arrow = arrows[i];
      arrow.update(dt);
      final aPos = arrow.transform.position;
      if (arrow.lifeTime <= 0 ||
          aPos.dx < minX || aPos.dx > maxX ||
          aPos.dy < minY || aPos.dy > maxY) {
        arrows.removeAt(i);
        continue;
      }
      // Va chạm với khối
      for (final block in blocks) {
        if (block.health!.isDestroyed) continue;
        if (block.transform.rect.contains(arrow.transform.position)) {
          _damageBlock(block, arrow.damage, 'BẮN TỈA');
          arrow.pierceCount--;
          if (arrow.pierceCount <= 0) {
            arrows.removeAt(i);
            break;
          }
        }
      }
    }

    // Cập nhật Móc câu
    for (int i = hooks.length - 1; i >= 0; i--) {
      final hook = hooks[i];
      hook.update(dt);
      final hPos = hook.transform.position;
      if (hPos.dx < minX || hPos.dx > maxX || hPos.dy < minY || hPos.dy > maxY) {
        hook.isReturning = true;
      }
      if (hook.isReturning &&
          (hook.transform.position - hook.origin).distance < 15) {
        hooks.removeAt(i);
        continue;
      }
      for (final block in blocks) {
        if (block.health!.isDestroyed) continue;
        if (block.transform.rect.contains(hook.transform.position)) {
          _damageBlock(block, hook.damage, 'MÓC GIẬT');
          hook.isReturning = true;
          break;
        }
      }
    }
  }

  void _updateMistZones(double dt) {
    for (int i = mistZones.length - 1; i >= 0; i--) {
      final mist = mistZones[i];
      if (mist.update(dt)) {
        mistZones.removeAt(i);
        continue;
      }
      // Gây DoT lên các khối trong bán kính sương mù
      for (final block in blocks) {
        if (block.health!.isDestroyed) continue;
        if ((block.transform.position - mist.center).distance <= mist.radius) {
          _damageBlock(block, mist.damagePerSec * dt, 'SƯƠNG MÙ');
        }
      }
    }
  }

  void _damageBlock(PixelBlock block, double dmg, String source) {
    if (block.health!.isDestroyed) return;

    // Áp dụng hiệu ứng Tộc Người Cá (Làm ướt)
    if (race.type == RaceType.merfolk) {
      block.elementAffinity?.applyWater(4.0);
    }

    // Áp dụng các Nguyên Tố Cơ Bản mà người chơi sở hữu
    if (ownedElements.contains(ElementType.fire)) {
      block.elementAffinity?.applyFire(3.2, totalDamage * 0.35);
      if (Random().nextDouble() < 0.20) {
        _triggerFireBurst(block);
      }
    }
    if (ownedElements.contains(ElementType.frost)) {
      block.elementAffinity?.applyFrost(4.0);
    }
    if (ownedElements.contains(ElementType.poison)) {
      block.elementAffinity?.applyPoison(4.5, totalDamage * 0.25);
    }
    if (ownedElements.contains(ElementType.water)) {
      block.elementAffinity?.applyWater(5.0);
    }
    if (ownedElements.contains(ElementType.lightning)) {
      block.elementAffinity?.applyShock(1.5);
      if (Random().nextDouble() < 0.30) {
        _triggerLightningBolt(block);
      }
    }

    // Nếu khối đang bị đóng băng (Frozen): Nhận thêm 50% sát thương
    if (block.elementAffinity?.isFrozen ?? false) {
      dmg *= 1.5;
    }

    // Kích hoạt Sương Mù nếu có Dung Hợp Mist
    if (activeFusions.contains(ElementType.mist) && Random().nextDouble() < 0.08) {
      mistZones.add(MistZone(center: block.transform.position));
    }

    // Kích hoạt Tia sét giật chuỗi nếu có Chain Lightning
    if (activeFusions.contains(ElementType.chainLightning) &&
        (block.elementAffinity?.isSoaked ?? false)) {
      _triggerChainLightning(block);
    }

    // Chớp sáng trắng khi bị đánh trúng & Rung cực nhẹ (tinh tế, không gây nhức mắt)
    block.hitFlashTimer = 0.08;
    screenShake = max(screenShake, 0.5);
    AudioService.playHit();

    final justDestroyed = block.health!.takeDamage(dmg);

    if (justDestroyed) {
      _onBlockDestroyed(block);
    }
  }

  void _triggerFireBurst(PixelBlock origin) {
    floatingTexts.add(FloatingText(
      text: '🔥 HỎA NỔ!',
      x: origin.transform.x,
      y: origin.transform.y - 12,
      color: Colors.deepOrangeAccent,
    ));
    for (final b in blocks) {
      if (b == origin || b.health!.isDestroyed) continue;
      if ((b.transform.position - origin.transform.position).distance < 60) {
        b.health!.takeDamage(totalDamage * 0.5);
        b.elementAffinity?.applyFire(2.5, totalDamage * 0.25);
      }
    }
  }

  void _triggerLightningBolt(PixelBlock target) {
    AudioService.playLightning();
    lightningArcs.add(LightningArc.createZigzag(
      player.transform.position,
      target.transform.position,
      Colors.amberAccent,
    ));
    floatingTexts.add(FloatingText(
      text: '⚡ LÔI ĐIỆN!',
      x: target.transform.x,
      y: target.transform.y - 10,
      color: Colors.amberAccent,
    ));
    // Sét lan sang 1 khối lân cận
    for (final b in blocks) {
      if (b == target || b.health!.isDestroyed) continue;
      if ((b.transform.position - target.transform.position).distance < 75) {
        lightningArcs.add(LightningArc.createZigzag(
          target.transform.position,
          b.transform.position,
          Colors.yellowAccent,
        ));
        b.health!.takeDamage(totalDamage * 0.7);
        b.elementAffinity?.applyShock(1.5);
        break;
      }
    }
  }

  void _triggerChainLightning(PixelBlock origin) {
    int chainCount = 0;
    AudioService.playLightning();
    for (final b in blocks) {
      if (b == origin || b.health!.isDestroyed) continue;
      if ((b.transform.position - origin.transform.position).distance < 75) {
        lightningArcs.add(LightningArc.createZigzag(
          origin.transform.position,
          b.transform.position,
          Colors.yellowAccent,
        ));
        b.health!.takeDamage(totalDamage * 0.9);
        floatingTexts.add(FloatingText(
          text: '⚡ SÉT!',
          x: b.transform.x,
          y: b.transform.y,
          color: Colors.yellowAccent,
        ));
        chainCount++;
        if (chainCount >= 5) break;
      }
    }
  }

  void _onBlockDestroyed(PixelBlock block) {
    brokenBlocksCount++;
    completionPercent = (brokenBlocksCount / totalBlocksCount).clamp(0.0, 1.0);

    // Kích hoạt Rung giật màn hình vừa vặn (2.5px), sóng xung kích và âm thanh nổ vỡ
    screenShake = max(screenShake, 2.5);
    AudioService.playBlockBreak();
    shockwaves.add(ShockwaveRing(
      center: block.transform.position,
      color: block.memeColor,
    ));
    onBlockDestroyedEffect?.call();

    // 1. Tạo các hạt vỡ nổ tung (Debris) nhiều và xoay sống động
    final rng = Random();
    for (int i = 0; i < 14; i++) {
      final pAngle = rng.nextDouble() * 2 * pi;
      final pSpeed = rng.nextDouble() * 160 + 50;
      debris.add(PixelDebris(
        x: block.transform.x,
        y: block.transform.y,
        vx: cos(pAngle) * pSpeed,
        vy: sin(pAngle) * pSpeed,
        size: rng.nextDouble() * 5 + 3,
        color: (i % 3 == 0) ? Colors.white : block.memeColor,
        rotSpeed: (rng.nextDouble() - 0.5) * 14.0,
        isSparkle: i % 4 == 0,
      ));
    }

    // 2. Rơi Vàng & Ngọc EXP (Nông dân được +25% Bội thu, Người lùn +30% Vàng)
    double goldVal = 10.0 * (1.0 + race.goldBonus);
    double expVal = 15.0 * (1.0 + race.expBonus);
    if (role.type == RoleType.farmer) {
      goldVal *= 1.25;
      expVal *= 1.25;
    }

    drops.add(DropItem(
      id: 'gold_${DateTime.now().microsecondsSinceEpoch}',
      transform: TransformComponent(
        x: block.transform.x,
        y: block.transform.y,
        vx: (rng.nextDouble() - 0.5) * 80,
        vy: (rng.nextDouble() - 0.5) * 80,
      ),
      type: DropType.gold,
      value: goldVal,
    ));

    drops.add(DropItem(
      id: 'exp_${DateTime.now().microsecondsSinceEpoch}',
      transform: TransformComponent(
        x: block.transform.x,
        y: block.transform.y,
        vx: (rng.nextDouble() - 0.5) * 80,
        vy: (rng.nextDouble() - 0.5) * 80,
      ),
      type: DropType.exp,
      value: expVal,
    ));

    // Hiển thị text bay sảng khoái
    floatingTexts.add(FloatingText(
      text: '+${goldVal.toInt()}G',
      x: block.transform.x,
      y: block.transform.y - 10,
      color: Colors.amber,
    ));

    // Kiểm tra chiến thắng màn chơi khi phá sạch hoặc đạt 100%
    if (brokenBlocksCount >= totalBlocksCount) {
      isLevelCompleted = true;
      AudioService.playVictory();
      onVictory?.call();
    }
  }

  void _updateDrops(double dt) {
    final pCenter = player.transform.position;
    final mRange = magnetRange;

    for (int i = drops.length - 1; i >= 0; i--) {
      final drop = drops[i];
      final dPos = drop.transform.position;
      final dist = (pCenter - dPos).distance;

      // Hút về phía người chơi nếu nằm trong vùng nam châm
      if (dist <= mRange) {
        final dirX = (pCenter.dx - dPos.dx) / (dist > 0 ? dist : 1);
        final dirY = (pCenter.dy - dPos.dy) / (dist > 0 ? dist : 1);
        final pullSpeed = 420.0;
        drop.transform.vx = dirX * pullSpeed;
        drop.transform.vy = dirY * pullSpeed;
      }

      drop.update(dt);

      // Giữ vật phẩm bên trong khung bức ảnh
      if (isGridBuilt) {
        final gridWidth = level.cols * gridBlockSize;
        final gridHeight = level.rows * gridBlockSize;
        drop.transform.x = drop.transform.x.clamp(gridStartX + 4, gridStartX + gridWidth - 4);
        drop.transform.y = drop.transform.y.clamp(gridStartY + 4, gridStartY + gridHeight - 4);
      }

      // Thu thập thành công
      if (dist <= player.radius + 6) {
        if (drop.type == DropType.gold) {
          gold += drop.value.toInt();
        } else {
          addExp(drop.value);
        }
        AudioService.playCoinCollect();
        drops.removeAt(i);
      } else if (drop.lifeTime <= 0) {
        drops.removeAt(i);
      }
    }
  }

  void addExp(double amount) {
    exp += amount;
    if (exp >= expToNextLevel) {
      exp -= expToNextLevel;
      characterLevel++;
      expToNextLevel = (expToNextLevel * 1.35).roundToDouble();
      AudioService.playLevelUp();
      onLevelUp?.call();
    }
  }

  // Đẩy bóng (Boost / Dash) khi người chơi chạm kéo
  void boostBall(Offset flingVelocity) {
    player.transform.vx += flingVelocity.dx * 0.4;
    player.transform.vy += flingVelocity.dy * 0.4;
    // Giới hạn vận tốc tối đa
    final curSpeed = sqrt(player.transform.vx * player.transform.vx +
        player.transform.vy * player.transform.vy);
    final maxSpeed = 480.0;
    if (curSpeed > maxSpeed) {
      player.transform.vx = (player.transform.vx / curSpeed) * maxSpeed;
      player.transform.vy = (player.transform.vy / curSpeed) * maxSpeed;
    }
  }

  // Thêm nguyên tố mới khi lên cấp
  void addElement(ElementType element) {
    ownedElements.add(element);
    // Tự động triệu hồi thêm tinh linh theo hệ nguyên tố đó nếu chưa đủ 4 tinh linh
    if (spirits.length < 4) {
      summonSpirit(element);
    }
    notifyListeners();
  }

  void upgradeSpinSpeed() {
    spinUpgradeLevel++;
    player.spinMultiplier = weaponSpinSpeedMultiplier;
    floatingTexts.add(FloatingText(
      text: '🌀 CUỒNG VŨ XOAY!',
      x: player.transform.x,
      y: player.transform.y - 15,
      color: Colors.cyanAccent,
    ));
    notifyListeners();
  }

  void summonSpirit([ElementType? el]) {
    spiritUpgradeLevel++;
    final elementList = [
      ElementType.fire,
      ElementType.frost,
      ElementType.lightning,
      ElementType.wind,
      ElementType.poison,
    ];
    final spiritEl = el ?? elementList[(spirits.length) % elementList.length];
    final colors = {
      ElementType.fire: Colors.deepOrangeAccent,
      ElementType.frost: Colors.cyanAccent,
      ElementType.lightning: Colors.amberAccent,
      ElementType.wind: Colors.tealAccent,
      ElementType.poison: Colors.lightGreenAccent,
    };

    spirits.add(OrbitingSpirit(
      id: 'spirit_${DateTime.now().millisecondsSinceEpoch}',
      element: spiritEl,
      orbitRadius: 46.0 + spirits.length * 6.0,
      angle: 0.0,
      orbitSpeed: 3.6 + spirits.length * 0.4,
      color: colors[spiritEl] ?? Colors.cyanAccent,
    ));
    // Chia đều góc xoay quanh quả cầu
    for (int i = 0; i < spirits.length; i++) {
      spirits[i].angle = i * (2 * pi / spirits.length);
    }
    floatingTexts.add(FloatingText(
      text: '🧚 THÊM TINH LINH!',
      x: player.transform.x,
      y: player.transform.y - 20,
      color: Colors.amberAccent,
    ));
    notifyListeners();
  }

  // Thực hiện Dung hợp nguyên tố
  bool fuseElements(ElementType a, ElementType b) {
    final fusion = ElementData.findFusion(a, b);
    if (fusion != null) {
      activeFusions.add(fusion.type);
      notifyListeners();
      return true;
    }
    return false;
  }

  // Nâng cấp tại Lò rèn
  int getUpgradeCost(int currentLevel) {
    int baseCost = 40 + currentLevel * 30;
    // Giảm giá người lùn (-25%)
    if (race.type == RaceType.dwarf) {
      baseCost = (baseCost * 0.75).round();
    }
    return baseCost;
  }

  bool upgradeDamage() {
    final cost = getUpgradeCost(damageUpgradeLevel);
    if (gold >= cost) {
      gold -= cost;
      damageUpgradeLevel++;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool upgradeSpeed() {
    final cost = getUpgradeCost(speedUpgradeLevel);
    if (gold >= cost) {
      gold -= cost;
      speedUpgradeLevel++;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool upgradeRange() {
    final cost = getUpgradeCost(rangeUpgradeLevel);
    if (gold >= cost) {
      gold -= cost;
      rangeUpgradeLevel++;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool upgradeBounce() {
    final cost = getUpgradeCost(bounceUpgradeLevel);
    if (gold >= cost) {
      gold -= cost;
      bounceUpgradeLevel++;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool upgradeMagnet() {
    final cost = getUpgradeCost(magnetUpgradeLevel);
    if (gold >= cost) {
      gold -= cost;
      magnetUpgradeLevel++;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool upgradeSpin() {
    final cost = getUpgradeCost(spinUpgradeLevel);
    if (gold >= cost) {
      gold -= cost;
      upgradeSpinSpeed();
      return true;
    }
    return false;
  }

  bool upgradeSpirit() {
    final cost = getUpgradeCost(spiritUpgradeLevel) + 25;
    if (gold >= cost && spirits.length < 4) {
      gold -= cost;
      summonSpirit();
      return true;
    }
    return false;
  }
}
