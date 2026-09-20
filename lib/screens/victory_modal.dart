import 'package:flutter/material.dart';
import '../models/pixel_art_data.dart';

class VictoryModal extends StatelessWidget {
  final MemeLevel level;
  final int earnedGold;
  final bool isFinalStoryLevel;
  final VoidCallback onNextLevel;
  final VoidCallback onReturnMenu;

  const VictoryModal({
    super.key,
    required this.level,
    required this.earnedGold,
    required this.isFinalStoryLevel,
    required this.onNextLevel,
    required this.onReturnMenu,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isFinalStoryLevel ? Colors.cyanAccent : Colors.amberAccent,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isFinalStoryLevel ? Colors.cyanAccent : Colors.amberAccent)
                    .withOpacity(0.35),
                blurRadius: 30,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon & Tiêu đề
              Icon(
                isFinalStoryLevel ? Icons.emoji_events : Icons.verified,
                color: isFinalStoryLevel ? Colors.cyanAccent : Colors.amberAccent,
                size: 54,
              ),
              const SizedBox(height: 8),
              Text(
                isFinalStoryLevel
                    ? 'PHÁ ĐẢO THẾ GIỚI PIXEL!'
                    : 'CHIẾN THẮNG MÀN CHƠI!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isFinalStoryLevel
                      ? Colors.cyanAccent
                      : Colors.amberAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 12),

              // Tên meme được giải phóng
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Cổ vật Meme đã hé lộ: ${level.memeName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Nếu là màn cuối Story Mode: Phần thưởng Yeti
              if (isFinalStoryLevel) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.cyanAccent),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.ac_unit, color: Colors.cyanAccent, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'PHẦN THƯỞNG MỞ KHÓA: YETI',
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Tinh linh 3D chúc mừng ngươi! Cổng không gian đã mở và Tộc Yeti (Người Tuyết Cổ Đại) đã được mở khóa vĩnh viễn!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Thống kê Vàng kiếm được
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    'Thu được: +$earnedGold Vàng',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Các nút hành động
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onNextLevel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFinalStoryLevel
                            ? Colors.cyanAccent.shade700
                            : Colors.amberAccent.shade700,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isFinalStoryLevel ? 'CHƠI LẠI VỚI YETI' : 'MÀN TIẾP THEO',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onReturnMenu,
                      child: const Text(
                        'VỀ MENU CHÍNH',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
