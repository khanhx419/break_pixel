import 'package:flutter/material.dart';

import '../game/game_engine.dart';
import '../models/element.dart';
import '../models/fusion_cast.dart';

class FusionLabModal extends StatefulWidget {
  final GameEngine engine;
  const FusionLabModal({super.key, required this.engine});
  @override
  State<FusionLabModal> createState() => _FusionLabModalState();
}

class _FusionLabModalState extends State<FusionLabModal> {
  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.84,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF152231),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_outlined, color: Color(0xFFC8B1E9)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'DUNG HỢP CHIẾN THUẬT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            const Text(
              '1 công thức đang dùng · 2 nguyên tố thành phần + 1 nguyên tố phụ',
              style: TextStyle(color: Color(0xFFB4A1D0), fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'Phá tổng cộng 100 khối để mở kỹ năng một lần trong lượt chơi. Sau đó dùng lại theo hồi chiêu 10 giây; nâng cấp tại Lò rèn xuống tối thiểu 7 giây. Đổi công thức giữ tiến trình và hồi chiêu.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: ElementData.fusionElements.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final data = ElementData.fusionElements[index];
                  final ingredients = data.ingredients!
                      .map(
                        (type) => ElementData.baseElements.firstWhere(
                          (d) => d.type == type,
                        ),
                      )
                      .toList();
                  final researched = engine.activeFusions.contains(data.type);
                  final available = data.ingredients!.every(
                    engine.ownedElements.contains,
                  );
                  final selected = engine.selectedFusion == data.type;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? data.color.withValues(alpha: 0.09)
                          : const Color(0xFF1C2A3B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? data.color.withValues(alpha: 0.6)
                            : Colors.white10,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              data.icon,
                              color: available ? data.color : Colors.white24,
                              size: 25,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                data.name.split(' (').first,
                                style: TextStyle(
                                  color: selected ? data.color : Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check_circle,
                                color: data.color,
                                size: 18,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 7,
                          runSpacing: 5,
                          children: ingredients.map((part) {
                            final owned = engine.ownedElements.contains(
                              part.type,
                            );
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  owned ? part.icon : Icons.lock_outline,
                                  size: 14,
                                  color: owned ? part.color : Colors.white30,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  part.name.split(' (').first,
                                  style: TextStyle(
                                    color: owned ? part.color : Colors.white30,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        if (researched) ...[
                          Text(
                            engine.isFusionUnlocked
                                ? 'Đã mở kỹ năng · Hồi ${engine.fusionCooldownDuration.toStringAsFixed(0)}s'
                                : 'Mở kỹ năng: ${engine.fusionEnergy.floor()}/100 khối',
                            key: ValueKey('fusion-energy-${data.type.name}'),
                            style: TextStyle(color: data.color, fontSize: 11),
                          ),
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                            value: engine.fusionEnergyFor(data.type) / 100,
                            color: data.color,
                            backgroundColor: Colors.white10,
                            minHeight: 3,
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          FusionRules.hint(data.type),
                          style: const TextStyle(
                            color: Color(0xFFA5B5C5),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed:
                                !available ||
                                    selected ||
                                    engine.pendingFusion != null
                                ? null
                                : () {
                                    if (!researched) {
                                      engine.fuseElements(
                                        data.ingredients![0],
                                        data.ingredients![1],
                                      );
                                    }
                                    engine.selectFusion(data.type);
                                    setState(() {});
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: data.color,
                              side: BorderSide(
                                color: available
                                    ? data.color.withValues(alpha: 0.35)
                                    : Colors.white10,
                              ),
                            ),
                            child: Text(
                              selected
                                  ? 'ĐANG TRANG BỊ'
                                  : !available
                                  ? 'CẦN MỞ KHÓA ĐỦ NGUYÊN TỐ'
                                  : researched
                                  ? 'TRANG BỊ CÔNG THỨC'
                                  : 'NGHIÊN CỨU & TRANG BỊ',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
