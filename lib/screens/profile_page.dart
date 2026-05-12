import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_page.dart';
import '../widgets/avatar_frame_utils.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;

  late AnimationController _bgController;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  late AnimationController _vipPulseController;
  late Animation<double> _vipPulseAnimation;

  bool _showAllBadges = false;

  final List<String> _avatarOptions = [
    'Katherine', 'Sarah', 'Jude', 'Liliana',
    'Avery', 'Oliver', 'Ryan', 'Brian',
    'Max', 'Coco', 'Sky', 'Leo'
  ];

  // ── 30 Rozet Tanımı ───────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> _badgeDefs = [
    // ─ Giriş Serisi ─
    {
      'id': 'streak_3',
      'name': '3 Gün Seri',
      'desc': '3 gün üst üste giriş yap',
      'emoji': '🔥',
      'color': Color(0xFFFF5252),
      'trackField': 'loginStreak',
      'threshold': 3,
      'category': 'Seri',
    },
    {
      'id': 'streak_7',
      'name': '7 Gün Seri',
      'desc': '7 gün üst üste giriş yap',
      'emoji': '🔥',
      'color': Color(0xFFFF6D00),
      'trackField': 'loginStreak',
      'threshold': 7,
      'category': 'Seri',
    },
    {
      'id': 'streak_14',
      'name': '2 Hafta Seri',
      'desc': '14 gün üst üste giriş yap',
      'emoji': '⚡',
      'color': Color(0xFFFFD600),
      'trackField': 'loginStreak',
      'threshold': 14,
      'category': 'Seri',
    },
    {
      'id': 'streak_30',
      'name': 'Aylık Şampiyon',
      'desc': '30 gün üst üste giriş yap',
      'emoji': '🏆',
      'color': Color(0xFFFFAB00),
      'trackField': 'loginStreak',
      'threshold': 30,
      'category': 'Seri',
    },
    {
      'id': 'streak_60',
      'name': 'Efsane Seri',
      'desc': '60 gün üst üste giriş yap',
      'emoji': '🌋',
      'color': Color(0xFFFF1744),
      'trackField': 'loginStreak',
      'threshold': 60,
      'category': 'Seri',
    },

    // ─ Doğru Cevap ─
    {
      'id': 'correct_10',
      'name': 'İlk Adım',
      'desc': '10 doğru cevap ver',
      'emoji': '✅',
      'color': Color(0xFF00E676),
      'trackField': 'totalCorrect',
      'threshold': 10,
      'category': 'Doğru',
    },
    {
      'id': 'correct_50',
      'name': 'Başarı Yolu',
      'desc': '50 doğru cevap ver',
      'emoji': '🎯',
      'color': Color(0xFF00BFA5),
      'trackField': 'totalCorrect',
      'threshold': 50,
      'category': 'Doğru',
    },
    {
      'id': 'correct_100',
      'name': 'Keskin Nişancı',
      'desc': '100 doğru cevap ver',
      'emoji': '🏹',
      'color': Color(0xFF00E5FF),
      'trackField': 'totalCorrect',
      'threshold': 100,
      'category': 'Doğru',
    },
    {
      'id': 'correct_250',
      'name': 'Bilgi Ustası',
      'desc': '250 doğru cevap ver',
      'emoji': '🧠',
      'color': Color(0xFF448AFF),
      'trackField': 'totalCorrect',
      'threshold': 250,
      'category': 'Doğru',
    },
    {
      'id': 'correct_500',
      'name': 'Soru Avcısı',
      'desc': '500 doğru cevap ver',
      'emoji': '💎',
      'color': Color(0xFF7C4DFF),
      'trackField': 'totalCorrect',
      'threshold': 500,
      'category': 'Doğru',
    },
    {
      'id': 'correct_1000',
      'name': 'Yenilmez',
      'desc': '1000 doğru cevap ver',
      'emoji': '👑',
      'color': Color(0xFFFFD700),
      'trackField': 'totalCorrect',
      'threshold': 1000,
      'category': 'Doğru',
    },

    // ─ Bölüm ─
    {
      'id': 'section_1',
      'name': 'İlk Adım',
      'desc': 'İlk bölümünü tamamla',
      'emoji': '🚀',
      'color': Color(0xFF69F0AE),
      'trackField': 'totalSections',
      'threshold': 1,
      'category': 'Bölüm',
    },
    {
      'id': 'section_5',
      'name': 'Hızlı Başlangıç',
      'desc': '5 bölüm tamamla',
      'emoji': '📚',
      'color': Color(0xFF40C4FF),
      'trackField': 'totalSections',
      'threshold': 5,
      'category': 'Bölüm',
    },
    {
      'id': 'section_20',
      'name': 'Kitap Kurdu',
      'desc': '20 bölüm tamamla',
      'emoji': '📖',
      'color': Color(0xFFE040FB),
      'trackField': 'totalSections',
      'threshold': 20,
      'category': 'Bölüm',
    },
    {
      'id': 'section_50',
      'name': 'Maratoncu',
      'desc': '50 bölüm tamamla',
      'emoji': '🏃',
      'color': Color(0xFFFF6E40),
      'trackField': 'totalSections',
      'threshold': 50,
      'category': 'Bölüm',
    },
    {
      'id': 'section_100',
      'name': 'Sınav Tanrısı',
      'desc': '100 bölüm tamamla',
      'emoji': '⚡',
      'color': Color(0xFFFFD740),
      'trackField': 'totalSections',
      'threshold': 100,
      'category': 'Bölüm',
    },

    // ─ XP ─
    {
      'id': 'xp_100',
      'name': 'Başlangıç',
      'desc': '100 XP kazan',
      'emoji': '⭐',
      'color': Color(0xFFFFF176),
      'trackField': 'totalXp',
      'threshold': 100,
      'category': 'XP',
    },
    {
      'id': 'xp_500',
      'name': 'Parlayan Yıldız',
      'desc': '500 XP kazan',
      'emoji': '🌟',
      'color': Color(0xFFFFD54F),
      'trackField': 'totalXp',
      'threshold': 500,
      'category': 'XP',
    },
    {
      'id': 'xp_1000',
      'name': 'XP Canavarı',
      'desc': '1000 XP kazan',
      'emoji': '💥',
      'color': Color(0xFFFF9100),
      'trackField': 'totalXp',
      'threshold': 1000,
      'category': 'XP',
    },
    {
      'id': 'xp_5000',
      'name': 'Efsanevi',
      'desc': '5000 XP kazan',
      'emoji': '🔮',
      'color': Color(0xFFD500F9),
      'trackField': 'totalXp',
      'threshold': 5000,
      'category': 'XP',
    },
    {
      'id': 'xp_10000',
      'name': 'Ölümsüz',
      'desc': '10000 XP kazan',
      'emoji': '🌌',
      'color': Color(0xFF6200EA),
      'trackField': 'totalXp',
      'threshold': 10000,
      'category': 'XP',
    },

    // ─ Günlük ─
    {
      'id': 'daily_done',
      'name': 'Günlük Kahraman',
      'desc': 'Tüm günlük görevleri tamamla',
      'emoji': '🎖️',
      'color': Color(0xFF00BCD4),
      'trackField': 'dailyAllDone',
      'threshold': 1,
      'category': 'Görev',
    },
    {
      'id': 'weekly_done',
      'name': 'Haftalık Şampiyon',
      'desc': 'Tüm haftalık görevleri tamamla',
      'emoji': '🏅',
      'color': Color(0xFF8BC34A),
      'trackField': 'weeklyAllDone',
      'threshold': 1,
      'category': 'Görev',
    },

    // ─ Özel ─
    {
      'id': 'night_owl',
      'name': 'Gece Kuşu',
      'desc': 'Gece 00:00-06:00 arası giriş yap',
      'emoji': '🦉',
      'color': Color(0xFF5C6BC0),
      'trackField': 'nightOwl',
      'threshold': 1,
      'category': 'Özel',
    },
    {
      'id': 'early_bird',
      'name': 'Sabahın Ereni',
      'desc': 'Sabah 06:00-08:00 arası giriş yap',
      'emoji': '🌅',
      'color': Color(0xFFFF7043),
      'trackField': 'earlyBird',
      'threshold': 1,
      'category': 'Özel',
    },
    {
      'id': 'ad_watcher',
      'name': 'Destekçi',
      'desc': '10 reklam izle',
      'emoji': '📺',
      'color': Color(0xFF26C6DA),
      'trackField': 'totalAds',
      'threshold': 10,
      'category': 'Özel',
    },
    {
      'id': 'invite_friend',
      'name': 'Sosyal Kelebek',
      'desc': 'Bir arkadaşını davet et',
      'emoji': '👥',
      'color': Color(0xFFEC407A),
      'trackField': 'invitedFriends',
      'threshold': 1,
      'category': 'Özel',
    },
    {
      'id': 'rate_app',
      'name': 'Uygulama Dostu',
      'desc': 'Uygulamayı değerlendir',
      'emoji': '⭐',
      'color': Color(0xFFFFC107),
      'trackField': 'ratedApp',
      'threshold': 1,
      'category': 'Özel',
    },
    {
      'id': 'perfect_day',
      'name': 'Mükemmel Gün',
      'desc': 'Günde 50 doğru cevap ver',
      'emoji': '💯',
      'color': Color(0xFF76FF03),
      'trackField': 'dailyCorrect',
      'threshold': 50,
      'category': 'Özel',
    },
    {
      'id': 'league_gold',
      'name': 'Altın Lig',
      'desc': 'Altın Ligi\'ne yüksel',
      'emoji': '🥇',
      'color': Color(0xFFFFD700),
      'trackField': 'leagueLevel',
      'threshold': 3,
      'category': 'Lig',
    },
    {
      'id': 'league_diamond',
      'name': 'Elmas Lig',
      'desc': 'Elmas Ligi\'ne yüksel',
      'emoji': '💎',
      'color': Color(0xFF80DEEA),
      'trackField': 'leagueLevel',
      'threshold': 5,
      'category': 'Lig',
    },
  ];

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
    _vipPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _vipPulseAnimation = Tween<double>(begin: 0.3, end: 0.85).animate(
      CurvedAnimation(parent: _vipPulseController, curve: Curves.easeInOut),
    );

    // Gece kuşu / sabahın ereni kontrolü
    _checkTimeBasedBadges();
  }

  Future<void> _checkTimeBasedBadges() async {
    if (user == null) return;
    final hour = DateTime.now().hour;
    final uid = user!.uid;
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    if (hour >= 0 && hour < 6) {
      await ref.set({'nightOwl': 1}, SetOptions(merge: true));
    } else if (hour >= 6 && hour < 8) {
      await ref.set({'earlyBird': 1}, SetOptions(merge: true));
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _floatController.dispose();
    _vipPulseController.dispose();
    super.dispose();
  }

  void _showAvatarSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1F6A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 500,
        child: Column(
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text('Robotunu Seç', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 15, mainAxisSpacing: 15),
                itemCount: _avatarOptions.length,
                itemBuilder: (context, index) {
                  final seed = _avatarOptions[index];
                  return GestureDetector(
                    onTap: () async {
                      if (user != null) {
                        final nav = Navigator.of(context);
                        await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'avatarSeed': seed});
                        if (!mounted) return;
                    nav.pop();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white24)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          'https://api.dicebear.com/9.x/bottts-neutral/png?seed=$seed',
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, chunk) => chunk == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        ),
                      ),
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

  // Rozet detay popup
  void _showBadgeDetail(Map<String, dynamic> badge, bool unlocked, int current) {
    final color = badge['color'] as Color;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1F6A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: unlocked ? color : Colors.white24, width: 2),
            boxShadow: unlocked ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 4)] : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(badge['emoji'], style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 10),
              Text(
                badge['name'],
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(badge['category'], style: GoogleFonts.poppins(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Text(badge['desc'], style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              if (!unlocked) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (current / (badge['threshold'] as int)).clamp(0.0, 1.0),
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text('$current / ${badge['threshold']}', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 16),
              ],
              if (unlocked) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
                    const SizedBox(width: 6),
                    Text('Kazanıldı!', style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: unlocked ? color : Colors.white12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text('Tamam', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLeagueSheet(int totalXp, String currentLeague) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1F6A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        final leagues = [
          {
            'name': 'Bronz',
            'min': 0,
            'max': 499,
            'color': const Color(0xFF8D6E63),
          },
          {
            'name': 'Gümüş',
            'min': 500,
            'max': 1499,
            'color': const Color(0xFFB0BEC5),
          },
          {
            'name': 'Altın',
            'min': 1500,
            'max': 3499,
            'color': const Color(0xFFFFD54F),
          },
          {
            'name': 'Platin',
            'min': 3500,
            'max': 6999,
            'color': const Color(0xFFB39DDB),
          },
          {
            'name': 'Elmas',
            'min': 7000,
            'max': 11999,
            'color': const Color(0xFF80DEEA),
          },
          {
            'name': 'Şampiyon',
            'min': 12000,
            'max': 19999,
            'color': const Color(0xFFFFAB91),
          },
          {
            'name': 'Efsane',
            'min': 20000,
            'max': null,
            'color': const Color(0xFFFFF176),
          },
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Lig Sistemi',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Toplam XP\'ine göre ligler otomatik belirlenir.',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Toplam XP: $totalXp  •  Şu an: $currentLeague Ligi',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF00E5FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: leagues.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final lg = leagues[index];
                    final String name = lg['name'] as String;
                    final int min = lg['min'] as int;
                    final int? max = lg['max'] as int?;
                    final Color color = lg['color'] as Color;
                    final bool isCurrent = currentLeague == name;

                    final String rangeText = max == null
                        ? '$min+ XP'
                        : '$min - $max XP';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.22),
                            color.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrent
                              ? color.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.12),
                          width: isCurrent ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  color,
                                  color.withValues(alpha: 0.2),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$name Ligi',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  rangeText,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.9),
                                ),
                              ),
                              child: Text(
                                'Şu Anki Lig',
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
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
        );
      },
    );
  }

  void _showFrameSelectionSheet(int currentFrame) {
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1F6A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'VIP Çerçeveni Seç',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Seçtiğin çerçeve profil resminin göründüğü her yerde uygulanacak.',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 140,
                child: GridView.builder(
                  scrollDirection: Axis.horizontal,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: kVipAvatarFrames.length,
                  itemBuilder: (context, index) {
                    final frame = kVipAvatarFrames[index];
                    final bool isSelected = index == currentFrame;
                    return GestureDetector(
                      onTap: () async {
                        final nav = Navigator.of(context);
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user!.uid)
                            .set({'avatarFrame': index}, SetOptions(merge: true));
                        if (mounted) nav.pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? frame.glowColor
                                : Colors.white.withValues(alpha: 0.15),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    ...frame.colors,
                                    frame.colors.first,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: frame.glowColor.withValues(alpha: 0.5),
                                    blurRadius: 14,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF1B1F6A),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white70,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              frame.name,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF152C5B), Color(0xFF223A70), Color(0xFF5A189A)],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          ..._buildStaticStars(size),
          _buildMovingCloud(top: size.height * 0.05, scale: 1.2, speed: 0.8, moveRight: true),
          _buildMovingCloud(top: size.height * 0.4, scale: 0.9, speed: 0.5, moveRight: false),

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
            builder: (context, snapshot) {
              int totalXp = 0;
              String league = 'Bronz';
              String? avatarSeed;
              Map<String, dynamic> userData = {};
              bool isVip = false;
              int avatarFrame = 0;

              if (snapshot.hasData && snapshot.data!.exists) {
                userData = snapshot.data!.data() as Map<String, dynamic>;
                totalXp = (userData['totalXp'] ?? 0).toInt();
                league = userData['league'] ?? 'Bronz';
                avatarSeed = userData['avatarSeed'];
                isVip = userData['isVip'] ?? false;
                final dynamic frameRaw = userData['avatarFrame'] ?? 0;
                if (frameRaw is int) avatarFrame = frameRaw;
              }

              final int unlockedCount = _badgeDefs.where((b) {
                int val = (userData[b['trackField']] ?? 0).toInt();
                return val >= (b['threshold'] as int);
              }).length;

              return SafeArea(
                child: Column(
                  children: [
                    // AppBar
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Text('Profilim',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        clipBehavior: Clip.none,
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            AnimatedBuilder(
                              animation: _floatAnimation,
                              builder: (context, child) => Transform.translate(
                                offset: Offset(0, _floatAnimation.value),
                                child: _buildAvatarSection(totalXp, league, avatarSeed, isVip, avatarFrame),
                              ),
                            ),
                            const SizedBox(height: 30),
                            _buildLevelBar(totalXp),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _showLeagueSheet(totalXp, league),
                                    child: _buildStatBox('Lig', league, Icons.emoji_events_rounded, Colors.cyanAccent),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(child: _buildStatBox('Toplam Puan', '${(totalXp / 1000).toStringAsFixed(1)}K', Icons.bolt_rounded, Colors.amber)),
                              ],
                            ),
                            const SizedBox(height: 30),

                            // ── Kupa Odası Başlık ──────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('🏆 Kupa Odası', style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    '$unlockedCount / ${_badgeDefs.length}',
                                    style: GoogleFonts.poppins(color: const Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Rozete tıklayarak detayları gör',
                                  style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _showAllBadges = !_showAllBadges;
                                    });
                                  },
                                  child: Text(
                                    _showAllBadges ? 'Daha Az Göster' : 'Tümünü Göster',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF00E5FF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Kategori grupları
                            ..._buildCategoryGroups(userData),

                            _buildLogoutButton(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Kategoriye göre grupla ─────────────────────────────────────────────────
  List<Widget> _buildCategoryGroups(Map<String, dynamic> userData) {
    final categories = <String>[];
    for (final b in _badgeDefs) {
      final cat = b['category'] as String;
      if (!categories.contains(cat)) categories.add(cat);
    }

    return categories.map((cat) {
      final catBadges = _badgeDefs.where((b) => b['category'] == cat).toList();
      final visibleBadges = _showAllBadges
          ? catBadges
          : (catBadges.length <= 3 ? catBadges : catBadges.sublist(0, 3));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _categoryLabel(cat),
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: visibleBadges.length,
            itemBuilder: (context, index) {
              final badge = visibleBadges[index];
              final int current = (userData[badge['trackField']] ?? 0).toInt();
              final bool unlocked = current >= (badge['threshold'] as int);
              return _buildBadgeCard(badge, unlocked, current);
            },
          ),
          const SizedBox(height: 24),
        ],
      );
    }).toList();
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'Seri': return '🔥 GİRİŞ SERİSİ';
      case 'Doğru': return '✅ DOĞRU CEVAP';
      case 'Bölüm': return '📚 BÖLÜM';
      case 'XP': return '⭐ XP';
      case 'Görev': return '🎯 GÖREVLER';
      case 'Özel': return '🌟 ÖZEL';
      case 'Lig': return '🏅 LİG';
      default: return cat.toUpperCase();
    }
  }

  // ── Rozet Kartı ───────────────────────────────────────────────────────────
  Widget _buildBadgeCard(Map<String, dynamic> badge, bool unlocked, int current) {
    final color = badge['color'] as Color;
    final threshold = badge['threshold'] as int;
    final progress = (current / threshold).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => _showBadgeDetail(badge, unlocked, current),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: unlocked ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unlocked ? color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
            width: unlocked ? 1.5 : 1,
          ),
          boxShadow: unlocked
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12, spreadRadius: 1)]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji veya kilit
              unlocked
                  ? Text(badge['emoji'], style: const TextStyle(fontSize: 30))
                  : const Icon(Icons.lock_rounded, color: Colors.white24, size: 28),
              const SizedBox(height: 6),
              Text(
                badge['name'],
                style: GoogleFonts.poppins(
                  color: unlocked ? Colors.white : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // İlerleme çubuğu (kilitliyse)
              if (!unlocked)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.6)),
                    minHeight: 4,
                  ),
                ),
              if (unlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('✓ Kazanıldı', style: GoogleFonts.poppins(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Avatar bölümü — VIP: animasyonlu nefes alan çerçeve, Normal: mor/mavi daire
  Widget _buildAvatarSection(int xp, String league, String? avatarSeed, bool isVip, int avatarFrame) {
    final rawName = user?.displayName ?? '';
    final displayName = rawName.isNotEmpty ? rawName : 'Pilot';
    final initial = displayName[0].toUpperCase();

    final Widget innerAvatar = avatarSeed != null
        ? Image.network(
            'https://api.dicebear.com/9.x/bottts-neutral/png?seed=$avatarSeed',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Center(
              child: Text(initial,
                  style: const TextStyle(
                      fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        : Center(
            child: Text(initial,
                style: const TextStyle(
                    fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold)));

    Widget ringWidget;
    final frameData = getVipAvatarFrame(avatarFrame);
    if (isVip) {
      ringWidget = AnimatedBuilder(
        animation: _vipPulseAnimation,
        builder: (context, child) {
          return Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  ...frameData.colors,
                  frameData.colors.first,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: frameData.glowColor
                      .withValues(alpha: _vipPulseAnimation.value),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration:
                  const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1B1F6A)),
              child: ClipOval(child: innerAvatar),
            ),
          );
        },
      );
    } else {
      ringWidget = Container(
        width: 124,
        height: 124,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFFD500F9)]),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                blurRadius: 18,
                spreadRadius: 2),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration:
              const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1B1F6A)),
          child: ClipOval(child: innerAvatar),
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _showAvatarSelectionSheet,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              ringWidget,
              Positioned(
                bottom: 4, right: 4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD500F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: const Color(0xFFD500F9).withValues(alpha: 0.5), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              ),
              if (isVip)
                Positioned(
                  top: -20,
                  child: Text(
                    '👑',
                    style: TextStyle(
                      fontSize: 28,
                      shadows: [Shadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.9),
                          blurRadius: 16)],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Şampiyon $displayName',
                style: GoogleFonts.poppins(
                    color: isVip ? const Color(0xFFFFD700) : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isVip) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD700)),
                ),
                child: Text('VIP',
                    style: GoogleFonts.poppins(
                        color: const Color(0xFFFFD700),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        if (isVip)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00E5FF),
              ),
              onPressed: () => _showFrameSelectionSheet(avatarFrame),
              icon: const Icon(Icons.style_rounded, size: 16),
              label: Text(
                'Çerçeve Seç',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text('🚀 $league Ligi Oyuncusu',
            style: GoogleFonts.poppins(
                color: const Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
  Widget _buildLevelBar(int xp) {
    double progress = (xp % 100) / 100;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Seviye ${(xp / 100).floor()}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              Text('Seviye ${(xp / 100).floor() + 1}', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFFD500F9)), minHeight: 12)),
          const SizedBox(height: 10),
          Text('${100 - (xp % 100)} XP sonra seviye atlayacaksın!', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.15))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: InkWell(
        onTap: () async {
          await FirebaseAuth.instance.signOut();
          if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthPage()), (route) => false);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
          decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
            const SizedBox(width: 10),
            Text('Hesaptan Çıkış Yap', style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }

  List<Widget> _buildStaticStars(Size size) {
    final rand = Random(42);
    return List.generate(30, (_) => Positioned(
      left: rand.nextDouble() * size.width,
      top: rand.nextDouble() * size.height,
      child: Icon(Icons.star, size: rand.nextDouble() * 4 + 2, color: Colors.white.withValues(alpha: 0.3)),
    ));
  }

  Widget _buildMovingCloud({required double top, required double scale, required double speed, required bool moveRight}) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final cloudWidth = 150.0 * scale;
        double offset = (_bgController.value * speed * (screenWidth + cloudWidth)) % (screenWidth + cloudWidth);
        if (!moveRight) offset = screenWidth - offset;
        return Positioned(top: top, left: offset - cloudWidth, child: Transform.scale(scale: scale, child: Icon(Icons.cloud_rounded, color: Colors.white.withValues(alpha: 0.10), size: 100)));
      },
    );
  }
}