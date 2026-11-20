import 'dart:math';

import 'package:flutter/material.dart';

import 'ecs.dart';
import 'character.dart';
import 'stage_theme.dart';

enum BlockSpecialType {
  none,
  explosiveCrystal, // Tinh thể nổ 3x3
  energyCore, // Lõi năng lượng hồi cooldown Dung Hợp & Lướt
  magnetBeacon, // Từ trường hút toàn bản đồ
  overdriveRune, // Cổ ngữ kích hoạt Cuồng Nộ
}

/// Khối Pixel To (Chunky Pixel Block)
class PixelBlock extends GameEntity {
  // Normalized geometry is shared by every tile, rather than allocated per frame.
  static final Path _topFacet = Path()
    ..moveTo(0.08, 0)
    ..lineTo(0.92, 0)
    ..lineTo(0.84, 0.16)
    ..lineTo(0.16, 0.16)
    ..close();
  static final Path _leftFacet = Path()
    ..moveTo(0, 0.08)
    ..lineTo(0.14, 0.16)
    ..lineTo(0.14, 0.84)
    ..lineTo(0, 0.92)
    ..close();
  static final Path _sideFacet = Path()
    ..moveTo(1, 0.08)
    ..lineTo(1, 0.92)
    ..lineTo(0.84, 0.84)
    ..lineTo(0.84, 0.16)
    ..close();
  static final Path _bottomFacet = Path()
    ..moveTo(0.08, 1)
    ..lineTo(0.92, 1)
    ..lineTo(0.84, 0.85)
    ..lineTo(0.16, 0.85)
    ..close();
  static final Path _crystalFacet = Path()
    ..moveTo(0.22, 0.2)
    ..lineTo(0.62, 0.24)
    ..lineTo(0.32, 0.78)
    ..close();
  static final Path _crystalSheen = Path()
    ..moveTo(0.62, 0.24)
    ..lineTo(0.78, 0.56)
    ..lineTo(0.48, 0.76)
    ..close();
  final int col;
  final int row;
  final Color memeColor;
  final bool isCenterEmpty;
  final BlockSpecialType specialType;
  bool isRevealed = false;
  bool isCorroded = false;
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
    this.specialType = BlockSpecialType.none,
  });

  bool takeDamage(double damage) {
    damage *= elementAffinity?.damageMultiplier ?? 1;
    if ((elementAffinity?.voidTimer ?? 0) > 0 && health!.hpPercent < 0.35) {
      damage *= 1.12;
    }
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
  void draw(Canvas canvas, Paint paint, {double time = 0, StageTheme? theme}) {
    if (health?.isDestroyed ?? false) return;
    final cell = transform.rect;
    final unit = cell.width;
    final rect = cell.deflate(min(0.65, unit * 0.042));
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(unit * 0.11));
    final skin = theme ?? StageTheme.all.first;
    final affinity = elementAffinity;
    final frozen = affinity?.isFrozen ?? false;
    final wet = affinity?.isSoaked ?? false;
    final burning = (affinity?.burnTimer ?? 0) > 0;
    final poisoned = (affinity?.poisonTimer ?? 0) > 0;
    final shocked = (affinity?.shockTimer ?? 0) > 0;
    final voided = (affinity?.voidTimer ?? 0) > 0;
    final phase = time * 2.6 + row * 0.7 + col * 1.3;
    final hash = (row * 37 + col * 17) % 11;

    var face = Color.lerp(skin.tile, skin.edge, 0.08 + hash * 0.013)!;
    if (wet) face = Color.lerp(face, const Color(0xFF1D7FA8), 0.38)!;
    if (poisoned) face = Color.lerp(face, const Color(0xFF568B33), 0.42)!;
    if (burning) face = Color.lerp(face, const Color(0xFFB53E20), 0.52)!;
    if (frozen) face = Color.lerp(face, const Color(0xFF7FD1EC), 0.62)!;
    if (shocked) face = Color.lerp(face, const Color(0xFFD2B256), 0.28)!;
    if (voided) face = Color.lerp(face, const Color(0xFF523285), 0.36)!;
    if (hitFlashTimer > 0) {
      face = Color.lerp(
        face,
        const Color(0xFFFFF8E7),
        (hitFlashTimer / 0.1).clamp(0, 1) * 0.68,
      )!;
    }

    paint
      ..shader = null
      ..maskFilter = null
      ..style = PaintingStyle.fill;

    // Sculpted 3D base ledge for tactile block depth
    paint.color = Color.lerp(skin.edge, Colors.black, 0.28)!;
    canvas.drawRRect(shape.shift(Offset(0, unit * 0.065)), paint);

    // Main tile face
    paint.color = face;
    canvas.drawRRect(shape, paint);

    // 4-sided 3D chisel bevel facets
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width, rect.height);
    paint.color = Color.lerp(
      face,
      frozen ? Colors.white : skin.accent,
      frozen ? 0.56 : 0.32,
    )!;
    canvas.drawPath(_topFacet, paint);
    paint.color = Color.lerp(face, skin.accent, 0.14)!;
    canvas.drawPath(_leftFacet, paint);
    paint.color = Color.lerp(face, skin.edge, 0.55)!;
    canvas.drawPath(_sideFacet, paint);
    paint.color = Color.lerp(face, skin.edge, 0.72)!;
    canvas.drawPath(_bottomFacet, paint);
    canvas.restore();

    // Crisp outer rim + top specular glint
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.5, unit * 0.028)
      ..color = Colors.black.withValues(alpha: 0.34);
    canvas.drawRRect(shape, paint);

    final cut = unit * 0.13;
    paint
      ..strokeWidth = max(0.55, unit * 0.035)
      ..color = Color.lerp(skin.accent, Colors.white, 0.45)!
          .withValues(alpha: frozen ? 0.65 : 0.34);
    canvas.drawLine(
      rect.topLeft + Offset(cut, unit * 0.075),
      rect.topRight + Offset(-cut, unit * 0.075),
      paint,
    );

    // Deterministic material micro-textures (never samples memeColor)
    if (unit >= 8.5 && !frozen) {
      paint.style = PaintingStyle.fill;
      switch (skin.material) {
        case BlockMaterial.stone:
          paint.color = skin.accent.withValues(alpha: 0.1);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                rect.left + unit * 0.22,
                rect.top + unit * (0.34 + hash * 0.015),
                unit * 0.2,
                unit * 0.055,
              ),
              Radius.circular(unit * 0.02),
            ),
            paint,
          );
          if (hash % 3 == 0) {
            paint.color = skin.edge.withValues(alpha: 0.4);
            canvas.drawRect(
              Rect.fromLTWH(
                rect.left + unit * 0.6,
                rect.top + unit * 0.62,
                unit * 0.12,
                unit * 0.07,
              ),
              paint,
            );
          }
        case BlockMaterial.moss:
          paint.color = skin.accent.withValues(alpha: 0.18);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                rect.left + unit * 0.14,
                rect.top + unit * 0.22,
                unit * 0.22,
                unit * 0.1,
              ),
              Radius.circular(unit * 0.04),
            ),
            paint,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                rect.left + unit * 0.18,
                rect.top + unit * 0.3,
                unit * 0.09,
                unit * 0.18,
              ),
              Radius.circular(unit * 0.04),
            ),
            paint,
          );
          if (hash % 2 == 0) {
            paint.color = Colors.white.withValues(alpha: 0.16);
            canvas.drawCircle(
              rect.topLeft + Offset(unit * 0.22, unit * 0.26),
              unit * 0.028,
              paint,
            );
          }
        case BlockMaterial.alloy:
          // Brushed panel seam & metallic rivets
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(0.55, unit * 0.03)
            ..color = skin.edge.withValues(alpha: 0.55);
          canvas.drawLine(
            rect.topLeft + Offset(unit * 0.2, unit * 0.72),
            rect.topRight + Offset(-unit * 0.2, unit * 0.72),
            paint,
          );
          paint.color = Colors.white.withValues(alpha: 0.09);
          canvas.drawLine(
            rect.topLeft + Offset(unit * 0.22, unit * 0.32),
            rect.topLeft + Offset(unit * 0.44, unit * 0.54),
            paint,
          );
          if (hash % 3 == 0) {
            paint
              ..style = PaintingStyle.fill
              ..color = skin.accent.withValues(alpha: 0.35);
            canvas.drawCircle(
              rect.topLeft + Offset(unit * 0.23, unit * 0.28),
              unit * 0.038,
              paint,
            );
            canvas.drawCircle(
              rect.topRight + Offset(-unit * 0.23, unit * 0.28),
              unit * 0.038,
              paint,
            );
          }
        case BlockMaterial.crystal:
          canvas.save();
          canvas.translate(rect.left, rect.top);
          canvas.scale(rect.width, rect.height);
          paint.color = Colors.white.withValues(alpha: 0.15);
          canvas.drawPath(_crystalFacet, paint);
          paint.color = skin.accent.withValues(alpha: 0.12);
          canvas.drawPath(_crystalSheen, paint);
          canvas.restore();
        case BlockMaterial.astral:
          if (hash % 3 == 0) {
            final c = rect.center;
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = max(0.55, unit * 0.032)
              ..color = skin.accent.withValues(alpha: 0.3);
            canvas.drawLine(
              c - Offset(unit * 0.13, 0),
              c + Offset(unit * 0.13, 0),
              paint,
            );
            canvas.drawLine(
              c - Offset(0, unit * 0.13),
              c + Offset(0, unit * 0.13),
              paint,
            );
            paint
              ..style = PaintingStyle.fill
              ..color = Colors.white.withValues(alpha: 0.35);
            canvas.drawCircle(c, unit * 0.032, paint);
          }
      }
    }

    // Corroded (Acid Melt) visual etch
    if (isCorroded) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.7, unit * 0.05)
        ..color = const Color(0x9934D399);
      canvas.drawRRect(shape.deflate(unit * 0.06), paint);
    }

    // Special block emblem (deterministic, never leaks memeColor)
    if (specialType != BlockSpecialType.none && unit >= 8.5) {
      _drawSpecialEmblem(canvas, paint, rect, unit, phase);
    }

    // === ELEMENTAL STATUS OVERLAYS ===
    if (wet) {
      final waveLift = sin(phase * 1.4) * 0.045;
      final surface = rect.bottom - unit * (0.24 + waveLift);
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0x6622D3EE);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(rect.left + unit * 0.03, surface, rect.right - unit * 0.03, rect.bottom - unit * 0.03),
          bottomLeft: Radius.circular(unit * 0.08),
          bottomRight: Radius.circular(unit * 0.08),
        ),
        paint,
      );
      // Shimmering foam crest
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.7, unit * 0.05)
        ..color = const Color(0xDDF0FDFF);
      canvas.drawLine(
        Offset(rect.left + unit * 0.12, surface),
        Offset(rect.right - unit * 0.12, surface),
        paint,
      );
      // Glossy water droplet glint
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xCCF0FDFF);
      canvas.drawCircle(
        Offset(rect.left + unit * 0.28, rect.top + unit * 0.34),
        unit * 0.055,
        paint,
      );
    }

    if (frozen) {
      // Crystalline ice glaze & gleaming rim
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0x36CCF4FF);
      canvas.drawRRect(shape, paint);
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(0.9, unit * 0.068)
        ..color = const Color(0xE6D8F8FF);
      canvas.drawRRect(shape, paint);

      // Sharp glacial refraction streaks + sparkle cross
      final center = rect.center;
      paint
        ..strokeWidth = max(0.7, unit * 0.05)
        ..color = Colors.white.withValues(alpha: 0.85);
      canvas.drawLine(
        center + Offset(-unit * 0.28, -unit * 0.24),
        center + Offset(unit * 0.22, unit * 0.26),
        paint,
      );
      paint.color = const Color(0xBB9CEAFF);
      canvas.drawLine(
        center + Offset(-unit * 0.02, -unit * 0.28),
        center + Offset(unit * 0.26, 0),
        paint,
      );
      canvas.drawLine(
        center + Offset(-unit * 0.24, unit * 0.04),
        center + Offset(0, unit * 0.28),
        paint,
      );
      paint.strokeCap = StrokeCap.butt;
    }

    if (burning) {
      // Glowing molten heat rim
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.7, unit * 0.05)
        ..color = const Color(0xBBFF7B29);
      canvas.drawRRect(shape.deflate(unit * 0.02), paint);

      // Layered flickering flames (crimson-orange outer + bright yellow-white inner)
      paint.style = PaintingStyle.fill;
      for (int i = 0; i < 2; i++) {
        final x = rect.left + unit * (0.31 + i * 0.36);
        final lift = unit * (0.18 + (sin(phase * 2.4 + i * 2.2) + 1) * 0.09);
        final sway = sin(phase * 3.1 + i) * unit * 0.05;
        final base = Offset(x, rect.top + unit * 0.3);
        final outerFlame = Path()
          ..moveTo(base.dx - unit * 0.11, base.dy)
          ..quadraticBezierTo(
            base.dx - unit * 0.14,
            base.dy - lift * 0.55,
            base.dx + sway,
            base.dy - lift * 1.45,
          )
          ..quadraticBezierTo(
            base.dx + unit * 0.14,
            base.dy - lift * 0.5,
            base.dx + unit * 0.11,
            base.dy,
          )
          ..close();
        paint.color = const Color(0xF0FF6A2B);
        canvas.drawPath(outerFlame, paint);

        final innerFlame = Path()
          ..moveTo(base.dx - unit * 0.06, base.dy)
          ..quadraticBezierTo(
            base.dx,
            base.dy - lift * 0.95,
            base.dx + unit * 0.06,
            base.dy,
          )
          ..close();
        paint.color = const Color(0xFFFFF3B0);
        canvas.drawPath(innerFlame, paint);
      }
    }

    if (poisoned) {
      // Toxic bubbling slime rim + rising glowing bubbles
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0x5584CC16);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(
            rect.left + unit * 0.06,
            rect.bottom - unit * 0.22,
            rect.right - unit * 0.06,
            rect.bottom - unit * 0.04,
          ),
          bottomLeft: Radius.circular(unit * 0.07),
          bottomRight: Radius.circular(unit * 0.07),
        ),
        paint,
      );
      for (int i = 0; i < 3; i++) {
        final drift = (time * 0.6 + i * 0.34 + (row % 3) * 0.13) % 1;
        final bx = rect.left + unit * (0.24 + i * 0.25);
        final by = rect.bottom - unit * (0.14 + drift * 0.56);
        final br = unit * (0.055 + (i % 2) * 0.025) * (1 - drift * 0.4);
        paint.color = const Color(0xFFBEF264).withValues(alpha: (1 - drift) * 0.85);
        canvas.drawCircle(Offset(bx, by), br, paint);
        paint.color = Colors.white.withValues(alpha: (1 - drift) * 0.65);
        canvas.drawCircle(Offset(bx - br * 0.3, by - br * 0.3), br * 0.35, paint);
      }
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.55, unit * 0.04)
        ..color = const Color(0xBBA855F7);
      canvas.drawLine(
        rect.bottomLeft + Offset(unit * 0.14, -unit * 0.09),
        rect.bottomRight + Offset(-unit * 0.14, -unit * 0.09),
        paint,
      );
    }

    if (shocked && sin(phase * 3.4) > -0.45) {
      final center = rect.center;
      final bolt = Path()
        ..moveTo(center.dx - unit * 0.2, center.dy - unit * 0.3)
        ..lineTo(center.dx + unit * 0.1, center.dy - unit * 0.03)
        ..lineTo(center.dx - unit * 0.09, center.dy + unit * 0.05)
        ..lineTo(center.dx + unit * 0.22, center.dy + unit * 0.3);
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = max(1.8, unit * 0.14)
        ..color = const Color(0x66FACC15);
      canvas.drawPath(bolt, paint);
      paint
        ..strokeWidth = max(0.85, unit * 0.06)
        ..color = const Color(0xFFFFFBE6);
      canvas.drawPath(bolt, paint);
      paint.strokeCap = StrokeCap.butt;
    }

    if (voided) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(0.75, unit * 0.055)
        ..color = const Color(0xDDC084FC);
      canvas.drawArc(
        Rect.fromCircle(center: rect.center, radius: unit * 0.28),
        phase * 0.6,
        pi * 1.25,
        false,
        paint,
      );
      paint.color = const Color(0xAAF472B6);
      canvas.drawArc(
        Rect.fromCircle(center: rect.center, radius: unit * 0.16),
        -phase * 0.9,
        pi * 1.1,
        false,
        paint,
      );
      paint.strokeCap = StrokeCap.butt;
    }

    // Crisp dual-tone fracture cracks + color-shifting HP bar
    final hp = health?.hpPercent ?? 1;
    if (hp < 0.78) {
      final c = rect.center;
      final crack = Path()
        ..moveTo(rect.left + unit * 0.2, rect.top + unit * 0.18)
        ..lineTo(c.dx - unit * 0.07, c.dy - unit * 0.08)
        ..lineTo(c.dx + unit * 0.09, c.dy + unit * 0.02);
      if (hp < 0.48) {
        crack
          ..lineTo(c.dx - unit * 0.06, c.dy + unit * 0.2)
          ..lineTo(c.dx + unit * 0.13, rect.bottom - unit * 0.14);
        crack
          ..moveTo(c.dx + unit * 0.09, c.dy + unit * 0.02)
          ..lineTo(rect.right - unit * 0.14, c.dy - unit * 0.13);
      }
      if (hp < 0.25) {
        crack
          ..moveTo(c.dx - unit * 0.07, c.dy - unit * 0.08)
          ..lineTo(rect.left + unit * 0.14, c.dy + unit * 0.14);
      }
      // Subtle bright edge highlight behind crack
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(0.7, unit * 0.055)
        ..color = skin.accent.withValues(alpha: 0.25);
      canvas.save();
      canvas.translate(0.5, 0.5);
      canvas.drawPath(crack, paint);
      canvas.restore();
      // Deep dark fracture
      paint
        ..strokeWidth = max(0.75, unit * 0.062)
        ..color = Color.lerp(skin.edge, Colors.black, 0.55)!;
      canvas.drawPath(crack, paint);
      paint.strokeCap = StrokeCap.butt;

      if (unit >= 9.5 && (hitFlashTimer > 0 || hp < 0.35)) {
        final bar = Rect.fromLTWH(
          rect.left + unit * 0.16,
          rect.bottom - unit * 0.19,
          unit * 0.68,
          max(1.1, unit * 0.06),
        );
        paint
          ..style = PaintingStyle.fill
          ..color = Colors.black.withValues(alpha: 0.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(bar, Radius.circular(bar.height)),
          paint,
        );
        paint.color = hp < 0.3
            ? const Color(0xFFFF6B6B)
            : Color.lerp(const Color(0xFFFFB74D), skin.accent, hp)!;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bar.left, bar.top, bar.width * hp, bar.height),
            Radius.circular(bar.height),
          ),
          paint,
        );
      }
    }
    paint.style = PaintingStyle.fill;
  }

  void _drawSpecialEmblem(
    Canvas canvas,
    Paint paint,
    Rect rect,
    double unit,
    double phase,
  ) {
    final c = rect.center;
    final pulse = 0.72 + 0.28 * sin(phase * 1.4);
    final r = unit * 0.24;
    switch (specialType) {
      case BlockSpecialType.explosiveCrystal:
        paint
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFF6B35).withValues(alpha: 0.32 * pulse);
        canvas.drawCircle(c, r * 1.35, paint);
        final diamond = Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r, c.dy)
          ..close();
        paint.color = const Color(0xFFFF9F1C).withValues(alpha: 0.9);
        canvas.drawPath(diamond, paint);
        paint.color = const Color(0xFFFFF3B0);
        canvas.drawCircle(c, r * 0.38, paint);
      case BlockSpecialType.energyCore:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.8, unit * 0.06)
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.85 * pulse);
        canvas.drawCircle(c, r, paint);
        paint
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFE0F2FE);
        canvas.drawCircle(c, r * 0.45, paint);
      case BlockSpecialType.magnetBeacon:
        paint
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = max(0.9, unit * 0.065)
          ..color = const Color(0xFFFACC15).withValues(alpha: 0.9 * pulse);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.9),
          pi * 0.15,
          pi * 1.7,
          false,
          paint,
        );
        paint
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF5EEAD4);
        canvas.drawCircle(c, r * 0.36, paint);
        paint.strokeCap = StrokeCap.butt;
      case BlockSpecialType.overdriveRune:
        paint
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFE879F9).withValues(alpha: 0.3 * pulse);
        canvas.drawCircle(c, r * 1.35, paint);
        final star = Path()
          ..moveTo(c.dx, c.dy - r * 1.1)
          ..lineTo(c.dx + r * 0.35, c.dy - r * 0.35)
          ..lineTo(c.dx + r * 1.1, c.dy)
          ..lineTo(c.dx + r * 0.35, c.dy + r * 0.35)
          ..lineTo(c.dx, c.dy + r * 1.1)
          ..lineTo(c.dx - r * 0.35, c.dy + r * 0.35)
          ..lineTo(c.dx - r * 1.1, c.dy)
          ..lineTo(c.dx - r * 0.35, c.dy - r * 0.35)
          ..close();
        paint.color = const Color(0xFFFDE047);
        canvas.drawPath(star, paint);
      case BlockSpecialType.none:
        break;
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

    // Lưu vệt chuyển động sao chổi mượt hơn
    trail.insert(0, Offset(transform.x, transform.y));
    if (trail.length > 12) trail.removeLast();

    // Xoay vũ khí (nhân thêm hệ số xoay cuồng nộ)
    final speedMultiplier = race.speedMultiplier;
    weaponAngle +=
        (role.attackSpeed * speedMultiplier * 4.5 * spinMultiplier) * dt;
    if (weaponAngle > 2 * pi) weaponAngle -= 2 * pi;

    if (attackCooldown > 0) attackCooldown -= dt;
  }

  @override
  void draw(
    Canvas canvas,
    Paint paint, {
    double time = 0,
    bool isDashing = false,
    List<Color> elementColors = const [],
  }) {
    final center = transform.position;
    paint
      ..shader = null
      ..maskFilter = null;

    // 0. Smooth glowing comet ribbon trail (amplified during dash)
    if (trail.length >= 2) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (int i = trail.length - 1; i >= 1; i--) {
        final tProg = 1.0 - (i / trail.length);
        final a = trail[i];
        final b = trail[i - 1];
        // Outer luminous tail
        paint
          ..strokeWidth = radius * (0.35 + 1.1 * tProg) * (isDashing ? 1.25 : 1.0)
          ..color = role.themeColor.withValues(
            alpha: tProg * (isDashing ? 0.34 : 0.2),
          );
        canvas.drawLine(a, b, paint);
        // Inner white-tinted plasma streak
        paint
          ..strokeWidth = radius * (0.14 + 0.45 * tProg)
          ..color = Colors.white.withValues(
            alpha: tProg * (isDashing ? 0.55 : 0.25),
          );
        canvas.drawLine(a, b, paint);
      }
      paint.strokeCap = StrokeCap.butt;
    }

    // 1. Race-specific energy halo around the 3D sphere
    _drawRaceAura(canvas, paint, center, time, isDashing);

    // 2. Soft drop shadow underneath sphere to float above revealed artwork
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.38);
    canvas.drawCircle(center + Offset(1.5, 2.5), radius * 1.02, paint);

    // 3. Rich glossy 3D metallic-glass sphere
    final sphereRect = Rect.fromCircle(center: center, radius: radius);
    paint.shader = RadialGradient(
      center: const Alignment(-0.38, -0.42),
      radius: 0.9,
      colors: [
        Colors.white,
        Color.lerp(Colors.white, role.themeColor, 0.35)!,
        role.themeColor,
        Color.lerp(role.themeColor, Colors.black, 0.68)!,
      ],
      stops: const [0.0, 0.22, 0.55, 1.0],
    ).createShader(sphereRect);
    canvas.drawCircle(center, radius, paint);
    paint.shader = null;

    // Glossy top-left specular highlight
    paint.color = Colors.white.withValues(alpha: 0.78);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(-radius * 0.32, -radius * 0.34),
        width: radius * 0.42,
        height: radius * 0.26,
      ),
      paint,
    );

    // Bottom-right rim light bounce
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, radius * 0.13)
      ..color = Color.lerp(race.themeColor, Colors.white, 0.45)!
          .withValues(alpha: 0.65);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.86),
      0.3,
      1.3,
      false,
      paint,
    );

    // Crisp outer light rim
    paint
      ..strokeWidth = isDashing ? 2.0 : 1.3
      ..color = Colors.white.withValues(alpha: isDashing ? 0.92 : 0.68);
    canvas.drawCircle(center, radius, paint);

    // 4. Tiny orbiting elemental pips showing equipped elements (up to 3)
    if (elementColors.isNotEmpty) {
      paint.style = PaintingStyle.fill;
      final pipOrbit = radius + 4.5;
      for (int i = 0; i < elementColors.length; i++) {
        final a = time * 2.4 + i * (2 * pi / elementColors.length);
        final pos = center + Offset(cos(a) * pipOrbit, sin(a) * pipOrbit);
        paint.color = elementColors[i].withValues(alpha: 0.42);
        canvas.drawCircle(pos, 3.4, paint);
        paint.color = Colors.white.withValues(alpha: 0.92);
        canvas.drawCircle(pos, 1.4, paint);
      }
    }
    paint.style = PaintingStyle.fill;
  }

  void _drawRaceAura(
    Canvas canvas,
    Paint paint,
    Offset center,
    double time,
    bool isDashing,
  ) {
    final pulse = 0.7 + 0.3 * sin(time * 4.0);
    final auraR = radius * (isDashing ? 1.9 : 1.55);
    paint
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          race.themeColor.withValues(alpha: (isDashing ? 0.42 : 0.24) * pulse),
          race.themeColor.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: auraR));
    canvas.drawCircle(center, auraR, paint);
    paint.shader = null;

    if (race.type == RaceType.yeti) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.cyanAccent.withValues(alpha: 0.55);
      canvas.drawCircle(center, radius + 4 + pulse * 2, paint);
      for (int i = 0; i < 6; i++) {
        final a = time * 1.1 + i * pi / 3;
        final p1 = center + Offset(cos(a), sin(a)) * (radius + 2);
        final p2 = center + Offset(cos(a), sin(a)) * (radius + 6.5);
        canvas.drawLine(p1, p2, paint);
      }
    } else if (race.type == RaceType.elf) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.2
        ..color = Colors.tealAccent.withValues(alpha: 0.55);
      for (int i = 0; i < 2; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius + 3.5),
          time * 3.5 + i * pi,
          1.1,
          false,
          paint,
        );
      }
      paint.strokeCap = StrokeCap.butt;
    } else if (race.type == RaceType.orc) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.redAccent.withValues(alpha: 0.45 * pulse);
      canvas.drawCircle(center, radius + 2.5, paint);
    } else if (race.type == RaceType.merfolk) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.lightBlueAccent.withValues(alpha: 0.45);
      canvas.drawCircle(center, radius + 2.5 + (time * 6 % 4), paint);
    }
    paint.style = PaintingStyle.fill;
  }
}

/// Mũi tên của Cung thủ
class ArrowEntity extends GameEntity {
  double damage;
  bool isRicochet = false;
  final List<Offset> trail = [];
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
    trail.insert(0, transform.position);
    if (trail.length > 6) trail.removeLast();
    transform.x += transform.vx * dt;
    transform.y += transform.vy * dt;
    lifeTime -= dt;
  }

  @override
  void draw(Canvas canvas, Paint paint) {
    // Tapered glowing energy wake
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < trail.length - 1; i++) {
      final prog = 1 - i / trail.length;
      paint
        ..strokeWidth = 4.2 * prog
        ..color = const Color(0xFF34D399).withValues(alpha: prog * 0.25);
      canvas.drawLine(trail[i], trail[i + 1], paint);
      paint
        ..strokeWidth = 1.5 * prog
        ..color = const Color(0xFFD1FAE5).withValues(alpha: prog * 0.65);
      canvas.drawLine(trail[i], trail[i + 1], paint);
    }

    final center = transform.position;
    final angle = atan2(transform.vy, transform.vx);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Outer energy glow around shaft
    paint
      ..strokeWidth = 5.0
      ..color = Colors.greenAccent.withValues(alpha: 0.28);
    canvas.drawLine(const Offset(-11, 0), const Offset(11, 0), paint);

    // Shaft
    paint
      ..strokeWidth = 2.2
      ..color = const Color(0xFF6EE7B7);
    canvas.drawLine(const Offset(-11, 0), const Offset(9, 0), paint);

    // Glowing feather fletching at tail
    paint
      ..strokeWidth = 1.5
      ..color = const Color(0xFFA7F3D0);
    canvas.drawLine(const Offset(-8, 0), const Offset(-13, -3.5), paint);
    canvas.drawLine(const Offset(-8, 0), const Offset(-13, 3.5), paint);

    // Razor crystalline arrowhead
    final head = Path()
      ..moveTo(13, 0)
      ..lineTo(5, -4.5)
      ..lineTo(7, 0)
      ..lineTo(5, 4.5)
      ..close();
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawPath(head, paint);

    canvas.restore();
    paint
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.fill;
  }
}

/// Móc câu của Người đánh cá
class HookEntity extends GameEntity {
  final double damage;
  final double maxDistance;
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
    this.maxDistance = 140,
  });

  @override
  void update(double dt) {
    if (!isReturning) {
      transform.x += transform.vx * dt;
      transform.y += transform.vy * dt;
      distanceTravelled += 300 * dt;
      if (distanceTravelled > maxDistance) isReturning = true;
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
    final pos = transform.position;
    final sag = isReturning ? 4.0 : min(14.0, (pos - origin).distance * 0.12);
    final middle = (origin + pos) / 2 + Offset(0, sag);
    final line = Path()
      ..moveTo(origin.dx, origin.dy)
      ..quadraticBezierTo(middle.dx, middle.dy, pos.dx, pos.dy);

    // Luminous aqua tether glow + bright core line
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0
      ..color = const Color(0x4438BDF8);
    canvas.drawPath(line, paint);
    paint
      ..strokeWidth = 1.1
      ..color = const Color(0xCCD8F6FF);
    canvas.drawPath(line, paint);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(
      isReturning
          ? atan2(origin.dy - pos.dy, origin.dx - pos.dx)
          : atan2(transform.vy, transform.vx),
    );

    // Water splash wake around hook
    paint
      ..strokeWidth = 1.2
      ..color = const Color(0x887DD3FC);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(-2, 0), radius: 7.5),
      pi * 0.65,
      pi * 0.7,
      false,
      paint,
    );

    // Gleaming metallic barbed harpoon hook
    final hook = Path()
      ..moveTo(-6, 0)
      ..lineTo(4, 0)
      ..quadraticBezierTo(10, 0, 8.5, 6)
      ..quadraticBezierTo(6, 9.5, 3, 5)
      ..lineTo(1.5, 7);
    paint
      ..strokeWidth = 3.5
      ..color = const Color(0x5538BDF8);
    canvas.drawPath(hook, paint);
    paint
      ..strokeWidth = 1.9
      ..color = Colors.white;
    canvas.drawPath(hook, paint);

    canvas.restore();
    paint
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.fill;
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
  void draw(Canvas canvas, Paint paint, {double time = 0}) {
    final pos = transform.position;
    final phase = time * 4.5 + id.hashCode * 0.37;
    paint
      ..shader = null
      ..maskFilter = null;

    if (type == DropType.gold) {
      // Soft golden halo
      paint
        ..style = PaintingStyle.fill
        ..color = Colors.amber.withValues(alpha: 0.24);
      canvas.drawCircle(pos, 7.2, paint);

      // Animated spinning 3D coin silhouette
      final spinW = 3.0 + (cos(phase).abs()) * 2.2;
      final coinRect = Rect.fromCenter(center: pos, width: spinW * 2, height: 9.6);
      paint.color = const Color(0xFFF59E0B);
      canvas.drawOval(coinRect, paint);
      paint.color = const Color(0xFFFDE047);
      canvas.drawOval(coinRect.deflate(1.2), paint);
      // Specular gleam
      paint.color = Colors.white.withValues(alpha: 0.85);
      canvas.drawCircle(pos + Offset(-spinW * 0.25, -1.8), 1.2, paint);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = const Color(0xFFFFFBEB);
      canvas.drawOval(coinRect, paint);
    } else {
      // Glowing faceted cyan-violet EXP crystal
      final pulse = 0.85 + 0.15 * sin(phase);
      paint
        ..style = PaintingStyle.fill
        ..color = Colors.cyanAccent.withValues(alpha: 0.25 * pulse);
      canvas.drawCircle(pos, 8.0 * pulse, paint);

      final path = Path()
        ..moveTo(pos.dx, pos.dy - 6.5)
        ..lineTo(pos.dx + 4.8, pos.dy)
        ..lineTo(pos.dx, pos.dy + 6.5)
        ..lineTo(pos.dx - 4.8, pos.dy)
        ..close();
      paint.color = const Color(0xFF22D3EE);
      canvas.drawPath(path, paint);

      // Inner bright crystal facet
      final facet = Path()
        ..moveTo(pos.dx, pos.dy - 5.2)
        ..lineTo(pos.dx + 3.2, pos.dy)
        ..lineTo(pos.dx, pos.dy + 1.5)
        ..lineTo(pos.dx - 2.0, pos.dy)
        ..close();
      paint.color = Colors.white.withValues(alpha: 0.72);
      canvas.drawPath(facet, paint);

      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = const Color(0xFFE0F2FE);
      canvas.drawPath(path, paint);
    }
    paint.style = PaintingStyle.fill;
  }
}

/// Vòng sóng xung kích phát sáng nổ bung khi khối pixel vỡ
class ShockwaveRing {
  Offset center;
  double radius = 4.0;
  double maxRadius = 52.0;
  Color color;
  double lifeTime = 0.28;
  double currentLife = 0.28;

  ShockwaveRing({required this.center, required this.color});

  bool update(double dt) {
    currentLife -= dt;
    final progress = 1.0 - (currentLife / lifeTime).clamp(0.0, 1.0);
    final easeOut = 1 - pow(1 - progress, 3).toDouble();
    radius = 4.0 + (maxRadius - 4.0) * easeOut;
    return currentLife <= 0;
  }

  void draw(Canvas canvas, Paint paint) {
    final alpha = (currentLife / lifeTime).clamp(0.0, 1.0);
    paint
      ..shader = null
      ..style = PaintingStyle.stroke;
    // Soft outer bloom ring
    paint
      ..color = color.withValues(alpha: alpha * 0.35)
      ..strokeWidth = 6.5 * alpha;
    canvas.drawCircle(center, radius, paint);
    // Crisp bright inner core ring
    paint
      ..color = Color.lerp(color, Colors.white, 0.55)!.withValues(alpha: alpha * 0.92)
      ..strokeWidth = 1.8 * alpha + 0.4;
    canvas.drawCircle(center, radius * 0.92, paint);
    paint.style = PaintingStyle.fill;
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
    vy += 210 * dt; // Trọng lực nhẹ rơi xuống
    rotation += rotSpeed * dt;
    lifeTime -= dt;
    alpha = (lifeTime / maxLife).clamp(0.0, 1.0);
    return lifeTime <= 0;
  }

  void draw(Canvas canvas, Paint paint) {
    paint
      ..shader = null
      ..maskFilter = null
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rotation);
    if (isSparkle) {
      // Glowing 4-point diamond spark
      final r = size * (1.2 + alpha * 0.8);
      paint.color = color.withValues(alpha: alpha * 0.35);
      canvas.drawCircle(Offset.zero, r * 1.4, paint);
      final star = Path()
        ..moveTo(0, -r)
        ..lineTo(r * 0.32, -r * 0.32)
        ..lineTo(r, 0)
        ..lineTo(r * 0.32, r * 0.32)
        ..lineTo(0, r)
        ..lineTo(-r * 0.32, r * 0.32)
        ..lineTo(-r, 0)
        ..lineTo(-r * 0.32, -r * 0.32)
        ..close();
      paint.color = Color.lerp(color, Colors.white, 0.65)!.withValues(alpha: alpha);
      canvas.drawPath(star, paint);
    } else {
      // Crisp tumbling beveled pixel shard
      final s = size * (0.7 + alpha * 0.55);
      paint.color = color.withValues(alpha: alpha);
      final rect = Rect.fromCenter(center: Offset.zero, width: s, height: s);
      canvas.drawRect(rect, paint);
      paint.color = Colors.white.withValues(alpha: alpha * 0.55);
      canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, s, s * 0.35), paint);
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

  double get ageProgress => (1.0 - lifeTime / 0.8).clamp(0.0, 1.0);

  double get popScale {
    final p = ageProgress;
    if (p < 0.16) return 0.72 + (p / 0.16) * 0.48;
    if (p < 0.32) return 1.2 - ((p - 0.16) / 0.16) * 0.2;
    return 1.0;
  }

  bool update(double dt) {
    y -= (44 - ageProgress * 18) * dt; // Pop nhanh rồi trôi chậm dần
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
    // Volumetric soft radial mist billows
    for (int i = 0; i < 4; i++) {
      final driftX = sin(duration * 1.4 + i * 1.9) * radius * 0.18;
      final driftY = cos(duration * 1.1 + i * 1.5) * radius * 0.14;
      final puffCenter = center + Offset(driftX, driftY);
      final puffR = radius * (0.72 + (i % 2) * 0.18);
      paint
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFD9F3F8).withValues(alpha: fade * 0.19),
            const Color(0xFF94C5D4).withValues(alpha: fade * 0.09),
            const Color(0x0094C5D4),
          ],
        ).createShader(Rect.fromCircle(center: puffCenter, radius: puffR));
      canvas.drawCircle(puffCenter, puffR, paint);
    }
    paint.shader = null;

    // Swirling vapor arcs around perimeter
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4
      ..color = const Color(0xFFD4F5F8).withValues(alpha: fade * 0.38);
    for (int i = 0; i < 2; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * (0.85 - i * 0.16)),
        duration * (0.7 + i * 0.4) + i * pi,
        2.1,
        false,
        paint,
      );
    }
    paint
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.fill;
  }
}

/// Tinh Linh Hộ Vệ bay xoay quanh Quả cầu người chơi
class OrbitingSpirit {
  static const contactCooldown = 0.65;
  static const damageRatio = 0.55;
  double hitCooldown = 0;
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
    hitCooldown = max(0, hitCooldown - dt);
    angle += orbitSpeed * dt;
    if (angle > 2 * pi) angle -= 2 * pi;

    final currentPos = getPosition(center);
    trail.insert(0, currentPos);
    if (trail.length > 9) trail.removeLast();
  }

  Offset getPosition(Offset center) {
    return Offset(
      center.dx + cos(angle) * orbitRadius,
      center.dy + sin(angle) * orbitRadius,
    );
  }

  void draw(Canvas canvas, Paint paint, Offset center, {double time = 0}) {
    final pos = getPosition(center);
    paint
      ..shader = null
      ..maskFilter = null;

    // Smooth tapered ethereal wisp ribbon tail
    if (trail.length >= 2) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (int i = trail.length - 1; i >= 1; i--) {
        final prog = 1.0 - (i / trail.length);
        paint
          ..strokeWidth = size * (0.3 + prog * 1.1)
          ..color = color.withValues(alpha: prog * 0.34);
        canvas.drawLine(trail[i], trail[i - 1], paint);
        paint
          ..strokeWidth = size * (0.12 + prog * 0.35)
          ..color = Colors.white.withValues(alpha: prog * 0.45);
        canvas.drawLine(trail[i], trail[i - 1], paint);
      }
      paint.strokeCap = StrokeCap.butt;
    }

    // Soft radial aura bloom
    paint
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.9),
          color.withValues(alpha: 0.65),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Rect.fromCircle(center: pos, radius: size * 2.2));
    canvas.drawCircle(pos, size * 2.2, paint);
    paint.shader = null;

    // Rotating miniature rune ring around the wisp
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: 0.65);
    canvas.drawArc(
      Rect.fromCircle(center: pos, radius: size * 1.15),
      time * 4.5 + angle,
      pi * 1.1,
      false,
      paint,
    );

    // Sparkling 4-point star core
    final r = size * 0.95;
    final star = Path()
      ..moveTo(pos.dx, pos.dy - r)
      ..lineTo(pos.dx + r * 0.35, pos.dy - r * 0.35)
      ..lineTo(pos.dx + r, pos.dy)
      ..lineTo(pos.dx + r * 0.35, pos.dy + r * 0.35)
      ..lineTo(pos.dx, pos.dy + r)
      ..lineTo(pos.dx - r * 0.35, pos.dy + r * 0.35)
      ..lineTo(pos.dx - r, pos.dy)
      ..lineTo(pos.dx - r * 0.35, pos.dy - r * 0.35)
      ..close();
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawPath(star, paint);
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
    this.lifeTime = 0.18,
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
      ..strokeCap = StrokeCap.round;

    // 1. Wide luminous electric outer bloom
    paint
      ..strokeWidth = 6.5 * alpha + 1.0
      ..color = color.withValues(alpha: alpha * 0.25);
    canvas.drawPath(_path, paint);

    // 2. Vivid mid plasma channel
    paint
      ..strokeWidth = 2.6 * alpha + 0.6
      ..color = color.withValues(alpha: alpha * 0.8);
    canvas.drawPath(_path, paint);

    // 3. White-hot razor core
    paint
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFFFCEB).withValues(alpha: alpha);
    canvas.drawPath(_path, paint);

    // 4. Endpoint spark flashes
    paint.style = PaintingStyle.fill;
    paint.color = Colors.white.withValues(alpha: alpha * 0.9);
    canvas.drawCircle(points.first, 2.2 * alpha + 0.5, paint);
    canvas.drawCircle(points.last, 2.8 * alpha + 0.8, paint);
    paint.strokeCap = StrokeCap.butt;
  }

  static LightningArc createZigzag(Offset start, Offset end, Color color) {
    final List<Offset> pts = [start];
    final dist = (end - start).distance;
    final segments = (dist / 13.0).clamp(3, 10).toInt();
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
      final offsetDist = (rng.nextDouble() - 0.5) * 18.0;
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
  Offset center;
  double life = 2.5;
  double pulse = 0.5;

  VoidVortexZone(this.center);

  void draw(Canvas canvas) {
    final fade = (life / 0.5).clamp(0.0, 1.0);
    final paint = Paint();

    // Outer gravitational violet bloom
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFF060312).withValues(alpha: fade * 0.96),
        const Color(0xFF2E1065).withValues(alpha: fade * 0.85),
        const Color(0xFFA855F7).withValues(alpha: fade * 0.35),
        const Color(0x00A855F7),
      ],
      stops: const [0.0, 0.35, 0.62, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: 48));
    canvas.drawCircle(center, 48, paint);
    paint.shader = null;

    // Counter-rotating luminous accretion arcs
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      paint
        ..strokeWidth = 2.6 - i * 0.35
        ..color = (i.isEven ? const Color(0xFFD8B4FE) : const Color(0xFFF472B6))
            .withValues(alpha: fade * (0.85 - i * 0.14));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 19.0 + i * 7.5),
        (i.isEven ? 1 : -1) * life * 5.2 + i * 1.7,
        1.8,
        false,
        paint,
      );
    }

    // Event horizon bright photon rim
    paint
      ..strokeWidth = 1.6
      ..color = const Color(0xFFF5D0FE).withValues(alpha: fade * 0.9);
    canvas.drawCircle(center, 15, paint);
  }
}

/// A handful of parametric strokes, with no particles or blur per elemental hit.
class ElementImpact {
  final Offset center;
  final ElementType element;
  final double radius;
  final double angle;
  final double duration;
  double age = 0;
  ElementImpact({
    required this.center,
    required this.element,
    this.radius = 22,
    this.angle = 0,
    this.duration = 0.38,
  });

  bool update(double dt) {
    age += dt;
    return age >= duration;
  }

  Color get color => switch (element) {
    ElementType.fire => const Color(0xFFFF8A4C),
    ElementType.frost => const Color(0xFF93E8FF),
    ElementType.poison => const Color(0xFFA3E635),
    ElementType.water => const Color(0xFF38BDF8),
    ElementType.lightning => const Color(0xFFFDE047),
    ElementType.voidDark => const Color(0xFFC084FC),
    ElementType.wind => const Color(0xFF5EEAD4),
    _ => const Color(0xFFFFE4B5),
  };

  void draw(Canvas canvas, Paint paint) {
    final t = (age / duration).clamp(0.0, 1.0);
    final ease = 1 - pow(1 - t, 3).toDouble();
    final reach = radius * (0.2 + ease * 0.85);
    final alpha = (1 - t);

    paint
      ..shader = null
      ..maskFilter = null;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Subtle radial impact flash
    if (t < 0.45) {
      final f = 1 - t / 0.45;
      paint
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: f * 0.65),
            color.withValues(alpha: f * 0.35),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: reach * 0.85));
      canvas.drawCircle(Offset.zero, reach * 0.85, paint);
      paint.shader = null;
    }

    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2 * alpha + 0.5
      ..color = color.withValues(alpha: alpha * 0.9);

    if (element == ElementType.water || element == ElementType.wind) {
      for (int i = 0; i < 2; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: reach * (1 - i * 0.32)),
          i * pi + t * 1.4,
          pi * 0.85,
          false,
          paint,
        );
      }
      if (element == ElementType.water) {
        paint.style = PaintingStyle.fill;
        for (int i = 0; i < 4; i++) {
          final a = i * pi / 2 + 0.4;
          paint.color = const Color(0xFFE0F7FA).withValues(alpha: alpha * 0.85);
          canvas.drawCircle(Offset(cos(a), sin(a)) * reach * 0.9, 2.0 * alpha + 0.5, paint);
        }
      }
    } else if (element == ElementType.fire || element == ElementType.voidDark) {
      for (int i = 0; i < 3; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: reach),
          i * pi * 2 / 3 + t * 2.0,
          0.95,
          false,
          paint,
        );
      }
      paint.style = PaintingStyle.fill;
      for (int i = 0; i < 5; i++) {
        final a = i * pi * 2 / 5 + t * 1.2;
        paint.color = (element == ElementType.fire
                ? const Color(0xFFFFF3B0)
                : const Color(0xFFF5D0FE))
            .withValues(alpha: alpha * 0.9);
        canvas.drawCircle(Offset(cos(a), sin(a)) * reach * 0.82, 2.1 * alpha + 0.4, paint);
      }
    } else if (element == ElementType.poison) {
      paint.strokeWidth = 1.4 * alpha + 0.4;
      canvas.drawCircle(Offset.zero, reach * 0.72, paint);
      paint.style = PaintingStyle.fill;
      for (int i = 0; i < 6; i++) {
        final a = i * pi / 3 + 0.3;
        final pt = Offset(cos(a), sin(a)) * reach * (0.75 + (i % 2) * 0.28);
        paint.color = color.withValues(alpha: alpha * 0.9);
        canvas.drawCircle(pt, 2.8 * alpha + 0.5, paint);
      }
    } else if (element == ElementType.none) {
      // Crisp bright melee/collision slash spark
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: reach),
        -0.75,
        1.5,
        false,
        paint,
      );
      paint
        ..strokeWidth = 1.6 * alpha + 0.4
        ..color = Colors.white.withValues(alpha: alpha * 0.9);
      canvas.drawLine(Offset(-reach * 0.45, 0), Offset(reach * 0.65, 0), paint);
      canvas.drawLine(Offset(0, -reach * 0.4), Offset(0, reach * 0.4), paint);
    } else {
      // Frost crystalline burst or Lightning electric sparks
      for (int i = 0; i < 6; i++) {
        final a = i * pi / 3;
        final start = Offset(cos(a), sin(a)) * reach * 0.35;
        final end = Offset(cos(a + 0.1), sin(a + 0.1)) * reach;
        canvas.drawLine(start, end, paint);
        if (element == ElementType.frost) {
          canvas.drawLine(
            end,
            end + Offset(cos(a + 2.4), sin(a + 2.4)) * radius * 0.18,
            paint,
          );
        }
      }
    }

    canvas.restore();
    paint
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.butt;
  }
}
