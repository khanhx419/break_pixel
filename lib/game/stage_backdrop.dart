import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/stage_theme.dart';

/// Keeps a single picture per engine, disposing it on scene/viewport changes.
class StageBackdrop {
  ui.Picture? _picture;
  Size? _size;
  Rect? _board;
  StageTheme? _theme;
  int generationCount = 0;
  bool get isCached => _picture != null;

  void draw(
    Canvas canvas,
    Size size,
    Rect board,
    StageTheme theme,
    double time,
  ) {
    if (_picture == null ||
        _size != size ||
        _board != board ||
        _theme != theme) {
      _picture?.dispose();
      final recorder = ui.PictureRecorder();
      _record(Canvas(recorder), size, board, theme);
      _picture = recorder.endRecording();
      _size = size;
      _board = board;
      _theme = theme;
      generationCount++;
    }
    canvas.drawPicture(_picture!);

    // Fixed-count live atmospheric effects; zero emitters or growing particle lists.
    _drawLiveAtmosphere(canvas, size, board, theme, time);
    _drawAnimatedBoardFrame(canvas, board, theme, time);
  }

  void _drawLiveAtmosphere(
    Canvas canvas,
    Size size,
    Rect board,
    StageTheme theme,
    double time,
  ) {
    final paint = Paint();
    final safeBoard = board.inflate(10);
    final w = size.width;
    final h = size.height;

    switch (theme.motif) {
      case StageMotif.volcano:
      case StageMotif.foundry:
        // Rising embers / forge sparks
        for (int i = 0; i < 20; i++) {
          final seed = i * 0.371;
          final x =
              ((seed * 2.13 + sin(time * 0.6 + i) * 0.025) % 1.0) * w;
          final y = (1.0 - ((time * (0.045 + (i % 4) * 0.015) + seed) % 1.0)) * h;
          final pos = Offset(x, y);
          if (safeBoard.contains(pos)) continue;
          final flicker = 0.3 + (sin(time * 5.0 + i * 2.1) + 1) * 0.32;
          paint.color = theme.accent.withValues(alpha: flicker * 0.25);
          canvas.drawCircle(pos, i % 3 == 0 ? 4.2 : 2.6, paint);
          paint.color = Color.lerp(theme.accent, Colors.white, 0.5)!
              .withValues(alpha: flicker * 0.85);
          canvas.drawCircle(pos, i % 3 == 0 ? 1.5 : 1.0, paint);
        }
      case StageMotif.city:
        // Neon rain streaks & distant blinking beacons
        paint
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.1;
        for (int i = 0; i < 18; i++) {
          final x = ((i * 0.197 + 0.04) % 1.0) * w;
          final y = ((time * (0.28 + (i % 3) * 0.08) + i * 0.23) % 1.0) * h;
          final pos = Offset(x, y);
          if (safeBoard.contains(pos)) continue;
          final len = 10.0 + (i % 3) * 6.0;
          paint.color = theme.accent.withValues(alpha: 0.22);
          canvas.drawLine(pos, pos + Offset(-1.5, len), paint);
        }
        paint.style = PaintingStyle.fill;
      case StageMotif.glacier:
        // Drifting frost snowflakes & aurora shimmer
        for (int i = 0; i < 20; i++) {
          final x = ((i * 0.271 + time * 0.022 + sin(time * 0.7 + i) * 0.02) % 1.0) * w;
          final y = ((i * 0.193 + time * (0.032 + (i % 3) * 0.012)) % 1.0) * h;
          final pos = Offset(x, y);
          if (safeBoard.contains(pos)) continue;
          final alpha = 0.25 + (sin(time * 2.2 + i) + 1) * 0.22;
          paint.color = Colors.white.withValues(alpha: alpha * 0.35);
          canvas.drawCircle(pos, 3.0, paint);
          paint.color = theme.accent.withValues(alpha: alpha * 0.85);
          canvas.drawCircle(pos, 1.2, paint);
        }
      case StageMotif.forest:
      case StageMotif.marsh:
        // Glowing drifting fireflies / spores
        for (int i = 0; i < 18; i++) {
          final x =
              ((i * 0.237 + 0.06) % 1.0) * w + sin(time * 0.45 + i * 1.4) * 14;
          final y =
              ((i * 0.173 + 0.12) % 0.88) * h + cos(time * 0.38 + i * 1.1) * 10;
          final pos = Offset(x, y);
          if (safeBoard.contains(pos)) continue;
          final pulse = (sin(time * 2.1 + i * 1.7) + 1) * 0.5;
          paint.color = theme.accent.withValues(alpha: 0.08 + pulse * 0.18);
          canvas.drawCircle(pos, 3.5 + pulse * 2.5, paint);
          paint.color = Colors.white.withValues(alpha: 0.28 + pulse * 0.55);
          canvas.drawCircle(pos, 1.3, paint);
        }
      case StageMotif.temple:
      case StageMotif.cosmos:
      case StageMotif.valley:
        // Twinkling 4-point starlight / mystic wisps / golden dust
        for (int i = 0; i < 18; i++) {
          final x =
              ((i * 0.237 + 0.05) % 1.0) * w + sin(time * 0.22 + i) * 7;
          final y =
              ((i * 0.173 + 0.1) % 0.9) * h + cos(time * 0.18 + i) * 6;
          final pos = Offset(x, y);
          if (safeBoard.contains(pos)) continue;
          final pulse = (sin(time * 1.8 + i * 1.3) + 1) * 0.5;
          final r = (i % 3 == 0 ? 3.2 : 2.0) * (0.65 + pulse * 0.45);
          paint.color = theme.accent.withValues(alpha: 0.1 + pulse * 0.2);
          canvas.drawCircle(pos, r * 1.6, paint);
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = Color.lerp(theme.accent, Colors.white, 0.55)!
                .withValues(alpha: 0.25 + pulse * 0.55);
          canvas.drawLine(pos - Offset(r, 0), pos + Offset(r, 0), paint);
          canvas.drawLine(pos - Offset(0, r), pos + Offset(0, r), paint);
          paint.style = PaintingStyle.fill;
        }
    }
  }

  void _drawAnimatedBoardFrame(
    Canvas canvas,
    Rect board,
    StageTheme theme,
    double time,
  ) {
    final frame = board.inflate(5);
    final perim = 2 * (frame.width + frame.height);
    if (perim <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Two subtle light glints orbiting the arena border
    for (int g = 0; g < 2; g++) {
      final dist = ((time * 58 + g * perim * 0.5) % perim);
      final p1 = _pointOnRect(frame, dist);
      final p2 = _pointOnRect(frame, (dist + 26) % perim);
      if ((p2 - p1).distance < 34) {
        paint
          ..strokeWidth = 3.2
          ..color = theme.accent.withValues(alpha: 0.18);
        canvas.drawLine(p1, p2, paint);
        paint
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.55);
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  Offset _pointOnRect(Rect r, double d) {
    if (d < r.width) return Offset(r.left + d, r.top);
    d -= r.width;
    if (d < r.height) return Offset(r.right, r.top + d);
    d -= r.height;
    if (d < r.width) return Offset(r.right - d, r.bottom);
    d -= r.width;
    return Offset(r.left, r.bottom - d);
  }

  void _record(Canvas canvas, Size size, Rect board, StageTheme theme) {
    final w = size.width, h = size.height;
    final full = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(theme.sky, Colors.black, 0.25)!,
          theme.sky,
          theme.horizon,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(full);
    canvas.drawRect(full, paint);
    paint.shader = null;

    // Position the celestial body in the visible margin outside the board when wide enough.
    final rightMargin = w - board.right;
    final lightX = rightMargin > 70
        ? board.right + rightMargin * 0.52
        : w * 0.86;
    final lightY = h * 0.16;
    final light = Offset(lightX, lightY);
    final orbR = min(w, h) * 0.044;

    // Atmospheric radial bloom
    paint.shader = RadialGradient(
      colors: [
        theme.accent.withValues(alpha: 0.26),
        theme.accent.withValues(alpha: 0.08),
        theme.accent.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.38, 1.0],
    ).createShader(Rect.fromCircle(center: light, radius: h * 0.65));
    canvas.drawRect(full, paint);
    paint.shader = null;

    // Outer soft corona + crisp celestial disc (or true crescent moon for City & Temple)
    final isCrescent =
        theme.motif == StageMotif.city || theme.motif == StageMotif.temple;
    paint.color = theme.accent.withValues(alpha: 0.22);
    canvas.drawCircle(light, orbR * 1.55, paint);
    if (isCrescent) {
      final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: light, radius: orbR)),
        Path()..addOval(
          Rect.fromCircle(
            center: light - Offset(orbR * 0.42, orbR * 0.24),
            radius: orbR * 0.88,
          ),
        ),
      );
      paint.shader = RadialGradient(
        center: const Alignment(0.35, 0.25),
        colors: [
          Colors.white.withValues(alpha: 0.9),
          theme.accent.withValues(alpha: 0.75),
        ],
      ).createShader(Rect.fromCircle(center: light, radius: orbR));
      canvas.drawPath(moon, paint);
      paint.shader = null;
    } else {
      paint.shader = RadialGradient(
        center: const Alignment(-0.25, -0.25),
        colors: [
          Colors.white.withValues(alpha: 0.85),
          theme.accent.withValues(alpha: 0.7),
        ],
      ).createShader(Rect.fromCircle(center: light, radius: orbR));
      canvas.drawCircle(light, orbR, paint);
      paint.shader = null;
    }

    // Crisp multi-scale starfield in upper sky
    for (int i = 0; i < 64; i++) {
      final x = ((i * 137 + 41) % 997) / 997 * w;
      final y = ((i * 71 + 13) % 503) / 503 * h * 0.62;
      final bright = i % 7 == 0;
      paint.color = Color.lerp(theme.accent, Colors.white, bright ? 0.7 : 0.3)!
          .withValues(alpha: bright ? 0.45 : (i % 3 == 0 ? 0.24 : 0.11));
      if (bright) {
        canvas.drawCircle(Offset(x, y), 1.4, paint);
        paint.color = theme.accent.withValues(alpha: 0.16);
        canvas.drawCircle(Offset(x, y), 3.2, paint);
      } else {
        canvas.drawRect(Rect.fromLTWH(x, y, i % 4 == 0 ? 1.8 : 1.1, 1.1), paint);
      }
    }

    // Layered angular terrain with atmospheric rim lighting
    for (
      int layer = 0;
      layer < (theme.motif == StageMotif.cosmos ? 0 : 3);
      layer++
    ) {
      final path = Path()..moveTo(0, h);
      final ridge = Path();
      for (int j = 0; j <= 16; j++) {
        final x = w * j / 16;
        final jagged =
            theme.motif == StageMotif.glacier ||
            theme.motif == StageMotif.volcano;
        final y =
            h * (0.48 + layer * 0.145) +
            sin(j * 1.65 + layer * 2.1 + theme.motif.index) *
                h *
                (jagged
                    ? 0.145
                    : theme.motif == StageMotif.marsh
                    ? 0.015
                    : 0.068);
        path.lineTo(x, y);
        if (j == 0) {
          ridge.moveTo(x, y);
        } else {
          ridge.lineTo(x, y);
        }
      }
      path
        ..lineTo(w, h)
        ..close();
      final baseColor = [
        theme.far,
        Color.lerp(theme.far, theme.near, 0.55)!,
        theme.near,
      ][layer];
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          baseColor,
          Color.lerp(baseColor, Colors.black, 0.32)!,
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.35, w, h * 0.65));
      paint.style = PaintingStyle.fill;
      canvas.drawPath(path, paint);
      paint.shader = null;

      // Subtle rim highlight along mountain silhouettes
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = layer == 0 ? 1.1 : 0.8
        ..color = theme.accent.withValues(alpha: layer == 0 ? 0.18 : 0.09);
      canvas.drawPath(ridge, paint);
      paint.style = PaintingStyle.fill;
    }

    switch (theme.motif) {
      case StageMotif.valley:
        _clouds(canvas, paint, size, theme);
        // Warm horizon mist band
        paint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.accent.withValues(alpha: 0),
            theme.accent.withValues(alpha: 0.09),
            theme.accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.62, w, h * 0.24));
        canvas.drawRect(Rect.fromLTWH(0, h * 0.62, w, h * 0.24), paint);
        paint.shader = null;
        for (int i = 0; i < 11; i++) {
          _pine(
            canvas,
            paint,
            Offset(w * i / 10, h * (0.85 + sin(i * 1.3) * 0.035)),
            h * (0.12 + i % 3 * 0.03),
            theme.near,
            theme.accent.withValues(alpha: 0.12),
          );
        }
      case StageMotif.marsh:
        for (final x in [w * 0.065, w * 0.935]) {
          paint
            ..style = PaintingStyle.fill
            ..color = theme.near;
          canvas.drawRect(Rect.fromLTWH(x - 6, h * 0.4, 12, h * 0.48), paint);
          final canopy = Rect.fromCenter(
            center: Offset(x, h * 0.38),
            width: w * 0.24,
            height: h * 0.14,
          );
          canvas.drawOval(canopy, paint);
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = Color.lerp(theme.near, theme.accent, 0.2)!;
          for (int j = -3; j <= 3; j++) {
            final vine = Path()
              ..moveTo(x + j * 14, h * 0.4)
              ..quadraticBezierTo(
                x + j * 17,
                h * 0.51,
                x + j * 19 - 7,
                h * (0.6 - j.abs() * 0.024),
              );
            canvas.drawPath(vine, paint);
          }
        }
        // Shimmering jade water surface & glowing lotus pads
        paint.style = PaintingStyle.fill;
        paint.color = theme.accent.withValues(alpha: 0.16);
        for (int i = 0; i < 18; i++) {
          final y = h * (0.78 + i * 0.011);
          final x = ((i * 0.317) % 1) * w;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, w * (0.035 + i % 3 * 0.025), 1.5),
              const Radius.circular(1),
            ),
            paint,
          );
        }
        // Subtle glowing lotus blossoms on water margins
        for (final lx in [w * 0.09, w * 0.16, w * 0.85, w * 0.92]) {
          final ly = h * 0.87;
          paint.color = theme.accent.withValues(alpha: 0.18);
          canvas.drawOval(
            Rect.fromCenter(center: Offset(lx, ly), width: 28, height: 8),
            paint,
          );
          paint.color = const Color(0x88F8C6D8);
          canvas.drawCircle(Offset(lx, ly - 3), 3.5, paint);
        }
        for (int i = 0; i < 12; i++) {
          final x = i * w / 11;
          final y = h * 0.96;
          paint
            ..color = theme.near
            ..strokeWidth = 2;
          canvas.drawLine(Offset(x, y), Offset(x + 5, y - h * 0.13), paint);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x + 4, y - h * 0.1),
              width: 5,
              height: 15,
            ),
            paint,
          );
        }
      case StageMotif.city:
        // Distant neon glow at horizon
        paint.shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            theme.accent.withValues(alpha: 0.18),
            theme.accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.65, w, h * 0.35));
        canvas.drawRect(Rect.fromLTWH(0, h * 0.65, w, h * 0.35), paint);
        paint.shader = null;
        for (int i = 0; i < 20; i++) {
          final x = w * i / 19;
          final bw = w / 22;
          final bh = h * (0.16 + ((i * 7) % 11) * 0.022);
          final topY = h * 0.93 - bh;
          paint.color = i.isEven ? theme.near : theme.far;
          canvas.drawRect(Rect.fromLTWH(x, topY, bw, bh), paint);
          // Neon rooftop rim & spire
          paint.color = theme.accent.withValues(alpha: i % 3 == 0 ? 0.45 : 0.18);
          canvas.drawRect(Rect.fromLTWH(x, topY, bw, 1.5), paint);
          if (i % 4 == 0) {
            canvas.drawRect(Rect.fromLTWH(x + bw * 0.48, topY - 14, 1.5, 14), paint);
            paint.color = const Color(0xBB82F3FF);
            canvas.drawCircle(Offset(x + bw * 0.5, topY - 14), 2, paint);
          }
          // Glowing cyberpunk window grid
          for (int row = 0; row < 6; row++) {
            for (int col = 0; col < 2; col++) {
              if ((row + i + col) % 3 == 0) continue;
              paint.color = ((row + i) % 5 == 0
                      ? const Color(0xFF7BE8FF)
                      : theme.accent)
                  .withValues(alpha: 0.32);
              canvas.drawRect(
                Rect.fromLTWH(
                  x + 4 + col * (bw * 0.36),
                  topY + row * 10 + 7,
                  3.2,
                  3.5,
                ),
                paint,
              );
            }
          }
        }
      case StageMotif.glacier:
        // Multi-toned shimmering Aurora Borealis curtains
        for (int i = 0; i < 4; i++) {
          final ribbon = Path()
            ..moveTo(-20, h * (0.11 + i * 0.048))
            ..cubicTo(
              w * 0.28,
              h * (-0.04 + i * 0.03),
              w * 0.62,
              h * (0.38 - i * 0.02),
              w + 20,
              h * (0.08 + i * 0.03),
            );
          paint
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 18.0 + i * 6
            ..color = Color.lerp(
              theme.accent,
              const Color(0xFF7E74F7),
              i / 4,
            )!.withValues(alpha: 0.055);
          canvas.drawPath(ribbon, paint);
          paint
            ..strokeWidth = 3.0
            ..color = theme.accent.withValues(alpha: 0.11);
          canvas.drawPath(ribbon, paint);
        }
        paint.style = PaintingStyle.fill;
        for (int i = 0; i < 10; i++) {
          _pine(
            canvas,
            paint,
            Offset(w * i / 9, h * 0.96),
            h * 0.16,
            theme.near,
            theme.accent.withValues(alpha: 0.22),
          );
        }
      case StageMotif.forest:
        for (final x in [w * 0.075, w * 0.925]) {
          final glowRect = Rect.fromCircle(
            center: Offset(x, h * 0.78),
            radius: h * 0.16,
          );
          paint
            ..style = PaintingStyle.fill
            ..shader = RadialGradient(
              colors: [
                theme.accent.withValues(alpha: 0.2),
                theme.accent.withValues(alpha: 0),
              ],
            ).createShader(glowRect);
          canvas.drawRect(glowRect, paint);
          paint.shader = null;
          paint.color = Color.lerp(theme.near, theme.accent, 0.18)!;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 6, h * 0.78, 12, h * 0.15),
              const Radius.circular(5),
            ),
            paint,
          );
          paint.color = theme.accent.withValues(alpha: 0.34);
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset(x, h * 0.78),
              width: h * 0.125,
              height: h * 0.08,
            ),
            pi,
            pi,
            true,
            paint,
          );
          // Luminous cap spots
          paint.color = Colors.white.withValues(alpha: 0.55);
          canvas.drawCircle(Offset(x - 12, h * 0.76), 2.5, paint);
          canvas.drawCircle(Offset(x + 9, h * 0.75), 2.0, paint);
          canvas.drawCircle(Offset(x - 1, h * 0.745), 1.6, paint);
        }
        for (int i = 0; i < 10; i++) {
          final x = i * w / 9;
          final tall = h * (0.3 + (i % 3) * 0.06);
          paint.color = theme.near;
          canvas.drawRect(
            Rect.fromLTWH(x, h * 0.82 - tall, w * 0.018, tall),
            paint,
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x, h * 0.82 - tall),
              width: w * 0.2,
              height: h * 0.2,
            ),
            paint,
          );
          final base = Offset(x + w * 0.035, h * 0.95);
          paint.color = theme.accent.withValues(alpha: 0.2);
          canvas.drawRect(
            Rect.fromLTWH(base.dx - 2, base.dy - 14, 4, 14),
            paint,
          );
          canvas.drawArc(
            Rect.fromCenter(
              center: base - const Offset(0, 14),
              width: 28,
              height: 18,
            ),
            pi,
            pi,
            true,
            paint,
          );
        }
      case StageMotif.foundry:
        // Warm furnace glow rising from bottom
        paint.shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0x38FF8C42),
            const Color(0x00FF8C42),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.65, w, h * 0.35));
        canvas.drawRect(Rect.fromLTWH(0, h * 0.65, w, h * 0.35), paint);
        paint.shader = null;
        for (int i = 0; i < 7; i++) {
          final center = Offset(w * i / 6, h * (0.32 + (i % 2) * 0.44));
          final gearR = h * (0.062 + (i % 3) * 0.014);
          canvas.save();
          canvas.translate(center.dx, center.dy);
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = theme.accent.withValues(alpha: 0.16);
          canvas.drawCircle(Offset.zero, gearR, paint);
          canvas.drawCircle(Offset.zero, gearR * 0.68, paint);
          canvas.drawCircle(Offset.zero, gearR * 0.22, paint);
          // Gear spokes
          for (int s = 0; s < 4; s++) {
            canvas.rotate(pi / 4);
            canvas.drawLine(
              Offset(gearR * 0.22, 0),
              Offset(gearR * 0.68, 0),
              paint,
            );
          }
          // Gear teeth
          paint.strokeWidth = 3.2;
          for (int tooth = 0; tooth < 12; tooth++) {
            canvas.rotate(pi / 6);
            canvas.drawLine(
              Offset(gearR, 0),
              Offset(gearR * 1.2, 0),
              paint,
            );
          }
          canvas.restore();
        }
        paint.style = PaintingStyle.fill;
      case StageMotif.volcano:
        // Molten magma under-glow
        paint.shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0x44FF5A2C),
            const Color(0x00FF5A2C),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.68, w, h * 0.32));
        canvas.drawRect(Rect.fromLTWH(0, h * 0.68, w, h * 0.32), paint);
        paint.shader = null;
        paint
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        for (int i = 0; i < 6; i++) {
          final x = w * (i + 0.25) / 6;
          final lava = Path()
            ..moveTo(x, h * 0.78)
            ..lineTo(x + 16, h * 0.84)
            ..lineTo(x - 10, h * 0.90)
            ..lineTo(x + 26, h);
          paint
            ..strokeWidth = 7
            ..color = const Color(0x33FF5E2B);
          canvas.drawPath(lava, paint);
          paint
            ..strokeWidth = 2.8
            ..color = theme.accent.withValues(alpha: 0.45);
          canvas.drawPath(lava, paint);
          paint
            ..strokeWidth = 1.0
            ..color = const Color(0xAAFFF0B3);
          canvas.drawPath(lava, paint);
        }
        paint.style = PaintingStyle.fill;
      case StageMotif.temple:
        for (final x in [w * 0.085, w * 0.915]) {
          paint
            ..style = PaintingStyle.fill
            ..color = theme.near;
          for (final side in [-1, 1]) {
            canvas.drawRect(
              Rect.fromLTWH(x + side * w * 0.042 - 5, h * 0.52, 10, h * 0.32),
              paint,
            );
          }
          // Upturned pagoda / shrine roof
          final roof = Path()
            ..moveTo(x - w * 0.09, h * 0.51)
            ..quadraticBezierTo(x, h * 0.46, x + w * 0.09, h * 0.51)
            ..lineTo(x + w * 0.068, h * 0.55)
            ..lineTo(x - w * 0.068, h * 0.55)
            ..close();
          canvas.drawPath(roof, paint);
          // Glowing shrine lantern
          final lantern = Offset(x, h * 0.6);
          paint.shader = RadialGradient(
            colors: [
              theme.accent.withValues(alpha: 0.32),
              theme.accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: lantern, radius: 26));
          canvas.drawCircle(lantern, 26, paint);
          paint.shader = null;
          paint.color = theme.accent.withValues(alpha: 0.65);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: lantern, width: 7, height: 11),
              const Radius.circular(3),
            ),
            paint,
          );
        }
        for (int i = 0; i < 8; i++) {
          final x = w * i / 7;
          final y = h * (0.74 + i % 2 * 0.1);
          paint.color = theme.near;
          canvas.drawRect(Rect.fromLTWH(x, y - h * 0.25, 14, h * 0.25), paint);
          canvas.drawRect(Rect.fromLTWH(x - 6, y - h * 0.25, 26, 6), paint);
          paint.color = theme.accent.withValues(alpha: 0.18);
          canvas.drawRect(
            Rect.fromLTWH(x + 4, y - h * 0.22, 2, h * 0.19),
            paint,
          );
        }
      case StageMotif.cosmos:
        // Layered glowing nebula clouds
        for (final cloud in [
          (Offset(w * 0.16, h * 0.68), h * 0.36, const Color(0x227A5AF8)),
          (Offset(w * 0.85, h * 0.62), h * 0.34, const Color(0x22E879F9)),
          (Offset(w * 0.22, h * 0.26), h * 0.28, const Color(0x1E38BDF8)),
        ]) {
          paint.shader = RadialGradient(
            colors: [cloud.$3, cloud.$3.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: cloud.$1, radius: cloud.$2));
          canvas.drawCircle(cloud.$1, cloud.$2, paint);
        }
        paint.shader = null;

        // Ringed planet with subtle shading
        final planet = Offset(w * 0.12, h * 0.31);
        final pR = h * 0.088;
        paint.shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: [
            theme.accent.withValues(alpha: 0.35),
            theme.far.withValues(alpha: 0.5),
            theme.sky,
          ],
        ).createShader(Rect.fromCircle(center: planet, radius: pR));
        canvas.drawCircle(planet, pR, paint);
        paint.shader = null;
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = theme.accent.withValues(alpha: 0.28);
        canvas.save();
        canvas.translate(planet.dx, planet.dy);
        canvas.rotate(-0.22);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: pR * 3.4, height: pR * 0.72),
          paint,
        );
        paint
          ..strokeWidth = 0.8
          ..color = Colors.white.withValues(alpha: 0.2);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: pR * 2.9, height: pR * 0.56),
          paint,
        );
        canvas.restore();

        // Floating crystal shards
        for (int i = 0; i < 10; i++) {
          final x = ((i * 0.291 + 0.08) % 1) * w;
          final y = ((i * 0.187 + 0.18) % 0.82) * h;
          final shard = Path()
            ..moveTo(x, y - 13)
            ..lineTo(x + 8, y + 2)
            ..lineTo(x - 4, y + 16)
            ..close();
          paint
            ..style = PaintingStyle.fill
            ..color = theme.far.withValues(alpha: 0.45);
          canvas.drawPath(shard, paint);
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = theme.accent.withValues(alpha: 0.28);
          canvas.drawPath(shard, paint);
        }
        paint.style = PaintingStyle.fill;
    }

    // Vignette at outer viewport edges; inner board retains exact true meme colors.
    paint.shader = RadialGradient(
      radius: 0.92,
      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.38)],
    ).createShader(full);
    canvas.drawRect(full, paint);
    paint.shader = null;

    // Soft ambient theme glow behind the board bezel
    paint.shader = RadialGradient(
      colors: [
        theme.accent.withValues(alpha: 0.14),
        theme.accent.withValues(alpha: 0),
      ],
    ).createShader(board.inflate(48));
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.inflate(42), const Radius.circular(24)),
      paint,
    );
    paint.shader = null;

    // Deep drop shadow under board
    paint.color = const Color(0xBB040812);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        board.inflate(11).shift(const Offset(0, 6)),
        const Radius.circular(10),
      ),
      paint,
    );

    // Outer metallic/stone bezel
    paint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(theme.near, theme.accent, 0.22)!,
        Color.lerp(theme.near, theme.sky, 0.45)!,
        Color.lerp(theme.edge, Colors.black, 0.35)!,
      ],
    ).createShader(board.inflate(7));
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.inflate(7), const Radius.circular(7)),
      paint,
    );
    paint.shader = null;

    // Inner recessed dark socket
    paint.color = theme.edge;
    canvas.drawRect(board.inflate(1.5), paint);

    // Glowing bevel outline
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = theme.accent.withValues(alpha: 0.38);
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.inflate(5.5), const Radius.circular(5.5)),
      paint,
    );

    // Ornate L-shaped runic corner brackets + corner jewels
    for (final corner in [
      board.topLeft,
      board.topRight,
      board.bottomLeft,
      board.bottomRight,
    ]) {
      final dx = corner.dx == board.left ? 1.0 : -1.0;
      final dy = corner.dy == board.top ? 1.0 : -1.0;
      final outer = corner + Offset(-dx * 5.5, -dy * 5.5);
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.2
        ..color = theme.accent.withValues(alpha: 0.78);
      canvas.drawLine(outer, outer + Offset(dx * 16, 0), paint);
      canvas.drawLine(outer, outer + Offset(0, dy * 16), paint);

      paint
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: 0.85);
      canvas.drawCircle(outer, 1.8, paint);
    }
    paint.style = PaintingStyle.fill;
  }

  void _clouds(Canvas canvas, Paint paint, Size size, StageTheme theme) {
    for (int i = 0; i < 5; i++) {
      final cx = size.width * (i + 0.25) / 5;
      final cy = size.height * (0.17 + i % 2 * 0.09);
      final cw = size.width * 0.14;
      paint.color = theme.accent.withValues(alpha: 0.06);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: cw, height: 9),
          const Radius.circular(5),
        ),
        paint,
      );
      paint.color = theme.accent.withValues(alpha: 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy - 2), width: cw * 0.65, height: 4),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  void _pine(
    Canvas canvas,
    Paint paint,
    Offset base,
    double height,
    Color color,
    Color rimColor,
  ) {
    paint
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawRect(
      Rect.fromLTWH(base.dx - 2, base.dy - height * 0.45, 4, height * 0.45),
      paint,
    );
    // Two-tiered conifer silhouette
    for (int tier = 0; tier < 2; tier++) {
      final topY = base.dy - height * (1.0 - tier * 0.24);
      final botY = base.dy - height * (0.48 - tier * 0.24);
      final halfW = height * (0.24 + tier * 0.08);
      final path = Path()
        ..moveTo(base.dx, topY)
        ..lineTo(base.dx + halfW, botY)
        ..lineTo(base.dx - halfW, botY)
        ..close();
      paint.color = color;
      canvas.drawPath(path, paint);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = rimColor;
      canvas.drawLine(Offset(base.dx, topY), Offset(base.dx + halfW * 0.85, botY), paint);
      paint.style = PaintingStyle.fill;
    }
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
  }
}
