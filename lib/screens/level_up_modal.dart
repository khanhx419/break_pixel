import 'dart:math';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../models/ecs.dart';
import '../models/element.dart';

class LevelUpModal extends StatelessWidget {
  final GameEngine engine;
  final VoidCallback onOptionSelected;

  const LevelUpModal({
    super.key,
    required this.engine,
    required this.onOptionSelected,
  });

  List<ElementData> _getRandomOptions() {
    final pool = List<ElementData>.from(ElementData.baseElements);
    pool.shuffle(Random());
    return pool.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final options = _getRandomOptions();

    return WillPopScope(
      onWillPop: () async => false, // Bắt buộc phải chọn 1 thẻ
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amberAccent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.amberAccent.withOpacity(0.3),
                blurRadius: 25,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Lên cấp
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upgrade, color: Colors.amberAccent, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'LÊN CẤP! (LEVEL UP)',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Nhân vật đạt Cấp ${engine.characterLevel}! Hãy chọn 1 Nguyên Tố:',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // 3 Thẻ lựa chọn
              Column(
                children: options.map((data) {
                  final isAlreadyOwned = engine.ownedElements.contains(data.type);
                  return InkWell(
                    onTap: () {
                      engine.addElement(data.type);
                      onOptionSelected();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: data.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: data.color, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: data.color.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(data.icon, color: data.color, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      data.name,
                                      style: TextStyle(
                                        color: data.color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (isAlreadyOwned) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'ĐÃ SỞ HỮU',
                                          style: TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data.description,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
