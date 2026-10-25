import 'package:flutter/material.dart';

import '../game/game_engine.dart';
import '../models/upgrade.dart';

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
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF152231),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.hardware_outlined, color: Color(0xFFF1C587)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'LÒ RÈN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF263344),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${engine.gold} G',
                    style: const TextStyle(
                      color: Color(0xFFF1C587),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white60),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                engine.race.shopDiscount > 0
                    ? 'Ưu đãi Người Lùn: −25% mọi nâng cấp'
                    : 'Chọn hướng phát triển · Xem trước chỉ số thật',
                style: const TextStyle(color: Color(0xFF98ADBF), fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: UpgradeSpec.all.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _card(UpgradeSpec.all[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(UpgradeSpec spec) {
    final engine = widget.engine;
    final rank = engine.upgradeRank(spec.type);
    final maxed = !engine.canImprove(spec.type);
    final cost = engine.upgradeCost(spec.type);
    final affordable = engine.gold >= cost;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1D2C3D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: maxed ? spec.color.withValues(alpha: 0.25) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: spec.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(spec.icon, color: spec.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bậc $rank / ${spec.maxRank}',
                      style: TextStyle(color: spec.color, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: maxed || !affordable
                    ? null
                    : () {
                        if (engine.purchaseUpgrade(spec.type)) setState(() {});
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: spec.color,
                  foregroundColor: const Color(0xFF13202C),
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  maxed ? 'TỐI ĐA' : '$cost G',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            spec.description,
            style: const TextStyle(
              color: Color(0xFF9DAEBE),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          if (!maxed)
            Text(
              engine.upgradePreview(spec.type),
              style: TextStyle(
                color: spec.color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: rank / spec.maxRank,
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              color: spec.color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
