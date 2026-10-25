import 'package:flutter/material.dart';

enum UpgradeType {
  damage,
  speed,
  range,
  bounce,
  magnet,
  spin,
  spirit,
  resonance,
}

class UpgradeSpec {
  final UpgradeType type;
  final String title;
  final String description;
  final int maxRank;
  final int baseCost;
  final IconData icon;
  final Color color;
  const UpgradeSpec(
    this.type,
    this.title,
    this.description,
    this.maxRank,
    this.baseCost,
    this.icon,
    this.color,
  );

  static const all = [
    UpgradeSpec(
      UpgradeType.damage,
      'Rèn sắc',
      'Tăng 12% sát thương gốc mỗi bậc cho mọi đòn đánh.',
      15,
      50,
      Icons.colorize,
      Color(0xFFFFA085),
    ),
    UpgradeSpec(
      UpgradeType.speed,
      'Nhịp chiến đấu',
      'Tăng 12% nhịp bắn, phóng móc và sát thương cận chiến mỗi bậc.',
      8,
      55,
      Icons.speed,
      Color(0xFF85DBC8),
    ),
    UpgradeSpec(
      UpgradeType.range,
      'Tầm kiểm soát',
      'Tăng tầm quét; tên xuyên thêm mỗi 2 bậc, móc câu vươn xa hơn.',
      6,
      65,
      Icons.open_in_full,
      Color(0xFFF1C587),
    ),
    UpgradeSpec(
      UpgradeType.bounce,
      'Lướt nảy',
      'Tăng tốc độ bóng 8% mỗi bậc, có giới hạn để dễ điều khiển.',
      6,
      45,
      Icons.sports_volleyball,
      Color(0xFFB2D88C),
    ),
    UpgradeSpec(
      UpgradeType.magnet,
      'Thu hoạch',
      'Tăng 22 đơn vị bán kính hút mỗi bậc.',
      6,
      40,
      Icons.all_out,
      Color(0xFFBCA5EB),
    ),
    UpgradeSpec(
      UpgradeType.spin,
      'Vũ điệu vũ khí',
      'Tăng 18% tốc xoay mỗi bậc; quét tới khối tiếp theo nhanh hơn.',
      8,
      50,
      Icons.cyclone,
      Color(0xFF8CC9E9),
    ),
    UpgradeSpec(
      UpgradeType.spirit,
      'Tinh linh hộ vệ',
      'Thêm một vệ tinh; chia đều quỹ đạo, tối đa 4 tinh linh.',
      4,
      100,
      Icons.blur_circular,
      Color(0xFFA5DCE8),
    ),
    UpgradeSpec(
      UpgradeType.resonance,
      'Tinh thông nguyên tố',
      'Tăng 10% sát thương nguyên tố mỗi bậc, giữ nguyên tỉ lệ kích hoạt.',
      6,
      70,
      Icons.auto_awesome,
      Color(0xFFD5ABE9),
    ),
  ];

  static UpgradeSpec of(UpgradeType type) => all[type.index];
}
