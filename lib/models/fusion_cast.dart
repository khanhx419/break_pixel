import 'dart:math';

import 'package:flutter/material.dart';

import 'ecs.dart';

class FusionRules {
  static String hint(ElementType type) => switch (type) {
    ElementType.chainLightning => 'Cần khối ướt. Sét truyền tối đa 24 ô ướt tiếp giáp; chuẩn bị mạng dẫn trước khi bấm.',
    ElementType.superconductor => 'Cần khối đông cứng. Đánh vào cụm băng để phát điện lạnh và làm giòn các ô bên cạnh.',
    ElementType.explosiveGas => 'Cần khối nhiễm độc. Chờ độc phủ cụm rồi kích nổ, sát thương giảm theo khoảng cách.',
    ElementType.acidMelt => 'Cần khối ướt. Ăn mòn 25% HP tối đa của tối đa 9 ô, chỉ một lần mỗi ô; tiếp tục gây độc.',
    ElementType.avalanche => 'Ngắm một khối để chọn hàng ngang. Sóng tuyết quét cả hàng; hiệu quả với hàng còn nhiều khối.',
    ElementType.firestorm => 'Bão lửa bám theo bóng trong 4 giây. Lướt dọc mép cụm khối để tận dụng vùng thiêu đốt.',
    ElementType.permafrost => 'Đóng băng cụm trong 6 giây. Tiếp cận và đánh tiếp trong cửa sổ khối giòn +50% sát thương.',
    ElementType.voidVortex => 'Đặt điện trường tồn tại 2,5 giây, giật nhiều nhịp và hút vật phẩm; các ô tranh giữ nguyên vị trí.',
    ElementType.mist => 'Đặt vùng sương gây sát thương trong 4 giây. Ngắm cụm dày để giữ nhiều mục tiêu trong vùng.',
    ElementType.lavaBurst => 'Nổ dung nham quanh điểm ngắm, để lại bỏng nặng. Dùng để mở một lối xuyên cụm khối.',
    _ => '',
  };
}

/// One cast uses a fixed set of strokes, not one emitter per affected tile.
class FusionCast {
  static const windup = 0.35;
  final ElementType type;
  Offset center;
  final Color color;
  final String targetId;
  Rect board;
  final double duration = 1.25;
  double age = 0;
  FusionCast({
    required this.type,
    required this.center,
    required this.color,
    required this.targetId,
    required this.board,
  });

  void draw(Canvas canvas, Paint paint) {
    final preparing = age < windup;
    final prepT = (age / windup).clamp(0.0, 1.0);
    final t = ((age - windup) / (duration - windup)).clamp(0.0, 1.0);
    final easeOut = 1 - pow(1 - t, 3).toDouble();
    final radius = preparing
        ? 44.0 - prepT * 24.0
        : 18.0 + easeOut * 74.0;
    final alpha = preparing ? (0.45 + prepT * 0.55) : (1 - t);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    paint
      ..shader = null
      ..maskFilter = null;

    if (preparing) {
      _drawRunicWindup(canvas, paint, radius, prepT, alpha);
    } else {
      _drawActiveCast(canvas, paint, radius, t, easeOut, alpha);
    }

    canvas.restore();
    paint
      ..shader = null
      ..maskFilter = null
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.fill;
  }

  void _drawRunicWindup(
    Canvas canvas,
    Paint paint,
    double radius,
    double prepT,
    double alpha,
  ) {
    // Soft converging energy aura
    paint
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: prepT * 0.45),
          color.withValues(alpha: prepT * 0.32),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius * 1.4));
    canvas.drawCircle(Offset.zero, radius * 1.4, paint);
    paint.shader = null;

    // Outer counter-rotating magic ring
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0
      ..color = color.withValues(alpha: alpha * 0.85);
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4 + age * 3.2;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        a,
        0.48,
        false,
        paint,
      );
      // Converging energy sparks
      final outer = Offset(cos(a), sin(a)) * (radius + 14 * (1 - prepT) + 4);
      final inner = Offset(cos(a), sin(a)) * (radius + 3);
      paint
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: alpha * 0.75);
      canvas.drawLine(outer, inner, paint);
      paint
        ..strokeWidth = 2.0
        ..color = color.withValues(alpha: alpha * 0.85);
    }

    // Inner inscribed hexagram / rune star
    final innerR = radius * 0.62;
    for (int tri = 0; tri < 2; tri++) {
      final path = Path();
      for (int v = 0; v < 3; v++) {
        final a = -age * 2.5 + tri * pi / 3 + v * 2 * pi / 3;
        final pt = Offset(cos(a), sin(a)) * innerR;
        if (v == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      paint
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: alpha * 0.65);
      canvas.drawPath(path, paint);
    }

    // Bright charging core
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: prepT * 0.9);
    canvas.drawCircle(Offset.zero, 2.5 + prepT * 4.5, paint);
  }

  void _drawActiveCast(
    Canvas canvas,
    Paint paint,
    double radius,
    double t,
    double easeOut,
    double alpha,
  ) {
    // Ground radial bloom
    paint
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: (1 - t) * 0.22),
          color.withValues(alpha: (1 - t) * 0.34),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.38, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius * 1.45));
    canvas.drawCircle(Offset.zero, radius * 1.45, paint);
    paint.shader = null;

    // Expanding outer shockwave ring
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5 * (1 - t) + 0.6
      ..color = color.withValues(alpha: alpha * 0.35);
    canvas.drawCircle(Offset.zero, radius * 1.08, paint);

    switch (type) {
      case ElementType.avalanche:
        _drawAvalanche(canvas, paint, radius, t, alpha);
      case ElementType.superconductor:
        _drawSuperconductor(canvas, paint, radius, t, alpha);
      case ElementType.permafrost:
        _drawPermafrost(canvas, paint, radius, t, alpha);
      case ElementType.voidVortex:
        _drawVoidVortex(canvas, paint, radius, t, alpha);
      case ElementType.firestorm:
        _drawFirestorm(canvas, paint, radius, t, alpha);
      case ElementType.mist:
        _drawMist(canvas, paint, radius, t, alpha);
      case ElementType.explosiveGas:
        _drawExplosiveGas(canvas, paint, radius, t, alpha);
      case ElementType.acidMelt:
        _drawAcidMelt(canvas, paint, radius, t, alpha);
      case ElementType.lavaBurst:
        _drawLavaBurst(canvas, paint, radius, t, alpha);
      case ElementType.chainLightning:
        _drawChainLightning(canvas, paint, radius, t, alpha);
      default:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * (1 - t) + 0.5
          ..color = color.withValues(alpha: alpha);
        for (int i = 0; i < 4; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset.zero, radius: radius),
            i * pi / 2 + t,
            1.1,
            false,
            paint,
          );
        }
    }

    // Incandescent flash core at detonation
    if (t < 0.22 && type != ElementType.voidVortex && type != ElementType.mist) {
      final flash = 1 - t / 0.22;
      paint
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: flash * 0.85);
      canvas.drawCircle(Offset.zero, 10 * flash + 2, paint);
    }
  }

  void _drawAvalanche(
    Canvas canvas,
    Paint paint,
    double radius,
    double t,
    double alpha,
  ) {
    final left = board.left - center.dx;
    final right = board.right - center.dx;
    final bandH = (16.0 + (1 - t) * 18.0);
    // Frosted snow-wave gradient ribbon across full row
    final bandRect = Rect.fromLTRB(left, -bandH * 0.5, right, bandH * 0.5);
    paint
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0x00B8ECFF),
          const Color(0xFFCCF2FF).withValues(alpha: alpha * 0.42),
          Colors.white.withValues(alpha: alpha * 0.58),
          const Color(0xFF9CD9F5).withValues(alpha: alpha * 0.35),
          const Color(0x00B8ECFF),
        ],
      ).createShader(bandRect);
    canvas.drawRect(bandRect, paint);
    paint.shader = null;

    // Sweeping wind-slash streaks & snow boulders
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final y = (i - 2) * bandH * 0.22;
      final shift = (i.isEven ? 1 : -1) * t * 45;
      paint
        ..strokeWidth = i == 2 ? 2.6 : 1.4
        ..color = (i == 2 ? Colors.white : const Color(0xFFA7E5FF))
            .withValues(alpha: alpha * (i == 2 ? 0.92 : 0.65));
      canvas.drawLine(
        Offset(left + shift * 0.3, y),
        Offset(right + shift * 0.3, y),
        paint,
      );
    }
    // Tumbling angular ice shards along the row
    paint.style = PaintingStyle.fill;
    final span = right - left;
    for (int i = 0; i < 10; i++) {
      final u = ((i / 10) + t * 0.35) % 1.0;
      final x = left + u * span;
      final y = sin(i * 2.3 + t * 8) * bandH * 0.35;
      final sz = 3.0 + (i % 3) * 2.2;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 7 + i);
      paint.color = (i.isEven ? Colors.white : const Color(0xFF8BE2FF))
          .withValues(alpha: alpha * 0.85);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: sz, height: sz), paint);
      canvas.restore();
    }
  }

  void _drawSuperconductor(
    Canvas canvas,
    Paint paint,
    double radius,
    double t,
    double alpha,
  ) {
    // Dual cryogenic-electric hexagonal field
    paint.style = PaintingStyle.stroke;
    for (int ring = 0; ring < 2; ring++) {
      final r = radius * (ring == 0 ? 0.92 : 0.56);
      final hex = Path();
      for (int i = 0; i < 6; i++) {
        final a = i * pi / 3 + t * (ring == 0 ? 0.45 : -0.7);
        final pt = Offset(cos(a), sin(a)) * r;
        if (i == 0) {
          hex.moveTo(pt.dx, pt.dy);
        } else {
          hex.lineTo(pt.dx, pt.dy);
        }
      }
      hex.close();
      paint
        ..strokeWidth = ring == 0 ? 4.0 : 2.2
        ..color = const Color(0xFF53C8FF).withValues(alpha: alpha * 0.3);
      canvas.drawPath(hex, paint);
      paint
        ..strokeWidth = 1.3
        ..color = const Color(0xFFE0FAFF).withValues(alpha: alpha * 0.9);
      canvas.drawPath(hex, paint);
    }

    // 6 jagged cryo-plasma arms with glowing terminals
    for (int i = 0; i < 6; i++) {
      canvas.save();
      canvas.rotate(i * pi / 3 + t * 0.35);
      final circuit = Path()
        ..moveTo(6, 0)
        ..lineTo(radius * 0.28, -7)
        ..lineTo(radius * 0.46, 9)
        ..lineTo(radius * 0.68, -8)
        ..lineTo(radius * 0.86, 4)
        ..lineTo(radius, 0);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0 * (1 - t * 0.4)
        ..color = const Color(0xFF40BFFF).withValues(alpha: alpha * 0.35);
      canvas.drawPath(circuit, paint);
      paint
        ..strokeWidth = 1.6
        ..color = const Color(0xFFF2FCFF).withValues(alpha: alpha * 0.95);
      canvas.drawPath(circuit, paint);
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF8BE9FF).withValues(alpha: alpha * 0.5);
      canvas.drawCircle(Offset(radius, 0), 5.0 * (1 - t * 0.4), paint);
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(radius, 0), 2.2, paint);
      canvas.restore();
    }
  }

  void _drawPermafrost(
    Canvas canvas,
    Paint paint,
    double radius,
    double t,
    double alpha,
  ) {
    // Faceted 6-point glacial crystal star
    final star = Path();
    for (int i = 0; i < 12; i++) {
      final a = i * pi / 6 + t * 0.25;
      final r = i.isEven ? radius * 0.95 : radius * 0.38;
      final pt = Offset(cos(a), sin(a)) * r;
      if (i == 0) {
        star.moveTo(pt.dx, pt.dy);
      } else {
        star.lineTo(pt.dx, pt.dy);
      }
    }
    star.close();
    paint
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: alpha * 0.5),
          const Color(0xFF67E8F9).withValues(alpha: alpha * 0.28),
          const Color(0xFF0EA5E9).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.drawPath(star, paint);
    paint.shader = null;

    // Ornate crystalline frost branches + chevron needles
    paint.style = PaintingStyle.stroke;
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3 + t * 0.25;
      final dir = Offset(cos(a), sin(a));
      final end = dir * radius;
      paint
        ..strokeWidth = 4.2 * (1 - t * 0.4)
        ..color = const Color(0xFF38BDF8).withValues(alpha: alpha * 0.35);
      canvas.drawLine(dir * 6, end, paint);
      paint
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: alpha * 0.95);
      canvas.drawLine(dir * 6, end, paint);

      // Symmetrical frost chevrons at 55% and 80%
      for (final frac in [0.55, 0.8]) {
        final node = dir * (radius * frac);
        final branchLen = radius * (frac == 0.55 ? 0.24 : 0.16);
        for (final side in [-1.0, 1.0]) {
          final tip = node +
              Offset(cos(a + side * 0.72), sin(a + side * 0.72)) * branchLen;
          paint
            ..strokeWidth = 1.3
            ..color = const Color(0xFFCFFAFE).withValues(alpha: alpha * 0.85);
          canvas.drawLine(node, tip, paint);
        }
      }
    }
    // Inner ice ring
    paint
      ..strokeWidth = 2.0
      ..color = const Color(0xFFA5F3FC).withValues(alpha: alpha * 0.8);
    canvas.drawCircle(Offset.zero, radius * 0.56, paint);
  }

  void _drawVoidVortex(
    Canvas canvas,
    Paint paint,
    double radius,
    double t,
    double alpha,
  ) {
    // Deep event horizon glow + pitch black core
    paint
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF05040E).withValues(alpha: alpha * 0.95),
          const Color(0xFF1A0B38).withValues(alpha: alpha * 0.85),
          const Color(0xFF9333EA).withValues(alpha: alpha * 0.45),
          const Color(0x00A855F7),
        ],
        stops: const [0.0, 0.36, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius * 0.9));
    canvas.drawCircle(Offset.zero, radius * 0.9, paint);
    paint.shader = null;

    // Warped accretion disk ellipses
    paint.style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(age * 2.2 + i * 0.72);
      final oval = Rect.fromCenter(
        center: Offset.zero,
        width: radius * (1.2 + i * 0.22),
        height: radius * 0.46,
      );
      paint
        ..strokeWidth = 3.8 * (1 - t * 0.3)
        ..color = (i.isEven ? const Color(0xFFC084FC) : const Color(0xFFF472B6))
            .withValues(alpha: alpha * 0.35);
      canvas.drawOval(oval, paint);
      paint
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: alpha * 0.8);
      canvas.drawOval(oval, paint);
      canvas.restore();
    }

    // Singularity photon ring
    paint
      ..strokeWidth = 2.2
      ..color = const Color(0xFFF5D0FE).withValues(alpha: alpha * 0.9);
    canvas.drawCircle(Offset.zero, radius * 0.35, paint);
  }

  void _drawFirestorm(
    Canvas canvas,
    Paint paint,
    double radius,
    double t,
    double alpha,
  ) {
    // 4 blazing multi-pass spiral flame arms
    paint.style = PaintingStyle.stroke;
    for (int arm = 0; arm < 4; arm++) {
      final path = Path();
      for (int j = 0; j <= 18; j++) {
        final u = j / 18;
        final a = arm * pi * 0.5 + age * 4.8 + u * 3.8;
        final pt = Offset(cos(a), sin(a)) * radius * (0.1 + u * 0.92);
        if (j == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      // Outer crimson glow
      paint
        ..strokeWidth = 9.0 * (1 - t * 0.45)
        ..color = const Color(0xFFEA580C).withValues(alpha: alpha * 0.32);
      canvas.drawPath(path, paint);
      // Mid blazing orange flame
      paint
        ..strokeWidth = 4.2 * (1 - t * 0.45)
        ..color = const Color(0xFFFB923C).withValues(alpha: alpha * 0.85);
      canvas.drawPath(path, paint);
      // White-gold hot core
      paint
        ..strokeWidth = 1.4
        ..color = const Color(0xFFFFF7CD).withValues(alpha: alpha * 0.95);
      canvas.drawPath(path, paint);
    }

    // Flying ember sparks spiraling outward
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4 + age * 5.2;
      final dist = radius * (0.45 + ((i * 0.19 + t) % 0.6));
      final pt = Offset(cos(a), sin(a)) * dist;
      paint.color = const Color(0xFFFFE082).withValues(alpha: alpha * 0.9);
      canvas.drawCircle(pt, 2.2 * (1 - t * 0.5), paint);
    }
  }

  void _drawMist(
    Canvas canvas,
    Paint paint,
    double radius,
    double t,
    double alpha,
  ) {
    // Soft billowing volumetric steam clouds
    for (int i = 0; i < 5; i++) {
      final angle = i * pi * 2 / 5 + t * 0.6;
      final offset = Offset(cos(angle) * radius * 0.42, sin(angle) * radius * 0.24);
      final puffR = radius * (0.52 + (i % 2) * 0.12);
      paint
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE0F7FA).withValues(alpha: alpha * 0.34),
            const Color(0xFF94C5D3).withValues(alpha: alpha * 0.16),
            const Color(0x0094C5D3),
          ],
        ).createShader(Rect.fromCircle(center: offset, radius: puffR));
      canvas.drawCircle(offset, puffR, paint);
    }
    paint.shader = null;

    // Curling luminous vapor wind ribbons
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      paint
        ..strokeWidth = 2.0
        ..color = const Color(0xFFD9F3F7).withValues(alpha: alpha * 0.55);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * (1.3 + i * 0.25),
          height: radius * (0.65 + i * 0.14),
        ),
        t * 2.0 + i * 2.1,
        1.8,
        false,
        paint,
      );
    }
  }

  void _drawExplosiveGas(
    Canvas canvas,
    Paint paint,
    double radius,
    double t,
    double alpha,
  ) {
    // Billowing toxic-lime & fiery blast clouds
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3 + t * 0.4;
      final pt = Offset(cos(a), sin(a)) * (radius * 0.48);
      final cloudR = radius * 0.48;
      paint
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFB703).withValues(alpha: alpha * 0.45),
            const Color(0xFFA3E635).withValues(alpha: alpha * 0.3),
            const Color(0x0084CC16),
          ],
        ).createShader(Rect.fromCircle(center: pt, radius: cloudR));
      canvas.drawCircle(pt, cloudR, paint);
      paint.shader = null;
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * (1 - t * 0.4)
        ..color = const Color(0xFFD9F99D).withValues(alpha: alpha * 0.72);
      canvas.drawCircle(pt, cloudR * 0.78, paint);
    }

    // Incandescent blast rays shooting out from ignition center
    paint.style = PaintingStyle.stroke;
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4 + 0.2;
      final dir = Offset(cos(a), sin(a));
      paint
        ..strokeWidth = 3.0 * (1 - t)
        ..color = const Color(0xFFFF9F1C).withValues(alpha: alpha * 0.85);
      canvas.drawLine(dir * radius * 0.15, dir * radius * 0.95, paint);
    }
  }

  void _drawAcidMelt(
    Canvas canvas,
    Paint paint,
    double radius,
    double t,
    double alpha,
  ) {
    // Corrosive emerald splash pool
    paint
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF4ADE80).withValues(alpha: alpha * 0.36),
          const Color(0xFF10B981).withValues(alpha: alpha * 0.14),
          const Color(0x0010B981),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius * 1.1));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, radius * 0.18), width: radius * 1.8, height: radius * 0.9),
      paint,
    );
    paint.shader = null;

    // 5 viscous glowing acid droplets + sizzling concentric ripples
    for (int i = 0; i < 5; i++) {
      final x = (i - 2) * radius * 0.38;
      final y = sin(i * 1.9) * radius * 0.25 + t * radius * 0.35;
      final drop = Path()
        ..moveTo(x, y - 14)
        ..quadraticBezierTo(x + 9, y + 7, x, y + 9)
        ..quadraticBezierTo(x - 9, y + 7, x, y - 14);
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF22C55E).withValues(alpha: alpha * 0.55);
      canvas.drawPath(drop, paint);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFBBF7D0).withValues(alpha: alpha * 0.9);
      canvas.drawPath(drop, paint);
      // Specular shine on droplet
      paint
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: alpha * 0.75);
      canvas.drawCircle(Offset(x - 2, y + 1), 1.6, paint);
      // Sizzling ripple ring underneath
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF86EFAC).withValues(alpha: alpha * 0.75);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y + 13),
          width: radius * (0.35 + t * 0.25),
          height: 8,
        ),
        paint,
      );
    }
  }

  void _drawLavaBurst(
    Canvas canvas,
    Paint paint,
    double radius,
    double t,
    double alpha,
  ) {
    // Molten glowing crater ring
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0 * (1 - t * 0.4)
      ..color = const Color(0xFFEF4444).withValues(alpha: alpha * 0.45);
    canvas.drawCircle(Offset.zero, radius * 0.58, paint);
    paint
      ..strokeWidth = 1.8
      ..color = const Color(0xFFFDE047).withValues(alpha: alpha * 0.85);
    canvas.drawCircle(Offset.zero, radius * 0.58, paint);

    // 10 erupting magma jets + glowing molten blobs
    for (int i = 0; i < 10; i++) {
      final angle = i * pi / 5 + (i.isEven ? 0.08 : -0.08);
      final d = Offset(cos(angle), sin(angle));
      final reach = radius * (i.isEven ? 1.0 : 0.78);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.2 * (1 - t * 0.45)
        ..color = const Color(0xFFDC2626).withValues(alpha: alpha * 0.45);
      canvas.drawLine(d * radius * 0.2, d * reach, paint);
      paint
        ..strokeWidth = 2.0 * (1 - t * 0.3)
        ..color = const Color(0xFFFDBA74).withValues(alpha: alpha * 0.92);
      canvas.drawLine(d * radius * 0.25, d * reach, paint);
      // Molten droplet head
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFEF4444).withValues(alpha: alpha * 0.85);
      canvas.drawCircle(d * reach, 4.5 * (1 - t * 0.45) + 1, paint);
      paint.color = const Color(0xFFFEF08A).withValues(alpha: alpha);
      canvas.drawCircle(d * reach, 2.0 * (1 - t * 0.45) + 0.6, paint);
    }
  }

  void _drawChainLightning(
    Canvas canvas,
    Paint paint,
    double radius,
    double t,
    double alpha,
  ) {
    // High-voltage inner shock ring
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFFFACC15).withValues(alpha: alpha * 0.45);
    canvas.drawCircle(Offset.zero, radius * 0.45, paint);

    // 6 branching luminous lightning bolts
    for (int i = 0; i < 6; i++) {
      canvas.save();
      canvas.rotate(i * pi / 3 + t * 0.15);
      final bolt = Path()
        ..moveTo(4, 0)
        ..lineTo(radius * 0.3, -9)
        ..lineTo(radius * 0.48, 7)
        ..lineTo(radius * 0.68, -6)
        ..lineTo(radius * 0.85, 5)
        ..lineTo(radius * 1.05, 0);
      // Secondary fork
      final fork = Path()
        ..moveTo(radius * 0.48, 7)
        ..lineTo(radius * 0.66, 16)
        ..lineTo(radius * 0.82, 13);

      paint
        ..strokeWidth = 6.0 * (1 - t * 0.35)
        ..color = const Color(0xFFFACC15).withValues(alpha: alpha * 0.32);
      canvas.drawPath(bolt, paint);
      canvas.drawPath(fork, paint);

      paint
        ..strokeWidth = 2.4
        ..color = const Color(0xFFFEF08A).withValues(alpha: alpha * 0.88);
      canvas.drawPath(bolt, paint);

      paint
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: alpha);
      canvas.drawPath(bolt, paint);
      canvas.drawPath(fork, paint);

      // Electric terminal spark
      paint
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: alpha * 0.9);
      canvas.drawCircle(Offset(radius * 1.05, 0), 2.4 * (1 - t * 0.4), paint);
      paint.style = PaintingStyle.stroke;
      canvas.restore();
    }
  }
}
