import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game_engine.dart';
import '../models/element.dart';
import '../models/upgrade.dart';

enum ChoiceKind { element, upgrade, gold }

class LevelUpOption {
  final ChoiceKind kind;
  final ElementData? element;
  final UpgradeType? upgrade;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  LevelUpOption({
    required this.kind,
    this.element,
    this.upgrade,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class LevelUpModal extends StatefulWidget {
  final GameEngine engine;
  final VoidCallback onOptionSelected;

  const LevelUpModal({
    super.key,
    required this.engine,
    required this.onOptionSelected,
  });

  @override
  State<LevelUpModal> createState() => _LevelUpModalState();
}

class _LevelUpModalState extends State<LevelUpModal> {
  GameEngine get engine => widget.engine;
  late List<LevelUpOption> _options;
  bool _rerolled = false;
  bool _selected = false;
  int get _rerollCost => 25 + engine.characterLevel * 5;

  @override
  void initState() {
    super.initState();
    _options = _getChoices();
  }

  List<LevelUpOption> _getChoices() {
    final rng = Random();
    final unowned =
        ElementData.baseElements
            .where((e) => !engine.ownedElements.contains(e.type))
            .toList()
          ..shuffle(rng);
    final upgrades =
        UpgradeSpec.all.where((spec) => engine.canImprove(spec.type)).toList()
          ..shuffle(rng);
    final options = <LevelUpOption>[
      if (unowned.isNotEmpty)
        LevelUpOption(
          kind: ChoiceKind.element,
          element: unowned.first,
          title: unowned.first.name,
          description: unowned.first.description,
          icon: unowned.first.icon,
          color: unowned.first.color,
        ),
      ...upgrades
          .take(unowned.isEmpty ? 3 : 2)
          .map(
            (spec) => LevelUpOption(
              kind: ChoiceKind.upgrade,
              upgrade: spec.type,
              title: spec.title,
              description: engine.upgradePreview(spec.type),
              icon: spec.icon,
              color: spec.color,
            ),
          ),
    ];
    if (options.length < 3) {
      options.add(
        LevelUpOption(
          kind: ChoiceKind.gold,
          title: 'Dự trữ lò rèn',
          description: 'Nhận 100 vàng để mua nâng cấp theo ý bạn.',
          icon: Icons.monetization_on,
          color: Colors.amberAccent,
        ),
      );
    }
    return options;
  }

  void _applyChoice(LevelUpOption choice) {
    switch (choice.kind) {
      case ChoiceKind.element:
        engine.addElement(choice.element!.type);
      case ChoiceKind.upgrade:
        engine.grantUpgrade(choice.upgrade!);
      case ChoiceKind.gold:
        engine.gold += 100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;

    return PopScope(
      canPop: false, // Choose an upgrade before returning to combat.
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
                color: Colors.amberAccent.withValues(alpha: 0.35),
                blurRadius: 25,
                spreadRadius: 4,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Lên cấp
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upgrade, color: Colors.amberAccent, size: 28),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CHỌN NÂNG CẤP',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Nhân vật đạt Cấp ${engine.characterLevel}! Hãy chọn 1 Kỹ Năng mới:',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _rerolled || engine.gold < _rerollCost
                        ? null
                        : () {
                            engine.gold -= _rerollCost;
                            setState(() {
                              _rerolled = true;
                              _options = _getChoices();
                            });
                          },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(
                      _rerolled
                          ? 'Đã đổi lựa chọn'
                          : 'Đổi lựa chọn · $_rerollCost G',
                    ),
                  ),
                ),
                // 3 Thẻ lựa chọn mới (hoàn toàn không trùng thẻ đã sở hữu)
                Column(
                  children: options.map((opt) {
                    return InkWell(
                      onTap: () {
                        if (_selected) return;
                        _selected = true;
                        _applyChoice(opt);
                        widget.onOptionSelected();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: opt.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: opt.color, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: opt.color.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(opt.icon, color: opt.color, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          opt.title,
                                          style: TextStyle(
                                            color: opt.color,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: opt.kind == ChoiceKind.element
                                              ? Colors.purple.withValues(
                                                  alpha: 0.4,
                                                )
                                              : Colors.blue.withValues(
                                                  alpha: 0.4,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          opt.kind == ChoiceKind.element
                                              ? 'MỚI'
                                              : '+1 BẬC',
                                          style: TextStyle(
                                            color:
                                                opt.kind == ChoiceKind.element
                                                ? Colors.purpleAccent
                                                : Colors.lightBlueAccent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    opt.description,
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
      ),
    );
  }
}
