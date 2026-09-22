import 'dart:math';
import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../models/element.dart';

enum ChoiceKind { element, damage, speed, magnet, gold, spin, spirit }

class LevelUpOption {
  final ChoiceKind kind;
  final ElementData? element;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  LevelUpOption({
    required this.kind,
    this.element,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class LevelUpModal extends StatelessWidget {
  final GameEngine engine;
  final VoidCallback onOptionSelected;

  const LevelUpModal({
    super.key,
    required this.engine,
    required this.onOptionSelected,
  });

  List<LevelUpOption> _getChoices() {
    final rng = Random();
    final List<LevelUpOption> choices = [];

    // 1. Lọc ra danh sách các nguyên tố CHƯA SỞ HỮU (loại bỏ hoàn toàn các nguyên tố đã có)
    final unownedElements = ElementData.baseElements
        .where((e) => !engine.ownedElements.contains(e.type))
        .toList();
    unownedElements.shuffle(rng);

    // Lấy tối đa 2 nguyên tố chưa sở hữu
    for (final el in unownedElements.take(2)) {
      choices.add(LevelUpOption(
        kind: ChoiceKind.element,
        element: el,
        title: el.name,
        description: el.description,
        icon: el.icon,
        color: el.color,
      ));
    }

    // 2. Danh sách các thẻ Cường Hóa Chỉ Số & Kỹ Năng Sáng Tạo Đặc Biệt
    final List<LevelUpOption> statOptions = [
      if (engine.spirits.length < 4)
        LevelUpOption(
          kind: ChoiceKind.spirit,
          title: '🔮 Cầu Vệ Tinh Xoay Quanh (+1 Cầu Hộ Vệ)',
          description: 'Thêm 1 quả cầu năng lượng bay xoay quanh bóng, tự động va đập và phá nát các khối pixel.',
          icon: Icons.blur_circular,
          color: Colors.cyanAccent,
        ),
      LevelUpOption(
        kind: ChoiceKind.spin,
        title: '🌀 Cuồng Vũ Xoay Kiếm (+40% Tốc Độ Xoay)',
        description: 'Vũ khí xoay tít với tốc độ cuồng phong bão lốc, càn quét toàn bộ khối xung quanh.',
        icon: Icons.cyclone,
        color: Colors.cyanAccent,
      ),
      LevelUpOption(
        kind: ChoiceKind.damage,
        title: 'Cường Hóa Sát Thương (+25%)',
        description: 'Tăng mạnh uy lực cho đòn đánh, vũ khí xoay và các mũi tên.',
        icon: Icons.colorize,
        color: Colors.redAccent,
      ),
      LevelUpOption(
        kind: ChoiceKind.speed,
        title: 'Tăng Tốc Đánh & Nảy (+20%)',
        description: 'Quả bóng nảy nhanh hơn và nhịp ra đòn dày đặc hơn đáng kể.',
        icon: Icons.speed,
        color: Colors.tealAccent,
      ),
      LevelUpOption(
        kind: ChoiceKind.magnet,
        title: 'Bão Từ Nam Châm (+40%)',
        description: 'Tự động hút Vàng và Ngọc EXP từ khoảng cách xa trên toàn sàn.',
        icon: Icons.all_out,
        color: Colors.purpleAccent,
      ),
      LevelUpOption(
        kind: ChoiceKind.gold,
        title: 'Túi Vàng Khổng Lồ (+150 G)',
        description: 'Nhận ngay 150 Vàng để nâng cấp vũ khí tại Lò Rèn.',
        icon: Icons.monetization_on,
        color: Colors.amberAccent,
      ),
    ];
    statOptions.shuffle(rng);

    // 3. Nếu chưa đủ 3 lựa chọn, bù đắp bằng các thẻ nâng cấp kỹ năng
    for (final stat in statOptions) {
      if (choices.length >= 3) break;
      choices.add(stat);
    }

    return choices;
  }

  void _applyChoice(LevelUpOption choice) {
    switch (choice.kind) {
      case ChoiceKind.element:
        if (choice.element != null) {
          engine.addElement(choice.element!.type);
        }
        break;
      case ChoiceKind.spirit:
        engine.summonSpirit();
        break;
      case ChoiceKind.spin:
        engine.upgradeSpinSpeed();
        break;
      case ChoiceKind.damage:
        engine.damageUpgradeLevel += 2;
        break;
      case ChoiceKind.speed:
        engine.speedUpgradeLevel += 2;
        break;
      case ChoiceKind.magnet:
        engine.magnetUpgradeLevel += 2;
        break;
      case ChoiceKind.gold:
        engine.gold += 150;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _getChoices();

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
                color: Colors.amberAccent.withOpacity(0.35),
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
                'Nhân vật đạt Cấp ${engine.characterLevel}! Hãy chọn 1 Kỹ Năng mới:',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // 3 Thẻ lựa chọn mới (hoàn toàn không trùng thẻ đã sở hữu)
              Column(
                children: options.map((opt) {
                  return InkWell(
                    onTap: () {
                      _applyChoice(opt);
                      onOptionSelected();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: opt.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: opt.color, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: opt.color.withOpacity(0.25),
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
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: opt.kind == ChoiceKind.element
                                            ? Colors.purple.withOpacity(0.4)
                                            : Colors.blue.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        opt.kind == ChoiceKind.element
                                            ? 'NGUYÊN TỐ MỚI'
                                            : 'CƯỜNG HÓA',
                                        style: TextStyle(
                                          color: opt.kind == ChoiceKind.element
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
    );
  }
}
