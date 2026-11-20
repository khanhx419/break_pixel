import 'dart:math';

import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/element.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  final GameEngine engine;

  GamePainter({required this.engine}) : super(repaint: engine);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Áp dụng rung lắc màn hình (Screen Shake)
    if (engine.shakeOffset != Offset.zero) {
      canvas.translate(engine.shakeOffset.dx, engine.shakeOffset.dy);
    }

    final paint = Paint();

    // 1. Vẽ nền không gian Arena phong cách viễn tưởng + hiệu ứng môi trường
    _drawBackground(canvas, size, paint);

    canvas.save();
    final boardCenter = Offset(
      engine.gridStartX + engine.level.cols * engine.gridBlockSize / 2,
      engine.gridStartY + engine.level.rows * engine.gridBlockSize / 2,
    );
    canvas.translate(boardCenter.dx, boardCenter.dy);
    canvas.scale(engine.cameraScale);
    canvas.translate(-boardCenter.dx, -boardCenter.dy);
    canvas.clipRect(
      Rect.fromLTWH(
        engine.gridStartX,
        engine.gridStartY,
        engine.level.cols * engine.gridBlockSize,
        engine.level.rows * engine.gridBlockSize,
      ),
    );

    // 3. Vẽ Lớp Bức Tranh Meme Ẩn bên dưới (giữ nguyên 100% màu gốc)
    _drawRevealedMemeLayer(canvas, paint);

    // 4. Vẽ các Khối Pixel còn nguyên hoặc đang bị nứt
    for (final block in engine.blocks) {
      block.draw(
        canvas,
        paint,
        time: engine.elapsedTime,
        theme: engine.level.theme,
      );
    }

    // 4.5 Vẽ vùng tầm ngắm kỹ năng Dung Hợp khi đã sẵn sàng
    if (engine.canCastFusion && engine.fusionData != null) {
      _drawFusionTargeting(canvas, paint);
    }

    for (final mist in engine.mistZones) {
      mist.draw(canvas, paint);
    }

    // 5. Vẽ Sóng xung kích phát sáng nổ vỡ (Shockwaves)
    for (final sw in engine.shockwaves) {
      sw.draw(canvas, paint);
    }

    // 6. Vẽ Vật phẩm rơi (Gold & EXP Gems)
    for (final drop in engine.drops) {
      drop.draw(canvas, paint, time: engine.elapsedTime);
    }

    // 7. Vẽ Mũi tên & Móc câu
    for (final arrow in engine.arrows) {
      arrow.draw(canvas, paint);
    }
    for (final hook in engine.hooks) {
      hook.draw(canvas, paint);
    }

    // 8. Vẽ Vũ khí gắn liền với nhân vật
    _drawWeapon(canvas, paint);

    // 9. Vẽ Quả cầu Nhân vật 3D (Player Ball)
    final speed = Offset(
      engine.player.transform.vx,
      engine.player.transform.vy,
    ).distance;
    final elementColors = [
      for (final el in engine.equippedElements)
        ElementData.baseElements.firstWhere((e) => e.type == el).color,
    ];
    engine.player.draw(
      canvas,
      paint,
      time: engine.elapsedTime,
      isDashing: speed > engine.normalBallSpeed * 1.15,
      elementColors: elementColors,
    );

    // 9.1 Vẽ Vòng xoáy Bão Lửa (Firestorm Vortex) hoặc Hào Quang Cuồng Nộ (Overdrive)
    if (engine.isFirestormActive) {
      _drawFirestormVortex(canvas, paint);
    }
    if (engine.isOverdriveActive) {
      _drawOverdriveAura(canvas, paint);
    }

    // 10. Vẽ Tinh Linh Hộ Vệ bay xoay quanh bóng (Orbiting Spirits)
    for (final spirit in engine.spirits) {
      spirit.draw(
        canvas,
        paint,
        engine.player.transform.position,
        time: engine.elapsedTime,
      );
    }

    for (final vortex in engine.vortexZones) {
      vortex.draw(canvas);
    }

    // 11. Vẽ Tia sét giật chuỗi chân thực (Lightning Arcs)
    for (final arc in engine.lightningArcs) {
      arc.draw(canvas, paint);
    }

    for (final impact in engine.impacts) {
      impact.draw(canvas, paint);
    }

    for (final cast in engine.fusionCasts) {
      cast.draw(canvas, paint);
    }

    if (engine.fusionData != null) {
      _drawFusionAuraMeter(canvas, paint);
    }

    // 12. Vẽ Hạt nổ tung (Debris)
    for (final p in engine.debris) {
      p.draw(canvas, paint);
    }

    // 13. Vẽ Chữ số sát thương & text trạng thái bay lên
    canvas.restore();
    _drawFloatingTexts(canvas);
    if (engine.isExpanding) _drawExpansionBanner(canvas, size);

    canvas.restore();
  }

  void _drawBackground(Canvas canvas, Size size, Paint paint) {
    engine.backdrop.draw(
      canvas,
      size,
      Rect.fromLTWH(
        engine.gridStartX,
        engine.gridStartY,
        engine.level.cols * engine.gridBlockSize,
        engine.level.rows * engine.gridBlockSize,
      ),
      engine.level.theme,
      engine.elapsedTime,
    );
  }

  void _drawRevealedMemeLayer(Canvas canvas, Paint paint) {
    paint.isAntiAlias = false;
    for (final block in engine.blocks) {
      if (block.health!.isDestroyed) {
        final rect = block.transform.rect;
        paint.color = block.memeColor;
        paint.style = PaintingStyle.fill;
        canvas.drawRect(rect, paint);
      }
    }
    paint.isAntiAlias = true;
  }

  void _drawFusionTargeting(Canvas canvas, Paint paint) {
    final data = engine.fusionData!;
    final center = engine.player.transform.position;
    final pulse = 0.65 + 0.35 * sin(engine.elapsedTime * 5.0);

    // Subtle pulsing dashed range ring (180px cast radius)
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..color = data.color.withValues(alpha: 0.24 * pulse);
    const segments = 24;
    const sweep = (2 * pi / segments) * 0.52;
    for (int i = 0; i < segments; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 180),
        engine.elapsedTime * 0.25 + i * (2 * pi / segments),
        sweep,
        false,
        paint,
      );
    }

    // Highlight nearest valid target with a crisp animated crosshair reticle
    final target = engine.fusionTarget();
    if (target != null) {
      final tPos = target.transform.position;
      final r = max(12.0, engine.gridBlockSize * 0.72) + pulse * 2.5;
      paint
        ..strokeWidth = 2.0
        ..color = data.color.withValues(alpha: 0.85);
      for (int i = 0; i < 4; i++) {
        final a = engine.elapsedTime * 2.0 + i * pi / 2;
        canvas.drawArc(
          Rect.fromCircle(center: tPos, radius: r),
          a - 0.35,
          0.7,
          false,
          paint,
        );
      }
      paint
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: 0.75);
      canvas.drawCircle(tPos, 2.5, paint);
    }
    paint
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.fill;
  }

  void _drawFusionAuraMeter(Canvas canvas, Paint paint) {
    final data = engine.fusionData!;
    final center = engine.player.transform.position;
    final ready = engine.canCastFusion;
    final radius = engine.player.radius + 10;

    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (ready) {
      // Glowing outer bloom when skill is ready
      paint
        ..strokeWidth = 4.8
        ..color = data.color.withValues(
          alpha: 0.28 + 0.14 * sin(engine.elapsedTime * 6),
        );
      canvas.drawCircle(center, radius, paint);
    }

    paint
      ..strokeWidth = ready ? 2.4 : 1.4
      ..color = data.color.withValues(alpha: ready ? 0.92 : 0.38);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * engine.fusionMeterProgress,
      false,
      paint,
    );

    if (ready) {
      for (int i = 0; i < 2; i++) {
        paint
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.78);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius + 4.5),
          engine.elapsedTime * 2.4 + i * pi,
          pi * 0.42,
          false,
          paint,
        );
      }
    }
    paint
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.fill;
  }

  void _drawWeapon(Canvas canvas, Paint paint) {
    final player = engine.player;
    final center = player.transform.position;
    final angle = player.role.type == RoleType.archer
        ? engine.projectileAimAngle ?? player.weaponAngle
        : player.weaponAngle;
    final range = engine.totalWeaponRange;

    // Multi-layered anime energy slash crescent for melee roles
    if (player.role.type == RoleType.warrior ||
        player.role.type == RoleType.farmer ||
        player.role.type == RoleType.lumberjack ||
        player.role.type == RoleType.fisherman) {
      const segments = 9;
      final totalSweep = player.role.type == RoleType.lumberjack ? 1.05 : 1.2;
      final slashRadius = range * 0.88;
      paint
        ..shader = null
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < segments; i++) {
        final t = (i + 1) / segments;
        final segStart = angle - totalSweep + (i * totalSweep / segments);
        final segSweep = totalSweep / segments + 0.02;

        // Soft outer theme-colored energy bloom
        paint
          ..strokeWidth = 3.5 + t * 11.0
          ..color = player.role.themeColor.withValues(alpha: t * t * 0.24);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: slashRadius),
          segStart,
          segSweep,
          false,
          paint,
        );

        // Vivid mid ribbon
        paint
          ..strokeWidth = 1.4 + t * 5.0
          ..color = Color.lerp(
            player.role.themeColor,
            Colors.white,
            t * 0.45,
          )!.withValues(alpha: t * t * 0.65);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: slashRadius),
          segStart,
          segSweep,
          false,
          paint,
        );

        // Razor-bright leading edge on tip half
        if (i >= segments ~/ 2) {
          paint
            ..strokeWidth = 0.9 + t * 1.8
            ..color = Colors.white.withValues(alpha: t * 0.85);
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: range * 0.96),
            segStart,
            segSweep,
            false,
            paint,
          );
        }
      }
      paint.strokeCap = StrokeCap.butt;
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    switch (player.role.type) {
      case RoleType.warrior:
        _drawSword(canvas, paint, range);
        break;
      case RoleType.archer:
        _drawBow(canvas, paint);
        break;
      case RoleType.farmer:
        _drawRake(canvas, paint, range);
        break;
      case RoleType.lumberjack:
        _drawAxe(canvas, paint, range);
        break;
      case RoleType.fisherman:
        _drawFishingRod(canvas, paint, range);
        break;
    }

    canvas.restore();
    paint
      ..shader = null
      ..style = PaintingStyle.fill;
  }

  void _drawSword(Canvas canvas, Paint paint, double range) {
    // Pommel gem
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.amber.shade700;
    canvas.drawCircle(const Offset(-2, 0), 3.4, paint);
    paint.color = Colors.cyanAccent;
    canvas.drawCircle(const Offset(-2, 0), 1.6, paint);

    // Leather-wrapped grip
    paint
      ..color = const Color(0xFF5D3A1A)
      ..strokeWidth = 3.6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(1, 0), const Offset(13, 0), paint);

    // Sculpted gold crossguard
    final guard = Path()
      ..moveTo(11, -9)
      ..lineTo(15.5, -7.5)
      ..lineTo(14.5, 0)
      ..lineTo(15.5, 7.5)
      ..lineTo(11, 9)
      ..lineTo(12, 0)
      ..close();
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFCA28);
    canvas.drawPath(guard, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFFFF8E1);
    canvas.drawPath(guard, paint);

    // Metallic rune-forged blade with gradient sheen
    final bladePath = Path()
      ..moveTo(14.5, -4.6)
      ..lineTo(range - 9, -3.4)
      ..lineTo(range + 1, 0)
      ..lineTo(range - 9, 3.4)
      ..lineTo(14.5, 4.6)
      ..close();

    paint
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white,
          const Color(0xFF80F2FF),
          const Color(0xFF22B8CF),
        ],
      ).createShader(Rect.fromLTRB(14, -5, range + 1, 5));
    canvas.drawPath(bladePath, paint);
    paint.shader = null;

    // Central luminous fuller ridge
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3
      ..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawLine(Offset(17, 0), Offset(range - 6, 0), paint);

    // Crisp outer edge outline
    paint
      ..strokeWidth = 0.95
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawPath(bladePath, paint);
    paint.strokeCap = StrokeCap.butt;
  }

  void _drawBow(Canvas canvas, Paint paint) {
    final drawPull = (1.0 - (engine.player.attackCooldown * engine.totalAttackSpeed).clamp(0.0, 1.0)) * 5.0;
    final stringX = 16.0 - drawPull;

    // Luminous bowstring
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..color = const Color(0xCCDCFFE4);
    canvas.drawLine(const Offset(16, -19), Offset(stringX, 0), paint);
    canvas.drawLine(Offset(stringX, 0), const Offset(16, 19), paint);

    // Sculpted energy recurve limbs (outer glow + solid limb)
    final bowPath = Path()
      ..moveTo(16, -19)
      ..quadraticBezierTo(27, -12, 24, 0)
      ..quadraticBezierTo(27, 12, 16, 19);
    paint
      ..strokeWidth = 6.0
      ..color = Colors.greenAccent.withValues(alpha: 0.25);
    canvas.drawPath(bowPath, paint);
    paint
      ..strokeWidth = 3.0
      ..color = const Color(0xFF69F0AE);
    canvas.drawPath(bowPath, paint);
    paint
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawPath(bowPath, paint);

    // Golden bow grip
    paint
      ..strokeWidth = 4.0
      ..color = Colors.amber;
    canvas.drawLine(const Offset(24, -4), const Offset(24, 4), paint);

    // Nocked glowing energy arrow ready to loose
    paint
      ..strokeWidth = 1.6
      ..color = Colors.white;
    canvas.drawLine(Offset(stringX, 0), Offset(stringX + 16, 0), paint);
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.greenAccent;
    canvas.drawCircle(Offset(stringX + 16, 0), 2.2, paint);
    paint.strokeCap = StrokeCap.butt;
  }

  void _drawRake(Canvas canvas, Paint paint, double range) {
    // Reinforced timber pole with golden bindings
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5
      ..color = const Color(0xFF8D5524);
    canvas.drawLine(Offset.zero, Offset(range - 9, 0), paint);
    paint
      ..strokeWidth = 4.2
      ..color = const Color(0xFFFFCA28);
    canvas.drawLine(Offset(range - 15, 0), Offset(range - 11, 0), paint);

    // Gleaming curved harvest rake bar
    final bar = Path()
      ..moveTo(range - 10, -14)
      ..quadraticBezierTo(range - 6, 0, range - 10, 14);
    paint
      ..strokeWidth = 3.4
      ..color = const Color(0xFFFFD54F);
    canvas.drawPath(bar, paint);

    // Sharp glowing harvest tines
    for (int i = -2; i <= 2; i++) {
      final y = i * 6.2;
      paint
        ..strokeWidth = 2.6
        ..color = Colors.orangeAccent.withValues(alpha: 0.45);
      canvas.drawLine(Offset(range - 9, y), Offset(range + 1, y), paint);
      paint
        ..strokeWidth = 1.5
        ..color = Colors.white;
      canvas.drawLine(Offset(range - 9, y), Offset(range + 1, y), paint);
    }
    paint.strokeCap = StrokeCap.butt;
  }

  void _drawAxe(Canvas canvas, Paint paint, double range) {
    // Heavy oak handle + iron pommel
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.4
      ..color = const Color(0xFF5D3A1A);
    canvas.drawLine(const Offset(-2, 0), Offset(range * 0.86, 0), paint);
    paint
      ..strokeWidth = 2.0
      ..color = const Color(0xFFD97706);
    canvas.drawLine(const Offset(5, -2), const Offset(5, 2), paint);
    canvas.drawLine(const Offset(11, -2), const Offset(11, 2), paint);

    // Heavy curved double-bit battle-axe head
    final axeHead = Path()
      ..moveTo(range * 0.56, -8)
      ..quadraticBezierTo(range * 0.72, -16, range * 0.9, -18)
      ..quadraticBezierTo(range * 0.98, 0, range * 0.9, 18)
      ..quadraticBezierTo(range * 0.72, 16, range * 0.56, 8)
      ..quadraticBezierTo(range * 0.64, 0, range * 0.56, -8)
      ..close();

    paint
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF475569),
          const Color(0xFFCBD5E1),
          Colors.white,
        ],
        stops: const [0.0, 0.72, 1.0],
      ).createShader(Rect.fromLTRB(range * 0.55, -18, range, 18));
    canvas.drawPath(axeHead, paint);
    paint.shader = null;

    // Razor edge highlight
    final edge = Path()
      ..moveTo(range * 0.89, -17)
      ..quadraticBezierTo(range * 0.98, 0, range * 0.89, 17);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xFFFFF3E0);
    canvas.drawPath(edge, paint);

    paint
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawPath(axeHead, paint);
    paint.strokeCap = StrokeCap.butt;
  }

  void _drawFishingRod(Canvas canvas, Paint paint, double range) {
    // Sleek flexible aqua-carbon rod
    final rod = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(range * 0.45, -2.5, range * 0.86, 1.5);
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.2
      ..color = Colors.cyanAccent.withValues(alpha: 0.28);
    canvas.drawPath(rod, paint);
    paint
      ..strokeWidth = 2.4
      ..color = const Color(0xFF22D3EE);
    canvas.drawPath(rod, paint);

    // Metallic fishing reel near handle
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFE2E8F0);
    canvas.drawCircle(const Offset(11, 4.5), 3.6, paint);
    paint.color = Colors.cyanAccent;
    canvas.drawCircle(const Offset(11, 4.5), 1.6, paint);

    // Glowing guide tip lure
    final tip = Offset(range * 0.86, 1.5);
    paint.color = Colors.cyanAccent.withValues(alpha: 0.45);
    canvas.drawCircle(tip, 5.2, paint);
    paint.color = Colors.white;
    canvas.drawCircle(tip, 2.2, paint);
    paint.strokeCap = StrokeCap.butt;
  }

  void _drawFloatingTexts(Canvas canvas) {
    for (final textItem in engine.floatingTexts) {
      final isSpecial = !textItem.text.startsWith('+');
      final fontSize = (isSpecial ? 14.0 : 12.5) * textItem.popScale;
      final textPainter = TextPainter(
        text: TextSpan(
          text: textItem.text,
          style: TextStyle(
            color: textItem.color.withValues(alpha: textItem.alpha),
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: isSpecial ? 0.5 : 0.0,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: textItem.alpha * 0.92),
                offset: const Offset(0, 1.4),
                blurRadius: 3,
              ),
              Shadow(
                color: textItem.color.withValues(alpha: textItem.alpha * 0.45),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          textItem.x - textPainter.width / 2,
          textItem.y - textPainter.height / 2,
        ),
      );
      textPainter.dispose();
    }
  }

  void _drawFirestormVortex(Canvas canvas, Paint paint) {
    final center = engine.player.transform.position;
    final time = engine.elapsedTime;

    // Heat-wave radial aura
    paint
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          const Color(0x38FF6B2B),
          const Color(0x18FF9F1C),
          const Color(0x00FF6B2B),
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 82));
    canvas.drawCircle(center, 82, paint);
    paint.shader = null;

    // Multi-layered spiraling flame ribbons
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final r = 46.0 + i * 9.5;
      final start = time * (4.2 - i * 0.4) + i * 1.6;
      paint
        ..strokeWidth = 5.0
        ..color = const Color(0x55EA580C);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start,
        1.5,
        false,
        paint,
      );
      paint
        ..strokeWidth = 2.0
        ..color = (i.isEven ? const Color(0xFFFFB74D) : const Color(0xFFFFF59D))
            .withValues(alpha: 0.85);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start + 0.1,
        1.25,
        false,
        paint,
      );
    }

    // Orbiting incandescent embers
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final a = time * 4.8 + i * pi / 4;
      final r = 50.0 + (i % 3) * 11.0;
      final pt = center + Offset(cos(a) * r, sin(a) * r);
      paint.color = const Color(0xFFFFE082).withValues(alpha: 0.9);
      canvas.drawCircle(pt, i.isEven ? 2.2 : 1.5, paint);
    }
    paint.strokeCap = StrokeCap.butt;
  }

  void _drawOverdriveAura(Canvas canvas, Paint paint) {
    final center = engine.player.transform.position;
    final time = engine.elapsedTime;
    final r = engine.player.radius + 14;
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4
      ..color = Colors.amberAccent.withValues(alpha: 0.75);
    for (int i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r + i * 4),
        time * 6.5 + i * 2 * pi / 3,
        1.1,
        false,
        paint,
      );
    }
    paint
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.fill;
  }

  void _drawExpansionBanner(Canvas canvas, Size size) {
    final accent = engine.level.theme.accent;
    final label = TextPainter(
      text: const TextSpan(
        text: 'HOÀN THÀNH · ĐANG MỞ RỘNG',
        style: TextStyle(
          color: Color(0xFFF1F5F9),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);
    final position = Offset((size.width - label.width) / 2, 18);
    final bannerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        position.dx - 16,
        position.dy - 9,
        label.width + 32,
        label.height + 18,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(bannerRect, Paint()..color = const Color(0xEE101C2C));
    canvas.drawRRect(
      bannerRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent.withValues(alpha: 0.65),
    );
    label.paint(canvas, position);
    label.dispose();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
