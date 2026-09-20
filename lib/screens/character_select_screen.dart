import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/pixel_art_data.dart';
import 'game_screen.dart';

class CharacterSelectScreen extends StatefulWidget {
  final bool isYetiUnlocked;

  const CharacterSelectScreen({super.key, this.isYetiUnlocked = false});

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  RoleInfo _selectedRole = RoleInfo.allRoles[0]; // Chiến binh mặc định
  RaceInfo _selectedRace = RaceInfo.allRaces[0]; // Người mặc định

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

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'BẮT ĐẦU PHÁ KHỐI',
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
        border: Border.all(color: _selectedRole.themeColor.withOpacity(0.4)),
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
                  color: _selectedRole.themeColor.withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                radius: 0.8,
                colors: [
                  Colors.white,
                  _selectedRole.themeColor,
                  Colors.black,
                ],
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
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
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
                  ? role.themeColor.withOpacity(0.18)
                  : const Color(0xFF1E293B).withOpacity(0.6),
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
        final isLocked = race.isSecret && !widget.isYetiUnlocked;

        return InkWell(
          onTap: () {
            if (isLocked) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '❄️ Tộc Yeti bị khóa! Hãy phá đảo Story Mode (Màn 3) để mở khóa.',
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
                      ? race.themeColor.withOpacity(0.18)
                      : const Color(0xFF1E293B).withOpacity(0.6)),
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
                                  : (isSelected ? race.themeColor : Colors.white),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (isLocked)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.3),
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
                            ? 'Hoàn thành Chế độ Cốt truyện (Đánh bại Màn 3 Popcat) để mở khóa.'
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GameScreen(
          role: _selectedRole,
          race: _selectedRace,
          levelIndex: 0,
          isYetiUnlocked: widget.isYetiUnlocked,
        ),
      ),
    );
  }
}
