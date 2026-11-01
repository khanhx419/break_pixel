import 'dart:math';

import 'package:flutter/material.dart';

import '../core/progress_store.dart';
import '../models/character.dart';
import '../models/element.dart';
import '../models/pixel_art_data.dart';
import 'game_screen.dart';
import 'character_select_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  final RoleInfo role;
  final RaceInfo race;
  final bool isYetiUnlocked;
  const LevelSelectScreen({
    super.key,
    required this.role,
    required this.race,
    this.isYetiUnlocked = false,
  });
  @override
  Widget build(BuildContext context) {
    final progress = ProgressStore.instance;
    final levels = MemeLevel.allLevels;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHỌN MÀN CHƠI'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  CharacterSelectScreen(isYetiUnlocked: isYetiUnlocked),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: levels.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, row) {
            if (row == 0) {
              return const Text(
                'Mỗi màn mới hoàn thành mở một nguyên tố. Chơi lại không nhận trùng phần thưởng. '
                'Màn mới tăng độ bền khối; cứ 3 màn mở rộng lưới. Tiến trình tự lưu mỗi 5 giây và khi về menu.',
                style: TextStyle(
                  color: Colors.white60,
                  height: 1.5,
                  fontSize: 13,
                ),
              );
            }
            final index = row - 1;
            final level = levels[index];
            final locked = index > progress.highestUnlockedIndex;
            final completed = progress.completedLevels.contains(level.id);
            final reward = index < ProgressStore.rewardOrder.length
                ? ElementData.baseElements
                      .firstWhere(
                        (e) => e.type == ProgressStore.rewardOrder[index],
                      )
                      .name
                : 'Mở khóa chủng tộc Yeti';
            final saved = progress.storyRun?['levelId'] == level.id
                ? progress.storyRun
                : null;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1D2C3D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: completed ? const Color(0xFF497F70) : Colors.white10,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        locked
                            ? Icons.lock_outline
                            : completed
                            ? Icons.check_circle_outline
                            : Icons.image_outlined,
                        color: locked
                            ? Colors.white30
                            : completed
                            ? const Color(0xFF8AD4BB)
                            : const Color(0xFFE6C38C),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          level.title,
                          style: TextStyle(
                            color: locked ? Colors.white38 : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${level.theme.name} · ${level.cols}×${level.rows} ô · Độ bền x${pow(1.16, index).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${completed ? 'Đã nhận' : 'Phần thưởng'}: $reward',
                    style: TextStyle(
                      color: locked ? Colors.white30 : const Color(0xFFBFA6E0),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (saved != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => GameScreen.resume(saved),
                          ),
                        ),
                        child: const Text('TIẾP TỤC TIẾN TRÌNH ĐÃ LƯU'),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: locked
                          ? null
                          : () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => GameScreen(
                                  role: role,
                                  race: race,
                                  levelIndex: index,
                                  isYetiUnlocked: isYetiUnlocked,
                                ),
                              ),
                            ),
                      child: Text(
                        locked
                            ? 'HOÀN THÀNH MÀN TRƯỚC ĐỂ MỞ'
                            : saved != null
                            ? 'CHƠI LẠI MÀN TỪ ĐẦU'
                            : completed
                            ? 'CHƠI LẠI'
                            : 'VÀO MÀN',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
