import 'dart:math';
import 'package:flutter/material.dart';
import 'ecs.dart';
import 'character.dart';

/// Khối Pixel To (Chunky Pixel Block)
class PixelBlock extends GameEntity {
  final int col;
  final int row;
  final Color memeColor;
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
  });

  @override
  void update(double dt) {
    if (hitFlashTimer > 0) hitFlashTimer -= dt;
    elementAffinity?.update(dt);
    // Sát thương theo thời gian từ Lửa (Burn) hoặc Độc (Poison)
    if (elementAffinity != null) {
      if (elementAffinity!.burnTimer > 0) {
        health?.takeDamage(elementAffinity!.burnDps * dt);
      }
      if (elementAffinity!.poisonTimer > 0) {
        health?.takeDamage(elementAffinity!.poisonDps * dt);
      }
    }
  }

  @override
  void draw(Canvas canvas, Paint paint) {
    if (health?.isDestroyed ?? false) return;

    final rect = transform.rect;
    final r = RRect.fromRectAndRadius(rect.deflate(1.5), const Radius.circular(3));

    // Hiệu ứng chớp sáng trắng khi bị đánh trúng (Hit Flash)
    if (hitFlashTimer > 0) {
      paint.color = Colors.white;
      paint.style = PaintingStyle.fill;
      canvas.drawRRect(r, paint);
      return;
    }

    // Nếu bị đóng băng
    if (elementAffinity?.isFrozen ?? false) {
      paint.color = Colors.lightBlueAccent.withOpacity(0.9);
      paint.style = PaintingStyle.fill;
      canvas.drawRRect(r, paint);
      // Viền tuyết
      paint.color = Colors.white;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.5;
      canvas.drawRRect(r, paint);
      return;
    }

    // Nếu đang bị đốt cháy
    if (elementAffinity?.burnTimer != null && elementAffinity!.burnTimer > 0) {
      paint.color = Colors.deepOrangeAccent;
      paint.style = PaintingStyle.fill;
      canvas.drawRRect(r, paint);
      return;
    }

    // Nếu đang bị nhiễm độc
    if (elementAffinity?.poisonTimer != null && elementAffinity!.poisonTimer > 0) {
      paint.color = Colors.greenAccent.shade700;
      paint.style = PaintingStyle.fill;
      canvas.drawRRect(r, paint);
      return;
    }

    // Màu thường: Gạch bảo vệ có màu đá/kim loại cứng cáp
    final hpPct = health?.hpPercent ?? 1.0;
    // Khi bị nứt/mất máu thì hơi chuyển dần sang màu của meme bên dưới
    final displayColor = Color.lerp(memeColor, const Color(0xFF333A42), hpPct * 0.75 + 0.25)!;

    paint.color = displayColor;
    paint.style = PaintingStyle.fill;
    canvas.drawRRect(r, paint);

    // Viền khối pixel đậm chất retro
    paint.color = Colors.white.withOpacity(0.18);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.0;
    canvas.drawRRect(r, paint);

    // Vẽ vết nứt nếu mất hơn 30% máu
    if (hpPct < 0.7) {
      paint.color = Colors.black.withOpacity(0.35);
      paint.strokeWidth = 1.2;
      canvas.drawLine(
        Offset(rect.left + 5, rect.top + 5),
        Offset(rect.center.dx, rect.center.dy),
        paint,
      );
      if (hpPct < 0.4) {
        canvas.drawLine(
          Offset(rect.center.dx, rect.center.dy),
          Offset(rect.right - 4, rect.bottom - 4),
          paint,
        );
      }
    }
  }
}

/// Nhân vật Quả Cầu 3D mượt mà
class PlayerBall extends GameEntity {
  final RoleInfo role;
  final RaceInfo race;
  double radius;
  double weaponAngle = 0.0;
  double attackCooldown = 0.0;
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

    // Xoay vũ khí
    final speedMultiplier = race.speedMultiplier;
    weaponAngle += (role.attackSpeed * speedMultiplier * 4.5) * dt;
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
      final trailPaint = Paint()
        ..color = role.themeColor.withOpacity(tAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
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
  final Offset origin;

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
        transform.x += (dx / dist) * 450 * dt;
        transform.y += (dy / dist) * 450 * dt;
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
  final double value;
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
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: size, height: size), paint);
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
    final cloudPaint = Paint()
      ..color = Colors.blueGrey.withOpacity(0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, radius, cloudPaint);
  }
}
