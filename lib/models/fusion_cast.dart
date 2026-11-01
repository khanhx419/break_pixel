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
    final t = ((age - windup) / (duration - windup)).clamp(0.0, 1.0);
    final radius = (preparing ? 34 - age * 35 : 20 + (1 - pow(1 - t, 3)) * 65)
        .toDouble();
    final alpha = preparing ? 0.45 + age : (1 - t) * 0.85;
    paint
      ..shader = null
      ..maskFilter = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = preparing ? 1 : 1.8 * (1 - t) + 0.4
      ..color = color.withValues(alpha: alpha.clamp(0, 1));
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (preparing) {
      for (int i = 0; i < 8; i++) {
        final a = i * pi / 4 + age * 2;
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: radius),
          a,
          0.45,
          false,
          paint,
        );
        canvas.drawLine(
          Offset(cos(a), sin(a)) * (radius + 6),
          Offset(cos(a), sin(a)) * (radius + 10),
          paint,
        );
      }
    } else {
      paint
        ..style = PaintingStyle.fill
        ..shader =
            RadialGradient(
              colors: [
                color.withValues(alpha: (1 - t) * 0.22),
                color.withValues(alpha: 0),
              ],
              stops: const [0.1, 1],
            ).createShader(
              Rect.fromCircle(center: Offset.zero, radius: radius * 1.5),
            );
      canvas.drawCircle(Offset.zero, radius * 1.5, paint);
      paint
        ..shader = null
        ..style = PaintingStyle.stroke;
      switch (type) {
        case ElementType.avalanche:
          for (int i = 0; i < 3; i++) {
            final y = (i - 1) * 8.0 * (1 - t);
            canvas.drawLine(
              Offset(board.left - center.dx, y),
              Offset(board.right - center.dx, y),
              paint,
            );
          }
        case ElementType.superconductor:
          for (int i = 0; i < 6; i++) {
            canvas.save();
            canvas.rotate(i * pi / 3 + t * 0.3);
            final circuit = Path()
              ..moveTo(6, 0)
              ..lineTo(radius * 0.3, -5)
              ..lineTo(radius * 0.45, 8)
              ..lineTo(radius * 0.65, -7)
              ..lineTo(radius, 0);
            canvas.drawPath(circuit, paint);
            canvas.drawCircle(Offset(radius, 0), 2, paint);
            canvas.restore();
          }
        case ElementType.permafrost:
          for (int i = 0; i < 6; i++) {
            final direction = Offset(cos(i * pi / 3), sin(i * pi / 3));
            final end = direction * radius;
            canvas.drawLine(direction * 8, end, paint);
            canvas.drawLine(
              end,
              end + Offset(cos(i * pi / 3 + 2.4), sin(i * pi / 3 + 2.4)) * 18,
              paint,
            );
          }
          canvas.drawCircle(Offset.zero, radius * 0.6, paint);
        case ElementType.voidVortex:
          paint
            ..style = PaintingStyle.fill
            ..color = const Color(0xFF090D19).withValues(alpha: 1 - t);
          canvas.drawCircle(Offset.zero, radius * 0.4, paint);
          paint
            ..style = PaintingStyle.stroke
            ..color = color.withValues(alpha: alpha);
          for (int i = 0; i < 4; i++) {
            canvas.save();
            canvas.rotate(age * 1.8 + i * 0.6);
            canvas.drawOval(
              Rect.fromCenter(
                center: Offset.zero,
                width: radius * (1.2 + i * 0.25),
                height: radius * 0.55,
              ),
              paint,
            );
            canvas.restore();
          }
        case ElementType.firestorm:
          for (int arm = 0; arm < 3; arm++) {
            final path = Path();
            for (int j = 0; j <= 16; j++) {
              final u = j / 16;
              final a = arm * pi * 2 / 3 + age * 4 + u * 3.5;
              final point = Offset(cos(a), sin(a)) * radius * (0.12 + u * 0.88);
              if (j == 0) {
                path.moveTo(point.dx, point.dy);
              } else {
                path.lineTo(point.dx, point.dy);
              }
            }
            paint
              ..strokeWidth = 3 * (1 - t) + 1
              ..color = const Color(0xFFF09A4F).withValues(alpha: alpha);
            canvas.drawPath(path, paint);
            paint
              ..strokeWidth = 0.8
              ..color = const Color(0xFFFFE3A9).withValues(alpha: alpha);
            canvas.drawPath(path, paint);
          }
        case ElementType.mist:
        case ElementType.explosiveGas:
          for (int i = 0; i < (type == ElementType.mist ? 3 : 5); i++) {
            final offset = type == ElementType.mist
                ? Offset((i - 1) * radius * 0.55, sin(i + t * 2) * 9)
                : Offset(cos(i * pi * 0.4), sin(i * pi * 0.4)) * radius * 0.5;
            final cloud = Rect.fromCenter(
              center: offset,
              width: radius,
              height: radius * (type == ElementType.mist ? 0.45 : 0.85),
            );
            paint
              ..style = PaintingStyle.fill
              ..color = color.withValues(alpha: alpha * 0.1);
            canvas.drawOval(cloud, paint);
            paint
              ..style = PaintingStyle.stroke
              ..color = color.withValues(alpha: alpha * 0.7);
            canvas.drawOval(cloud, paint);
          }
        case ElementType.acidMelt:
          for (int i = 0; i < 4; i++) {
            final x = (i - 1.5) * radius * 0.5;
            final y = sin(i * 2.0) * radius * 0.3 + t * radius * 0.4;
            final drop = Path()
              ..moveTo(x, y - 12)
              ..quadraticBezierTo(x + 9, y + 8, x, y + 8)
              ..quadraticBezierTo(x - 9, y + 8, x, y - 12);
            paint
              ..style = PaintingStyle.fill
              ..color = color.withValues(alpha: alpha * 0.3);
            canvas.drawPath(drop, paint);
            paint
              ..style = PaintingStyle.stroke
              ..color = color.withValues(alpha: alpha);
            canvas.drawArc(
              Rect.fromCenter(
                center: Offset(x, y + 13),
                width: radius * 0.5,
                height: 10,
              ),
              0,
              pi,
              false,
              paint,
            );
          }
        case ElementType.lavaBurst:
          for (int i = 0; i < 8; i++) {
            final angle = i * pi / 4;
            final d = Offset(cos(angle), sin(angle));
            canvas.drawLine(d * radius * 0.45, d * radius, paint);
            canvas.drawCircle(d * radius, 2.5 * (1 - t) + 0.5, paint);
          }
        case ElementType.chainLightning:
          for (int i = 0; i < 5; i++) {
            canvas.save();
            canvas.rotate(i * pi * 2 / 5);
            final bolt = Path()
              ..moveTo(5, 0)
              ..lineTo(radius * 0.35, -8)
              ..lineTo(radius * 0.5, 5)
              ..lineTo(radius * 0.65, -4)
              ..lineTo(radius, 0);
            paint
              ..strokeWidth = 3.5
              ..color = color.withValues(alpha: alpha * 0.3);
            canvas.drawPath(bolt, paint);
            paint
              ..strokeWidth = 1.1
              ..color = const Color(0xFFFFEFC0).withValues(alpha: alpha);
            canvas.drawPath(bolt, paint);
            canvas.restore();
          }
        default:
          for (int i = 0; i < 4; i++) {
            canvas.drawArc(
              Rect.fromCircle(center: Offset.zero, radius: radius),
              i * pi / 2,
              1,
              false,
              paint,
            );
          }
      }
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFEBD0).withValues(alpha: (1 - t) * 0.75);
      if (type != ElementType.voidVortex && type != ElementType.mist) {
        canvas.drawCircle(Offset.zero, 3.5 * (1 - t), paint);
      }
      if (t < 0.15) {
        paint
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: (1 - t / 0.15) * 0.15);
        canvas.drawCircle(Offset.zero, radius, paint);
      }
    }
    canvas.restore();
    paint.style = PaintingStyle.fill;
  }
}
