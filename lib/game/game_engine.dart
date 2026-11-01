import 'dart:math';

import 'package:flutter/material.dart';

import '../models/ecs.dart';
import '../models/character.dart';
import '../models/element.dart';
import '../models/pixel_art_data.dart';
import '../models/game_entities.dart';
import '../models/upgrade.dart';
import '../models/fusion_cast.dart';
import '../core/audio_service.dart';
import '../core/bounded_list.dart';
import 'stage_backdrop.dart';

class GameEngine extends ChangeNotifier {
  final StageBackdrop backdrop = StageBackdrop();
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
  final Random _random;
  double _hitSoundCooldown = 0;
  double _breakSoundCooldown = 0;
  double _coinSoundCooldown = 0;
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
  final Set<ElementType> equippedElements = {};
  static const maxEquippedElements = 3;
  // Research collection; only the equipped recipe can be cast.
  final Set<ElementType> activeFusions = {};
  ElementType? selectedFusion;
  static const fusionUnlockBlocks = 100;
  int totalDestroyedBlocks = 0;
  bool get isFusionUnlocked => totalDestroyedBlocks >= fusionUnlockBlocks;
  double get fusionEnergy =>
      min(fusionUnlockBlocks, totalDestroyedBlocks).toDouble();
  double fusionEnergyFor(ElementType type) => fusionEnergy;
  int fusionCooldownUpgradeLevel = 0;
  double get fusionCooldownDuration =>
      (10 - fusionCooldownUpgradeLevel).clamp(7, 10).toDouble();
  double fusionCooldown = 0;
  double get fusionMeterProgress => !isFusionUnlocked
      ? fusionEnergy / 100
      : (1 - fusionCooldown / fusionCooldownDuration).clamp(0.0, 1.0);
  double get spiritHitDamage => totalDamage * OrbitingSpirit.damageRatio;
  FusionCast? pendingFusion;
  final List<FusionCast> fusionCasts = BoundedList(3);
  ElementData? get fusionData => selectedFusion == null
      ? null
      : ElementData.fusionElements.firstWhere(
          (data) => data.type == selectedFusion,
        );
  bool get hasFusionIngredients =>
      fusionData?.ingredients?.every(equippedElements.contains) ?? false;
  bool get canCastFusion =>
      !isLevelCompleted &&
      isGridBuilt &&
      selectedFusion != null &&
      hasFusionIngredients &&
      isFusionUnlocked &&
      fusionCooldown <= 0 &&
      pendingFusion == null;
  String get fusionStatus => pendingFusion != null
      ? 'Đang kết ấn…'
      : !hasFusionIngredients
      ? 'Cần trang bị 2 nguyên tố thành phần'
      : fusionCooldown > 0
      ? 'Hồi ${fusionCooldown.toStringAsFixed(1)}s'
      : !isFusionUnlocked
      ? 'Mở kỹ năng: ${fusionEnergy.floor()}/100 khối đã phá'
      : 'Sẵn sàng · Chạm khối để ngắm';
  double get fusionDamage => elementDamage * 2.6;

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
  int resonanceUpgradeLevel = 0;
  double dashCooldown = 0;
  double? projectileAimAngle;
  double _impactCooldown = 0;
  static const maxImpacts = 32;
  final List<ElementImpact> impacts = BoundedList(maxImpacts);

  // Cooldown cho các hiệu ứng nguyên tố (tránh spam quá nhiều)
  double _fireBurstCooldown = 0.0;
  double _lightningCooldown = 0.0;
  double _firestormTimer = 0.0;

  double get weaponSpinSpeedMultiplier =>
      (1.0 + min(spinUpgradeLevel, 8) * 0.18) *
      (equippedElements.contains(ElementType.wind)
          ? (race.type == RaceType.elf ? 1.35 : 1.25)
          : 1.0);

  final Map<String, double> _elementHitTimers = {};
  bool get isFirestormActive => _firestormTimer > 0;

  // Lực hút nam châm cơ bản
  double get magnetRange => 80.0 + (min(magnetUpgradeLevel, 6) * 22.0);

  // Sát thương tổng thể
  double get totalDamage {
    final base =
        role.baseDamage *
        (1 + min(damageUpgradeLevel, 15) * 0.12) *
        race.damageMultiplier;
    return base * (isEndless ? 1 + log(endlessWave) * 0.18 : 1);
  }

  // Tốc độ đánh tổng thể
  double get totalAttackSpeed {
    return role.attackSpeed *
        race.speedMultiplier *
        (1.0 + min(speedUpgradeLevel, 8) * 0.12);
  }

  // Tầm với vũ khí
  double get totalWeaponRange {
    return (role.weaponRange + min(rangeUpgradeLevel, 6) * 6.0);
  }

  double get normalBallSpeed =>
      160 * (1 + race.bounceBonus + min(bounceUpgradeLevel, 6) * 0.08);
  double get elementPower => 1 + min(resonanceUpgradeLevel, 6) * 0.1;
  double get elementDamage => totalDamage * elementPower;
  double get meleeTempo =>
      race.speedMultiplier * (1 + min(speedUpgradeLevel, 8) * 0.12);

  // Callbacks
  VoidCallback? onLevelUp;
  VoidCallback? onVictory;
  VoidCallback? onBlockDestroyedEffect;

  GameEngine({
    required this.role,
    required this.race,
    required this.level,
    this.isEndless = false,
    int? randomSeed,
  }) : _random = Random(randomSeed) {
    if (isEndless) level = MemeLevel.endlessWave(endlessWave);
    _initEngine();
  }

  double gridStartX = 0;
  double gridStartY = 0;
  double gridBlockSize = 28;

  bool isGridBuilt = false;

  void _initEngine() {
    // Tốc độ nảy cơ bản
    double speed = normalBallSpeed;
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
          (isEndless ? min(0.43, 0.32 + (endlessWave - 1) * 0.012) : 0.32) *
          (1 + race.ballSizeBonus);

      final scale = gridWidth / oldWidth;
      Offset remap(Offset position) =>
          newCenter + (position - oldCenter) * scale;
      for (final entity in [...arrows, ...hooks, ...drops]) {
        entity.transform.position = remap(entity.transform.position);
      }
      for (final hook in hooks) {
        hook.origin = player.transform.position;
      }
      for (final mist in mistZones) {
        mist.center = remap(mist.center);
      }
      for (final vortex in vortexZones) {
        vortex.center = remap(vortex.center);
      }
      for (final cast in fusionCasts) {
        cast.center = remap(cast.center);
        cast.board = Rect.fromLTWH(
          gridStartX,
          gridStartY,
          gridWidth,
          gridHeight,
        );
      }
      player.trail.clear();
      for (final spirit in spirits) {
        spirit.trail.clear();
      }
      for (final arrow in arrows) {
        arrow.trail.clear();
      }
      impacts.clear();
      debris.clear();
      lightningArcs.clear();
      shockwaves.clear();
      floatingTexts.clear();

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
        (isEndless ? min(0.43, 0.32 + (endlessWave - 1) * 0.012) : 0.32) *
        (1 + race.ballSizeBonus);

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
        : 50.0 * pow(1.16, level.id - 1);
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
        // Bank uncollected loot before saving the completed story stage.
        for (final drop in drops) {
          if (drop.type == DropType.gold) {
            gold += drop.value.toInt();
          } else {
            addExp(drop.value);
          }
        }
        drops.clear();
        AudioService.playVictory();
        onVictory?.call();
      }
    }
  }

  void update(double dt) {
    if (!dt.isFinite || dt <= 0 || !isGridBuilt) return;
    final elapsed = min(dt, 0.1);
    elapsedTime += elapsed;
    fusionCooldown = max(0, fusionCooldown - elapsed);
    for (final cast in fusionCasts) {
      cast.age += elapsed;
    }
    if (pendingFusion != null && pendingFusion!.age >= FusionCast.windup) {
      final cast = pendingFusion!;
      pendingFusion = null;
      if (!isLevelCompleted) _resolveFusion(cast);
    }
    fusionCasts.removeWhere((cast) => cast.age >= cast.duration);
    _hudTimer += elapsed;
    _cameraSettle = max(0, _cameraSettle - elapsed * 1.5);
    _particlesThisFrame = 0;
    dashCooldown = max(0, dashCooldown - elapsed);
    _impactCooldown = max(0, _impactCooldown - elapsed);
    impacts.removeWhere((effect) => effect.update(elapsed));
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

  void _resetBoardState() {
    dashCooldown = 0;
    pendingFusion = null;
    fusionCasts.clear();
    projectileAimAngle = null;
    _impactCooldown = 0;
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
    impacts.clear();
    _firestormTimer = 0;
    _fireBurstCooldown = _lightningCooldown = 0;
    screenShake = 0;
    shakeOffset = Offset.zero;
    player.trail.clear();
    for (final spirit in spirits) {
      spirit.trail.clear();
    }
  }

  bool startStoryLevel(MemeLevel next) {
    if (isEndless || !isLevelCompleted) return false;
    _resetBoardState();
    level = next;
    isLevelCompleted = false;
    _buildPixelGrid();
    _cameraSettle = 1;
    hudRevision.value++;
    notifyListeners();
    return true;
  }

  void _advanceEndlessWave() {
    _resetBoardState();
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
    backdrop.dispose();
    hudRevision.dispose();
    super.dispose();
  }

  void _step(double dt) {
    if (isLevelCompleted || !isGridBuilt || dt <= 0) return;
    dt = min(dt, 0.05);
    _elementHitTimers.updateAll((key, value) => max(0.0, value - dt));
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
    final velocity = Offset(player.transform.vx, player.transform.vy);
    if (velocity.distance > normalBallSpeed + 0.1) {
      final speed =
          normalBallSpeed +
          (velocity.distance - normalBallSpeed) * expDecay(dt);
      player.transform.vx = velocity.dx / velocity.distance * speed;
      player.transform.vy = velocity.dy / velocity.distance * speed;
    }
    player.update(dt);
    _handleBallBorderCollision();
    _handleBallBlockCollision();
    _handleBallBorderCollision();

    // 2. Cập nhật Tinh Linh Hộ Vệ xoay quanh bóng
    final pCenter = player.transform.position;
    for (final spirit in spirits) {
      spirit.update(dt, pCenter);
      if (spirit.hitCooldown > 0) continue;
      final pos = spirit.getPosition(pCenter);
      for (final block in _blocksInRect(
        Rect.fromCircle(center: pos, radius: spirit.size),
      )) {
        final rect = block.transform.rect;
        final nearest = Offset(
          pos.dx.clamp(rect.left, rect.right),
          pos.dy.clamp(rect.top, rect.bottom),
        );
        if ((pos - nearest).distanceSquared > spirit.size * spirit.size) {
          continue;
        }
        spirit.hitCooldown = OrbitingSpirit.contactCooldown;
        block.hitFlashTimer = 0.1;
        _damageBlock(block, spiritHitDamage, 'TINH LINH');
        if (!block.health!.isDestroyed) {
          switch (spirit.element) {
            case ElementType.fire:
              block.elementAffinity?.applyFire(2.5, elementDamage * 0.25);
            case ElementType.frost:
              block.elementAffinity?.applyFrost(3);
            case ElementType.lightning:
              block.elementAffinity?.applyShock(1.2);
            case ElementType.poison:
              block.elementAffinity?.applyPoison(3, elementDamage * 0.2);
            default:
              break;
          }
        }
        if (_impactCooldown <= 0) {
          impacts.add(
            ElementImpact(center: nearest, element: spirit.element, radius: 12),
          );
          _impactCooldown = 0.065;
        }
        break; // A spirit hits one tile per contact beat, regardless of frame rate.
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
        if (block.takeDamage(fusionDamage * 0.22)) _onBlockDestroyed(block);
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
            (equippedElements.contains(ElementType.earth) ? 1.2 : 1.0);
        if (race.type == RaceType.yeti) {
          block.elementAffinity?.applyFrost(3.0);
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
          totalDamage * 1.25,
          dt,
          'BỔ RÌU',
        );
        break;

      case RoleType.archer:
        // Cung thủ tự bắn mũi tên theo nhịp
        if (player.attackCooldown <= 0) {
          player.attackCooldown = 1.0 / totalAttackSpeed;
          PixelBlock? target;
          double nearest = double.infinity;
          for (final block in _blocksNear(center, wRange)) {
            final distance =
                (block.transform.position - center).distanceSquared;
            if (distance < nearest) {
              nearest = distance;
              target = block;
            }
          }
          final aim = target == null
              ? wAngle
              : atan2(
                  target.transform.y - center.dy,
                  target.transform.x - center.dx,
                );
          projectileAimAngle = aim;
          final arrowVx = cos(aim) * 380.0;
          final arrowVy = sin(aim) * 380.0;
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
              damage: totalDamage,
              pierceCount: 3 + min(rangeUpgradeLevel, 6) ~/ 2,
              lifeTime: 1.2 + min(rangeUpgradeLevel, 6) * 0.12,
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
          totalDamage * 0.7,
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
              damage: totalDamage * 0.85,
              origin: center,
              maxDistance: 140 + min(rangeUpgradeLevel, 6) * 14.0,
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
    for (final block in _blocksInRect(
      Rect.fromPoints(start, end).inflate(role.type == RoleType.farmer ? 6 : 2),
    )) {
      final rect = block.transform.rect;
      if (_lineIntersectsRect(
        start,
        end,
        rect.inflate(role.type == RoleType.farmer ? 4 : 0),
      )) {
        _damageBlock(block, dmg * dt * 4.0 * meleeTempo, hitLabel);
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
      if (hook.isReturning && hook.returnHits.length >= 2) continue;
      for (final block in _blocksInRect(
        Rect.fromCircle(center: hook.transform.position, radius: 1),
      )) {
        if (block.transform.rect.contains(hook.transform.position) &&
            (hook.isReturning ? hook.returnHits : hook.outboundHits).add(
              block.id,
            )) {
          _damageBlock(block, hook.damage, 'MÓC GIẬT');
          if (!hook.isReturning && hook.outboundHits.length >= 2) {
            hook.isReturning = true;
          }
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
      if (equippedElements.contains(ElementType.fire)) {
        block.elementAffinity?.applyFire(3.0, elementDamage * 0.25);
        // Hỏa Nổ: 5% tỉ lệ và cooldown 1.6s
        if (_fireBurstCooldown <= 0 && _random.nextDouble() < 0.05) {
          _triggerFireBurst(block);
          _fireBurstCooldown = 1.6;
        }
      }
      if (equippedElements.contains(ElementType.frost)) {
        block.elementAffinity?.applyFrost(4.0);
      }
      if (equippedElements.contains(ElementType.poison)) {
        block.elementAffinity?.applyPoison(4.5, elementDamage * 0.20);
      }
      if (equippedElements.contains(ElementType.water)) {
        block.elementAffinity?.applyWater(5.0);
      }
      if (equippedElements.contains(ElementType.lightning)) {
        block.elementAffinity?.applyShock(1.5);
        // Lôi Điện: Giảm tỉ lệ từ 30% xuống 6% và thêm cooldown 2.0s để không spam
        if (_lightningCooldown <= 0 && _random.nextDouble() < 0.06) {
          _triggerLightningBolt(block);
          _lightningCooldown = 2.0;
        }
      }

      if (equippedElements.contains(ElementType.voidDark)) {
        block.elementAffinity?.applyVoid(3.0);
      }
      if (_impactCooldown <= 0) {
        final affinity = block.elementAffinity!;
        final type = affinity.isFrozen
            ? ElementType.frost
            : affinity.burnTimer > 0
            ? ElementType.fire
            : affinity.shockTimer > 0
            ? ElementType.lightning
            : affinity.poisonTimer > 0
            ? ElementType.poison
            : affinity.isSoaked
            ? ElementType.water
            : affinity.voidTimer > 0
            ? ElementType.voidDark
            : ElementType.none;
        impacts.add(
          ElementImpact(
            center: block.transform.position,
            element: type,
            radius: max(10, gridBlockSize * 1.5),
            angle: player.weaponAngle,
          ),
        );
        _impactCooldown = 0.065;
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
        b.elementAffinity?.applyFire(2.0, elementDamage * 0.3);
        final killed = b.takeDamage(elementDamage * 0.5 * dt);
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
        final killed = b.takeDamage(elementDamage * 0.5);
        b.elementAffinity?.applyFire(2.5, elementDamage * 0.25);
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
        final killed = b.takeDamage(elementDamage * 0.7);
        b.elementAffinity?.applyShock(1.5);
        if (killed) {
          _onBlockDestroyed(b);
        }
        break;
      }
    }
  }

  void _triggerChainLightning(PixelBlock origin) {
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
        if (block.takeDamage(fusionDamage * 0.9)) _onBlockDestroyed(block);
      }
    }
  }

  // === BÃO LỬA (Firestorm) — Hỏa + Phong: Lốc xoáy lửa thiêu rụi các khối quanh bóng ===
  void _triggerFirestorm() {
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
        b.elementAffinity?.applyFire(3.5, fusionDamage * 0.35);
        final killed = b.takeDamage(fusionDamage * 0.4);
        if (killed) _onBlockDestroyed(b);
        count++;
        if (count >= 10) break;
      }
    }
    _firestormTimer = 4.0;
  }

  // === BĂNG VĨNH CỬU (Permafrost) — Thủy + Băng: Đóng băng tức thì cụm khối ===
  void _triggerPermafrost(PixelBlock origin) {
    impacts.add(
      ElementImpact(
        center: origin.transform.position,
        element: ElementType.frost,
        radius: 55,
        duration: 0.6,
      ),
    );
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
        final killed = b.takeDamage(fusionDamage * 1.0);
        if (killed) _onBlockDestroyed(b);
        count++;
        if (count >= 6) break;
      }
    }
  }

  // === KHÍ NỔ (Explosive Gas) — Độc + Hỏa: Nổ diện rộng khi Độc và Lửa chạm nhau ===
  void _triggerExplosiveGas(PixelBlock origin) {
    impacts.add(
      ElementImpact(
        center: origin.transform.position,
        element: ElementType.poison,
        radius: 62,
        duration: 0.6,
      ),
    );
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
        final killed = b.takeDamage(fusionDamage * 1.3 * dmgFalloff);
        b.elementAffinity?.applyFire(2.0, fusionDamage * 0.25);
        if (killed) _onBlockDestroyed(b);
      }
    }
  }

  // === AXIT ĂN MÒN (Acid Melt) — Độc + Thủy: Tan chảy thanh HP tối đa của khối ===
  void _triggerAcidMelt(PixelBlock target) {
    impacts.add(
      ElementImpact(
        center: target.transform.position,
        element: ElementType.poison,
        radius: 28,
        duration: 0.6,
      ),
    );
    floatingTexts.add(
      FloatingText(
        text: '🧪 AXIT!',
        x: target.transform.x,
        y: target.transform.y - 10,
        color: Colors.greenAccent,
      ),
    );
    for (final block in _blocksNear(
      target.transform.position,
      gridBlockSize * 1.6,
    ).take(9)) {
      if (!block.isCorroded) {
        block.isCorroded = true;
        block.health!.maxHp *= 0.75;
        block.health!.currentHp = min(
          block.health!.currentHp,
          block.health!.maxHp,
        );
      }
      block.elementAffinity?.applyPoison(5, fusionDamage * 0.25);
    }
  }

  // === LỞ TUYẾT (Avalanche) — Băng + Địa: Sóng tuyết càn quét cả hàng pixel ===
  void _triggerAvalanche(PixelBlock origin) {
    impacts.add(
      ElementImpact(
        center: origin.transform.position,
        element: ElementType.frost,
        radius: 70,
        duration: 0.6,
      ),
    );
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
        final killed = b.takeDamage(fusionDamage * 0.85);
        if (killed) _onBlockDestroyed(b);
      }
    }
  }

  // === HỐ ĐEN LÔI ĐÌNH (Void Vortex) — Bóng Tối + Lôi: Hút tụ khối và giật sét ===
  void _triggerVoidVortex(PixelBlock origin) {
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
        final killed = b.takeDamage(fusionDamage * 0.85);
        if (killed) _onBlockDestroyed(b);
        count++;
        if (count >= 7) break;
      }
    }
  }

  // === DUNG NHAM (Lava Burst) — Hỏa + Địa: Bắn tàn nham nóng chảy ===
  void _triggerLavaBurst(PixelBlock origin) {
    impacts.add(
      ElementImpact(
        center: origin.transform.position,
        element: ElementType.fire,
        radius: 52,
        duration: 0.6,
      ),
    );
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
        b.elementAffinity?.applyFire(4.0, fusionDamage * 0.4);
        final killed = b.takeDamage(fusionDamage * 0.55);
        if (killed) _onBlockDestroyed(b);
      }
    }
  }

  void _onBlockDestroyed(PixelBlock block) {
    if (block.isCenterEmpty || block.isRevealed) return;
    block.isRevealed = true;
    totalDestroyedBlocks++;
    if (totalDestroyedBlocks == fusionUnlockBlocks) {
      floatingTexts.add(
        FloatingText(
          text: 'ĐÃ MỞ KỸ NĂNG DUNG HỢP',
          x: player.transform.x,
          y: player.transform.y - 30,
          color: const Color(0xFFCAB1F2),
        ),
      );
      hudRevision.value++;
    }

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

  double expDecay(double dt) => pow(0.06, dt).toDouble();

  bool boostBall(Offset flingVelocity) {
    if (!isGridBuilt ||
        isLevelCompleted ||
        dashCooldown > 0 ||
        flingVelocity.distance < 40) {
      return false;
    }
    final direction = flingVelocity / flingVelocity.distance;
    final speed = min(360.0, normalBallSpeed * 1.55);
    player.transform.vx = direction.dx * speed;
    player.transform.vy = direction.dy * speed;
    dashCooldown = 1.2;
    impacts.add(
      ElementImpact(
        center: player.transform.position,
        element: ElementType.wind,
        radius: 28,
        angle: atan2(direction.dy, direction.dx),
      ),
    );
    hudRevision.value++;
    return true;
  }

  // Thêm nguyên tố mới khi lên cấp
  void addElement(ElementType element) {
    if (!ElementData.baseElements.any((data) => data.type == element)) return;
    ownedElements.add(element);
    if (equippedElements.length < maxEquippedElements) {
      equippedElements.add(element);
    }
    hudRevision.value++;
    notifyListeners();
  }

  bool toggleElement(ElementType element) {
    if (!ownedElements.contains(element)) return false;
    if (!equippedElements.remove(element)) {
      if (equippedElements.length >= maxEquippedElements) return false;
      equippedElements.add(element);
    }
    hudRevision.value++;
    notifyListeners();
    return true;
  }

  void upgradeSpinSpeed() => grantUpgrade(UpgradeType.spin);

  void summonSpirit([ElementType? el]) {
    if (spirits.length >= 4) return;
    spiritUpgradeLevel = spirits.length + 1;
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
        text: 'TINH LINH HỘ VỆ',
        x: player.transform.x,
        y: player.transform.y - 20,
        color: Colors.cyanAccent,
      ),
    );
    notifyListeners();
  }

  bool selectFusion(ElementType type) {
    if (!activeFusions.contains(type) || pendingFusion != null) return false;
    final data = ElementData.fusionElements
        .where((data) => data.type == type)
        .firstOrNull;
    if (data == null || !data.ingredients!.every(ownedElements.contains)) {
      return false;
    }
    if (selectedFusion == type) return true;
    final extra = equippedElements
        .where((el) => !data.ingredients!.contains(el))
        .firstOrNull;
    equippedElements
      ..clear()
      ..addAll(data.ingredients!);
    if (extra != null) equippedElements.add(extra);
    selectedFusion = type;
    hudRevision.value++;
    notifyListeners();
    return true;
  }

  bool _validFusionTarget(PixelBlock block, ElementType type) => switch (type) {
    ElementType.chainLightning ||
    ElementType.acidMelt => block.elementAffinity!.isSoaked,
    ElementType.superconductor => block.elementAffinity!.isFrozen,
    ElementType.explosiveGas => block.elementAffinity!.poisonTimer > 0,
    _ => true,
  };

  PixelBlock? fusionTarget([Offset? point]) {
    final candidates = _blocksNear(player.transform.position, 180)
        .where(
          (block) =>
              _validFusionTarget(block, selectedFusion ?? ElementType.none),
        )
        .toList();
    final aim = point ?? player.transform.position;
    candidates.sort(
      (a, b) => (a.transform.position - aim).distanceSquared.compareTo(
        (b.transform.position - aim).distanceSquared,
      ),
    );
    if (point != null &&
        ((point - player.transform.position).distance > 180 ||
            candidates.isEmpty ||
            (candidates.first.transform.position - point).distance >
                gridBlockSize * 1.5)) {
      return null;
    }
    return candidates.firstOrNull;
  }

  bool castFusion([Offset? point]) {
    if (!canCastFusion) return false;
    final target = fusionTarget(point);
    if (target == null) return false;
    fusionCooldown = fusionCooldownDuration;
    final cast = FusionCast(
      type: selectedFusion!,
      center: selectedFusion == ElementType.firestorm
          ? player.transform.position
          : target.transform.position,
      color: fusionData!.color,
      targetId: target.id,
      board: Rect.fromLTWH(
        gridStartX,
        gridStartY,
        level.cols * gridBlockSize,
        level.rows * gridBlockSize,
      ),
    );
    pendingFusion = cast;
    fusionCasts.add(cast);
    hudRevision.value++;
    notifyListeners();
    return true;
  }

  void _resolveFusion(FusionCast cast) {
    final origin = blocks
        .where((block) => block.id == cast.targetId)
        .firstOrNull;
    if (origin == null) return;
    switch (cast.type) {
      case ElementType.mist:
        mistZones.add(
          MistZone(center: cast.center, damagePerSec: fusionDamage * 0.3),
        );
      case ElementType.chainLightning:
        _triggerChainLightning(origin);
      case ElementType.firestorm:
        _triggerFirestorm();
      case ElementType.permafrost:
        _triggerPermafrost(origin);
      case ElementType.superconductor:
        _triggerSuperconductor(origin);
      case ElementType.explosiveGas:
        _triggerExplosiveGas(origin);
      case ElementType.acidMelt:
        _triggerAcidMelt(origin);
      case ElementType.avalanche:
        _triggerAvalanche(origin);
      case ElementType.voidVortex:
        _triggerVoidVortex(origin);
      case ElementType.lavaBurst:
        _triggerLavaBurst(origin);
      default:
        break;
    }
    floatingTexts.add(
      FloatingText(
        text: ElementData.fusionElements
            .firstWhere((data) => data.type == cast.type)
            .name
            .split(' (')
            .first
            .toUpperCase(),
        x: cast.center.dx,
        y: cast.center.dy - 24,
        color: cast.color,
      ),
    );
  }

  // Thực hiện Dung hợp nguyên tố
  bool fuseElements(ElementType a, ElementType b) {
    final fusion = ElementData.findFusion(a, b);
    if (fusion != null &&
        ownedElements.contains(a) &&
        ownedElements.contains(b) &&
        !activeFusions.contains(fusion.type)) {
      activeFusions.add(fusion.type);
      if (selectedFusion == null) selectFusion(fusion.type);
      notifyListeners();
      return true;
    }
    return false;
  }

  int upgradeRank(UpgradeType type) => switch (type) {
    UpgradeType.damage => damageUpgradeLevel,
    UpgradeType.speed => speedUpgradeLevel,
    UpgradeType.range => rangeUpgradeLevel,
    UpgradeType.bounce => bounceUpgradeLevel,
    UpgradeType.magnet => magnetUpgradeLevel,
    UpgradeType.spin => spinUpgradeLevel,
    UpgradeType.spirit => spirits.length,
    UpgradeType.resonance => resonanceUpgradeLevel,
    UpgradeType.fusionCooldown => fusionCooldownUpgradeLevel,
  };

  bool upgradeAvailable(UpgradeType type) =>
      type != UpgradeType.fusionCooldown || isFusionUnlocked;

  bool canImprove(UpgradeType type) =>
      upgradeRank(type) < UpgradeSpec.of(type).maxRank;

  int getUpgradeCost(int currentLevel) =>
      ((50 + currentLevel * 18 + currentLevel * currentLevel * 6) *
              (1 - race.shopDiscount))
          .round();

  int upgradeCost(UpgradeType type) {
    final rank = upgradeRank(type);
    return ((UpgradeSpec.of(type).baseCost + rank * 18 + rank * rank * 6) *
            (1 - race.shopDiscount))
        .round();
  }

  String upgradePreview(UpgradeType type) {
    final rank = upgradeRank(type);
    final next = min(rank + 1, UpgradeSpec.of(type).maxRank);
    return switch (type) {
      UpgradeType.damage =>
        '${totalDamage.toStringAsFixed(1)} → ${(totalDamage * (1 + next * 0.12) / (1 + rank * 0.12)).toStringAsFixed(1)} sát thương',
      UpgradeType.speed =>
        'x${(1 + rank * 0.12).toStringAsFixed(2)} → x${(1 + next * 0.12).toStringAsFixed(2)} nhịp đánh',
      UpgradeType.range =>
        role.type == RoleType.archer
            ? '${3 + rank ~/ 2} → ${3 + next ~/ 2} khối xuyên · tầm +6'
            : '${(role.weaponRange + rank * 6).round()} → ${(role.weaponRange + next * 6).round()} tầm quét',
      UpgradeType.bounce =>
        '${normalBallSpeed.round()} → ${(160 * (1 + race.bounceBonus + next * 0.08)).round()} tốc độ',
      UpgradeType.magnet =>
        '${(80 + rank * 22)} → ${(80 + next * 22)} bán kính hút',
      UpgradeType.spin =>
        'x${(1 + rank * 0.18).toStringAsFixed(2)} → x${(1 + next * 0.18).toStringAsFixed(2)} tốc xoay',
      UpgradeType.spirit =>
        '$rank → $next tinh linh · ${spiritHitDamage.toStringAsFixed(1)} sát thương/đòn',
      UpgradeType.fusionCooldown => '${10 - rank}s → ${10 - next}s hồi chiêu',
      UpgradeType.resonance =>
        'x${(1 + rank * 0.1).toStringAsFixed(2)} → x${(1 + next * 0.1).toStringAsFixed(2)} nguyên tố',
    };
  }

  bool grantUpgrade(UpgradeType type) {
    if (!canImprove(type) || !upgradeAvailable(type)) return false;
    final oldSpeed = normalBallSpeed;
    switch (type) {
      case UpgradeType.damage:
        damageUpgradeLevel++;
      case UpgradeType.speed:
        speedUpgradeLevel++;
      case UpgradeType.range:
        rangeUpgradeLevel++;
      case UpgradeType.bounce:
        bounceUpgradeLevel++;
      case UpgradeType.magnet:
        magnetUpgradeLevel++;
      case UpgradeType.spin:
        spinUpgradeLevel++;
      case UpgradeType.spirit:
        summonSpirit();
      case UpgradeType.resonance:
        resonanceUpgradeLevel++;
      case UpgradeType.fusionCooldown:
        fusionCooldownUpgradeLevel++;
        fusionCooldown = min(fusionCooldown, fusionCooldownDuration);
    }
    if (type == UpgradeType.bounce) {
      player.transform.vx *= normalBallSpeed / oldSpeed;
      player.transform.vy *= normalBallSpeed / oldSpeed;
    }
    player.spinMultiplier = weaponSpinSpeedMultiplier;
    impacts.add(
      ElementImpact(
        center: player.transform.position,
        element: ElementType.wind,
        radius: 34,
      ),
    );
    hudRevision.value++;
    notifyListeners();
    return true;
  }

  bool purchaseUpgrade(UpgradeType type) {
    if (!canImprove(type) || !upgradeAvailable(type)) return false;
    final cost = upgradeCost(type);
    if (gold < cost) return false;
    gold -= cost;
    return grantUpgrade(type);
  }

  bool upgradeDamage() => purchaseUpgrade(UpgradeType.damage);
  bool upgradeSpeed() => purchaseUpgrade(UpgradeType.speed);
  bool upgradeRange() => purchaseUpgrade(UpgradeType.range);
  bool upgradeBounce() => purchaseUpgrade(UpgradeType.bounce);
  bool upgradeMagnet() => purchaseUpgrade(UpgradeType.magnet);
  bool upgradeSpin() => purchaseUpgrade(UpgradeType.spin);
  bool upgradeSpirit() => purchaseUpgrade(UpgradeType.spirit);
  Map<String, dynamic> exportBuild() => {
    'gold': gold,
    'exp': exp,
    'expNext': expToNextLevel,
    'characterLevel': characterLevel,
    'kills': totalDestroyedBlocks,
    'upgrades': {
      for (final type in UpgradeType.values) type.name: upgradeRank(type),
    },
    'elements': ownedElements.map((e) => e.name).toList(),
    'equipped': equippedElements.map((e) => e.name).toList(),
    'fusions': activeFusions.map((e) => e.name).toList(),
    'selected': selectedFusion?.name,
  };

  void restoreBuild(Map<String, dynamic> data) {
    double number(dynamic value, double fallback, double upper) =>
        value is num && value.isFinite
        ? value.toDouble().clamp(0.0, upper)
        : fallback;
    gold = number(data['gold'], 0, 1e12).toInt();
    exp = number(data['exp'], 0, 1e12);
    expToNextLevel = max(100, number(data['expNext'], 100, 1e12));
    characterLevel = max(1, number(data['characterLevel'], 1, 1000).toInt());
    totalDestroyedBlocks = number(data['kills'], 0, 1e12).toInt();
    final ranks = data['upgrades'] as Map<String, dynamic>? ?? {};
    int rank(UpgradeType type) => number(
      ranks[type.name],
      0,
      UpgradeSpec.of(type).maxRank.toDouble(),
    ).toInt();
    damageUpgradeLevel = rank(UpgradeType.damage);
    speedUpgradeLevel = rank(UpgradeType.speed);
    rangeUpgradeLevel = rank(UpgradeType.range);
    bounceUpgradeLevel = rank(UpgradeType.bounce);
    magnetUpgradeLevel = rank(UpgradeType.magnet);
    spinUpgradeLevel = rank(UpgradeType.spin);
    resonanceUpgradeLevel = rank(UpgradeType.resonance);
    fusionCooldownUpgradeLevel = rank(UpgradeType.fusionCooldown);
    spirits.clear();
    spiritUpgradeLevel = 0;
    for (int n = 0; n < rank(UpgradeType.spirit); n++) {
      summonSpirit();
    }
    ownedElements
      ..clear()
      ..addAll(
        ElementData.baseElements
            .where(
              (e) => (data['elements'] as List? ?? []).contains(e.type.name),
            )
            .map((e) => e.type),
      );
    equippedElements
      ..clear()
      ..addAll(
        ownedElements
            .where((e) => (data['equipped'] as List? ?? []).contains(e.name))
            .take(maxEquippedElements),
      );
    activeFusions
      ..clear()
      ..addAll(
        ElementData.fusionElements
            .where(
              (e) =>
                  (data['fusions'] as List? ?? []).contains(e.type.name) &&
                  e.ingredients!.every(ownedElements.contains),
            )
            .map((e) => e.type),
      );
    selectedFusion = activeFusions
        .where((e) => e.name == data['selected'])
        .firstOrNull;
    final angle = atan2(player.transform.vy, player.transform.vx);
    player.transform.vx = cos(angle) * normalBallSpeed;
    player.transform.vy = sin(angle) * normalBallSpeed;
    impacts.clear();
    floatingTexts.clear();
  }

  Map<String, dynamic> exportSnapshot() => {
    'version': 1,
    'endless': isEndless,
    'levelId': level.id,
    'wave': endlessWave,
    'role': role.type.name,
    'race': race.type.name,
    'build': exportBuild(),
    'cells': blocks.map((b) {
      final a = b.elementAffinity!;
      return [
        b.health!.maxHp,
        b.health!.currentHp,
        b.isCorroded ? 1 : 0,
        a.burnTimer,
        a.burnDps,
        a.poisonTimer,
        a.poisonDps,
        a.frozenTimer,
        a.soakedTimer,
        a.shockTimer,
        a.voidTimer,
      ];
    }).toList(),
    'ball': [
      (player.transform.x - gridStartX) / (level.cols * gridBlockSize),
      (player.transform.y - gridStartY) / (level.rows * gridBlockSize),
      player.transform.vx,
      player.transform.vy,
      player.weaponAngle,
    ],
    'drops': drops
        .map(
          (d) => [
            d.type.index,
            d.value,
            (d.transform.x - gridStartX) / (level.cols * gridBlockSize),
            (d.transform.y - gridStartY) / (level.rows * gridBlockSize),
            d.lifeTime,
          ],
        )
        .toList(),
    'completed': isLevelCompleted,
    'waveWait': _waveWait,
    'cooldown': fusionCooldown,
    'firestorm': _firestormTimer,
    'spiritOrbits': spirits
        .map((spirit) => [spirit.angle, spirit.hitCooldown])
        .toList(),
    'attackCooldown': player.attackCooldown,
    'dashCooldown': dashCooldown,
    if (pendingFusion != null)
      'pending': {
        'type': pendingFusion!.type.name,
        'target': pendingFusion!.targetId,
        'age': pendingFusion!.age,
      },
  };

  void restoreSnapshot(Map<String, dynamic> data) {
    if (data['version'] != 1 || data['endless'] != isEndless) {
      throw const FormatException('Invalid run');
    }
    if (isEndless) {
      endlessWave = (data['wave'] as int).clamp(1, 1000000);
      level = MemeLevel.endlessWave(endlessWave);
    } else if (data['levelId'] != level.id) {
      throw const FormatException('Wrong stage');
    }
    restoreBuild(Map<String, dynamic>.from(data['build'] as Map));
    isGridBuilt = true;
    _buildPixelGrid();
    final cells = data['cells'] as List;
    if (cells.length != blocks.length) {
      throw const FormatException('Wrong grid');
    }
    double numAt(List values, int index) {
      final value = values[index];
      if (value is! num || !value.isFinite) {
        throw const FormatException('Invalid number');
      }
      return max(0, value.toDouble());
    }

    for (int index = 0; index < cells.length; index++) {
      final values = cells[index] as List;
      final block = blocks[index];
      final a = block.elementAffinity!;
      block.health!.maxHp = max(1, numAt(values, 0));
      block.health!.currentHp = block.isCenterEmpty
          ? 0
          : min(block.health!.maxHp, numAt(values, 1));
      block.health!.isDestroyed = block.health!.currentHp <= 0;
      block.isRevealed = block.health!.isDestroyed;
      block.isCorroded = values[2] == 1;
      a.burnTimer = numAt(values, 3);
      a.burnDps = numAt(values, 4);
      a.poisonTimer = numAt(values, 5);
      a.poisonDps = numAt(values, 6);
      a.frozenTimer = numAt(values, 7);
      a.isFrozen = a.frozenTimer > 0;
      a.soakedTimer = numAt(values, 8);
      a.isSoaked = a.soakedTimer > 0;
      a.shockTimer = numAt(values, 9);
      a.voidTimer = numAt(values, 10);
    }
    final ball = data['ball'] as List;
    player.transform.position = Offset(
      gridStartX +
          (ball[0] as num).toDouble().clamp(0, 1) * level.cols * gridBlockSize,
      gridStartY +
          (ball[1] as num).toDouble().clamp(0, 1) * level.rows * gridBlockSize,
    );
    player.transform.vx = (ball[2] as num).toDouble().clamp(-360, 360);
    player.transform.vy = (ball[3] as num).toDouble().clamp(-360, 360);
    player.weaponAngle = (ball[4] as num).toDouble();
    player.trail.clear();
    drops.clear();
    for (final raw in (data['drops'] as List? ?? []).take(maxDrops)) {
      final d = raw as List;
      drops.add(
        DropItem(
          id: 'saved_${drops.length}',
          type: DropType.values[(d[0] as int).clamp(0, 1)],
          value: numAt(d, 1),
          transform: TransformComponent(
            x:
                gridStartX +
                numAt(d, 2).clamp(0, 1) * level.cols * gridBlockSize,
            y:
                gridStartY +
                numAt(d, 3).clamp(0, 1) * level.rows * gridBlockSize,
          ),
        )..lifeTime = numAt(d, 4),
      );
    }
    fusionCooldown = (data['cooldown'] as num? ?? 0).toDouble().clamp(
      0,
      fusionCooldownDuration,
    );
    _firestormTimer = (data['firestorm'] as num? ?? 0).toDouble().clamp(0, 4);
    brokenBlocksCount = actualBrokenBlocksCount;
    completionPercent = (brokenBlocksCount / totalBlocksCount).clamp(0, 1);
    isLevelCompleted = completionPercent >= 1;
    _waveWait = (data['waveWait'] as num? ?? 1.4).toDouble().clamp(0, 1.4);
    final orbits = data['spiritOrbits'] as List? ?? [];
    for (int i = 0; i < min(orbits.length, spirits.length); i++) {
      spirits[i].angle = ((orbits[i] as List)[0] as num).toDouble();
      spirits[i].hitCooldown = ((orbits[i] as List)[1] as num).toDouble().clamp(
        0,
        OrbitingSpirit.contactCooldown,
      );
    }
    player.attackCooldown = (data['attackCooldown'] as num? ?? 0)
        .toDouble()
        .clamp(0, 10);
    dashCooldown = (data['dashCooldown'] as num? ?? 0).toDouble().clamp(0, 1.2);
    final pending = data['pending'] as Map?;
    if (pending != null && !isLevelCompleted) {
      final type = activeFusions
          .where((e) => e.name == pending['type'])
          .firstOrNull;
      final target = blocks.where((b) => b.id == pending['target']).firstOrNull;
      if (type != null && target != null) {
        pendingFusion = FusionCast(
          type: type,
          center: target.transform.position,
          color: ElementData.fusionElements
              .firstWhere((e) => e.type == type)
              .color,
          targetId: target.id,
          board: Rect.fromLTWH(
            gridStartX,
            gridStartY,
            level.cols * gridBlockSize,
            level.rows * gridBlockSize,
          ),
        )..age = (pending['age'] as num).toDouble().clamp(0, FusionCast.windup);
        fusionCasts.add(pendingFusion!);
      }
    }
    _handleBallBorderCollision();
  }
}
