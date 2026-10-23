import 'dart:math';

import 'package:flutter/material.dart';

import '../models/ecs.dart';
import '../models/character.dart';
import '../models/element.dart';
import '../models/pixel_art_data.dart';
import '../models/game_entities.dart';
import '../core/audio_service.dart';
import '../core/bounded_list.dart';

class GameEngine extends ChangeNotifier {
  late PlayerBall player;
  RoleInfo role;
  RaceInfo race;
  MemeLevel level;
  Size arenaSize = const Size(400, 600);

  List<PixelBlock> blocks = [];
  static const maxDebris = 160;
  static const maxLightningArcs = 24;
  static const maxShockwaves = 16;
  static const maxFloatingTexts = 12;
  static const maxDrops = 160;
  static const maxChainTargets = 24;

  final bool isEndless;
  int endlessWave = 1;
  double elapsedTime = 0;
  double _waveWait = 0;
  double _cameraSettle = 0;
  bool get isExpanding => isEndless && isLevelCompleted;
  double get cameraScale => 1 + _cameraSettle * 0.06;
  final ValueNotifier<int> hudRevision = ValueNotifier(0);
  double _hudTimer = 0;
  final Random _random = Random();
  double _hitSoundCooldown = 0;
  double _breakSoundCooldown = 0;
  double _coinSoundCooldown = 0;
  double _fusionCooldown = 0;
  int _particlesThisFrame = 0;
  int _breakRingsThisFrame = 0;

  final List<ArrowEntity> arrows = BoundedList(24);
  final List<HookEntity> hooks = BoundedList(8);
  List<DropItem> drops = [];
  final List<PixelDebris> debris = BoundedList(maxDebris);
  final List<FloatingText> floatingTexts = BoundedList(maxFloatingTexts);
  final List<MistZone> mistZones = BoundedList(3);
  final List<VoidVortexZone> vortexZones = BoundedList(2);
  final List<ShockwaveRing> shockwaves = BoundedList(maxShockwaves);
  List<OrbitingSpirit> spirits = [];
  final List<LightningArc> lightningArcs = BoundedList(maxLightningArcs);

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

  // Cooldown cho các hiệu ứng nguyên tố (tránh spam quá nhiều)
  double _fireBurstCooldown = 0.0;
  double _lightningCooldown = 0.0;
  double _firestormTimer = 0.0;
  double _permafrostCooldown = 0.0;
  double _superconductorCooldown = 0.0;
  double _explosiveGasCooldown = 0.0;
  double _acidMeltCooldown = 0.0;
  double _avalancheCooldown = 0.0;
  double _voidVortexCooldown = 0.0;
  double _lavaBurstCooldown = 0.0;

  double get weaponSpinSpeedMultiplier =>
      (1.0 + spinUpgradeLevel * 0.4) *
      (ownedElements.contains(ElementType.wind) ? 1.25 : 1.0);

  final Map<String, double> _elementHitTimers = {};
  double _mistCooldown = 0;
  bool get isFirestormActive => _firestormTimer > 0;

  // Lực hút nam châm cơ bản
  double get magnetRange => 80.0 + (magnetUpgradeLevel * 25.0);

  // Sát thương tổng thể
  double get totalDamage {
    final base =
        (role.baseDamage + damageUpgradeLevel * 4.0) * race.damageMultiplier;
    return base * (isEndless ? 1 + log(endlessWave) * 0.18 : 1);
  }

  // Tốc độ đánh tổng thể
  double get totalAttackSpeed {
    return role.attackSpeed *
        race.speedMultiplier *
        (1.0 + speedUpgradeLevel * 0.15);
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
    this.isEndless = false,
  }) {
    if (isEndless) level = MemeLevel.endlessWave(endlessWave);
    _initEngine();
  }

  double gridStartX = 0;
  double gridStartY = 0;
  double gridBlockSize = 28;

  bool isGridBuilt = false;

  void _initEngine() {
    // Tốc độ nảy cơ bản
    double speed = 160.0 * (1.0 + race.bounceBonus + bounceUpgradeLevel * 0.1);
    final randomAngle = _random.nextDouble() * 2 * pi; // Bất kỳ góc nào 360 độ
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
  }

  void resize(Size newSize, {bool notify = true}) {
    if (arenaSize == newSize && isGridBuilt) return;
    final isFirstSetup = !isGridBuilt;
    final oldWidth = level.cols * gridBlockSize;
    final oldHeight = level.rows * gridBlockSize;
    final oldCenter = Offset(
      gridStartX + oldWidth / 2,
      gridStartY + oldHeight / 2,
    );
    arenaSize = newSize;

    if (isFirstSetup) {
      isGridBuilt = true;
      _buildPixelGrid();
    } else {
      // Điều chỉnh lại vị trí grid khi thay đổi kích thước mà vẫn giữ nguyên vị trí bóng trong không gian
      final cols = level.cols;
      final rows = level.rows;
      const padding = 10.0;
      final availableWidth = arenaSize.width - padding * 2;
      const topOffset = 42.0;
      final availableHeight = (arenaSize.height - topOffset - 48.0).clamp(
        100.0,
        2000.0,
      );
      final blockSizeByWidth = availableWidth / cols;
      final blockSizeByHeight = availableHeight / rows;
      final blockSize = min(
        blockSizeByWidth,
        blockSizeByHeight,
      ).clamp(1.0, 24.0);
      gridBlockSize = blockSize;
      final gridWidth = cols * blockSize;
      final gridHeight = rows * blockSize;
      gridStartX = (arenaSize.width - gridWidth) / 2;
      gridStartY = topOffset + (availableHeight - gridHeight) / 2;

      final newCenter = Offset(
        gridStartX + gridWidth / 2,
        gridStartY + gridHeight / 2,
      );
      final offsetFromCenter = player.transform.position - oldCenter;
      player.transform.position =
          newCenter + offsetFromCenter * (gridWidth / oldWidth);
      player.radius =
          blockSize *
          (isEndless ? min(0.48, 0.32 + (endlessWave - 1) * 0.015) : 0.32);

      for (final block in blocks) {
        block.transform.x = gridStartX + block.col * blockSize + blockSize / 2;
        block.transform.y = gridStartY + block.row * blockSize + blockSize / 2;
        block.transform.width = blockSize;
        block.transform.height = blockSize;
      }
    }
    if (notify) notifyListeners();
  }

  void _buildPixelGrid() {
    blocks.clear();
    final cols = level.cols;
    final rows = level.rows;

    const padding = 10.0;
    final availableWidth = arenaSize.width - padding * 2;
    const topOffset = 42.0;
    final availableHeight = (arenaSize.height - topOffset - 48.0).clamp(
      100.0,
      2000.0,
    );

    final blockSizeByWidth = availableWidth / cols;
    final blockSizeByHeight = availableHeight / rows;
    final blockSize = min(blockSizeByWidth, blockSizeByHeight).clamp(1.0, 24.0);
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
    player.radius =
        blockSize *
        (isEndless ? min(0.48, 0.32 + (endlessWave - 1) * 0.015) : 0.32);

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

        final isCenterEmpty =
            (r == centerRow1 || r == centerRow2) &&
            (c == centerCol1 || c == centerCol2);

        final block = PixelBlock(
          id: 'block_${r}_$c',
          transform: TransformComponent(
            x: bx,
            y: by,
            width: blockSize,
            height: blockSize,
          ),
          health: HealthComponent(maxHp: _calculateBlockHp(r, c, rows, cols)),
          elementAffinity: ElementAffinityComponent(),
          render: RenderComponent(primaryColor: const Color(0xFF4A5568)),
          col: c,
          row: r,
          memeColor: memeColor,
          isCenterEmpty: isCenterEmpty,
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

  double _calculateBlockHp(int row, int col, int totalRows, int totalCols) {
    // HP cơ sở cao hơn để trận đấu kéo dài hơn
    double baseHp = isEndless
        ? 50 * (1 + log(endlessWave) * 0.35)
        : 50.0 + (level.id - 1) * 20.0;
    // Tính khoảng cách từ tâm (khối ở rìa ngoài trâu hơn)
    final centerRow = (totalRows - 1) / 2.0;
    final centerCol = (totalCols - 1) / 2.0;
    final distance = Offset(row - centerRow, col - centerCol).distance;
    final innerDistance = sqrt(
      2.5,
    ); // First intact tile outside the 2x2 chamber.
    final outerDistance = Offset(centerRow, centerCol).distance;
    final progress =
        ((distance - innerDistance) / max(1.0, outerDistance - innerDistance))
            .clamp(0.0, 1.0);
    final hpMultiplier = 1.0 + progress * 1.5;
    return baseHp * hpMultiplier;
  }

  int get actualBrokenBlocksCount =>
      blocks.where((b) => b.health!.isDestroyed && !b.isCenterEmpty).length;

  void _updateCompletion() {
    brokenBlocksCount = actualBrokenBlocksCount;
    completionPercent = (brokenBlocksCount / totalBlocksCount).clamp(0.0, 1.0);
    if (brokenBlocksCount >= totalBlocksCount && !isLevelCompleted) {
      isLevelCompleted = true;
      if (isEndless) {
        _waveWait = 1.4;
      } else {
        AudioService.playVictory();
        onVictory?.call();
      }
    }
  }

  void update(double dt) {
    if (!dt.isFinite || dt <= 0 || !isGridBuilt) return;
    final elapsed = min(dt, 0.1);
    elapsedTime += elapsed;
    _hudTimer += elapsed;
    _cameraSettle = max(0, _cameraSettle - elapsed * 1.5);
    _particlesThisFrame = 0;
    _breakRingsThisFrame = 0;
    if (isExpanding) {
      _waveWait -= elapsed;
      _updateCosmetics(elapsed);
      if (_waveWait <= 0) _advanceEndlessWave();
    } else if (!isLevelCompleted) {
      final steps = (elapsed / (1 / 120)).ceil();
      for (int i = 0; i < steps && !isLevelCompleted; i++) {
        _step(elapsed / steps);
      }
    }
    if (_hudTimer >= 0.1) {
      _hudTimer = 0;
      hudRevision.value++;
    }
    _processLevelUp();
    notifyListeners();
  }

  void _updateCosmetics(double dt) {
    shockwaves.removeWhere((effect) => effect.update(dt));
    lightningArcs.removeWhere((effect) => effect.update(dt));
    debris.removeWhere((effect) => effect.update(dt));
    floatingTexts.removeWhere((effect) => effect.update(dt));
  }

  void _advanceEndlessWave() {
    // Collect outstanding rewards before replacing the board.
    for (final drop in drops) {
      if (drop.type == DropType.gold) {
        gold += drop.value.toInt();
      } else {
        addExp(drop.value);
      }
    }
    drops.clear();
    arrows.clear();
    hooks.clear();
    debris.clear();
    floatingTexts.clear();
    mistZones.clear();
    vortexZones.clear();
    shockwaves.clear();
    lightningArcs.clear();
    _elementHitTimers.clear();
    _firestormTimer = 0;
    _fireBurstCooldown = _lightningCooldown = _mistCooldown = 0;
    _permafrostCooldown = _superconductorCooldown = _explosiveGasCooldown = 0;
    _acidMeltCooldown = _avalancheCooldown = _voidVortexCooldown =
        _lavaBurstCooldown = 0;
    _fusionCooldown = 0.6;
    screenShake = 0;
    shakeOffset = Offset.zero;
    player.trail.clear();
    for (final spirit in spirits) {
      spirit.trail.clear();
    }
    endlessWave++;
    level = MemeLevel.endlessWave(endlessWave);
    isLevelCompleted = false;
    _buildPixelGrid();
    _cameraSettle = 1;
    hudRevision.value++;
  }

  // A uniform grid makes each collision query local instead of scanning the board.
  Iterable<PixelBlock> _blocksInRect(Rect rect) sync* {
    if (blocks.isEmpty || !isGridBuilt) return;
    final firstCol = max(0, ((rect.left - gridStartX) / gridBlockSize).floor());
    final lastCol = min(
      level.cols - 1,
      ((rect.right - gridStartX) / gridBlockSize).floor(),
    );
    final firstRow = max(0, ((rect.top - gridStartY) / gridBlockSize).floor());
    final lastRow = min(
      level.rows - 1,
      ((rect.bottom - gridStartY) / gridBlockSize).floor(),
    );
    for (int row = firstRow; row <= lastRow; row++) {
      for (int col = firstCol; col <= lastCol; col++) {
        final block = blocks[row * level.cols + col];
        if (!block.health!.isDestroyed) yield block;
      }
    }
  }

  Iterable<PixelBlock> _blocksNear(Offset center, double radius) =>
      _blocksInRect(Rect.fromCircle(center: center, radius: radius)).where(
        (block) =>
            (block.transform.position - center).distanceSquared <=
            radius * radius,
      );

  @override
  void dispose() {
    hudRevision.dispose();
    super.dispose();
  }

  void _step(double dt) {
    if (isLevelCompleted || !isGridBuilt || dt <= 0) return;
    dt = min(dt, 0.05);
    _elementHitTimers.updateAll((key, value) => max(0.0, value - dt));
    _mistCooldown = max(0.0, _mistCooldown - dt);
    _fusionCooldown = max(0.0, _fusionCooldown - dt);
    _hitSoundCooldown = max(0.0, _hitSoundCooldown - dt);
    _breakSoundCooldown = max(0.0, _breakSoundCooldown - dt);
    _coinSoundCooldown = max(0.0, _coinSoundCooldown - dt);

    // Giảm dần độ rung màn hình rất nhanh (Screen Shake decay)
    if (screenShake > 0) {
      screenShake = max(0.0, screenShake - dt * 38.0);
      final rng = _random;
      shakeOffset = Offset(
        (rng.nextDouble() - 0.5) * 2 * screenShake,
        (rng.nextDouble() - 0.5) * 2 * screenShake,
      );
    } else {
      shakeOffset = Offset.zero;
    }

    // Giảm cooldown các hiệu ứng nguyên tố
    if (_fireBurstCooldown > 0) _fireBurstCooldown -= dt;
    if (_lightningCooldown > 0) _lightningCooldown -= dt;
    if (_permafrostCooldown > 0) _permafrostCooldown -= dt;
    if (_superconductorCooldown > 0) _superconductorCooldown -= dt;
    if (_explosiveGasCooldown > 0) _explosiveGasCooldown -= dt;
    if (_acidMeltCooldown > 0) _acidMeltCooldown -= dt;
    if (_avalancheCooldown > 0) _avalancheCooldown -= dt;
    if (_voidVortexCooldown > 0) _voidVortexCooldown -= dt;
    if (_lavaBurstCooldown > 0) _lavaBurstCooldown -= dt;
    if (_firestormTimer > 0) {
      _firestormTimer -= dt;
      _updateFirestormAura(dt);
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
    _handleBallBorderCollision();

    // 2. Cập nhật Tinh Linh Hộ Vệ xoay quanh bóng
    final pCenter = player.transform.position;
    for (final spirit in spirits) {
      spirit.update(dt, pCenter);
      final sPos = spirit.getPosition(pCenter);
      for (final b in _blocksInRect(
        Rect.fromCircle(center: sPos, radius: spirit.size),
      )) {
        if (b.transform.rect.inflate(spirit.size * 0.5).contains(sPos)) {
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
    for (final vortex in vortexZones) {
      vortex.life -= dt;
      vortex.pulse -= dt;
      if (vortex.pulse > 0) continue;
      vortex.pulse += 0.5;
      for (final block in _blocksNear(vortex.center, 90).take(12)) {
        lightningArcs.add(
          LightningArc.createZigzag(
            vortex.center,
            block.transform.position,
            Colors.purpleAccent,
          ),
        );
        block.elementAffinity?.applyShock(1.0);
        if (block.takeDamage(totalDamage * 0.22)) _onBlockDestroyed(block);
      }
      for (final drop in drops) {
        final offset = vortex.center - drop.transform.position;
        if (offset.distance > 1 && offset.distance < 110) {
          drop.transform.vx = offset.dx * 3;
          drop.transform.vy = offset.dy * 3;
        }
      }
    }
    vortexZones.removeWhere((zone) => zone.life <= 0);

    // 6. Cập nhật các khối Pixel
    for (final b in blocks) {
      if (!b.health!.isDestroyed) {
        b.update(dt);
        if (b.health!.isDestroyed) {
          _onBlockDestroyed(b);
        }
      }
    }

    // 7. Cập nhật Vật phẩm rơi & Lực hút Nam châm
    _updateDrops(dt);

    // 8. Cập nhật Hạt vỡ & Chữ bay
    debris.removeWhere((p) => p.update(dt));
    floatingTexts.removeWhere((t) => t.update(dt));

    // 9. Đồng bộ chuẩn xác 100% thanh tiến trình & kiểm tra chiến thắng
    _updateCompletion();
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

    for (final block in _blocksInRect(
      Rect.fromCircle(center: pt.position, radius: r),
    )) {
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
        double collisionDmg =
            totalDamage *
            0.8 *
            (ownedElements.contains(ElementType.earth) ? 1.2 : 1.0);
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
        _checkMeleeLineCollision(
          center,
          scytheTip,
          totalDamage * 0.9,
          dt,
          'GẶT',
        );
        break;

      case RoleType.lumberjack:
        // Rìu bổ nặng theo chu kỳ
        final axeTip = Offset(
          center.dx + cos(wAngle) * wRange,
          center.dy + sin(wAngle) * wRange,
        );
        _checkMeleeLineCollision(
          center,
          axeTip,
          totalDamage * 1.6,
          dt,
          'BỔ RÌU',
        );
        break;

      case RoleType.archer:
        // Cung thủ tự bắn mũi tên theo nhịp
        if (player.attackCooldown <= 0) {
          player.attackCooldown = 1.0 / totalAttackSpeed;
          final arrowVx = cos(wAngle) * 380.0;
          final arrowVy = sin(wAngle) * 380.0;
          arrows.add(
            ArrowEntity(
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
            ),
          );
        }
        break;

      case RoleType.fisherman:
        // Cần câu quay quanh bóng quất mạnh vào các khối pixel
        final rodTip = Offset(
          center.dx + cos(wAngle) * wRange * 0.85,
          center.dy + sin(wAngle) * wRange * 0.85,
        );
        _checkMeleeLineCollision(
          center,
          rodTip,
          totalDamage * 1.0,
          dt,
          'QUẤT CẦU',
        );

        // Người đánh cá phóng cần câu giật kéo theo chu kỳ
        if (player.attackCooldown <= 0) {
          player.attackCooldown = 1.0 / totalAttackSpeed;
          final hookVx = cos(wAngle) * 360.0;
          final hookVy = sin(wAngle) * 360.0;
          hooks.add(
            HookEntity(
              id: 'hook_${DateTime.now().millisecondsSinceEpoch}',
              transform: TransformComponent(
                x: center.dx,
                y: center.dy,
                vx: hookVx,
                vy: hookVy,
                width: 12,
                height: 12,
              ),
              damage: totalDamage * 1.25,
              origin: center,
            ),
          );
        }
        break;
    }
  }

  void _checkMeleeLineCollision(
    Offset start,
    Offset end,
    double dmg,
    double dt,
    String hitLabel,
  ) {
    for (final block in _blocksInRect(Rect.fromPoints(start, end).inflate(2))) {
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
    final t =
        (((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2)
            .clamp(0.0, 1.0);
    final projection = Offset(
      v.dx + t * (w.dx - v.dx),
      v.dy + t * (w.dy - v.dy),
    );
    return (p - projection).distance;
  }

  void _updateProjectiles(double dt) {
    final double minX = isGridBuilt ? gridStartX : 0;
    final double maxX = isGridBuilt
        ? gridStartX + level.cols * gridBlockSize
        : arenaSize.width;
    final double minY = isGridBuilt ? gridStartY : 45;
    final double maxY = isGridBuilt
        ? gridStartY + level.rows * gridBlockSize
        : arenaSize.height;

    // Cập nhật tên bắn
    for (int i = arrows.length - 1; i >= 0; i--) {
      final arrow = arrows[i];
      arrow.update(dt);
      final t = arrow.transform;
      if (t.x <= minX + 10 || t.x >= maxX - 10) {
        t.x = t.x.clamp(minX + 10, maxX - 10);
        t.vx = t.x <= minX + 10 ? t.vx.abs() : -t.vx.abs();
      }
      if (t.y <= minY + 10 || t.y >= maxY - 10) {
        t.y = t.y.clamp(minY + 10, maxY - 10);
        t.vy = t.y <= minY + 10 ? t.vy.abs() : -t.vy.abs();
      }
      final aPos = arrow.transform.position;
      if (arrow.lifeTime <= 0 ||
          aPos.dx < minX ||
          aPos.dx > maxX ||
          aPos.dy < minY ||
          aPos.dy > maxY) {
        arrows.removeAt(i);
        continue;
      }
      // Va chạm với khối
      for (final block in _blocksInRect(
        Rect.fromCircle(center: arrow.transform.position, radius: 1),
      )) {
        if (block.transform.rect.contains(arrow.transform.position) &&
            arrow.hitBlocks.add(block.id)) {
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
      hook.origin = player.transform.position;
      hook.update(dt);
      final hPos = hook.transform.position;
      if (hPos.dx < minX ||
          hPos.dx > maxX ||
          hPos.dy < minY ||
          hPos.dy > maxY) {
        hook.isReturning = true;
        hook.transform.x = hook.transform.x.clamp(minX + 6, maxX - 6);
        hook.transform.y = hook.transform.y.clamp(minY + 6, maxY - 6);
      }
      if (hook.isReturning &&
          (hook.transform.position - hook.origin).distance < 15) {
        hooks.removeAt(i);
        continue;
      }
      for (final block in _blocksInRect(
        Rect.fromCircle(center: hook.transform.position, radius: 1),
      )) {
        if (block.transform.rect.contains(hook.transform.position) &&
            (hook.isReturning ? hook.returnHits : hook.outboundHits).add(
              block.id,
            )) {
          _damageBlock(block, hook.damage, 'MÓC GIẬT');
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
      for (final block in _blocksNear(mist.center, mist.radius)) {
        {
          _damageBlock(block, mist.damagePerSec * dt, 'SƯƠNG MÙ');
        }
      }
    }
  }

  void _damageBlock(PixelBlock block, double dmg, String source) {
    if (block.health!.isDestroyed) return;

    final triggerElements =
        source != 'SƯƠNG MÙ' &&
        source != 'TINH LINH' &&
        (_elementHitTimers[block.id] ?? 0) <= 0;
    if (triggerElements) {
      _elementHitTimers[block.id] = 0.25;
      // Áp dụng hiệu ứng Tộc Người Cá (Làm ướt)
      if (race.type == RaceType.merfolk) {
        block.elementAffinity?.applyWater(4.0);
      }

      // === ÁP DỤNG CÁC NGUYÊN TỐ CƠ BẢN (Đã cân bằng tỉ lệ & Cooldown) ===
      if (ownedElements.contains(ElementType.fire)) {
        block.elementAffinity?.applyFire(3.0, totalDamage * 0.25);
        // Hỏa Nổ: 5% tỉ lệ và cooldown 1.6s
        if (_fireBurstCooldown <= 0 && _random.nextDouble() < 0.05) {
          _triggerFireBurst(block);
          _fireBurstCooldown = 1.6;
        }
      }
      if (ownedElements.contains(ElementType.frost)) {
        block.elementAffinity?.applyFrost(4.0);
      }
      if (ownedElements.contains(ElementType.poison)) {
        block.elementAffinity?.applyPoison(4.5, totalDamage * 0.20);
      }
      if (ownedElements.contains(ElementType.water)) {
        block.elementAffinity?.applyWater(5.0);
      }
      if (ownedElements.contains(ElementType.lightning)) {
        block.elementAffinity?.applyShock(1.5);
        // Lôi Điện: Giảm tỉ lệ từ 30% xuống 6% và thêm cooldown 2.0s để không spam
        if (_lightningCooldown <= 0 && _random.nextDouble() < 0.06) {
          _triggerLightningBolt(block);
          _lightningCooldown = 2.0;
        }
      }

      // === CÁC DUNG HỢP NGUYÊN TỐ (FUSIONS) ===
      // 1. Sương Mù (Mist) — Hỏa + Thủy
      if (_fusionCooldown <= 0 &&
          activeFusions.contains(ElementType.mist) &&
          _mistCooldown <= 0 &&
          _random.nextDouble() < 0.06) {
        _fusionCooldown = 0.6;
        mistZones.add(
          MistZone(
            center: block.transform.position,
            damagePerSec: totalDamage * 0.45,
          ),
        );
        _mistCooldown = 2.5;
      }

      // 2. Nhiễm Điện (Chain Lightning) — Thủy + Lôi
      if (_fusionCooldown <= 0 &&
          activeFusions.contains(ElementType.chainLightning) &&
          _lightningCooldown <= 0 &&
          (block.elementAffinity?.isSoaked ?? false)) {
        _triggerChainLightning(block);
        _lightningCooldown = 2.5;
      }

      // 3. Bão Lửa (Firestorm) — Hỏa + Phong
      if (_fusionCooldown <= 0 &&
          activeFusions.contains(ElementType.firestorm) &&
          _firestormTimer <= 0 &&
          _random.nextDouble() < 0.08) {
        _triggerFirestorm();
      }

      // 4. Băng Vĩnh Cửu (Permafrost) — Thủy + Băng
      if (_fusionCooldown <= 0 &&
          activeFusions.contains(ElementType.permafrost) &&
          _permafrostCooldown <= 0 &&
          _random.nextDouble() < 0.08) {
        _triggerPermafrost(block);
        _permafrostCooldown = 3.5;
      }

      // 5. Siêu Dẫn (Superconductor) — Băng + Lôi
      if (_fusionCooldown <= 0 &&
          activeFusions.contains(ElementType.superconductor) &&
          _superconductorCooldown <= 0 &&
          (block.elementAffinity?.isFrozen ?? false)) {
        _triggerSuperconductor(block);
        _superconductorCooldown = 3.0;
      }

      // 6. Khí Nổ (Explosive Gas) — Độc + Hỏa
      if (_fusionCooldown <= 0 &&
          activeFusions.contains(ElementType.explosiveGas) &&
          _explosiveGasCooldown <= 0 &&
          ((block.elementAffinity?.burnTimer ?? 0) > 0 ||
              (block.elementAffinity?.poisonTimer ?? 0) > 0) &&
          _random.nextDouble() < 0.08) {
        _triggerExplosiveGas(block);
        _explosiveGasCooldown = 3.5;
      }

      // 7. Axit Ăn Mòn (Acid Melt) — Độc + Thủy
      if (_fusionCooldown <= 0 &&
          activeFusions.contains(ElementType.acidMelt) &&
          _acidMeltCooldown <= 0 &&
          _random.nextDouble() < 0.10) {
        _triggerAcidMelt(block);
        _acidMeltCooldown = 2.0;
      }

      // 8. Lở Tuyết (Avalanche) — Băng + Địa
      if (_fusionCooldown <= 0 &&
          activeFusions.contains(ElementType.avalanche) &&
          _avalancheCooldown <= 0 &&
          _random.nextDouble() < 0.05) {
        _triggerAvalanche(block);
        _avalancheCooldown = 4.5;
      }

      // 9. Hố Đen Lôi Đình (Void Vortex) — Bóng Tối + Lôi
      if (_fusionCooldown <= 0 &&
          activeFusions.contains(ElementType.voidVortex) &&
          _voidVortexCooldown <= 0 &&
          _random.nextDouble() < 0.06) {
        _triggerVoidVortex(block);
        _voidVortexCooldown = 4.0;
      }

      // 10. Dung Nham (Lava Burst) — Hỏa + Địa
      if (_fusionCooldown <= 0 &&
          activeFusions.contains(ElementType.lavaBurst) &&
          _lavaBurstCooldown <= 0 &&
          _random.nextDouble() < 0.08) {
        _triggerLavaBurst(block);
        _lavaBurstCooldown = 3.0;
      }
    }
    // Chớp sáng trắng khi bị đánh trúng & Rung cực nhẹ (tinh tế, không gây nhức mắt)
    if (triggerElements) block.hitFlashTimer = 0.1;
    if (triggerElements && _hitSoundCooldown <= 0) {
      AudioService.playHit();
      _hitSoundCooldown = 0.06;
    }

    final justDestroyed = block.takeDamage(dmg);

    if (justDestroyed) {
      _onBlockDestroyed(block);
    }
  }

  // Cập nhật vòng xoáy Bão Lửa (Firestorm) quét quanh bóng
  void _updateFirestormAura(double dt) {
    final center = player.transform.position;
    for (final b in _blocksNear(center, 75)) {
      {
        b.elementAffinity?.applyFire(2.0, totalDamage * 0.3);
        final killed = b.takeDamage(totalDamage * 0.5 * dt);
        if (killed) _onBlockDestroyed(b);
      }
    }
  }

  void _triggerFireBurst(PixelBlock origin) {
    floatingTexts.add(
      FloatingText(
        text: '🔥 HỎA NỔ!',
        x: origin.transform.x,
        y: origin.transform.y - 12,
        color: Colors.deepOrangeAccent,
      ),
    );
    for (final b in blocks) {
      if (b == origin || b.health!.isDestroyed) continue;
      if ((b.transform.position - origin.transform.position).distance < 60) {
        final killed = b.takeDamage(totalDamage * 0.5);
        b.elementAffinity?.applyFire(2.5, totalDamage * 0.25);
        if (killed) {
          _onBlockDestroyed(b);
        }
      }
    }
  }

  void _triggerLightningBolt(PixelBlock target) {
    AudioService.playLightning();
    lightningArcs.add(
      LightningArc.createZigzag(
        player.transform.position,
        target.transform.position,
        Colors.amberAccent,
      ),
    );
    floatingTexts.add(
      FloatingText(
        text: '⚡ LÔI ĐIỆN!',
        x: target.transform.x,
        y: target.transform.y - 10,
        color: Colors.amberAccent,
      ),
    );
    // Sét lan sang 1 khối lân cận
    for (final b in blocks) {
      if (b == target || b.health!.isDestroyed) continue;
      if ((b.transform.position - target.transform.position).distance < 75) {
        lightningArcs.add(
          LightningArc.createZigzag(
            target.transform.position,
            b.transform.position,
            Colors.yellowAccent,
          ),
        );
        final killed = b.takeDamage(totalDamage * 0.7);
        b.elementAffinity?.applyShock(1.5);
        if (killed) {
          _onBlockDestroyed(b);
        }
        break;
      }
    }
  }

  void _triggerChainLightning(PixelBlock origin) {
    _fusionCooldown = 0.6;
    AudioService.playLightning();
    final visited = <PixelBlock>{origin};
    final queue = <PixelBlock>[origin];
    for (
      int i = 0;
      i < queue.length && visited.length <= maxChainTargets;
      i++
    ) {
      final from = queue[i];
      for (final block in _blocksNear(
        from.transform.position,
        gridBlockSize * 1.5,
      )) {
        if (visited.length >= maxChainTargets) break;
        if (visited.contains(block) ||
            block.health!.isDestroyed ||
            !(block.elementAffinity?.isSoaked ?? false)) {
          continue;
        }
        if ((block.transform.position - from.transform.position).distance >
            gridBlockSize * 1.5) {
          continue;
        }
        visited.add(block);
        queue.add(block);
        lightningArcs.add(
          LightningArc.createZigzag(
            from.transform.position,
            block.transform.position,
            Colors.yellowAccent,
          ),
        );
        block.elementAffinity?.applyShock(1.5);
        if (block.takeDamage(totalDamage * 0.9)) _onBlockDestroyed(block);
      }
    }
  }

  // === BÃO LỬA (Firestorm) — Hỏa + Phong: Lốc xoáy lửa thiêu rụi các khối quanh bóng ===
  void _triggerFirestorm() {
    _fusionCooldown = 0.6;
    final center = player.transform.position;
    floatingTexts.add(
      FloatingText(
        text: '🌪🔥 BÃO LỬA!',
        x: center.dx,
        y: center.dy - 20,
        color: Colors.orange,
      ),
    );
    shockwaves.add(
      ShockwaveRing(center: center, color: Colors.deepOrangeAccent),
    );
    int count = 0;
    for (final b in blocks) {
      if (b.health!.isDestroyed) continue;
      if ((b.transform.position - center).distance < 90) {
        b.elementAffinity?.applyFire(3.5, totalDamage * 0.35);
        final killed = b.takeDamage(totalDamage * 0.4);
        if (killed) _onBlockDestroyed(b);
        count++;
        if (count >= 10) break;
      }
    }
    _firestormTimer = 4.0;
  }

  // === BĂNG VĨNH CỬU (Permafrost) — Thủy + Băng: Đóng băng tức thì cụm khối ===
  void _triggerPermafrost(PixelBlock origin) {
    _fusionCooldown = 0.6;
    floatingTexts.add(
      FloatingText(
        text: '❄️ BĂNG VĨNH CỬU!',
        x: origin.transform.x,
        y: origin.transform.y - 15,
        color: Colors.cyan,
      ),
    );
    shockwaves.add(
      ShockwaveRing(
        center: origin.transform.position,
        color: Colors.cyanAccent,
      ),
    );
    int count = 0;
    for (final b in blocks) {
      if (b.health!.isDestroyed) continue;
      if ((b.transform.position - origin.transform.position).distance < 80) {
        b.elementAffinity?.applyFrost(6.0);
        b.elementAffinity?.applyWater(4.0);
        count++;
        if (count >= 8) break;
      }
    }
  }

  // === SIÊU DẪN (Superconductor) — Băng + Lôi: Phóng điện trường lạnh nổ lan xuyên giáp ===
  void _triggerSuperconductor(PixelBlock origin) {
    _fusionCooldown = 0.6;
    AudioService.playLightning();
    floatingTexts.add(
      FloatingText(
        text: '⚡❄️ SIÊU DẪN!',
        x: origin.transform.x,
        y: origin.transform.y - 15,
        color: Colors.lightBlueAccent,
      ),
    );
    int count = 0;
    for (final b in blocks) {
      if (b == origin || b.health!.isDestroyed) continue;
      if ((b.transform.position - origin.transform.position).distance < 90) {
        lightningArcs.add(
          LightningArc.createZigzag(
            origin.transform.position,
            b.transform.position,
            Colors.lightBlueAccent,
          ),
        );
        b.elementAffinity?.applyFrost(3.0);
        b.elementAffinity?.applyShock(2.0);
        final killed = b.takeDamage(totalDamage * 1.0);
        if (killed) _onBlockDestroyed(b);
        count++;
        if (count >= 6) break;
      }
    }
  }

  // === KHÍ NỔ (Explosive Gas) — Độc + Hỏa: Nổ diện rộng khi Độc và Lửa chạm nhau ===
  void _triggerExplosiveGas(PixelBlock origin) {
    _fusionCooldown = 0.6;
    floatingTexts.add(
      FloatingText(
        text: '💥☠️ KHÍ NỔ!',
        x: origin.transform.x,
        y: origin.transform.y - 15,
        color: Colors.limeAccent,
      ),
    );
    shockwaves.add(
      ShockwaveRing(center: origin.transform.position, color: Colors.lime),
    );
    screenShake = max(screenShake, 3.0);
    for (final b in blocks) {
      if (b.health!.isDestroyed) continue;
      final dist = (b.transform.position - origin.transform.position).distance;
      if (dist < 100) {
        final dmgFalloff = 1.0 - (dist / 100.0);
        final killed = b.takeDamage(totalDamage * 1.3 * dmgFalloff);
        b.elementAffinity?.applyFire(2.0, totalDamage * 0.25);
        if (killed) _onBlockDestroyed(b);
      }
    }
  }

  // === AXIT ĂN MÒN (Acid Melt) — Độc + Thủy: Tan chảy thanh HP tối đa của khối ===
  void _triggerAcidMelt(PixelBlock target) {
    _fusionCooldown = 0.6;
    floatingTexts.add(
      FloatingText(
        text: '🧪 AXIT!',
        x: target.transform.x,
        y: target.transform.y - 10,
        color: Colors.greenAccent,
      ),
    );
    target.health!.maxHp *= 0.75;
    if (target.health!.currentHp > target.health!.maxHp) {
      target.health!.currentHp = target.health!.maxHp;
    }
    target.elementAffinity?.applyPoison(5.0, totalDamage * 0.25);
    int count = 0;
    for (final b in blocks) {
      if (b == target || b.health!.isDestroyed) continue;
      if ((b.transform.position - target.transform.position).distance < 50) {
        b.health!.maxHp *= 0.75;
        b.health!.currentHp = min(b.health!.currentHp, b.health!.maxHp);
        b.elementAffinity?.applyPoison(3.0, totalDamage * 0.15);
        count++;
        if (count >= 2) break;
      }
    }
  }

  // === LỞ TUYẾT (Avalanche) — Băng + Địa: Sóng tuyết càn quét cả hàng pixel ===
  void _triggerAvalanche(PixelBlock origin) {
    _fusionCooldown = 0.6;
    shockwaves.add(
      ShockwaveRing(center: origin.transform.position, color: Colors.white),
    );
    floatingTexts.add(
      FloatingText(
        text: '🏔️ LỞ TUYẾT!',
        x: origin.transform.x,
        y: origin.transform.y - 15,
        color: Colors.white,
      ),
    );
    screenShake = max(screenShake, 3.5);
    for (final b in blocks) {
      if (b.health!.isDestroyed) continue;
      if (b.row == origin.row) {
        b.elementAffinity?.applyFrost(2.5);
        final killed = b.takeDamage(totalDamage * 0.85);
        if (killed) _onBlockDestroyed(b);
      }
    }
  }

  // === HỐ ĐEN LÔI ĐÌNH (Void Vortex) — Bóng Tối + Lôi: Hút tụ khối và giật sét ===
  void _triggerVoidVortex(PixelBlock origin) {
    _fusionCooldown = 0.6;
    vortexZones.add(VoidVortexZone(origin.transform.position));
    AudioService.playLightning();
    floatingTexts.add(
      FloatingText(
        text: '🌀⚡ HỐ ĐEN!',
        x: origin.transform.x,
        y: origin.transform.y - 15,
        color: Colors.deepPurpleAccent,
      ),
    );
    shockwaves.add(
      ShockwaveRing(
        center: origin.transform.position,
        color: Colors.deepPurple,
      ),
    );
    int count = 0;
    for (final b in blocks) {
      if (b == origin || b.health!.isDestroyed) continue;
      if ((b.transform.position - origin.transform.position).distance < 90) {
        lightningArcs.add(
          LightningArc.createZigzag(
            origin.transform.position,
            b.transform.position,
            Colors.purpleAccent,
          ),
        );
        b.elementAffinity?.applyShock(2.0);
        final killed = b.takeDamage(totalDamage * 0.85);
        if (killed) _onBlockDestroyed(b);
        count++;
        if (count >= 7) break;
      }
    }
  }

  // === DUNG NHAM (Lava Burst) — Hỏa + Địa: Bắn tàn nham nóng chảy ===
  void _triggerLavaBurst(PixelBlock origin) {
    _fusionCooldown = 0.6;
    floatingTexts.add(
      FloatingText(
        text: '🌋 DUNG NHAM!',
        x: origin.transform.x,
        y: origin.transform.y - 15,
        color: Colors.redAccent,
      ),
    );
    shockwaves.add(
      ShockwaveRing(center: origin.transform.position, color: Colors.red),
    );
    screenShake = max(screenShake, 2.8);
    for (final b in blocks) {
      if (b.health!.isDestroyed) continue;
      final dist = (b.transform.position - origin.transform.position).distance;
      if (dist < 80) {
        b.elementAffinity?.applyFire(4.0, totalDamage * 0.4);
        final killed = b.takeDamage(totalDamage * 0.55);
        if (killed) _onBlockDestroyed(b);
      }
    }
  }

  void _onBlockDestroyed(PixelBlock block) {
    block.isRevealed = true;

    // Kích hoạt Rung giật màn hình vừa vặn (2.5px), sóng xung kích và âm thanh nổ vỡ
    screenShake = max(screenShake, 0.7);
    if (_breakSoundCooldown <= 0) {
      AudioService.playBlockBreak();
      _breakSoundCooldown = 0.05;
    }
    if (_breakRingsThisFrame++ < 2) {
      shockwaves.add(
        ShockwaveRing(center: block.transform.position, color: block.memeColor),
      );
    }
    onBlockDestroyedEffect?.call();

    // 1. Tạo các hạt vỡ nổ tung (Debris) nhiều và xoay sống động
    final rng = _random;
    for (
      int i = 0;
      i < 4 && _particlesThisFrame < 28;
      i++, _particlesThisFrame++
    ) {
      final pAngle = rng.nextDouble() * 2 * pi;
      final pSpeed = rng.nextDouble() * 65 + 25;
      debris.add(
        PixelDebris(
          x: block.transform.x,
          y: block.transform.y,
          vx: cos(pAngle) * pSpeed,
          vy: sin(pAngle) * pSpeed,
          size: rng.nextDouble() * 2 + 1.2,
          color: (i % 3 == 0) ? Colors.white : block.memeColor,
          rotSpeed: (rng.nextDouble() - 0.5) * 14.0,
          isSparkle: false,
        ),
      );
    }

    // 2. Rơi Vàng & Ngọc EXP (Nông dân được +25% Bội thu, Người lùn +30% Vàng)
    double goldVal = 10.0 * (1.0 + race.goldBonus);
    double expVal = 15.0 * (1.0 + race.expBonus);
    if (role.type == RoleType.farmer) {
      goldVal *= 1.25;
      expVal *= 1.25;
    }

    _addDrop(
      DropItem(
        id: 'gold_${DateTime.now().microsecondsSinceEpoch}',
        transform: TransformComponent(
          x: block.transform.x,
          y: block.transform.y,
          vx: (rng.nextDouble() - 0.5) * 80,
          vy: (rng.nextDouble() - 0.5) * 80,
        ),
        type: DropType.gold,
        value: goldVal,
      ),
    );

    _addDrop(
      DropItem(
        id: 'exp_${DateTime.now().microsecondsSinceEpoch}',
        transform: TransformComponent(
          x: block.transform.x,
          y: block.transform.y,
          vx: (rng.nextDouble() - 0.5) * 80,
          vy: (rng.nextDouble() - 0.5) * 80,
        ),
        type: DropType.exp,
        value: expVal,
      ),
    );

    // Labels are sampled; a large blast should not cover the artwork.
    if (_breakRingsThisFrame <= 2) {
      floatingTexts.add(
        FloatingText(
          text: '+${goldVal.toInt()}G',
          x: block.transform.x,
          y: block.transform.y - 10,
          color: Colors.amber,
        ),
      );
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
        drop.transform.x = drop.transform.x.clamp(
          gridStartX + 4,
          gridStartX + gridWidth - 4,
        );
        drop.transform.y = drop.transform.y.clamp(
          gridStartY + 4,
          gridStartY + gridHeight - 4,
        );
      }

      // Thu thập thành công
      if (dist <= player.radius + 6) {
        if (drop.type == DropType.gold) {
          gold += drop.value.toInt();
        } else {
          addExp(drop.value);
        }
        if (_coinSoundCooldown <= 0) {
          AudioService.playCoinCollect();
          _coinSoundCooldown = 0.08;
        }
        drops.removeAt(i);
      } else if (drop.lifeTime <= 0) {
        drops.removeAt(i);
      }
    }
  }

  void _addDrop(DropItem item) {
    if (drops.length < maxDrops) {
      drops.add(item);
      return;
    }
    for (int i = drops.length - 1; i >= 0; i--) {
      if (drops[i].type == item.type) {
        drops[i].value += item.value;
        return;
      }
    }
    // If the buffer contains only the other resource, collect one to make room.
    final oldest = drops.removeAt(0);
    if (oldest.type == DropType.gold) {
      gold += oldest.value.toInt();
    } else {
      addExp(oldest.value);
    }
    drops.add(item);
  }

  void addExp(double amount) {
    exp += amount;
  }

  void _processLevelUp() {
    // Emit one choice at a time, even if an explosion collects many gems.
    if (exp >= expToNextLevel && !isLevelCompleted) {
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
    final curSpeed = sqrt(
      player.transform.vx * player.transform.vx +
          player.transform.vy * player.transform.vy,
    );
    final maxSpeed = 480.0;
    if (curSpeed > maxSpeed) {
      player.transform.vx = (player.transform.vx / curSpeed) * maxSpeed;
      player.transform.vy = (player.transform.vy / curSpeed) * maxSpeed;
    }
  }

  // Thêm nguyên tố mới khi lên cấp
  void addElement(ElementType element) {
    ownedElements.add(element);
    notifyListeners();
  }

  void upgradeSpinSpeed() {
    spinUpgradeLevel++;
    player.spinMultiplier = weaponSpinSpeedMultiplier;
    floatingTexts.add(
      FloatingText(
        text: '🌀 CUỒNG VŨ XOAY!',
        x: player.transform.x,
        y: player.transform.y - 15,
        color: Colors.cyanAccent,
      ),
    );
    notifyListeners();
  }

  void summonSpirit([ElementType? el]) {
    if (spirits.length >= 4) return;
    spiritUpgradeLevel++;
    final colors = [
      Colors.cyanAccent,
      Colors.amberAccent,
      Colors.deepOrangeAccent,
      Colors.purpleAccent,
    ];
    final orbColor = colors[(spirits.length) % colors.length];

    spirits.add(
      OrbitingSpirit(
        id: 'spirit_${DateTime.now().millisecondsSinceEpoch}',
        element: el ?? ElementType.none,
        orbitRadius: 48.0 + spirits.length * 6.0,
        angle: 0.0,
        orbitSpeed: 3.8 + spirits.length * 0.4,
        color: orbColor,
      ),
    );
    // Chia đều góc xoay quanh quả cầu
    for (int i = 0; i < spirits.length; i++) {
      spirits[i].angle = i * (2 * pi / spirits.length);
    }
    floatingTexts.add(
      FloatingText(
        text: '🔮 THÊM CẦU VỆ TINH!',
        x: player.transform.x,
        y: player.transform.y - 20,
        color: Colors.cyanAccent,
      ),
    );
    notifyListeners();
  }

  // Thực hiện Dung hợp nguyên tố
  bool fuseElements(ElementType a, ElementType b) {
    final fusion = ElementData.findFusion(a, b);
    if (fusion != null &&
        ownedElements.contains(a) &&
        ownedElements.contains(b) &&
        !activeFusions.contains(fusion.type)) {
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
      final multiplier =
          (1 + race.bounceBonus + bounceUpgradeLevel * 0.1) /
          (1 + race.bounceBonus + (bounceUpgradeLevel - 1) * 0.1);
      player.transform.vx *= multiplier;
      player.transform.vy *= multiplier;
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
