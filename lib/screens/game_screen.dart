import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../game/game_engine.dart';
import '../game/game_painter.dart';
import '../models/character.dart';
import '../models/pixel_art_data.dart';
import '../core/audio_service.dart';
import 'forge_modal.dart';
import 'fusion_lab_modal.dart';
import 'level_up_modal.dart';
import 'victory_modal.dart';
import 'character_select_screen.dart';

class GameScreen extends StatefulWidget {
  final RoleInfo role;
  final RaceInfo race;
  final int levelIndex;
  final bool isYetiUnlocked;

  const GameScreen({
    super.key,
    required this.role,
    required this.race,
    this.levelIndex = 0,
    this.isYetiUnlocked = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late GameEngine _engine;
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  bool _isPaused = false;
  late bool _yetiUnlocked;

  @override
  void initState() {
    super.initState();
    _yetiUnlocked = widget.isYetiUnlocked;
    final levels = MemeLevel.allLevels;
    final currentLevel = levels[widget.levelIndex % levels.length];

    _engine = GameEngine(
      role: widget.role,
      race: widget.race,
      level: currentLevel,
    );

    // Đăng ký callbacks
    _engine.onLevelUp = _showLevelUpDialog;
    _engine.onVictory = _showVictoryDialog;
    _engine.onBlockDestroyedEffect = () {
      AudioService.playBlockBreak();
    };

    // Khởi tạo Game Loop Ticker
    _ticker = createTicker((elapsed) {
      if (_isPaused) {
        _lastElapsed = elapsed;
        return;
      }
      if (_lastElapsed == Duration.zero) {
        _lastElapsed = elapsed;
        return;
      }
      final dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
      _lastElapsed = elapsed;

      // Giới hạn dt tối đa để tránh giật lag khi chuyển tab
      final clampedDt = dt.clamp(0.001, 0.033);
      _engine.update(clampedDt);
    });

    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _engine.dispose();
    super.dispose();
  }

  void _showLevelUpDialog() {
    setState(() => _isPaused = true);
    AudioService.playLevelUp();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LevelUpModal(
        engine: _engine,
        onOptionSelected: () {
          setState(() => _isPaused = false);
        },
      ),
    ).then((_) {
      if (mounted) setState(() => _isPaused = false);
    });
  }

  void _showVictoryDialog() {
    setState(() => _isPaused = true);
    AudioService.playVictory();

    final isFinal = (widget.levelIndex == MemeLevel.allLevels.length - 1);
    if (isFinal) {
      _yetiUnlocked = true;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VictoryModal(
        level: _engine.level,
        earnedGold: _engine.gold,
        isFinalStoryLevel: isFinal,
        onNextLevel: () {
          Navigator.of(context).pop();
          final nextIdx = (widget.levelIndex + 1) % MemeLevel.allLevels.length;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => GameScreen(
                role: widget.role,
                race: widget.race,
                levelIndex: nextIdx,
                isYetiUnlocked: _yetiUnlocked,
              ),
            ),
          );
        },
        onReturnMenu: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => CharacterSelectScreen(
                isYetiUnlocked: _yetiUnlocked,
              ),
            ),
          );
        },
      ),
    );
  }

  void _openForgeModal() {
    setState(() => _isPaused = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ForgeModal(engine: _engine),
    ).then((_) {
      if (mounted) setState(() => _isPaused = false);
    });
  }

  void _openFusionLabModal() {
    setState(() => _isPaused = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FusionLabModal(engine: _engine),
    ).then((_) {
      if (mounted) setState(() => _isPaused = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Top HUD: Thông tin màn chơi, Vàng, EXP, Nút Menu/Lò rèn/Lab
            _buildTopHUD(),

            // Khu vực Arena chơi chính
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxHeight);
                  _engine.resize(size);

                  return GestureDetector(
                    onPanUpdate: (details) {
                      // Hích bóng khi người chơi quẹt trên màn hình
                      _engine.boostBall(details.delta * 2.0);
                    },
                    child: ClipRect(
                      child: CustomPaint(
                        size: size,
                        painter: GamePainter(engine: _engine),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Bar: Hướng dẫn vuốt và các nút Lò Rèn / Dung Hợp
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHUD() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          Row(
            children: [
              // Nút thoát về menu
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => CharacterSelectScreen(
                        isYetiUnlocked: _yetiUnlocked,
                      ),
                    ),
                  );
                },
              ),

              // Thông tin màn chơi & meme
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _engine.level.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Thanh % Giải mã Meme
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _engine.completionPercent,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.cyanAccent,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(_engine.completionPercent * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Vàng hiện có
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    AnimatedBuilder(
                      animation: _engine,
                      builder: (context, _) => Text(
                        '${_engine.gold}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Thanh EXP & Level
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Lv.${_engine.characterLevel}',
                  style: const TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_engine.exp / _engine.expToNextLevel).clamp(0.0, 1.0),
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.purpleAccent,
                    ),
                    minHeight: 5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1E293B),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Nút Lò Rèn
          ElevatedButton.icon(
            onPressed: _openForgeModal,
            icon: const Icon(Icons.hardware, color: Colors.amber, size: 20),
            label: const Text(
              'LÒ RÈN',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.amber, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),

          // Gợi ý điều khiển
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, color: Colors.white38, size: 18),
              Text(
                'Vuốt để hích bóng',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),

          // Nút Dung Hợp Nguyên Tố (Lab)
          ElevatedButton.icon(
            onPressed: _openFusionLabModal,
            icon: const Icon(Icons.science, color: Colors.purpleAccent, size: 20),
            label: Row(
              children: [
                const Text(
                  'DUNG HỢP',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (_engine.activeFusions.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.purpleAccent, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
