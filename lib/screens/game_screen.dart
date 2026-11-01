import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/game_engine.dart';
import '../core/progress_store.dart';
import '../game/game_painter.dart';
import '../models/character.dart';
import '../models/element.dart';
import '../models/pixel_art_data.dart';
import 'forge_modal.dart';
import 'fusion_lab_modal.dart';
import 'level_up_modal.dart';
import 'victory_modal.dart';
import 'character_select_screen.dart';

class GameScreen extends StatefulWidget {
  final RoleInfo role;
  final RaceInfo race;
  final Map<String, dynamic>? resumeSnapshot;
  final int levelIndex;
  final bool isEndless;
  final bool isYetiUnlocked;

  const GameScreen({
    super.key,
    required this.role,
    required this.race,
    this.levelIndex = 0,
    this.resumeSnapshot,
    this.isEndless = false,
    this.isYetiUnlocked = false,
  });

  factory GameScreen.resume(Map<String, dynamic> snapshot) => GameScreen(
    role:
        RoleInfo.allRoles
            .where((r) => r.type.name == snapshot['role'])
            .firstOrNull ??
        RoleInfo.allRoles.first,
    race:
        RaceInfo.allRaces
            .where((r) => r.type.name == snapshot['race'])
            .firstOrNull ??
        RaceInfo.allRaces.first,
    levelIndex: ((snapshot['levelId'] as int? ?? 1) - 1).clamp(
      0,
      MemeLevel.allLevels.length - 1,
    ),
    isEndless: snapshot['endless'] == true,
    resumeSnapshot: snapshot,
  );

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late GameEngine _engine;
  Timer? _saveTimer;
  bool _lifecyclePaused = false;
  bool _levelChoicePending = false;
  ProgressStore get _progress => ProgressStore.instance;
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  bool _isPaused = false;
  late bool _yetiUnlocked;
  late int _storyLevelIndex;

  @override
  void initState() {
    super.initState();
    _yetiUnlocked = widget.isYetiUnlocked || _progress.yetiUnlocked;
    WidgetsBinding.instance.addObserver(this);
    _storyLevelIndex = widget.levelIndex;
    final levels = MemeLevel.allLevels;
    final currentLevel = levels[widget.levelIndex % levels.length];

    _engine = GameEngine(
      role: widget.role,
      race: widget.race,
      level: currentLevel,
      isEndless: widget.isEndless,
    );

    if (widget.resumeSnapshot != null) {
      try {
        _engine.restoreSnapshot(widget.resumeSnapshot!);
        _levelChoicePending =
            widget.resumeSnapshot!['levelChoicePending'] == true;
      } catch (_) {
        _progress.storageError = 'Không khôi phục được màn đang dở. Màn và nguyên tố đã mở vẫn được giữ.';
        _engine.dispose();
        _engine = GameEngine(
          role: widget.role,
          race: widget.race,
          level: currentLevel,
          isEndless: widget.isEndless,
        );
      }
    } else if (!widget.isEndless && _progress.storyBuild != null) {
      try {
        _engine.restoreBuild(_progress.storyBuild!);
        _levelChoicePending =
            _progress.storyBuild!['levelChoicePending'] == true;
      } catch (_) {
        _progress.storageError = 'Không khôi phục được nâng cấp. Màn và nguyên tố đã mở vẫn được giữ.';
        _engine.dispose();
        _engine = GameEngine(
          role: widget.role,
          race: widget.race,
          level: currentLevel,
        );
      }
    }
    for (final element in _progress.unlockedElements) {
      if (!_engine.ownedElements.contains(element)) _engine.addElement(element);
    }
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isPaused) _saveRun();
    });
    if (_levelChoicePending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLevelUpDialog();
      });
    } else if (_engine.isLevelCompleted && !widget.isEndless) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showVictoryDialog();
      });
    }

    // Đăng ký callbacks
    _engine.onLevelUp = _showLevelUpDialog;
    _engine.onVictory = _showVictoryDialog;

    // Khởi tạo Game Loop Ticker
    _ticker = createTicker((elapsed) {
      if (_isPaused || _lifecyclePaused) {
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
    _saveTimer?.cancel();
    _saveRun();
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _engine.dispose();
    super.dispose();
  }

  void _saveRun() {
    if (!_engine.isGridBuilt) return;
    if (widget.isEndless) {
      _progress.endlessRun = _engine.exportSnapshot()
        ..['levelChoicePending'] = _levelChoicePending;
    } else {
      _progress.storyBuild = _engine.exportBuild()
        ..['levelChoicePending'] = _levelChoicePending;
      _progress.storyRun = _engine.isLevelCompleted
          ? null
          : (_engine.exportSnapshot()
              ..['levelChoicePending'] = _levelChoicePending);
    }
    unawaited(_progress.save());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecyclePaused = state != AppLifecycleState.resumed;
    if (_lifecyclePaused) {
      _saveRun();
    } else {
      _lastElapsed = Duration.zero;
    }
  }

  void _showLevelUpDialog() {
    _levelChoicePending = true;
    _saveRun();
    setState(() => _isPaused = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LevelUpModal(
        engine: _engine,
        onOptionSelected: () {
          _levelChoicePending = false;
          setState(() => _isPaused = false);
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isPaused = false);
        _saveRun();
      }
    });
  }

  void _showVictoryDialog() {
    setState(() => _isPaused = true);

    final reward = _progress.completeLevel(_engine.level.id);
    if (reward != null) _engine.addElement(reward);
    _saveRun();
    final isFinal = (_storyLevelIndex == MemeLevel.allLevels.length - 1);
    if (isFinal) {
      _yetiUnlocked = true;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VictoryModal(
        level: _engine.level,
        earnedGold: _engine.gold,
        rewardElement: reward == null
            ? null
            : ElementData.baseElements.firstWhere((e) => e.type == reward).name,
        isFinalStoryLevel: isFinal,
        onNextLevel: () {
          Navigator.of(context).pop();
          if (isFinal) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) =>
                    CharacterSelectScreen(isYetiUnlocked: _yetiUnlocked),
              ),
            );
          } else {
            setState(() {
              _storyLevelIndex++;
              _engine.startStoryLevel(MemeLevel.allLevels[_storyLevelIndex]);
              _isPaused = false;
              _lastElapsed = Duration.zero;
              _saveRun();
            });
          }
        },
        onReturnMenu: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  CharacterSelectScreen(isYetiUnlocked: _yetiUnlocked),
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
      if (mounted) {
        setState(() => _isPaused = false);
        _saveRun();
      }
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
      if (mounted) {
        setState(() => _isPaused = false);
        _saveRun();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _engine.level.theme.sky,
      body: SafeArea(
        child: Column(
          children: [
            // Top HUD: Thông tin màn chơi, Vàng, EXP, Nút Menu/Lò rèn/Lab
            _buildTopHUD(),

            // Khu vực Arena chơi chính
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  _engine.resize(size, notify: false);

                  return GestureDetector(
                    onTapUp: (details) {
                      if (_engine.canCastFusion &&
                          !_engine.castFusion(details.localPosition)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Chọn khối đúng trạng thái trong tầm 180.',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    onPanEnd: (details) =>
                        _engine.boostBall(details.velocity.pixelsPerSecond),
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
            ValueListenableBuilder<int>(
              valueListenable: _engine.hudRevision,
              builder: (context, value, child) {
                final data = _engine.fusionData;
                if (data == null) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  color: const Color(0xFF15212F),
                  child: Row(
                    children: [
                      Icon(data.icon, color: data.color, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.name.split(' (').first,
                              style: TextStyle(
                                color: data.color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: _engine.fusionMeterProgress,
                              minHeight: 3,
                              color: data.color,
                              backgroundColor: Colors.white10,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _engine.fusionStatus,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: !_engine.canCastFusion
                            ? null
                            : () {
                                if (!_engine.castFusion()) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Chưa có mục tiêu đúng trạng thái trong tầm.',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                        child: const Text(
                          'GIẢI PHÓNG',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHUD() => ValueListenableBuilder<int>(
    valueListenable: _engine.hudRevision,
    builder: (context, value, child) => _buildTopHUDContent(),
  );

  Widget _buildTopHUDContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Color.lerp(_engine.level.theme.sky, const Color(0xFF172333), 0.65),
      child: Column(
        children: [
          Row(
            children: [
              // Nút thoát về menu
              IconButton(
                tooltip: 'Về chọn màn · Tự lưu tiến trình',
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) =>
                          CharacterSelectScreen(isYetiUnlocked: _yetiUnlocked),
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
                      _engine.isExpanding
                          ? 'Đã hé lộ tranh · Đang mở rộng…'
                          : _engine.level.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _engine.level.theme.name,
                      style: TextStyle(
                        color: _engine.level.theme.accent.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 10,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_engine.gold}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
                  color: Colors.purple.withValues(alpha: 0.35),
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
                    value: (_engine.exp / _engine.expToNextLevel).clamp(
                      0.0,
                      1.0,
                    ),
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
          if (_engine.ownedElements.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    '${_engine.equippedElements.length}/3  ',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  ...ElementData.baseElements
                      .where(
                        (data) => _engine.ownedElements.contains(data.type),
                      )
                      .map((data) {
                        final selected = _engine.equippedElements.contains(
                          data.type,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: Tooltip(
                            message: data.description,
                            child: ActionChip(
                              visualDensity: VisualDensity.compact,
                              avatar: Icon(
                                data.icon,
                                color: selected ? data.color : Colors.white38,
                                size: 14,
                              ),
                              backgroundColor: selected
                                  ? data.color.withValues(alpha: 0.12)
                                  : const Color(0xFF172333),
                              side: BorderSide(
                                color: selected
                                    ? data.color.withValues(alpha: 0.5)
                                    : Colors.white12,
                              ),
                              label: Text(
                                data.name.split(' (').first,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: selected ? data.color : Colors.white38,
                                ),
                              ),
                              onPressed: () {
                                if (!_engine.toggleElement(data.type)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Trang bị tối đa 3 nguyên tố. Bỏ chọn một nguyên tố để thay thế.',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      }),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _progress,
            builder: (context, child) => Align(
              alignment: Alignment.centerRight,
              child: Text(
                _progress.storageError ??
                    (_progress.savedAt == null
                        ? 'Tự lưu mỗi 5 giây'
                        : 'Đã tự lưu trên thiết bị'),
                maxLines: 2,
                style: TextStyle(
                  fontSize: 10,
                  color: _progress.storageError == null
                      ? Colors.white38
                      : Colors.orangeAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    Widget button(
      String label,
      IconData icon,
      Color color,
      VoidCallback onTap,
    ) => Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: FittedBox(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: const Color(0xFF172333),
      child: Row(
        children: [
          button(
            'LÒ RÈN',
            Icons.hardware_outlined,
            const Color(0xFFE8C393),
            _openForgeModal,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _engine.hudRevision,
              builder: (context, value, child) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swipe,
                    size: 18,
                    color: _engine.dashCooldown > 0
                        ? Colors.white24
                        : const Color(0xFF8BCFC6),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _engine.dashCooldown > 0
                        ? 'Lướt · ${_engine.dashCooldown.toStringAsFixed(1)}s'
                        : 'Vuốt để lướt',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          button(
            'DUNG HỢP',
            Icons.science_outlined,
            const Color(0xFFC3ABDF),
            _openFusionLabModal,
          ),
        ],
      ),
    );
  }
}
