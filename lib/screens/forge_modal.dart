import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../models/character.dart';

class ForgeModal extends StatefulWidget {
  final GameEngine engine;

  const ForgeModal({super.key, required this.engine});

  @override
  State<ForgeModal> createState() => _ForgeModalState();
}

class _ForgeModalState extends State<ForgeModal> {
  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final isDwarf = engine.race.type == RaceType.dwarf;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tiêu đề Lò Rèn
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.hardware, color: Colors.amber, size: 28),
                  const SizedBox(width: 10),
                  const Text(
                    'LÒ RÈN VŨ KHÍ',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (isDwarf) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DWARF -25%',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Hiển thị số Vàng
              Row(
                children: [
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 22),
                  const SizedBox(width: 4),
                  Text(
                    '${engine.gold}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),

          // Các mục nâng cấp
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildUpgradeRow(
                    title: 'Sát Thương Vũ Khí',
                    subtitle: 'Tăng sát thương chém / bắn (+4 dame)',
                    level: engine.damageUpgradeLevel,
                    cost: engine.getUpgradeCost(engine.damageUpgradeLevel),
                    icon: Icons.colorize,
                    color: Colors.redAccent,
                    onUpgrade: () {
                      if (engine.upgradeDamage()) setState(() {});
                    },
                  ),
                  _buildUpgradeRow(
                    title: 'Tốc Độ Vung / Bắn',
                    subtitle: 'Vũ khí xoay nhanh hơn, nhịp bắn dày hơn (+15%)',
                    level: engine.speedUpgradeLevel,
                    cost: engine.getUpgradeCost(engine.speedUpgradeLevel),
                    icon: Icons.speed,
                    color: Colors.tealAccent,
                    onUpgrade: () {
                      if (engine.upgradeSpeed()) setState(() {});
                    },
                  ),
                  _buildUpgradeRow(
                    title: 'Kích Cỡ & Tầm Quét',
                    subtitle: 'Mở rộng tầm quét trúng nhiều pixel hơn',
                    level: engine.rangeUpgradeLevel,
                    cost: engine.getUpgradeCost(engine.rangeUpgradeLevel),
                    icon: Icons.zoom_out_map,
                    color: Colors.orangeAccent,
                    onUpgrade: () {
                      if (engine.upgradeRange()) setState(() {});
                    },
                  ),
                  _buildUpgradeRow(
                    title: 'Tốc Độ Nảy Của Bóng',
                    subtitle: 'Bóng di chuyển và nảy nhanh hơn',
                    level: engine.bounceUpgradeLevel,
                    cost: engine.getUpgradeCost(engine.bounceUpgradeLevel),
                    icon: Icons.sports_volleyball,
                    color: Colors.lightGreenAccent,
                    onUpgrade: () {
                      if (engine.upgradeBounce()) setState(() {});
                    },
                  ),
                  _buildUpgradeRow(
                    title: 'Nam Châm Hút Vàng & EXP',
                    subtitle: 'Tự động hút Vàng và EXP từ khoảng cách xa hơn',
                    level: engine.magnetUpgradeLevel,
                    cost: engine.getUpgradeCost(engine.magnetUpgradeLevel),
                    icon: Icons.all_out,
                    color: Colors.purpleAccent,
                    onUpgrade: () {
                      if (engine.upgradeMagnet()) setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          // Nút Đóng
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('QUAY LẠI CHIẾN TRƯỜNG', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeRow({
    required String title,
    required String subtitle,
    required int level,
    required int cost,
    required IconData icon,
    required Color color,
    required VoidCallback onUpgrade,
  }) {
    final engine = widget.engine;
    final canAfford = engine.gold >= cost;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Lv.$level',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: canAfford ? onUpgrade : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent.shade700,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white12,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$cost G',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
