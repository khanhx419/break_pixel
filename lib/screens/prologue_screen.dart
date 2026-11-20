import 'dart:math';
import 'package:flutter/material.dart';
import 'character_select_screen.dart';

class PrologueScreen extends StatefulWidget {
  final bool isYetiUnlocked;

  const PrologueScreen({super.key, this.isYetiUnlocked = false});

  @override
  State<PrologueScreen> createState() => _PrologueScreenState();
}

class _PrologueScreenState extends State<PrologueScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _dialogStep = 0;

  final List<String> _dialogues = [
    'Hỡi sinh linh tròn trịa lạc lối...\nChào mừng ngươi đến với ranh giới không gian.',
    'Ngươi đã bị hút vào Vết Nứt Không Gian của Thế Giới Pixel 2D thô ráp này!',
    'Mọi lối thoát trở về thế giới 3D mượt mà của ngươi đã bị phong ấn dưới hàng triệu khối vật chất pixel góc cạnh.',
    'Cách duy nhất để mở lại Cổng Không Gian 3D là đập tan toàn bộ các khối pixel và giải phóng các cổ vật meme bị phong ấn bên dưới!',
    'Ta là Tinh Linh Không Gian 3D. Hãy chọn cho mình một Nghề nghiệp và Chủng tộc để bắt đầu công cuộc phá hủy thế giới này!',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _nextDialogue() {
    if (_dialogStep < _dialogues.length - 1) {
      setState(() {
        _dialogStep++;
      });
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => CharacterSelectScreen(
            isYetiUnlocked: widget.isYetiUnlocked,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: SafeArea(
        child: Stack(
          children: [
            // Nền sao & bụi không gian
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _CosmicBackgroundPainter(_animController.value),
                  );
                },
              ),
            ),

            // Nội dung chính
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Tinh linh 3D bay bồng bềnh
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        final bobbing = sin(_animController.value * 2 * pi) * 12;
                        return Transform.translate(
                          offset: Offset(0, bobbing),
                          child: child,
                        );
                      },
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.5),
                              blurRadius: 35,
                              spreadRadius: 8,
                            ),
                          ],
                          gradient: const RadialGradient(
                            center: Alignment(-0.3, -0.4),
                            radius: 0.85,
                            colors: [
                              Colors.white,
                              Colors.cyanAccent,
                              Color(0xFF0077B6),
                              Color(0xFF03045E),
                            ],
                            stops: [0.0, 0.35, 0.75, 1.0],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      'TINH LINH THẾ GIỚI 3D',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),

                    const SizedBox(height: 35),

                    // Khung thoại
                    Container(
                      constraints: const BoxConstraints(minHeight: 120),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161F36).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.cyanAccent.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _dialogues[_dialogStep],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 35),

                    // Nút bấm tiếp tục
                    ElevatedButton(
                      onPressed: _nextDialogue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _dialogStep == _dialogues.length - 1
                                ? 'CHỌN NHÂN VẬT'
                                : 'TIẾP TỤC',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CosmicBackgroundPainter extends CustomPainter {
  final double animValue;
  _CosmicBackgroundPainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint();

    // Soft glowing nebula washes
    for (final nebula in [
      (Offset(size.width * 0.2, size.height * 0.25), size.width * 0.45, const Color(0x2000B4D8)),
      (Offset(size.width * 0.82, size.height * 0.72), size.width * 0.5, const Color(0x1E7B2CBF)),
    ]) {
      paint.shader = RadialGradient(
        colors: [nebula.$3, nebula.$3.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: nebula.$1, radius: nebula.$2));
      canvas.drawCircle(nebula.$1, nebula.$2, paint);
    }
    paint.shader = null;

    // Twinkling multi-depth starfield & drifting pixel shards
    for (int i = 0; i < 55; i++) {
      final x = rng.nextDouble() * size.width;
      final speed = 16 + (i % 4) * 10.0;
      final y = (rng.nextDouble() * size.height + animValue * speed) % size.height;
      final r = rng.nextDouble() * 1.8 + 0.8;
      final twinkle = 0.2 + 0.5 * ((sin(animValue * 2 * pi + i) + 1) * 0.5);
      if (i % 7 == 0) {
        paint.color = Colors.cyanAccent.withValues(alpha: twinkle * 0.35);
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: r * 2.6, height: r * 2.6),
          paint,
        );
      } else {
        paint.color = Colors.white.withValues(alpha: twinkle);
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
