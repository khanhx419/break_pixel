import 'package:flutter/material.dart';

class MemeLevel {
  final int id;
  final String title;
  final String memeName;
  final int cols;
  final int rows;
  final List<List<Color>> colorGrid;

  const MemeLevel({
    required this.id,
    required this.title,
    required this.memeName,
    required this.cols,
    required this.rows,
    required this.colorGrid,
  });

  static List<MemeLevel> get allLevels => [
        _createDogeLevel(),
        _createPepeLevel(),
        _createPopcatLevel(),
      ];

  /// Level 1: Doge Pixel Meme (14x14 Chunky Grid)
  static MemeLevel _createDogeLevel() {
    const y = Color(0xFFE8B858); // Doge Gold Fur
    const w = Color(0xFFF6E7C8); // White Muzzle
    const b = Color(0xFF2A1C0E); // Dark Brown / Eyes / Nose
    const r = Color(0xFFD3524B); // Tongue
    const g = Color(0xFF4A752C); // Background Grass / Sky
    const t = Color(0xFF5D9CEC); // Sky Blue

    final grid = [
      [t, t, t, y, y, t, t, t, y, y, t, t, t, t],
      [t, t, y, y, y, y, t, y, y, y, y, t, t, t],
      [t, y, y, y, y, y, y, y, y, y, y, y, t, t],
      [t, y, y, b, y, y, y, y, y, b, y, y, t, t],
      [y, y, y, b, y, y, y, y, y, b, y, y, y, t],
      [y, y, y, y, y, w, w, w, y, y, y, y, y, t],
      [y, y, y, y, w, b, b, b, w, y, y, y, y, t],
      [y, y, y, y, w, w, b, w, w, y, y, y, y, t],
      [t, y, y, y, y, w, r, w, y, y, y, y, t, t],
      [t, y, y, y, y, w, w, w, y, y, y, y, t, t],
      [t, t, y, y, y, y, y, y, y, y, y, t, t, t],
      [t, t, t, y, y, y, y, y, y, y, t, t, t, t],
      [g, g, g, g, y, y, y, y, y, g, g, g, g, g],
      [g, g, g, g, g, g, g, g, g, g, g, g, g, g],
    ];

    return MemeLevel(
      id: 1,
      title: 'Màn 1: Cổng Không Gian Doge',
      memeName: 'Shiba Doge',
      cols: 14,
      rows: 14,
      colorGrid: grid,
    );
  }

  /// Level 2: Pepe the Frog (14x14 Chunky Grid)
  static MemeLevel _createPepeLevel() {
    const k = Color(0xFF6AAA36); // Pepe Green
    const d = Color(0xFF467822); // Pepe Dark Green
    const w = Color(0xFFFFFFFF); // White Eyes
    const b = Color(0xFF1B1B1B); // Black Pupil / Lips
    const r = Color(0xFFB82E2E); // Red Lips
    const s = Color(0xFF3B4A68); // Dark Background

    final grid = [
      [s, s, k, k, k, s, s, s, s, k, k, k, s, s],
      [s, k, w, w, b, k, s, s, k, w, w, b, k, s],
      [s, k, w, b, b, k, k, k, k, w, b, b, k, s],
      [k, k, k, k, k, k, k, k, k, k, k, k, k, k],
      [k, k, k, k, k, k, k, k, k, k, k, k, k, k],
      [k, k, d, d, d, d, d, d, d, d, d, d, k, k],
      [k, d, r, r, r, r, r, r, r, r, r, r, d, k],
      [k, d, r, b, b, b, b, b, b, b, b, r, d, k],
      [k, k, r, r, r, r, r, r, r, r, r, r, k, k],
      [s, k, k, d, d, d, d, d, d, d, d, k, k, s],
      [s, s, k, k, k, k, k, k, k, k, k, k, s, s],
      [s, s, s, k, k, k, k, k, k, k, k, s, s, s],
      [s, s, s, Color(0xFF1F5C8B), Color(0xFF1F5C8B), Color(0xFF1F5C8B), Color(0xFF1F5C8B), Color(0xFF1F5C8B), Color(0xFF1F5C8B), Color(0xFF1F5C8B), Color(0xFF1F5C8B), s, s, s],
      [s, s, Color(0xFF1F5C8B), Color(0xFF1F5C8B), Color(0xFF1F5C8B), Color(0xFF1F5C8B), Color(0xFF1F5C8B), Color(0xFF1F5C8B), Color(0xFF1F5C8B), Color(0xFF1F5C8B), Color(0xFF1F5C8B), Color(0xFF1F5C8B), s, s],
    ];

    return MemeLevel(
      id: 2,
      title: 'Màn 2: Cổ Vật Pepe',
      memeName: 'Pepe The Frog',
      cols: 14,
      rows: 14,
      colorGrid: grid,
    );
  }

  /// Level 3: Popcat (14x14 Chunky Grid)
  static MemeLevel _createPopcatLevel() {
    const o = Color(0xFFF3D5A5); // Cat Fur
    const p = Color(0xFFE8B682); // Cat Shadow
    const b = Color(0xFF221608); // Eyes / Nose
    const m = Color(0xFF6B1D2F); // Wide Open Mouth
    const t = Color(0xFFD64D62); // Mouth Inside
    const bg = Color(0xFF202028); // Dark Space Background

    final grid = [
      [bg, bg, o, o, bg, bg, bg, bg, bg, bg, o, o, bg, bg],
      [bg, o, o, o, o, bg, bg, bg, bg, o, o, o, o, bg],
      [bg, o, o, p, o, o, o, o, o, o, p, o, o, bg],
      [o, o, o, o, o, o, o, o, o, o, o, o, o, o],
      [o, o, b, b, o, o, o, o, o, o, b, b, o, o],
      [o, o, b, b, o, o, o, o, o, o, b, b, o, o],
      [o, o, o, o, o, o, b, b, o, o, o, o, o, o],
      [o, o, o, m, m, m, m, m, m, m, m, o, o, o],
      [o, o, m, t, t, t, t, t, t, t, t, m, o, o],
      [o, o, m, t, t, t, t, t, t, t, t, m, o, o],
      [o, o, m, t, t, t, t, t, t, t, t, m, o, o],
      [bg, o, o, m, m, m, m, m, m, m, m, o, o, bg],
      [bg, bg, o, o, o, o, o, o, o, o, o, o, bg, bg],
      [bg, bg, bg, o, o, o, o, o, o, o, o, bg, bg, bg],
    ];

    return MemeLevel(
      id: 3,
      title: 'Màn 3: Trùm Cuối Popcat (Mở Khóa Yeti)',
      memeName: 'Pop Cat',
      cols: 14,
      rows: 14,
      colorGrid: grid,
    );
  }
}
