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
                              color: Colors.cyanAccent.withOpacity(0.5),
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
                        color: const Color(0xFF161F36).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.cyanAccent.withOpacity(0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
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
    final paint = Paint()..color = Colors.white.withOpacity(0.2);

    for (int i = 0; i < 40; i++) {
      final x = rng.nextDouble() * size.width;
      final y = (rng.nextDouble() * size.height + animValue * 20) % size.height;
      final r = rng.nextDouble() * 2.0 + 1.0;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
