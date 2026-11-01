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
    // Fixed-count ambient glints; no emitters, timers or growing particle lists.
    final paint = Paint();
    for (int i = 0; i < 12; i++) {
      final x =
          ((i * 0.237 + 0.08) % 1) * size.width + sin(time * 0.18 + i) * 5;
      final y =
          ((i * 0.173 + 0.12) % 0.9) * size.height + cos(time * 0.15 + i) * 4;
      final pos = Offset(x, y);
      if (board.inflate(10).contains(pos)) continue;
      paint.color = theme.accent.withValues(
        alpha: 0.12 + (sin(time * 0.6 + i) + 1) * 0.07,
      );
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: i % 3 == 0 ? 2 : 1, height: 1),
        paint,
      );
    }
  }

  void _record(Canvas canvas, Size size, Rect board, StageTheme theme) {
    final w = size.width, h = size.height;
    final full = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.sky, theme.horizon],
      ).createShader(full);
    canvas.drawRect(full, paint);
    paint.shader = null;
    // A distant light source anchors the palette without obscuring the artwork.
    final light = Offset(w * 0.79, h * 0.18);
    paint.shader = RadialGradient(
      colors: [
        theme.accent.withValues(alpha: 0.12),
        theme.accent.withValues(alpha: 0),
      ],
    ).createShader(Rect.fromCircle(center: light, radius: h * 0.7));
    canvas.drawRect(full, paint);
    paint.shader = null;
    paint.color = theme.accent.withValues(alpha: 0.38);
    canvas.drawCircle(light, min(w, h) * 0.046, paint);
    if (theme.motif == StageMotif.city || theme.motif == StageMotif.temple) {
      paint.color = theme.sky;
      canvas.drawCircle(
        light - Offset(h * 0.017, h * 0.012),
        min(w, h) * 0.043,
        paint,
      );
    }
    for (int i = 0; i < 42; i++) {
      final x = ((i * 137 + 41) % 997) / 997 * w;
      final y = ((i * 71 + 13) % 503) / 503 * h * 0.62;
      paint.color = theme.accent.withValues(alpha: i % 4 == 0 ? 0.24 : 0.09);
      canvas.drawRect(Rect.fromLTWH(x, y, i % 4 == 0 ? 2 : 1, 1), paint);
    }
    // Layered angular terrain forms a continuous scene at narrow and wide sizes.
    for (
      int layer = 0;
      layer < (theme.motif == StageMotif.cosmos ? 0 : 3);
      layer++
    ) {
      final path = Path()..moveTo(0, h);
      for (int j = 0; j <= 14; j++) {
        final x = w * j / 14;
        final jagged =
            theme.motif == StageMotif.glacier ||
            theme.motif == StageMotif.volcano;
        final y =
            h * (0.48 + layer * 0.15) +
            sin(j * 1.7 + layer * 2 + theme.motif.index) *
                h *
                (jagged
                    ? 0.15
                    : theme.motif == StageMotif.marsh
                    ? 0.015
                    : 0.07);
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h)
        ..close();
      paint.color = [
        theme.far,
        Color.lerp(theme.far, theme.near, 0.55)!,
        theme.near,
      ][layer];
      canvas.drawPath(path, paint);
    }
    switch (theme.motif) {
      case StageMotif.valley:
        _clouds(canvas, paint, size, theme);
        for (int i = 0; i < 9; i++) {
          _pine(
            canvas,
            paint,
            Offset(w * i / 8, h * (0.84 + sin(i) * 0.035)),
            h * (0.12 + i % 3 * 0.025),
            theme.near,
          );
        }
      case StageMotif.marsh:
        for (final x in [w * 0.06, w * 0.94]) {
          paint
            ..style = PaintingStyle.fill
            ..color = theme.near;
          canvas.drawRect(Rect.fromLTWH(x - 5, h * 0.42, 10, h * 0.45), paint);
          final canopy = Rect.fromCenter(
            center: Offset(x, h * 0.4),
            width: w * 0.22,
            height: h * 0.13,
          );
          canvas.drawOval(canopy, paint);
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          for (int j = -2; j <= 2; j++) {
            final vine = Path()
              ..moveTo(x + j * 15, h * 0.42)
              ..quadraticBezierTo(
                x + j * 18,
                h * 0.52,
                x + j * 20 - 8,
                h * (0.58 - j.abs() * 0.025),
              );
            canvas.drawPath(vine, paint);
          }
        }
        paint.style = PaintingStyle.fill;
        paint.color = theme.accent.withValues(alpha: 0.12);
        for (int i = 0; i < 15; i++) {
          final y = h * (0.79 + i * 0.012);
          final x = ((i * 0.317) % 1) * w;
          canvas.drawRect(
            Rect.fromLTWH(x, y, w * (0.03 + i % 3 * 0.02), 1),
            paint,
          );
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
        for (int i = 0; i < 19; i++) {
          final x = w * i / 18;
          final bh = h * (0.14 + ((i * 7) % 11) * 0.018);
          paint.color = i.isEven ? theme.near : theme.far;
          canvas.drawRect(Rect.fromLTWH(x, h * 0.91 - bh, w / 24, bh), paint);
          paint.color = theme.accent.withValues(alpha: 0.25);
          for (int row = 0; row < 5; row++) {
            if ((row + i) % 3 == 0) continue;
            canvas.drawRect(
              Rect.fromLTWH(x + 4, h * 0.91 - bh + row * 9 + 6, 3, 3),
              paint,
            );
          }
        }
      case StageMotif.glacier:
        for (int i = 0; i < 3; i++) {
          final ribbon = Path()
            ..moveTo(-20, h * (0.14 + i * 0.05))
            ..cubicTo(w * 0.3, h * -0.05, w * 0.58, h * 0.4, w + 20, h * 0.09);
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10.0 + i * 5
            ..color = theme.accent.withValues(alpha: 0.035);
          canvas.drawPath(ribbon, paint);
        }
        paint.style = PaintingStyle.fill;
        for (int i = 0; i < 9; i++) {
          _pine(
            canvas,
            paint,
            Offset(w * i / 8, h * 0.96),
            h * 0.15,
            theme.near,
          );
        }
      case StageMotif.forest:
        for (final x in [w * 0.075, w * 0.925]) {
          final glowRect = Rect.fromCircle(
            center: Offset(x, h * 0.81),
            radius: h * 0.12,
          );
          paint
            ..style = PaintingStyle.fill
            ..shader = RadialGradient(
              colors: [
                theme.accent.withValues(alpha: 0.1),
                theme.accent.withValues(alpha: 0),
              ],
            ).createShader(glowRect);
          canvas.drawRect(glowRect, paint);
          paint.shader = null;
          paint.color = Color.lerp(theme.near, theme.accent, 0.12)!;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 5, h * 0.81, 10, h * 0.12),
              const Radius.circular(4),
            ),
            paint,
          );
          paint.color = theme.accent.withValues(alpha: 0.23);
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset(x, h * 0.81),
              width: h * 0.1,
              height: h * 0.065,
            ),
            pi,
            pi,
            true,
            paint,
          );
          paint.color = theme.accent.withValues(alpha: 0.4);
          canvas.drawCircle(Offset(x - 8, h * 0.8), 2, paint);
          canvas.drawCircle(Offset(x + 7, h * 0.79), 1.5, paint);
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
          paint.color = theme.accent.withValues(alpha: 0.13);
          canvas.drawRect(
            Rect.fromLTWH(base.dx - 2, base.dy - 14, 4, 14),
            paint,
          );
          canvas.drawArc(
            Rect.fromCenter(
              center: base - const Offset(0, 14),
              width: 26,
              height: 17,
            ),
            pi,
            pi,
            true,
            paint,
          );
        }
      case StageMotif.foundry:
        for (int i = 0; i < 7; i++) {
          final center = Offset(w * i / 6, h * (0.33 + (i % 2) * 0.42));
          canvas.save();
          canvas.translate(center.dx, center.dy);
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = theme.accent.withValues(alpha: 0.1);
          canvas.drawCircle(Offset.zero, h * 0.065, paint);
          canvas.drawCircle(Offset.zero, h * 0.045, paint);
          for (int tooth = 0; tooth < 12; tooth++) {
            canvas.rotate(pi / 6);
            canvas.drawLine(Offset(h * 0.065, 0), Offset(h * 0.08, 0), paint);
          }
          canvas.restore();
        }
        paint.style = PaintingStyle.fill;
      case StageMotif.volcano:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = theme.accent.withValues(alpha: 0.25);
        for (int i = 0; i < 5; i++) {
          final x = w * (i + 0.3) / 5;
          final lava = Path()
            ..moveTo(x, h * 0.82)
            ..lineTo(x + 15, h * 0.86)
            ..lineTo(x - 8, h * 0.91)
            ..lineTo(x + 30, h);
          canvas.drawPath(lava, paint);
        }
        paint.style = PaintingStyle.fill;
      case StageMotif.temple:
        for (final x in [w * 0.09, w * 0.91]) {
          paint
            ..style = PaintingStyle.fill
            ..color = theme.near;
          for (final side in [-1, 1]) {
            canvas.drawRect(
              Rect.fromLTWH(x + side * w * 0.045 - 5, h * 0.53, 10, h * 0.28),
              paint,
            );
          }
          final roof = Path()
            ..moveTo(x - w * 0.085, h * 0.52)
            ..lineTo(x, h * 0.48)
            ..lineTo(x + w * 0.085, h * 0.52)
            ..lineTo(x + w * 0.065, h * 0.55)
            ..lineTo(x - w * 0.065, h * 0.55)
            ..close();
          canvas.drawPath(roof, paint);
          paint.color = theme.accent.withValues(alpha: 0.12);
          canvas.drawRect(
            Rect.fromLTWH(x - w * 0.05, h * 0.57, w * 0.1, 2),
            paint,
          );
        }
        for (int i = 0; i < 8; i++) {
          final x = w * i / 7;
          final y = h * (0.73 + i % 2 * 0.1);
          paint.color = theme.near;
          canvas.drawRect(Rect.fromLTWH(x, y - h * 0.25, 14, h * 0.25), paint);
          canvas.drawRect(Rect.fromLTWH(x - 6, y - h * 0.25, 26, 6), paint);
          paint.color = theme.accent.withValues(alpha: 0.1);
          canvas.drawRect(
            Rect.fromLTWH(x + 3, y - h * 0.23, 2, h * 0.2),
            paint,
          );
        }
      case StageMotif.cosmos:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = theme.accent.withValues(alpha: 0.12);
        final planet = Offset(w * 0.14, h * 0.31);
        canvas.drawCircle(planet, h * 0.11, paint);
        canvas.drawOval(
          Rect.fromCenter(center: planet, width: h * 0.37, height: h * 0.09),
          paint,
        );
        for (int i = 0; i < 8; i++) {
          final x = ((i * 0.291 + 0.12) % 1) * w;
          final y = ((i * 0.187 + 0.2) % 0.8) * h;
          final shard = Path()
            ..moveTo(x, y - 12)
            ..lineTo(x + 7, y + 2)
            ..lineTo(x - 4, y + 15)
            ..close();
          canvas.drawPath(shard, paint);
        }
        paint.style = PaintingStyle.fill;
    }
    // Dim the outer scene at the edges; the actual picture always retains its true colors.
    paint.shader = RadialGradient(
      radius: 0.9,
      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
    ).createShader(full);
    canvas.drawRect(full, paint);
    paint.shader = null;
    paint.color = const Color(0x99060C16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        board.inflate(9).shift(const Offset(0, 4)),
        const Radius.circular(7),
      ),
      paint,
    );
    paint.color = Color.lerp(theme.near, theme.sky, 0.4)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.inflate(6), const Radius.circular(5)),
      paint,
    );
    paint.color = theme.edge;
    canvas.drawRect(board, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = theme.accent.withValues(alpha: 0.32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.inflate(5), const Radius.circular(4)),
      paint,
    );
    for (final corner in [
      board.topLeft,
      board.topRight,
      board.bottomLeft,
      board.bottomRight,
    ]) {
      final dx = corner.dx == board.left ? 1.0 : -1.0;
      final dy = corner.dy == board.top ? 1.0 : -1.0;
      paint
        ..strokeWidth = 2
        ..color = theme.accent.withValues(alpha: 0.5);
      canvas.drawLine(
        corner + Offset(dx * 3, -dy * 3),
        corner + Offset(dx * 13, -dy * 3),
        paint,
      );
    }
  }

  void _clouds(Canvas canvas, Paint paint, Size size, StageTheme theme) {
    paint.color = theme.accent.withValues(alpha: 0.05);
    for (int i = 0; i < 5; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * i / 5,
            size.height * (0.2 + i % 2 * 0.1),
            size.width * 0.13,
            7,
          ),
          const Radius.circular(4),
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
  ) {
    paint
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawRect(
      Rect.fromLTWH(base.dx - 2, base.dy - height * 0.5, 4, height * 0.5),
      paint,
    );
    final path = Path()
      ..moveTo(base.dx, base.dy - height)
      ..lineTo(base.dx + height * 0.3, base.dy - height * 0.25)
      ..lineTo(base.dx - height * 0.3, base.dy - height * 0.25)
      ..close();
    canvas.drawPath(path, paint);
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
  }
}
