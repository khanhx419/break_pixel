import 'package:flutter/material.dart';
import 'ecs.dart';

class ElementData {
  final ElementType type;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isFusion;
  final List<ElementType>? ingredients;

  const ElementData({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.isFusion = false,
    this.ingredients,
  });

  static const List<ElementData> baseElements = [
    ElementData(
      type: ElementType.fire,
      name: 'Hỏa (Fire)',
      description: 'Thiêu đốt pixel, gây sát thương liên tục và nổ lan tàn lửa.',
      icon: Icons.local_fire_department,
      color: Colors.deepOrangeAccent,
    ),
    ElementData(
      type: ElementType.water,
      name: 'Thủy (Water)',
      description: 'Làm ướt pixel, dẫn truyền điện trường và tăng độ lan tỏa.',
      icon: Icons.water_drop,
      color: Colors.blueAccent,
    ),
    ElementData(
      type: ElementType.wind,
      name: 'Phong (Wind)',
      description: 'Tăng tốc độ xoay vũ khí, phóng lưỡi đao gió chém xuyên khối.',
      icon: Icons.air,
      color: Colors.tealAccent,
    ),
    ElementData(
      type: ElementType.lightning,
      name: 'Lôi (Lightning)',
      description: 'Phóng tia sét giật cực nhanh, gây sát thương tức thời.',
      icon: Icons.bolt,
      color: Colors.amberAccent,
    ),
    ElementData(
      type: ElementType.earth,
      name: 'Địa (Earth)',
      description: 'Gia tăng trọng lực cú nảy, gây chấn động nứt vỡ khối xung quanh.',
      icon: Icons.landscape,
      color: Colors.brown,
    ),
    ElementData(
      type: ElementType.frost,
      name: 'Băng (Frost)',
      description: 'Đông cứng khối pixel, giảm khả năng chống chịu khiến pixel giòn x1.5 sát thương.',
      icon: Icons.ac_unit,
      color: Colors.cyanAccent,
    ),
    ElementData(
      type: ElementType.poison,
      name: 'Độc (Poison)',
      description: 'Tiết dịch độc ăn mòn HP theo thời gian và lây lan sang các khối tiếp giáp.',
      icon: Icons.coronavirus,
      color: Colors.lightGreenAccent,
    ),
    ElementData(
      type: ElementType.voidDark,
      name: 'Bóng Tối (Void)',
      description: 'Tạo lực hút vi mô kéo dồn các khối pixel về tâm quỹ đạo.',
      icon: Icons.brightness_3,
      color: Colors.purpleAccent,
    ),
  ];

  static const List<ElementData> fusionElements = [
    ElementData(
      type: ElementType.mist,
      name: 'Sương Mù (Mist)',
      description: 'Hỏa + Thủy: Tạo màn sương mù bao phủ, gây sát thương DoT ăn mòn liên tục diện rộng.',
      icon: Icons.cloud,
      color: Colors.blueGrey,
      isFusion: true,
      ingredients: [ElementType.fire, ElementType.water],
    ),
    ElementData(
      type: ElementType.chainLightning,
      name: 'Nhiễm Điện (Chain Lightning)',
      description: 'Thủy + Lôi: Phóng tia sét lan truyền qua 6-10 khối pixel lân cận trong chớp mắt.',
      icon: Icons.electric_bolt,
      color: Colors.yellowAccent,
      isFusion: true,
      ingredients: [ElementType.water, ElementType.lightning],
    ),
    ElementData(
      type: ElementType.firestorm,
      name: 'Bão Lửa (Firestorm)',
      description: 'Hỏa + Phong: Lốc xoáy lửa cuộn quanh bóng, thiêu rụi dải pixel trên đường đi.',
      icon: Icons.cyclone,
      color: Colors.orange,
      isFusion: true,
      ingredients: [ElementType.fire, ElementType.wind],
    ),
    ElementData(
      type: ElementType.permafrost,
      name: 'Băng Vĩnh Cửu (Permafrost)',
      description: 'Thủy + Băng: Đóng băng tức thì cụm pixel, đòn đánh kế tiếp vỡ vụn x2 sát thương.',
      icon: Icons.severe_cold,
      color: Colors.cyan,
      isFusion: true,
      ingredients: [ElementType.water, ElementType.frost],
    ),
    ElementData(
      type: ElementType.superconductor,
      name: 'Siêu Dẫn (Superconductor)',
      description: 'Băng + Lôi: Phóng điện trường lạnh nổ lan cực mạnh, bỏ qua lớp phòng thủ của pixel cứng.',
      icon: Icons.flash_on,
      color: Colors.lightBlueAccent,
      isFusion: true,
      ingredients: [ElementType.frost, ElementType.lightning],
    ),
    ElementData(
      type: ElementType.avalanche,
      name: 'Lở Tuyết (Avalanche)',
      description: 'Băng + Địa: Cú va chạm tạo sóng lở đá tuyết nghiền nát nguyên một hàng pixel.',
      icon: Icons.snowing,
      color: Colors.white70,
      isFusion: true,
      ingredients: [ElementType.frost, ElementType.earth],
    ),
    ElementData(
      type: ElementType.explosiveGas,
      name: 'Khí Nổ (Explosive Gas)',
      description: 'Độc + Hỏa: Tạo đám mây độc bốc cháy nổ tung diện rộng khi có tia lửa va chạm.',
      icon: Icons.warning_amber,
      color: Colors.limeAccent,
      isFusion: true,
      ingredients: [ElementType.poison, ElementType.fire],
    ),
    ElementData(
      type: ElementType.acidMelt,
      name: 'Axit Ăn Mòn (Acid Melt)',
      description: 'Độc + Thủy: Nước axit làm tan chảy thanh HP của các khối pixel cứng đầu nhất.',
      icon: Icons.science,
      color: Colors.greenAccent,
      isFusion: true,
      ingredients: [ElementType.poison, ElementType.water],
    ),
    ElementData(
      type: ElementType.voidVortex,
      name: 'Hố Đen Lôi Đình (Void Vortex)',
      description: 'Bóng Tối + Lôi: Hút tụ các khối pixel xung quanh về tâm rồi phóng sét tiêu diệt.',
      icon: Icons.all_inclusive,
      color: Colors.deepPurpleAccent,
      isFusion: true,
      ingredients: [ElementType.voidDark, ElementType.lightning],
    ),
    ElementData(
      type: ElementType.lavaBurst,
      name: 'Dung Nham (Lava Burst)',
      description: 'Hỏa + Địa: Khối vỡ bắn ra các tàn nham làm tan chảy các khối pixel xung quanh.',
      icon: Icons.volcano,
      color: Colors.redAccent,
      isFusion: true,
      ingredients: [ElementType.fire, ElementType.earth],
    ),
  ];

  static ElementData? findFusion(ElementType a, ElementType b) {
    for (final fusion in fusionElements) {
      final ingredients = fusion.ingredients;
      if (ingredients != null && ingredients.length == 2) {
        if ((ingredients[0] == a && ingredients[1] == b) ||
            (ingredients[0] == b && ingredients[1] == a)) {
          return fusion;
        }
      }
    }
    return null;
  }
}
