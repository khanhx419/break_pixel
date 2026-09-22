import 'dart:ui';
import 'package:flutter/material.dart';

/// Thuộc tính biến đổi không gian (Vị trí, Vận tốc, Kích thước, Góc quay)
class TransformComponent {
  double x;
  double y;
  double vx;
  double vy;
  double width;
  double height;
  double rotation; // radians

  TransformComponent({
    this.x = 0,
    this.y = 0,
    this.vx = 0,
    this.vy = 0,
    this.width = 28,
    this.height = 28,
    this.rotation = 0,
  });

  Offset get position => Offset(x, y);
  set position(Offset pos) {
    x = pos.dx;
    y = pos.dy;
  }

  Rect get rect => Rect.fromCenter(
        center: Offset(x, y),
        width: width,
        height: height,
      );
}

/// Thuộc tính Máu và Độ bền
class HealthComponent {
  double maxHp;
  double currentHp;
  bool isDestroyed;

  HealthComponent({
    required this.maxHp,
    double? currentHp,
    this.isDestroyed = false,
  }) : currentHp = currentHp ?? maxHp;

  bool takeDamage(double dmg) {
    if (isDestroyed) return false;
    currentHp -= dmg;
    if (currentHp <= 0) {
      currentHp = 0;
      isDestroyed = true;
      return true; // vừa mới bị tiêu diệt
    }
    return false;
  }

  double get hpPercent => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
}

/// Các trạng thái nguyên tố tác động lên thực thể
enum ElementType {
  none,
  fire,       // Hỏa
  water,      // Thủy
  wind,       // Phong
  lightning,  // Lôi
  earth,      // Địa
  frost,      // Băng
  poison,     // Độc
  voidDark,   // Bóng Tối
  // Các hệ Dung Hợp (Fusion)
  mist,          // Sương Mù (Hỏa + Thủy)
  chainLightning,// Nhiễm Điện (Thủy + Lôi)
  firestorm,     // Bão Lửa (Hỏa + Phong)
  permafrost,    // Băng Vĩnh Cửu (Thủy + Băng)
  superconductor,// Siêu Dẫn (Băng + Lôi)
  avalanche,     // Lở Tuyết (Băng + Địa)
  explosiveGas,  // Khí Nổ (Độc + Hỏa)
  acidMelt,      // Axit Ăn Mòn (Độc + Thủy)
  voidVortex,    // Hố Đen Lôi Đình (Bóng Tối + Lôi)
  lavaBurst,     // Dung Nham (Hỏa + Địa)
}

/// Thuộc tính tương tác nguyên tố
class ElementAffinityComponent {
  double burnTimer = 0;      // Thời gian bị cháy
  double burnDps = 0;
  bool isSoaked = false;     // Đang bị ướt
  double soakedTimer = 0;
  bool isFrozen = false;     // Đang bị đóng băng (giòn, x1.5-x2 damage)
  double frozenTimer = 0;
  double poisonTimer = 0;    // Bị nhiễm độc
  double poisonDps = 0;
  double shockTimer = 0;     // Bị giật điện / nhiễm sét

  void applyFire(double duration, double dps) {
    burnTimer = duration;
    burnDps = dps;
    if (isFrozen) {
      isFrozen = false;
      frozenTimer = 0;
    }
  }

  void applyWater(double duration) {
    isSoaked = true;
    soakedTimer = duration;
    burnTimer = 0; // Nước dập tắt lửa
  }

  void applyFrost(double duration) {
    isFrozen = true;
    frozenTimer = duration;
    burnTimer = 0;
  }

  void applyPoison(double duration, double dps) {
    poisonTimer = duration;
    poisonDps = dps;
  }

  void applyShock(double duration) {
    shockTimer = duration;
  }

  void update(double dt) {
    if (burnTimer > 0) burnTimer -= dt;
    if (soakedTimer > 0) {
      soakedTimer -= dt;
      if (soakedTimer <= 0) isSoaked = false;
    }
    if (frozenTimer > 0) {
      frozenTimer -= dt;
      if (frozenTimer <= 0) isFrozen = false;
    }
    if (poisonTimer > 0) poisonTimer -= dt;
    if (shockTimer > 0) shockTimer -= dt;
  }
}

/// Thuộc tính hiển thị (Render)
class RenderComponent {
  Color primaryColor;
  Color? borderColor;
  double opacity;
  bool isGlowing;

  RenderComponent({
    required this.primaryColor,
    this.borderColor,
    this.opacity = 1.0,
    this.isGlowing = false,
  });
}

/// Lớp gốc GameEntity kết nối toàn bộ thuộc tính chung theo ECS Pattern
abstract class GameEntity {
  final String id;
  final TransformComponent transform;
  HealthComponent? health;
  ElementAffinityComponent? elementAffinity;
  RenderComponent? render;

  GameEntity({
    required this.id,
    required this.transform,
    this.health,
    this.elementAffinity,
    this.render,
  });

  void update(double dt);
  void draw(Canvas canvas, Paint paint);
}
