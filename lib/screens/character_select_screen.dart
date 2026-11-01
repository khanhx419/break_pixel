import 'package:flutter/material.dart';

import '../models/character.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import '../core/progress_store.dart';

class CharacterSelectScreen extends StatefulWidget {
  final bool isYetiUnlocked;

  const CharacterSelectScreen({super.key, this.isYetiUnlocked = false});

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  bool _isEndless = false;
  RoleInfo _selectedRole = RoleInfo.allRoles[0]; // Chiến binh mặc định
  RaceInfo _selectedRace = RaceInfo.allRaces[0]; // Người mặc định

  @override
  void initState() {
    super.initState();
    ProgressStore.instance.addListener(_refreshProgress);
  }

  void _refreshProgress() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ProgressStore.instance.removeListener(_refreshProgress);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'CHỌN NGHỀ & CHỦNG TỘC',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preview Nhân vật kết hợp
            _buildCharacterPreview(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Cốt truyện'),
                      avatar: const Icon(Icons.auto_stories_outlined, size: 18),
                      selected: !_isEndless,
                      onSelected: (_) => setState(() => _isEndless = false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Vô tận'),
                      avatar: const Icon(Icons.all_inclusive, size: 18),
                      selected: _isEndless,
                      onSelected: (_) => setState(() => _isEndless = true),
                    ),
                  ),
                ],
              ),
            ),
            if (_isEndless)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Hết khối → bản đồ lớn hơn. Giữ nguyên vàng và nâng cấp.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ProgressStore.instance.storageError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          ProgressStore.instance.storageError!,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (ProgressStore.instance.storyRun != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.play_circle_outline),
                            label: Text(
                              'TIẾP TỤC MÀN ${ProgressStore.instance.storyRun!['levelId']}',
                            ),
                            onPressed: () =>
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => GameScreen.resume(
                                      ProgressStore.instance.storyRun!,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    if (ProgressStore.instance.endlessRun != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.all_inclusive),
                            label: Text(
                              'TIẾP TỤC VÔ TẬN · ĐỢT ${ProgressStore.instance.endlessRun!['wave']}',
                            ),
                            onPressed: () =>
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => GameScreen.resume(
                                      ProgressStore.instance.endlessRun!,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    Text(
                      'Đã hoàn thành ${ProgressStore.instance.completedLevels.length}/9 màn · '
                      '${ProgressStore.instance.unlockedElements.length}/8 nguyên tố',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 1. Chọn Nghề nghiệp (Role)
                    const Text(
                      '1. CHỌN NGHỀ NGHIỆP (ROLE)',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRoleList(),

                    const SizedBox(height: 20),

                    // 2. Chọn Chủng tộc (Race)
                    const Text(
                      '2. CHỌN CHỦNG TỘC (RACE)',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRaceList(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Nút Bắt đầu
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _onStartGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent.shade700,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 28),
                      SizedBox(width: 8),
                      Text(
                        _isEndless ? 'BẮT ĐẦU PHÁ KHỐI' : 'CHỌN MÀN CHƠI',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedRole.themeColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          // Quả cầu đại diện
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _selectedRole.themeColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                radius: 0.8,
                colors: [Colors.white, _selectedRole.themeColor, Colors.black],
              ),
            ),
            child: Center(
              child: Icon(_selectedRole.icon, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(width: 16),
          // Thông tin kết hợp
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedRole.name} • ${_selectedRace.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vũ khí: ${_selectedRole.weaponName}',
                  style: TextStyle(
                    color: _selectedRole.themeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nội tại: ${_selectedRace.passiveName}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleList() {
    return Column(
      children: RoleInfo.allRoles.map((role) {
        final isSelected = _selectedRole.type == role.type;
        return InkWell(
          onTap: () {
            setState(() {
              _selectedRole = role;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? role.themeColor.withValues(alpha: 0.18)
                  : const Color(0xFF1E293B).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? role.themeColor : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(role.icon, color: role.themeColor, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.name,
                        style: TextStyle(
                          color: isSelected ? role.themeColor : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        role.description,
                        style: const TextStyle(
                          color: Colors.white60,
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
    );
  }

  Widget _buildRaceList() {
    return Column(
      children: RaceInfo.allRaces.map((race) {
        final isSelected = _selectedRace.type == race.type;
        final isLocked =
            race.isSecret &&
            !(widget.isYetiUnlocked || ProgressStore.instance.yetiUnlocked);

        return InkWell(
          onTap: () {
            if (isLocked) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '❄️ Tộc Yeti bị khóa! Hãy phá đảo Story Mode (Màn 9) để mở khóa.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.blueGrey,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            setState(() {
              _selectedRace = race;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLocked
                  ? Colors.black26
                  : (isSelected
                        ? race.themeColor.withValues(alpha: 0.18)
                        : const Color(0xFF1E293B).withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected && !isLocked
                    ? race.themeColor
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isLocked ? Icons.lock : race.icon,
                  color: isLocked ? Colors.grey : race.themeColor,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            race.name,
                            style: TextStyle(
                              color: isLocked
                                  ? Colors.grey
                                  : (isSelected
                                        ? race.themeColor
                                        : Colors.white),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (isLocked)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PHẦN THƯỞNG STORY',
                                style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        isLocked
                            ? 'Hoàn thành Chế độ Cốt truyện (Đánh bại Màn 9 Popcat) để mở khóa.'
                            : race.description,
                        style: TextStyle(
                          color: isLocked ? Colors.grey : Colors.white60,
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
    );
  }

  void _onStartGame() {
    if (!_isEndless) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LevelSelectScreen(
            role: _selectedRole,
            race: _selectedRace,
            isYetiUnlocked:
                widget.isYetiUnlocked || ProgressStore.instance.yetiUnlocked,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GameScreen(
          role: _selectedRole,
          race: _selectedRace,
          levelIndex: 0,
          isEndless: _isEndless,
          isYetiUnlocked: widget.isYetiUnlocked,
        ),
      ),
    );
  }
}
