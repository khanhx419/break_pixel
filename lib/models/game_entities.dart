import 'dart:math';

import 'package:flutter/material.dart';

import 'ecs.dart';
import 'character.dart';

/// Khối Pixel To (Chunky Pixel Block)
class PixelBlock extends GameEntity {
  final int col;
  final int row;
  final Color memeColor;
  final bool isCenterEmpty;
  bool isRevealed = false;
  double hitFlashTimer = 0.0;

  PixelBlock({
    required super.id,
    required super.transform,
    required super.health,
    required super.elementAffinity,
    required super.render,
    required this.col,
    required this.row,
    required this.memeColor,
    this.isCenterEmpty = false,
  });

  bool takeDamage(double damage) {
    if (elementAffinity?.isFrozen ?? false) damage *= 1.5;
    if ((elementAffinity?.shockTimer ?? 0) > 0) damage *= 1.25;
    return health!.takeDamage(damage);
  }

  @override
  void update(double dt) {
    if (hitFlashTimer > 0) hitFlashTimer -= dt;

    // Sát thương theo thời gian từ Lửa (Burn) hoặc Độc (Poison)
    if (elementAffinity != null) {
      if (elementAffinity!.burnTimer > 0) {
        takeDamage(
          elementAffinity!.burnDps * min(dt, elementAffinity!.burnTimer),
        );
      }
      if (elementAffinity!.poisonTimer > 0) {
        takeDamage(
          elementAffinity!.poisonDps * min(dt, elementAffinity!.poisonTimer),
        );
      }
    }
    elementAffinity?.update(dt);
  }

  @override
  void draw(Canvas canvas, Paint paint, {double time = 0}) {
    if (health?.isDestroyed ?? false) return;
    final cell = transform.rect;
    final unit = cell.width;
    final rect = cell.deflate(min(0.6, unit * 0.045));
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(unit * 0.09));
    final affinity = elementAffinity;
    final frozen = affinity?.isFrozen ?? false;
    final wet = affinity?.isSoaked ?? false;
    final burning = (affinity?.burnTimer ?? 0) > 0;
    final poisoned = (affinity?.poisonTimer ?? 0) > 0;
    final shocked = (affinity?.shockTimer ?? 0) > 0;
    final phase = time * 2.4 + row * 0.7 + col * 1.3;
    var face = (row + col) % 2 == 0
        ? const Color(0xFF27384B)
        : const Color(0xFF2C3C50);
    if (wet) face = Color.lerp(face, const Color(0xFF267A9B), 0.35)!;
    if (poisoned) face = Color.lerp(face, const Color(0xFF668A41), 0.35)!;
    if (burning) face = Color.lerp(face, const Color(0xFF9B432B), 0.48)!;
    if (frozen) face = Color.lerp(face, const Color(0xFF8BC7DC), 0.55)!;
    if (shocked) face = Color.lerp(face, const Color(0xFFBDA669), 0.24)!;
    if (hitFlashTimer > 0)
      face = Color.lerp(
        face,
        Colors.white,
        (hitFlashTimer / 0.1).clamp(0, 1) * 0.45,
      )!;

    paint
      ..shader = null
      ..maskFilter = null
      ..style = PaintingStyle.fill
      ..color = face;
    canvas.drawRRect(shape, paint);
    // A restrained bevel keeps the material readable underneath every status.
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.5, unit * 0.045)
      ..color = Colors.white.withValues(alpha: frozen ? 0.35 : 0.12);
    canvas.drawLine(
      rect.topLeft + Offset(unit * 0.12, unit * 0.08),
      rect.topRight + Offset(-unit * 0.12, unit * 0.08),
      paint,
    );
    paint.color = Colors.black.withValues(alpha: 0.22);
    canvas.drawLine(
      rect.bottomLeft + Offset(unit * 0.1, -unit * 0.05),
      rect.bottomRight + Offset(-unit * 0.1, -unit * 0.05),
      paint,
    );

    if (wet) {
      final surface = rect.bottom - unit * (0.2 + sin(phase) * 0.04);
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0x4447C4E6);
      canvas.drawRect(
        Rect.fromLTRB(rect.left, surface, rect.right, rect.bottom),
        paint,
      );
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.6, unit * 0.045)
        ..color = const Color(0xAA9DE7F2);
      canvas.drawLine(
        Offset(rect.left + unit * 0.1, surface),
        Offset(rect.right - unit * 0.1, surface),
        paint,
      );
    }
    if (frozen) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.6, unit * 0.055)
        ..color = const Color(0xBBB9EAF2);
      canvas.drawRRect(shape, paint);
      final center = rect.center;
      canvas.drawLine(
        center + Offset(-unit * 0.28, -unit * 0.27),
        center + Offset(unit * 0.2, unit * 0.24),
        paint,
      );
      canvas.drawLine(
        center + Offset(unit * 0.02, -unit * 0.02),
        center + Offset(unit * 0.23, -unit * 0.2),
        paint,
      );
    }
    if (burning) {
      // Two small, animated ember tongues; no particle emitter per tile.
      paint.style = PaintingStyle.stroke;
      paint.strokeCap = StrokeCap.round;
      for (int i = 0; i < 2; i++) {
        final x = rect.left + unit * (0.32 + i * 0.34);
        final lift = unit * (0.12 + (sin(phase * 1.8 + i * 2) + 1) * 0.07);
        paint
          ..strokeWidth = unit * 0.13
          ..color = const Color(0xDDF08D49);
        canvas.drawLine(
          Offset(x, rect.top + unit * 0.24),
          Offset(x + unit * 0.04, rect.top + unit * 0.24 - lift),
          paint,
        );
        paint
          ..strokeWidth = unit * 0.055
          ..color = const Color(0xFFF9D38B);
        canvas.drawLine(
          Offset(x, rect.top + unit * 0.24),
          Offset(x, rect.top + unit * 0.13),
          paint,
        );
      }
      paint.strokeCap = StrokeCap.butt;
    }
    if (poisoned) {
      paint.style = PaintingStyle.fill;
      for (int i = 0; i < 2; i++) {
        final drift = (time * 0.5 + i * 0.47 + (row % 3) * 0.13) % 1;
        paint.color = const Color(0xFFACCA77)
            .withValues(alpha: (1 - drift) * 0.7);
        canvas.drawCircle(
          Offset(
            rect.left + unit * (0.3 + i * 0.35),
            rect.bottom - unit * (0.15 + drift * 0.5),
          ),
          unit * 0.07,
          paint,
        );
      }
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.5, unit * 0.04)
        ..color = const Color(0xAA9D81B9);
      canvas.drawLine(
        rect.bottomLeft + Offset(unit * 0.15, -unit * 0.1),
        rect.bottomRight + Offset(-unit * 0.15, -unit * 0.1),
        paint,
      );
    }
    if (shocked && sin(phase * 3) > -0.35) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.7, unit * 0.07)
        ..color = const Color(0xFFF6DF9A);
      final center = rect.center;
      canvas.drawLine(
        center + Offset(-unit * 0.16, -unit * 0.28),
        center + Offset(unit * 0.08, -unit * 0.02),
        paint,
      );
      canvas.drawLine(
        center + Offset(unit * 0.08, -unit * 0.02),
        center + Offset(-unit * 0.08, unit * 0.04),
        paint,
      );
      canvas.drawLine(
        center + Offset(-unit * 0.08, unit * 0.04),
        center + Offset(unit * 0.18, unit * 0.27),
        paint,
      );
    }
    if ((health?.hpPercent ?? 1) < 0.65) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.5, unit * 0.045)
        ..color = const Color(0xAA0C1726);
      canvas.drawLine(
        rect.center + Offset(-unit * 0.2, -unit * 0.15),
        rect.center,
        paint,
      );
      canvas.drawLine(
        rect.center,
        rect.center + Offset(-unit * 0.06, unit * 0.27),
        paint,
      );
    }
    paint.style = PaintingStyle.fill;
  }
}

/// Nhân vật Quả Cầu 3D mượt mà
class PlayerBall extends GameEntity {
  final RoleInfo role;
  final RaceInfo race;
  double radius;
  double weaponAngle = 0.0;
  double attackCooldown = 0.0;
  double spinMultiplier = 1.0;
  final List<Offset> trail = [];

  PlayerBall({
    required super.id,
    required super.transform,
    required this.role,
    required this.race,
    this.radius = 16.0,
  }) {
    // Buff kích thước của Yeti (+25%)
    if (race.type == RaceType.yeti) {
      radius *= 1.25;
      transform.width = radius * 2;
      transform.height = radius * 2;
    }
  }

  @override
  void update(double dt) {
    transform.x += transform.vx * dt;
    transform.y += transform.vy * dt;

    // Lưu vệt chuyển động sao chổi
    trail.insert(0, Offset(transform.x, transform.y));
    if (trail.length > 8) trail.removeLast();

    // Xoay vũ khí (nhân thêm hệ số xoay cuồng nộ)
    final speedMultiplier = race.speedMultiplier;
    weaponAngle +=
        (role.attackSpeed * speedMultiplier * 4.5 * spinMultiplier) * dt;
    if (weaponAngle > 2 * pi) weaponAngle -= 2 * pi;

    if (attackCooldown > 0) attackCooldown -= dt;
  }

  @override
  void draw(Canvas canvas, Paint paint) {
    final center = transform.position;

    // 0. Vẽ vệt chuyển động sao chổi phía sau bóng (Comet Motion Trail)
    for (int i = trail.length - 1; i >= 0; i--) {
      final tPos = trail[i];
      final tProgress = 1.0 - (i / trail.length);
      final tAlpha = tProgress * 0.35;
      final tRadius = radius * (0.4 + 0.6 * tProgress);
      final trailPaint = Paint()..color = role.themeColor.withOpacity(tAlpha);
      canvas.drawCircle(tPos, tRadius, trailPaint);
    }

    // 1. Nếu là Tộc Yeti: Vẽ hào quang băng giá (Frost Aura)
    if (race.type == RaceType.yeti) {
      final auraPaint = Paint()
        ..color = Colors.cyanAccent.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(center, radius + 12, auraPaint);
    }

    // 2. Vẽ quả cầu bóng bẩy theo phong cách 3D (RadialGradient tương phản với thế giới pixel)
    final gradient = RadialGradient(
      center: const Alignment(-0.35, -0.4),
      radius: 0.85,
      colors: [
        Colors.white,
        role.themeColor,
        Color.lerp(role.themeColor, Colors.black, 0.65)!,
      ],
      stops: const [0.0, 0.45, 1.0],
    );

    final sphereRect = Rect.fromCircle(center: center, radius: radius);
    paint.shader = gradient.createShader(sphereRect);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);
    paint.shader = null;

    // 3. Viền ánh sáng mượt mà
    paint.color = Colors.white.withOpacity(0.6);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawCircle(center, radius, paint);
  }
}

/// Mũi tên của Cung thủ
class ArrowEntity extends GameEntity {
  final double damage;
  final Set<String> hitBlocks = {};
  int pierceCount;
  double lifeTime;

  ArrowEntity({
    required super.id,
    required super.transform,
    required this.damage,
    this.pierceCount = 3,
    this.lifeTime = 2.0,
  });

  @override
  void update(double dt) {
    transform.x += transform.vx * dt;
    transform.y += transform.vy * dt;
    lifeTime -= dt;
  }

  @override
  void draw(Canvas canvas, Paint paint) {
    final center = transform.position;
    final angle = atan2(transform.vy, transform.vx);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    paint.color = Colors.greenAccent;
    paint.strokeWidth = 2.5;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(-10, 0), const Offset(10, 0), paint);

    // Mũi tên nhọn
    paint.color = Colors.white;
    canvas.drawLine(const Offset(10, 0), const Offset(5, -4), paint);
    canvas.drawLine(const Offset(10, 0), const Offset(5, 4), paint);

    canvas.restore();
  }
}

/// Móc câu của Người đánh cá
class HookEntity extends GameEntity {
  final double damage;
  double distanceTravelled = 0.0;
  bool isReturning = false;
  Offset origin;
  final Set<String> outboundHits = {};
  final Set<String> returnHits = {};

  HookEntity({
    required super.id,
    required super.transform,
    required this.damage,
    required this.origin,
  });

  @override
  void update(double dt) {
    if (!isReturning) {
      transform.x += transform.vx * dt;
      transform.y += transform.vy * dt;
      distanceTravelled += 300 * dt;
      if (distanceTravelled > 140) isReturning = true;
    } else {
      final dx = origin.dx - transform.x;
      final dy = origin.dy - transform.y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist > 5) {
        transform.x += (dx / dist) * min(dist, 450 * dt);
        transform.y += (dy / dist) * min(dist, 450 * dt);
      }
    }
  }

  @override
  void draw(Canvas canvas, Paint paint) {
    // Dây câu nối từ origin đến đầu móc
    paint.color = Colors.cyanAccent.withOpacity(0.5);
    paint.strokeWidth = 1.0;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(origin, transform.position, paint);

    // Đầu móc câu
    paint.color = Colors.cyanAccent;
    paint.strokeWidth = 2.5;
    canvas.drawCircle(transform.position, 4, paint);
  }
}

/// Vật phẩm rơi (Vàng & Ngọc EXP)
enum DropType { gold, exp }

class DropItem extends GameEntity {
  final DropType type;
  double value;
  double lifeTime = 15.0;

  DropItem({
    required super.id,
    required super.transform,
    required this.type,
    required this.value,
  });

  @override
  void update(double dt) {
    // Giảm dần vận tốc rơi tự do
    transform.vx *= 0.95;
    transform.vy *= 0.95;
    transform.x += transform.vx * dt;
    transform.y += transform.vy * dt;
    lifeTime -= dt;
  }

  @override
  void draw(Canvas canvas, Paint paint) {
    final pos = transform.position;
    if (type == DropType.gold) {
      // Đồng tiền vàng lấp lánh
      paint.color = Colors.amber;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(pos, 5, paint);
      paint.color = Colors.white;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.0;
      canvas.drawCircle(pos, 5, paint);
    } else {
      // Ngọc EXP xanh lục/lam đa giác
      paint.color = Colors.cyanAccent;
      paint.style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(pos.dx, pos.dy - 6)
        ..lineTo(pos.dx + 5, pos.dy)
        ..lineTo(pos.dx, pos.dy + 6)
        ..lineTo(pos.dx - 5, pos.dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }
}

/// Vòng sóng xung kích phát sáng nổ bung khi khối pixel vỡ
class ShockwaveRing {
  Offset center;
  double radius = 4.0;
  double maxRadius = 48.0;
  Color color;
  double lifeTime = 0.28;
  double currentLife = 0.28;

  ShockwaveRing({required this.center, required this.color});

  bool update(double dt) {
    currentLife -= dt;
    final progress = 1.0 - (currentLife / lifeTime).clamp(0.0, 1.0);
    radius = 4.0 + (maxRadius - 4.0) * progress;
    return currentLife <= 0;
  }

  void draw(Canvas canvas, Paint paint) {
    final alpha = (currentLife / lifeTime).clamp(0.0, 1.0);
    paint.color = color.withOpacity(alpha * 0.8);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3.0 * alpha;
    canvas.drawCircle(center, radius, paint);
  }
}

/// Hạt vỡ Pixel nổ tung sống động có góc xoay và trọng lực
class PixelDebris {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double alpha = 1.0;
  double lifeTime = 0.65;
  double maxLife = 0.65;
  double rotation = 0.0;
  double rotSpeed;
  bool isSparkle;

  PixelDebris({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    this.rotSpeed = 0.0,
    this.isSparkle = false,
  });

  bool update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 190 * dt; // Trọng lực nhẹ rơi xuống
    rotation += rotSpeed * dt;
    lifeTime -= dt;
    alpha = (lifeTime / maxLife).clamp(0.0, 1.0);
    return lifeTime <= 0;
  }

  void draw(Canvas canvas, Paint paint) {
    paint.color = color.withOpacity(alpha);
    paint.style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rotation);
    if (isSparkle) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset.zero, size * 0.8, paint);
      paint.maskFilter = null;
    } else {
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: size, height: size),
        paint,
      );
    }
    canvas.restore();
  }
}

/// Chữ số sát thương / Trạng thái bay lên
class FloatingText {
  String text;
  double x;
  double y;
  Color color;
  double lifeTime = 0.8;
  double alpha = 1.0;

  FloatingText({
    required this.text,
    required this.x,
    required this.y,
    required this.color,
  });

  bool update(double dt) {
    y -= 38 * dt; // Bay lên trên
    lifeTime -= dt;
    alpha = (lifeTime / 0.8).clamp(0.0, 1.0);
    return lifeTime <= 0;
  }
}

/// Đám mây sương mù gây DoT (Mist Cloud - Dung hợp Hỏa + Thủy)
class MistZone {
  Offset center;
  double radius;
  double duration;
  double damagePerSec;

  MistZone({
    required this.center,
    this.radius = 80.0,
    this.duration = 4.0,
    this.damagePerSec = 15.0,
  });

  bool update(double dt) {
    duration -= dt;
    return duration <= 0;
  }

  void draw(Canvas canvas, Paint paint) {
    final fade = (duration / 0.7).clamp(0.0, 1.0);
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFBFCDD2).withValues(alpha: fade * 0.09);
    for (int i = 0; i < 3; i++) {
      final drift = sin(duration * 1.2 + i * 2) * radius * 0.12;
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(drift, (i - 1) * radius * 0.2),
          width: radius * (1.5 - i * 0.15),
          height: radius * 0.75,
        ),
        paint,
      );
    }
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFCCE4E6).withValues(alpha: fade * 0.25);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.8),
      duration * 0.4,
      2.4,
      false,
      paint,
    );
    paint.style = PaintingStyle.fill;
  }
}

/// Tinh Linh Hộ Vệ bay xoay quanh Quả cầu người chơi
class OrbitingSpirit {
  final String id;
  ElementType element;
  double orbitRadius;
  double angle;
  double orbitSpeed; // radians per second
  Color color;
  double size;
  final List<Offset> trail = [];

  OrbitingSpirit({
    required this.id,
    this.element = ElementType.fire,
    this.orbitRadius = 52.0,
    this.angle = 0.0,
    this.orbitSpeed = 3.8,
    required this.color,
    this.size = 8.0,
  });

  void update(double dt, Offset center) {
    angle += orbitSpeed * dt;
    if (angle > 2 * pi) angle -= 2 * pi;

    final currentPos = getPosition(center);
    trail.insert(0, currentPos);
    if (trail.length > 6) trail.removeLast();
  }

  Offset getPosition(Offset center) {
    return Offset(
      center.dx + cos(angle) * orbitRadius,
      center.dy + sin(angle) * orbitRadius,
    );
  }

  void draw(Canvas canvas, Paint paint, Offset center) {
    final pos = getPosition(center);

    // Vệt sáng theo sau tinh linh
    for (int i = trail.length - 1; i >= 0; i--) {
      final tPos = trail[i];
      final prog = 1.0 - (i / trail.length);
      final trailPaint = Paint()..color = color.withOpacity(prog * 0.35);
      canvas.drawCircle(tPos, size * (0.4 + prog * 0.5), trailPaint);
    }

    // Hào quang tinh linh
    final glowPaint = Paint()..color = color.withOpacity(0.55);
    canvas.drawCircle(pos, size * 1.6, glowPaint);

    // Lõi tinh linh phát sáng
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(pos, size * 0.6, paint);

    paint.color = color;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;
    canvas.drawCircle(pos, size, paint);
  }
}

/// Tia sét điện giật ngoằn ngoèo chân thực
class LightningArc {
  final List<Offset> points;
  final Color color;
  late final Path _path = Path()..addPolygon(points, false);
  double lifeTime;
  final double maxLife;

  LightningArc({
    required this.points,
    required this.color,
    this.lifeTime = 0.16,
  }) : maxLife = lifeTime;

  bool update(double dt) {
    lifeTime -= dt;
    return lifeTime <= 0;
  }

  void draw(Canvas canvas, Paint paint) {
    if (points.length < 2) return;
    final alpha = (lifeTime / maxLife).clamp(0.0, 1.0);
    paint
      ..shader = null
      ..maskFilter = null
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0
      ..color = color.withValues(alpha: alpha * 0.35);
    canvas.drawPath(_path, paint);
    paint
      ..strokeWidth = 1.1
      ..color = const Color(0xFFFFF1CE).withValues(alpha: alpha * 0.95);
    canvas.drawPath(_path, paint);
    paint
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.fill;
  }

  static LightningArc createZigzag(Offset start, Offset end, Color color) {
    final List<Offset> pts = [start];
    final dist = (end - start).distance;
    final segments = (dist / 14.0).clamp(3, 10).toInt();
    final rng = Random();

    for (int i = 1; i < segments; i++) {
      final t = i / segments;
      final interp = Offset(
        start.dx + (end.dx - start.dx) * t,
        start.dy + (end.dy - start.dy) * t,
      );
      // Độ lệch zigzag vuông góc
      final perpX = -(end.dy - start.dy) / (dist > 0 ? dist : 1);
      final perpY = (end.dx - start.dx) / (dist > 0 ? dist : 1);
      final offsetDist = (rng.nextDouble() - 0.5) * 16.0;
      pts.add(
        Offset(interp.dx + perpX * offsetDist, interp.dy + perpY * offsetDist),
      );
    }
    pts.add(end);
    return LightningArc(points: pts, color: color);
  }
}

/// A persistent lightning field; tiles stay aligned with their hidden artwork.
class VoidVortexZone {
  final Offset center;
  double life = 2.5;
  double pulse = 0.5;

  VoidVortexZone(this.center);

  void draw(Canvas canvas) {
    final paint = Paint()..color = const Color(0xBB140B26);
    canvas.drawCircle(center, 18, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.purpleAccent.withValues(alpha: (life / 2.5).clamp(0, 1));
    for (int i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 22.0 + i * 9),
        life * 4 + i * 2,
        1.6,
        false,
        paint,
      );
    }
  }
}
