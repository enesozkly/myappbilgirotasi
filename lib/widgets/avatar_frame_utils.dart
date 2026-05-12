import 'package:flutter/material.dart';

/// VIP kullanıcılar için profil çerçevesi tanımı
class AvatarFrameData {
  final String id;
  final String name;
  final List<Color> colors;
  final Color glowColor;

  const AvatarFrameData({
    required this.id,
    required this.name,
    required this.colors,
    required this.glowColor,
  });
}

/// Kullanılabilir VIP çerçeveleri
const List<AvatarFrameData> kVipAvatarFrames = [
  AvatarFrameData(
    id: 'gold_aura',
    name: 'Altın Aura',
    colors: [Color(0xFFFFD700), Color(0xFFFFF59D), Color(0xFFFF8F00)],
    glowColor: Color(0xFFFFD700),
  ),
  AvatarFrameData(
    id: 'neon_blue',
    name: 'Neon Mavi',
    colors: [Color(0xFF00E5FF), Color(0xFF2979FF), Color(0xFF00C4FF)],
    glowColor: Color(0xFF00E5FF),
  ),
  AvatarFrameData(
    id: 'royal_purple',
    name: 'Kraliyet Moru',
    colors: [Color(0xFFD500F9), Color(0xFF7C4DFF), Color(0xFF651FFF)],
    glowColor: Color(0xFFD500F9),
  ),
  AvatarFrameData(
    id: 'inferno',
    name: 'Cehennem Ateşi',
    colors: [Color(0xFFFF6D00), Color(0xFFFF1744), Color(0xFFFF9100)],
    glowColor: Color(0xFFFF3D00),
  ),
  AvatarFrameData(
    id: 'emerald',
    name: 'Zümrüt',
    colors: [Color(0xFF00E676), Color(0xFF00C853), Color(0xFF1DE9B6)],
    glowColor: Color(0xFF00E676),
  ),
  AvatarFrameData(
    id: 'ice',
    name: 'Buz Kristali',
    colors: [Color(0xFFB3E5FC), Color(0xFFE1F5FE), Color(0xFF81D4FA)],
    glowColor: Color(0xFFB3E5FC),
  ),
  AvatarFrameData(
    id: 'cosmic',
    name: 'Kozmik',
    colors: [Color(0xFF536DFE), Color(0xFFAB47BC), Color(0xFF26C6DA)],
    glowColor: Color(0xFF7E57C2),
  ),
  AvatarFrameData(
    id: 'shadow',
    name: 'Gölge',
    colors: [Color(0xFF263238), Color(0xFF455A64), Color(0xFF000000)],
    glowColor: Color(0xFF90A4AE),
  ),
];

/// Geçerli index yoksa güvenli şekilde ilk çerçeveyi döndürür.
AvatarFrameData getVipAvatarFrame(int index) {
  if (index < 0 || index >= kVipAvatarFrames.length) {
    return kVipAvatarFrames.first;
  }
  return kVipAvatarFrames[index];
}

