import 'dart:math';
import 'package:flutter/material.dart';
import '../models/character.dart';
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

    // 1. Vẽ nền không gian Arena phong cách viễn tưởng
    _drawBackground(canvas, size, paint);

    // 2. Vẽ các vùng Sương mù (Mist Zones)
    for (final mist in engine.mistZones) {
      mist.draw(canvas, paint);
    }

    // 3. Vẽ Lớp Bức Tranh Meme Ẩn bên dưới (đối với những ô đã vỡ)
    _drawRevealedMemeLayer(canvas, paint);

    // 4. Vẽ các Khối Pixel còn nguyên hoặc đang bị nứt
    for (final block in engine.blocks) {
      block.draw(canvas, paint);
    }

    // 5. Vẽ Sóng xung kích phát sáng nổ vỡ (Shockwaves)
    for (final sw in engine.shockwaves) {
      sw.draw(canvas, paint);
    }

    // 6. Vẽ Vật phẩm rơi (Gold & EXP Gems)
    for (final drop in engine.drops) {
      drop.draw(canvas, paint);
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
    engine.player.draw(canvas, paint);

    // 10. Vẽ Hạt nổ tung (Debris)
    for (final p in engine.debris) {
      p.draw(canvas, paint);
    }

    // 11. Vẽ Chữ số sát thương & text trạng thái bay lên
    _drawFloatingTexts(canvas);

    canvas.restore();
  }

  void _drawBackground(Canvas canvas, Size size, Paint paint) {
    // Gradient nền tối sang trọng
    final bgGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    );
    paint.shader = bgGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    paint.shader = null;

    // Lưới grid mờ tạo chiều sâu không gian
    paint.color = Colors.white.withOpacity(0.025);
    paint.strokeWidth = 1.0;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Khung viền thế giới Pixel mà người chơi cần phá vỡ để thoát ra
    final gridWidth = engine.level.cols * engine.gridBlockSize;
    final gridHeight = engine.level.rows * engine.gridBlockSize;
    final worldRect = Rect.fromLTWH(engine.gridStartX, engine.gridStartY, gridWidth, gridHeight);

    // Nền tối phía sau bức tranh
    paint.color = const Color(0xFF0C1322);
    paint.style = PaintingStyle.fill;
    canvas.drawRect(worldRect, paint);

    // Tường biên giới bức tranh (Outer Barrier): Phát sáng neon chặn bóng nảy bên trong
    paint.color = Colors.cyanAccent.withOpacity(0.85);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3.0;
    canvas.drawRect(worldRect, paint);

    // Hào quang viền tường ngoài
    paint.color = Colors.cyanAccent.withOpacity(0.25);
    paint.strokeWidth = 6.0;
    canvas.drawRect(worldRect.inflate(2.0), paint);

    // Vẽ nền sàn và viền neon cho buồng rỗng 2x2 ở tâm
    final centerX = engine.gridStartX + gridWidth / 2;
    final centerY = engine.gridStartY + gridHeight / 2;
    final chamberRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: engine.gridBlockSize * 2,
      height: engine.gridBlockSize * 2,
    );

    // Viền neon làm nổi bật buồng xuất phát ở tâm trên nền ảnh ẩn
    paint.color = Colors.cyanAccent.withOpacity(0.7);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;
    canvas.drawRect(chamberRect, paint);
  }

  void _drawRevealedMemeLayer(Canvas canvas, Paint paint) {
    for (final block in engine.blocks) {
      if (block.health!.isDestroyed) {
        final rect = block.transform.rect.deflate(1.0);
        paint.color = block.memeColor;
        paint.style = PaintingStyle.fill;
        canvas.drawRect(rect, paint);

        // Hiệu ứng sáng viền nhẹ cho tranh pixel meme
        paint.color = Colors.white.withOpacity(0.08);
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 0.8;
        canvas.drawRect(rect, paint);
      }
    }
  }

  void _drawWeapon(Canvas canvas, Paint paint) {
    final player = engine.player;
    final center = player.transform.position;
    final angle = player.weaponAngle;
    final range = engine.totalWeaponRange;

    // Vệt chém hình vòng cung phát sáng rực rỡ (Slash Arc Trail)
    if (player.role.type == RoleType.warrior ||
        player.role.type == RoleType.farmer ||
        player.role.type == RoleType.lumberjack) {
      const segments = 5;
      const totalSweep = 0.85;
      for (int i = 0; i < segments; i++) {
        final t = (i + 1) / segments;
        final segStart = angle - totalSweep + (i * totalSweep / segments);
        final segSweep = totalSweep / segments;
        final slashPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.5 + t * 4.5
          ..color = Color.lerp(player.role.themeColor, Colors.white, t * 0.7)!
              .withOpacity(t * 0.6);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: range * 0.88),
          segStart,
          segSweep,
          false,
          slashPaint,
        );
      }
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    switch (player.role.type) {
      case RoleType.warrior:
        // Đại kiếm xoay tròn
        _drawSword(canvas, paint, range);
        break;
      case RoleType.archer:
        // Cây cung
        _drawBow(canvas, paint);
        break;
      case RoleType.farmer:
        // Liềm gặt mùa màng
        _drawScythe(canvas, paint, range);
        break;
      case RoleType.lumberjack:
        // Rìu đốn củi hạng nặng
        _drawAxe(canvas, paint, range);
        break;
      case RoleType.fisherman:
        // Cần câu cá
        _drawFishingRod(canvas, paint, range);
        break;
    }

    canvas.restore();
  }

  void _drawSword(Canvas canvas, Paint paint, double range) {
    // Cán kiếm
    paint.color = Colors.brown;
    paint.strokeWidth = 3.0;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, const Offset(12, 0), paint);

    // Chuôi kiếm
    paint.color = Colors.amber;
    canvas.drawLine(const Offset(12, -7), const Offset(12, 7), paint);

    // Lưỡi kiếm sáng bạc
    final bladePath = Path()
      ..moveTo(12, -4)
      ..lineTo(range - 6, -3)
      ..lineTo(range, 0)
      ..lineTo(range - 6, 3)
      ..lineTo(12, 4)
      ..close();

    paint.color = Colors.cyanAccent.shade100;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(bladePath, paint);

    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.0;
    canvas.drawPath(bladePath, paint);
  }

  void _drawBow(Canvas canvas, Paint paint) {
    // Thân cung uốn cong
    paint.color = Colors.lightGreenAccent;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3.0;
    final bowRect = const Rect.fromLTWH(10, -18, 16, 36);
    canvas.drawArc(bowRect, -pi / 2, pi, false, paint);

    // Dây cung
    paint.color = Colors.white.withOpacity(0.6);
    paint.strokeWidth = 1.0;
    canvas.drawLine(const Offset(18, -18), const Offset(18, 18), paint);
  }

  void _drawScythe(Canvas canvas, Paint paint, double range) {
    // Cán liềm gỗ
    paint.color = Colors.brown.shade400;
    paint.strokeWidth = 2.5;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(range * 0.75, 0), paint);

    // Lưỡi liềm vàng gặt lúa hình trăng khuyết
    final scythePath = Path()
      ..moveTo(range * 0.7, -2)
      ..quadraticBezierTo(range * 0.9, -16, range * 0.6, -26)
      ..quadraticBezierTo(range * 0.82, -14, range * 0.7, 2)
      ..close();

    paint.color = Colors.amber;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(scythePath, paint);

    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.0;
    canvas.drawPath(scythePath, paint);
  }

  void _drawAxe(Canvas canvas, Paint paint, double range) {
    // Cán rìu cứng cáp
    paint.color = Colors.brown.shade800;
    paint.strokeWidth = 4.0;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(range * 0.8, 0), paint);

    // Lưỡi rìu sắt bổ nặng
    final axeHead = Path()
      ..moveTo(range * 0.55, -12)
      ..lineTo(range * 0.82, -16)
      ..lineTo(range * 0.82, 16)
      ..lineTo(range * 0.55, 12)
      ..close();

    paint.color = Colors.blueGrey.shade200;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(axeHead, paint);

    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.2;
    canvas.drawPath(axeHead, paint);
  }

  void _drawFishingRod(Canvas canvas, Paint paint, double range) {
    // Cần câu dẻo cong
    paint.color = Colors.cyan;
    paint.strokeWidth = 2.5;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(range * 0.8, 0), paint);

    // Đầu cần có vòng khuyên
    paint.color = Colors.white;
    canvas.drawCircle(Offset(range * 0.8, 0), 2.5, paint);
  }

  void _drawFloatingTexts(Canvas canvas) {
    for (final textItem in engine.floatingTexts) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: textItem.text,
          style: TextStyle(
            color: textItem.color.withOpacity(textItem.alpha),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.8),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(textItem.x - textPainter.width / 2, textItem.y),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
