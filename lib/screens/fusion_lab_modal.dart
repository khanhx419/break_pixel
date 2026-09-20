import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../models/ecs.dart';
import '../models/element.dart';

class FusionLabModal extends StatefulWidget {
  final GameEngine engine;

  const FusionLabModal({super.key, required this.engine});

  @override
  State<FusionLabModal> createState() => _FusionLabModalState();
}

class _FusionLabModalState extends State<FusionLabModal> {
  ElementType? _slotA;
  ElementType? _slotB;
  String _resultMessage = '';

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final ownedList = engine.ownedElements.toList();

    // Tìm xem công thức ghép 2 slot hiện tại có ra gì không
    ElementData? previewFusion;
    if (_slotA != null && _slotB != null && _slotA != _slotB) {
      previewFusion = ElementData.findFusion(_slotA!, _slotB!);
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tiêu đề
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.science, color: Colors.purpleAccent, size: 26),
              ),
              const SizedBox(width: 10),
              const Text(
                'PHÒNG DUNG HỢP NGUYÊN TỐ',
                style: TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 20),

          // 2 Ô Slot ghép nguyên tố
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSlot(1, _slotA, () => setState(() => _slotA = null)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(Icons.add, color: Colors.white60, size: 28),
              ),
              _buildSlot(2, _slotB, () => setState(() => _slotB = null)),
            ],
          ),

          const SizedBox(height: 16),

          // Kết quả dự kiến / Thông báo
          if (previewFusion != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: previewFusion.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: previewFusion.color),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(previewFusion.icon, color: previewFusion.color, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Phát Hiện: ${previewFusion.name}',
                        style: TextStyle(
                          color: previewFusion.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    previewFusion.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ] else if (_slotA != null && _slotB != null) ...[
            const Text(
              '⚠️ Hai nguyên tố này chưa có phản ứng dung hợp.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],

          if (_resultMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _resultMessage,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Nút Dung hợp
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (previewFusion != null &&
                      !engine.activeFusions.contains(previewFusion.type))
                  ? () {
                      final success =
                          engine.fuseElements(_slotA!, _slotB!);
                      if (success) {
                        setState(() {
                          _resultMessage = '✨ Dung hợp thành công ${previewFusion!.name}!';
                          _slotA = null;
                          _slotB = null;
                        });
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                previewFusion != null &&
                        engine.activeFusions.contains(previewFusion.type)
                    ? 'ĐÃ KÍCH HOẠT KỸ NĂNG NÀY'
                    : 'KÍCH HOẠT DUNG HỢP (RESEARCH)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Danh sách Nguyên tố đang sở hữu để chọn
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Nguyên tố đã mở khóa (${ownedList.length}):',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),

          if (ownedList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Chưa có nguyên tố nào! Hãy đập vỡ pixel để tích EXP và lên cấp.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ownedList.map((type) {
                final data = ElementData.baseElements.firstWhere(
                  (e) => e.type == type,
                  orElse: () => ElementData.baseElements.first,
                );
                return ActionChip(
                  avatar: Icon(data.icon, color: data.color, size: 18),
                  label: Text(data.name, style: const TextStyle(fontSize: 12)),
                  backgroundColor: const Color(0xFF0F172A),
                  side: BorderSide(color: data.color.withOpacity(0.5)),
                  onPressed: () {
                    setState(() {
                      if (_slotA == null) {
                        _slotA = type;
                      } else if (_slotB == null && _slotA != type) {
                        _slotB = type;
                      }
                    });
                  },
                );
              }).toList(),
            ),

          const SizedBox(height: 16),
          // Nút Đóng
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('QUAY LẠI CHIẾN TRƯỜNG', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlot(int slotNum, ElementType? type, VoidCallback onClear) {
    if (type == null) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.touch_app, color: Colors.white38, size: 24),
              const SizedBox(height: 4),
              Text(
                'Slot $slotNum',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final data = ElementData.baseElements.firstWhere((e) => e.type == type);
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: data.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: data.color, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(data.icon, color: data.color, size: 36),
              const SizedBox(height: 4),
              Text(
                data.name.split(' ').first,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
