import 'package:flutter/material.dart';

enum RoleType {
  warrior,    // Chiến binh: Kiếm xoay chém diện rộng
  archer,     // Cung thủ: Cung xoay bắn tên tầm xa
  farmer,     // Nông dân: Liềm gặt quét cung, bội thu vàng/exp
  lumberjack, // Tiều phu: Rìu bổ nặng, phá khối cứng cực mạnh
  fisherman,  // Người đánh cá: Cần câu & Lao cá, kéo dồn pixel & sóng nước
}

enum RaceType {
  human,      // Người: Cân bằng, +15% EXP
  elf,        // Elf: Tốc độ vũ khí +25%, buff hệ Phong
  orc,        // Orc: Sát thương va chạm +40%
  dwarf,      // Người lùn: Giảm 25% giá lò rèn, +30% vàng rơi
  merfolk,    // Người cá: Nảy lướt trơn tru, làm ẩm pixel (combo Thủy/Lôi)
  yeti,       // Yeti (Người tuyết): Khối lượng nặng, bóng to +25%, Frost Aura làm đông cứng & giòn pixel
}

class RoleInfo {
  final RoleType type;
  final String name;
  final String description;
  final String weaponName;
  final IconData icon;
  final Color themeColor;
  final double baseDamage;
  final double attackSpeed;
  final double weaponRange;

  const RoleInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.weaponName,
    required this.icon,
    required this.themeColor,
    required this.baseDamage,
    required this.attackSpeed,
    required this.weaponRange,
  });

  static const List<RoleInfo> allRoles = [
    RoleInfo(
      type: RoleType.warrior,
      name: 'Chiến Binh',
      description: 'Vung thanh đại kiếm xoay tròn liên tục quét sạch các mảng pixel cận chiến.',
      weaponName: 'Đại Kiếm Xoay',
      icon: Icons.shield,
      themeColor: Colors.amber,
      baseDamage: 12.0,
      attackSpeed: 1.0,
      weaponRange: 55.0,
    ),
    RoleInfo(
      type: RoleType.archer,
      name: 'Cung Thủ',
      description: 'Tự động xoay và bắn liên hoàn các mũi tên tầm xa xuyên thấu các khối pixel.',
      weaponName: 'Cung Tên Phong Vũ',
      icon: Icons.gps_fixed,
      themeColor: Colors.greenAccent,
      baseDamage: 8.0,
      attackSpeed: 1.6,
      weaponRange: 180.0,
    ),
    RoleInfo(
      type: RoleType.farmer,
      name: 'Nông Dân',
      description: 'Vung liềm gặt quét theo vòng cung rộng. Nội tại "Bội Thu" tăng 25% Vàng và EXP thu hoạch.',
      weaponName: 'Liềm Gặt Mùa Màng',
      icon: Icons.agriculture,
      themeColor: Colors.orangeAccent,
      baseDamage: 10.0,
      attackSpeed: 1.1,
      weaponRange: 65.0,
    ),
    RoleInfo(
      type: RoleType.lumberjack,
      name: 'Tiều Phu',
      description: 'Cầm rìu đốn củi hạng nặng. Mỗi cú bổ đập tan nát các khối pixel cứng chỉ sau 1 đòn.',
      weaponName: 'Rìu Bổ Củi Hạng Nặng',
      icon: Icons.carpenter,
      themeColor: Colors.brown,
      baseDamage: 22.0,
      attackSpeed: 0.7,
      weaponRange: 50.0,
    ),
    RoleInfo(
      type: RoleType.fisherman,
      name: 'Người Đánh Cá',
      description: 'Phóng cần câu giật kéo các khối pixel lại gần và tạo đợt sóng nước đẩy lùi.',
      weaponName: 'Cần Câu & Lao Cá',
      icon: Icons.phishing,
      themeColor: Colors.cyanAccent,
      baseDamage: 11.0,
      attackSpeed: 1.2,
      weaponRange: 75.0,
    ),
  ];
}

class RaceInfo {
  final RaceType type;
  final String name;
  final String description;
  final String passiveName;
  final IconData icon;
  final Color themeColor;
  final bool isSecret;
  final double damageMultiplier;
  final double speedMultiplier;
  final double bounceBonus;
  final double expBonus;
  final double goldBonus;
  final double shopDiscount;
  final double ballSizeBonus;

  const RaceInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.passiveName,
    required this.icon,
    required this.themeColor,
    this.isSecret = false,
    this.damageMultiplier = 1.0,
    this.speedMultiplier = 1.0,
    this.bounceBonus = 0.0,
    this.expBonus = 0.0,
    this.goldBonus = 0.0,
    this.shopDiscount = 0.0,
    this.ballSizeBonus = 0.0,
  });

  static const List<RaceInfo> allRaces = [
    RaceInfo(
      type: RaceType.human,
      name: 'Người (Human)',
      description: 'Cân bằng mọi chỉ số, thích nghi nhanh chóng với thế giới mới.',
      passiveName: 'Toàn Diện (+10% Stats, +15% EXP)',
      icon: Icons.person,
      themeColor: Colors.blueAccent,
      damageMultiplier: 1.1,
      speedMultiplier: 1.1,
      expBonus: 0.15,
    ),
    RaceInfo(
      type: RaceType.elf,
      name: 'Tinh Linh (Elf)',
      description: 'Thân thủ nhanh nhẹn, tinh thông tốc độ và hệ Gió.',
      passiveName: 'Linh Hoạt (+25% Tốc đánh, +30% Hệ Phong)',
      icon: Icons.park,
      themeColor: Colors.tealAccent,
      speedMultiplier: 1.25,
    ),
    RaceInfo(
      type: RaceType.orc,
      name: 'Orc',
      description: 'Sức mạnh cơ bắp khủng khiếp, va đập hủy diệt.',
      passiveName: 'Cuồng Nộ (+40% Lực va chạm & Sát thương cận chiến)',
      icon: Icons.fitness_center,
      themeColor: Colors.redAccent,
      damageMultiplier: 1.4,
    ),
    RaceInfo(
      type: RaceType.dwarf,
      name: 'Người Lùn (Dwarf)',
      description: 'Bậc thầy luyện kim và tìm vàng từ lòng đất.',
      passiveName: 'Thợ Rèn Lão Luyện (Giảm 25% giá Lò rèn, +30% Vàng)',
      icon: Icons.hardware,
      themeColor: Colors.amberAccent,
      goldBonus: 0.30,
      shopDiscount: 0.25,
    ),
    RaceInfo(
      type: RaceType.merfolk,
      name: 'Người Cá (Merfolk)',
      description: 'Bơi lướt trơn tru, đòn đánh tự động làm ẩm pixel kích hoạt combo Thủy.',
      passiveName: 'Dòng Chảy Biển (+20% Lướt nảy, Đòn đánh Làm Ướt)',
      icon: Icons.water,
      themeColor: Colors.lightBlueAccent,
      bounceBonus: 0.20,
    ),
    RaceInfo(
      type: RaceType.yeti,
      name: 'Yeti (Người Tuyết Cổ Đại)',
      description: 'Quái vật tuyết khổng lồ. Bóng cực nặng càn quét mảng pixel, Frost Aura đóng băng & làm giòn khối.',
      passiveName: 'Băng Thể (+25% Kích cỡ bóng, Frost Aura, +35% Hệ Băng)',
      icon: Icons.ac_unit,
      themeColor: Colors.lightBlue,
      isSecret: true,
      ballSizeBonus: 0.25,
      damageMultiplier: 1.35,
    ),
  ];
}
