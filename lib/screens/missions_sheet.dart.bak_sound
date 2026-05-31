import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/mission_service.dart';

/// Ana ekranda çağırma:
/// MissionsSheet.show(context);
class MissionsSheet {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => const _MissionsSheetContent(),
    );
  }
}

class _MissionsSheetContent extends StatefulWidget {
  const _MissionsSheetContent();

  @override
  State<_MissionsSheetContent> createState() =>
      _MissionsSheetContentState();
}

class _MissionsSheetContentState extends State<_MissionsSheetContent>
    with TickerProviderStateMixin {
  final String?        _uid     = FirebaseAuth.instance.currentUser?.uid;
  final MissionService _service = MissionService();

  late TabController       _tabController;
  late AnimationController _entryController;
  late Animation<double>   _slideAnim;
  late Animation<double>   _fadeAnim;

  List<Mission>            _daily        = [];
  List<Mission>            _weekly       = [];
  List<AchievementMission> _achievements = [];
  List<OneTimeMission>     _onetime      = [];
  UserModel?               _userModel;
  bool                     _loading      = true;
  // Haftalık tüm görev bonus durumu
  bool                     _allWeeklyBonusClaimed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _entryController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<double>(begin: 80, end: 0).animate(
      CurvedAnimation(
          parent: _entryController, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  // ── Tüm verileri yükle ───────────────────────────────────────────────
  Future<void> _loadAll() async {
    final uid = _uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      // Paralel yükleme — hız optimizasyonu
      final results = await Future.wait([
        _service.getDailyMissions(uid),
        _service.getWeeklyMissions(uid),
        _service.getAchievements(uid),
        _service.getOneTimeMissions(uid),
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
      ]);

      // Haftalık bonus durumunu da çek
      final weekKey = _weekKey();
      bool allBonusClaimed = false;
      try {
        final weekDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('weekly_missions')
            .doc(weekKey)
            .get();
        allBonusClaimed =
            weekDoc.data()?['allBonusClaimed'] == true;
      } catch (_) {}

      final userDoc = results[4] as DocumentSnapshot;
      UserModel? model;
      if (userDoc.exists) {
        model = UserModel.fromMap(
            userDoc.data() as Map<String, dynamic>, userDoc.id);
      }

      if (!mounted) return;
      setState(() {
        _daily        = results[0] as List<Mission>;
        _weekly       = results[1] as List<Mission>;
        _achievements = results[2] as List<AchievementMission>;
        _onetime      = results[3] as List<OneTimeMission>;
        _userModel    = model;
        _allWeeklyBonusClaimed = allBonusClaimed;
        _loading      = false;
      });
      _entryController.forward();
    } catch (e) {
      debugPrint('Görev yükleme hatası: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      _entryController.forward();
    }
  }

  /// Türkiye saatine göre hafta başı anahtarı
  String _weekKey() {
    final now    = DateTime.now().toUtc().add(const Duration(hours: 3));
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  // ── Görev ilerlemesi ─────────────────────────────────────────────────
  /// `ratedApp` gibi UserModel'de karşılığı olmayan track field'lar
  /// için 0 döner — bu `manualClaim: true` olan görevler için doğru
  /// davranıştır (kullanıcı butona basarak talep eder).
  int _getProgress(Mission m) {
    final model = _userModel;
    if (model == null) return 0;

    switch (m.trackField) {
      case 'dailyCorrect':   return model.dailyCorrect;
      case 'dailyQuestions': return model.dailyQuestions;
      case 'dailySections':  return model.dailySections;
      case 'dailyAds':       return model.dailyAds;
      case 'dailyLogin':     return model.dailyLogin;
      case 'weeklyCorrect':  return model.weeklyCorrect;
      case 'weeklySections': return model.weeklySections;
      case 'weeklyAds':      return model.weeklyAds;
      case 'loginStreak':    return model.loginStreak;
      case 'totalSections':  return model.totalSections;
      case 'totalCorrect':   return model.totalCorrect;
      // 'ratedApp' ve bilinmeyen alanlar — manualClaim görevleri için 0
      default: return 0;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: AnimatedBuilder(
        animation: _entryController,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child:  Opacity(opacity: _fadeAnim.value, child: child),
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(35)),
            gradient: const LinearGradient(
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
              colors: [
                Color(0xFF0D1B4B),
                Color(0xFF0A0E43),
                Color(0xFF1A0A3B),
              ],
            ),
            border: Border(
              top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5),
            ),
          ),
          child: Column(children: [
            _buildHandle(),
            _buildHeader(),
            _buildEnergyBar(),
            _buildTabBar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFFF9100)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDailyTab(),
                        _buildWeeklyTab(),
                        _buildAchievementsTab(),
                        _buildOneTimeTab(),
                      ],
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Tutamaç ───────────────────────────────────────────────────────────
  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Center(
        child: Container(
          width: 45, height: 5,
          decoration: BoxDecoration(
            color:        Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  // ── Başlık + yenile ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(children: [
        const Text('⚡', style: TextStyle(fontSize: 26)),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Görevler',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  color:      Colors.white,
                  fontSize:   22,
                  fontWeight: FontWeight.bold)),
        ),
        GestureDetector(
          onTap: () {
            setState(() => _loading = true);
            _entryController.reset();
            _loadAll();
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:        Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.refresh_rounded,
                color: Colors.white54, size: 18),
          ),
        ),
      ]),
    );
  }

  // ── Enerji Barı ───────────────────────────────────────────────────────
  Widget _buildEnergyBar() {
    final model = _userModel;
    if (model == null) return const SizedBox.shrink();

    final int    main   = model.energy;
    final int    max    = model.maxEnergy;
    final int    bonus  = model.bonusEnergy;
    final double ratio  = max > 0
        ? (main / max).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin:  const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.bolt_rounded,
                        color: Colors.yellowAccent, size: 16),
                    const SizedBox(width: 4),
                    Text('Temel Enerji  $main/$max',
                        style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(
                          Colors.yellowAccent),
                      minHeight: 7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF00E5FF)
                        .withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.card_giftcard_rounded,
                        color: Color(0xFF00E5FF), size: 14),
                    const SizedBox(width: 5),
                    Text('+$bonus',
                        style: GoogleFonts.poppins(
                            color: const Color(0xFF00E5FF),
                            fontSize: 13,
                            fontWeight: FontWeight.w900)),
                  ]),
                  Text('Bonus Enerji',
                      style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 9,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: Colors.white38, size: 13),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Bonus enerji görev ve reklamlardan gelir; testlerde önce bonus, sonra ana enerji kullanılır.',
                style: GoogleFonts.poppins(
                    color: Colors.white38, fontSize: 10, height: 1.25),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller:          _tabController,
        indicator: BoxDecoration(
          color:        const Color(0xFFFF6B00).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize:          TabBarIndicatorSize.tab,
        dividerColor:           Colors.transparent,
        labelColor:             Colors.white,
        unselectedLabelColor:   Colors.white38,
        labelStyle:             GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.bold),
        unselectedLabelStyle:   GoogleFonts.poppins(fontSize: 10),
        tabs: const [
          Tab(text: 'Günlük'),
          Tab(text: 'Haftalık'),
          Tab(text: 'Başarım'),
          Tab(text: 'Tekli'),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // TAB İÇERİKLERİ
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildDailyTab() {
    final int completed = _daily
        .where((m) => m.isClaimed || _getProgress(m) >= m.targetCount)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _buildSectionInfo(
          '🗓️ Günlük Görevler',
          "Her gece 00:00'da yenilenir • Harika ödüller seni bekliyor!",
          completed: completed,
          total:     _daily.length,
        ),
        const SizedBox(height: 12),
        ..._daily.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildMissionCard(
            mission: m,
            current: _getProgress(m),
            onClaim: () => _onClaimDaily(m),
          ),
        )),
      ],
    );
  }

  Widget _buildWeeklyTab() {
    final int completed = _weekly
        .where((m) => m.isClaimed || _getProgress(m) >= m.targetCount)
        .length;
    final bool allDone =
        completed == _weekly.length && _weekly.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _buildSectionInfo(
          '📅 Haftalık Görevler',
          'Her Pazartesi sıfırlanır'
          ' • Tümünü bitirene +10 Enerji!',
          completed: completed,
          total:     _weekly.length,
        ),
        // Tüm görevler tamamlandıysa bonus banner
        if (allDone) ...[
          const SizedBox(height: 10),
          _buildAllWeeklyBonusBanner(),
        ],
        const SizedBox(height: 12),
        ..._weekly.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildMissionCard(
            mission: m,
            current: _getProgress(m),
            onClaim: () => _onClaimWeekly(m),
          ),
        )),
      ],
    );
  }

  Widget _buildAchievementsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _buildSectionInfo(
          '🏆 Uzun Vadeli Başarımlar',
          'Kalıcı rozetler, çerçeveler ve devasa XP kazanın',
        ),
        const SizedBox(height: 12),
        ..._achievements.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildAchievementCard(a),
        )),
      ],
    );
  }

  Widget _buildOneTimeTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _buildSectionInfo(
          '🎁 Tek Seferlik Görevler',
          'Bir kez tamamlanır, kalıcı bonus enerji kazandırır',
        ),
        const SizedBox(height: 12),
        ..._onetime.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildOneTimeMissionCard(m),
        )),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // YARDIMCI WIDGET'LAR
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildSectionInfo(String title, String subtitle,
      {int? completed, int? total}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    color:      Colors.white,
                    fontSize:   14,
                    fontWeight: FontWeight.bold)),
          ),
          if (completed != null && total != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: completed == total
                    ? Colors.greenAccent.withValues(alpha: 0.15)
                    : const Color(0xFFFF6B00).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$completed/$total',
                  style: GoogleFonts.poppins(
                      color: completed == total
                          ? Colors.greenAccent
                          : const Color(0xFFFF9100),
                      fontSize:   12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        const SizedBox(height: 3),
        Text(subtitle,
            style: GoogleFonts.poppins(
                color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  // ── Görev Kartı (günlük / haftalık) ───────────────────────────────────
  Widget _buildMissionCard({
    required Mission       mission,
    required int           current,
    required VoidCallback  onClaim,
  }) {
    final bool   isDone   = current >= mission.targetCount;
    final double progress =
        (current / mission.targetCount).clamp(0.0, 1.0);

    Color borderColor;
    Color progressColor;

    if (mission.isClaimed) {
      borderColor   = Colors.greenAccent.withValues(alpha: 0.4);
      progressColor = Colors.greenAccent;
    } else if (isDone) {
      borderColor   = const Color(0xFFFF9100).withValues(alpha: 0.6);
      progressColor = const Color(0xFFFF9100);
    } else {
      borderColor   = Colors.white.withValues(alpha: 0.08);
      progressColor = const Color(0xFF00E5FF);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(color: borderColor, width: 1.2),
        boxShadow: isDone && !mission.isClaimed
            ? [
                BoxShadow(
                    color: const Color(0xFFFF9100)
                        .withValues(alpha: 0.1),
                    blurRadius:   10,
                    spreadRadius: 1)
              ]
            : [],
      ),
      child: Row(children: [
        // İkon
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              progressColor.withValues(alpha: 0.2),
              progressColor.withValues(alpha: 0.05),
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: progressColor.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(mission.icon,
                style: const TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(width: 14),

        // İçerik
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mission.title,
                  style: GoogleFonts.poppins(
                      color:      Colors.white,
                      fontSize:   14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(mission.description,
                  style: GoogleFonts.poppins(
                      color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 6),

              // Ödül chip'leri — xpReward doğrudan mission'dan geliyor
              _buildRewardChips(
                  mission.bonusEnergyReward, mission.xpReward),
              const SizedBox(height: 10),

              // İlerleme barı
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value:           progress,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(
                          progressColor),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$current / ${mission.targetCount}',
                    style: GoogleFonts.poppins(
                        color:      Colors.white54,
                        fontSize:   9,
                        fontWeight: FontWeight.w600)),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 10),

        _buildRewardButton(
          isClaimed:    mission.isClaimed,
          isDone:       isDone,
          energyReward: mission.bonusEnergyReward,
          onClaim:      onClaim,
        ),
      ]),
    );
  }

  // ── Başarım Kartı ─────────────────────────────────────────────────────
  Widget _buildAchievementCard(AchievementMission achievement) {
    final int    current  = _getProgress(achievement);
    final bool   isDone   =
        current >= achievement.targetCount;
    final double progress =
        (current / achievement.targetCount).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: achievement.isClaimed
              ? Colors.greenAccent.withValues(alpha: 0.4)
              : isDone
                  ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFFFFD700)
                    .withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(achievement.icon,
                style: const TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(achievement.title,
                    style: GoogleFonts.poppins(
                        color:      Colors.white,
                        fontSize:   14,
                        fontWeight: FontWeight.bold)),
                // Rozet ve çerçeve ikonları
                if (achievement.badge != null) ...[
                  const SizedBox(width: 6),
                  const Text('🎖️',
                      style: TextStyle(fontSize: 14)),
                ],
                if (achievement.avatarFrame != null) ...[
                  const SizedBox(width: 4),
                  const Text('🖼️',
                      style: TextStyle(fontSize: 14)),
                ],
              ]),
              Text(achievement.description,
                  style: GoogleFonts.poppins(
                      color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 6),

              // Ödül chip'leri
              _buildRewardChips(achievement.bonusEnergyReward,
                  achievement.xpReward),
              const SizedBox(height: 10),

              // İlerleme barı
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value:           progress,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(
                        achievement.isClaimed
                            ? Colors.greenAccent
                            : const Color(0xFFFFD700),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$current / ${achievement.targetCount}',
                    style: GoogleFonts.poppins(
                        color:      Colors.white54,
                        fontSize:   10,
                        fontWeight: FontWeight.w600)),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 10),

        _buildRewardButton(
          isClaimed:    achievement.isClaimed,
          isDone:       isDone,
          energyReward: achievement.bonusEnergyReward,
          onClaim:      () => _onClaimAchievement(achievement),
        ),
      ]),
    );
  }

  // ── Tek Seferlik Görev Kartı ──────────────────────────────────────────
  Widget _buildOneTimeMissionCard(OneTimeMission mission) {
    final int  current = _getProgress(mission);
    // manualClaim görevler her zaman "tamamlandı" sayılır —
    // kullanıcı butona basarak talep eder
    final bool isDone  =
        mission.manualClaim || current >= mission.targetCount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: mission.isClaimed
              ? Colors.greenAccent.withValues(alpha: 0.4)
              : const Color(0xFFD500F9).withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFD500F9).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFFD500F9)
                    .withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(mission.icon,
                style: const TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mission.title,
                  style: GoogleFonts.poppins(
                      color:      Colors.white,
                      fontSize:   14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(mission.description,
                  style: GoogleFonts.poppins(
                      color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 6),

              _buildRewardChips(
                  mission.bonusEnergyReward, mission.xpReward),

              // Manuel onay notu
              if (mission.manualClaim)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Manuel onay gerekli',
                      style: GoogleFonts.poppins(
                          color: const Color(0xFFD500F9)
                              .withValues(alpha: 0.7),
                          fontSize: 10)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        _buildRewardButton(
          isClaimed:    mission.isClaimed,
          isDone:       isDone,
          energyReward: mission.bonusEnergyReward,
          onClaim:      () => _onClaimOneTime(mission),
        ),
      ]),
    );
  }

  // ── Ödül Chip'leri ────────────────────────────────────────────────────
  /// Enerji ve XP değerlerini doğrudan gösterir.
  /// Eski kodda `bonusEnergyReward * 4` hesabı yanlıştı —
  /// artık `xpReward` doğrudan mission'dan geliyor.
  Widget _buildRewardChips(int energy, int xp) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (energy > 0)
          _chip(
            icon:  Icons.flash_on_rounded,
            color: Colors.orangeAccent,
            label: '+$energy Enerji',
          ),
        if (xp > 0)
          _chip(
            icon:  Icons.star_rounded,
            color: const Color(0xFF00E5FF),
            label: '+$xp XP',
          ),
      ],
    );
  }

  Widget _chip({
    required IconData icon,
    required Color    color,
    required String   label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 2),
        Text(label,
            style: GoogleFonts.poppins(
                color:      color,
                fontSize:   10,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ── Ödül Butonu ───────────────────────────────────────────────────────
  Widget _buildRewardButton({
    required bool         isClaimed,
    required bool         isDone,
    required int          energyReward,
    required VoidCallback onClaim,
  }) {
    if (isClaimed) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:  Colors.greenAccent.withValues(alpha: 0.15),
          shape:  BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded,
            color: Colors.greenAccent, size: 20),
      );
    }

    if (isDone) {
      return GestureDetector(
        onTap: onClaim,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFFF6B00), Color(0xFFFF9100)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFFF9100)
                      .withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset:     const Offset(0, 4)),
            ],
          ),
          child: Column(children: [
            const Text('⚡', style: TextStyle(fontSize: 16)),
            Text('AL',
                style: GoogleFonts.poppins(
                    color:      Colors.white,
                    fontSize:   12,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      );
    }

    // Kilitli
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(children: [
        const Icon(Icons.lock_rounded,
            color: Colors.white30, size: 16),
        const SizedBox(height: 2),
        Text('Kilitli',
            style: GoogleFonts.poppins(
                color: Colors.white30, fontSize: 10)),
      ]),
    );
  }

  // ── Haftalık Tüm Görev Bonus Banner ──────────────────────────────────
  Widget _buildAllWeeklyBonusBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFFFD700).withValues(alpha: 0.15),
          const Color(0xFFFF9100).withValues(alpha: 0.15),
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Text('🎉', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
/*************  ✨ Windsurf Command ⭐  *************/
  /// Claim a daily mission and show a reward popup if successful.
  ///
  /// If the user is not logged in, this function does nothing.
  ///
  /// If the claim is successful, it shows a reward popup with the bonus
  /// energy reward and its quadruple value. It also marks the mission as
  /// claimed in the state.
  ///
/*******  7b1657c2-733f-409d-a2fa-27b41c7275c5  *******/              children: [
            Text(
              _allWeeklyBonusClaimed
                  ? 'Haftalık Bonus Alındı! ✅'
                  : 'Tüm Haftalık Görevler Tamamlandı!',
              style: GoogleFonts.poppins(
                  color:      const Color(0xFFFFD700),
                  fontSize:   14,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _allWeeklyBonusClaimed
                  ? 'Tebrikler! +10 Bonus Enerji hesabına eklendi.'
                  : 'Harikasın! Ekstra +10 enerji ödülün hesabına eklendi.',
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 11),
            ),
          ]),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // CLAIM İŞLEMLERİ — başarı sonrası local state güncellenir
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onClaimDaily(Mission mission) async {
    final uid = _uid;
    if (uid == null) return;

    final bool success =
        await _service.claimDailyMission(uid, mission);
    if (!success || !mounted) return;

    _showRewardPopup(mission.bonusEnergyReward, mission.xpReward);
    // Local state güncelle — Firestore'a tekrar gitmeye gerek yok
    setState(() {
      final idx = _daily.indexWhere((m) => m.id == mission.id);
      if (idx != -1) _daily[idx].isClaimed = true;
    });
  }

  Future<void> _onClaimWeekly(Mission mission) async {
    final uid = _uid;
    if (uid == null) return;

    final bool success =
        await _service.claimWeeklyMission(uid, mission);
    if (!success || !mounted) return;

    _showRewardPopup(mission.bonusEnergyReward, mission.xpReward);
    setState(() {
      final idx = _weekly.indexWhere((m) => m.id == mission.id);
      if (idx != -1) _weekly[idx].isClaimed = true;

      // Tüm haftalık görevler tamamlandıysa banner güncelle
      final allClaimed = _weekly.every((m) => m.isClaimed);
      if (allClaimed) _allWeeklyBonusClaimed = true;
    });
  }

  Future<void> _onClaimAchievement(
      AchievementMission achievement) async {
    final uid = _uid;
    if (uid == null) return;

    final bool success =
        await _service.claimAchievement(uid, achievement);
    if (!success || !mounted) return;

    _showRewardPopup(
      achievement.bonusEnergyReward,
      achievement.xpReward,
      extra: achievement.badge != null
          ? '🎖️ Yeni rozet kazandın!'
          : achievement.avatarFrame != null
              ? '🖼️ Yeni çerçeve kazandın!'
              : null,
    );
    setState(() {
      final idx =
          _achievements.indexWhere((a) => a.id == achievement.id);
      if (idx != -1) _achievements[idx].isClaimed = true;
    });
  }

  Future<void> _onClaimOneTime(OneTimeMission mission) async {
    final uid = _uid;
    if (uid == null) return;

    final bool success =
        await _service.claimOneTimeMission(uid, mission);
    if (!success || !mounted) return;

    _showRewardPopup(mission.bonusEnergyReward, mission.xpReward);
    setState(() {
      final idx = _onetime.indexWhere((m) => m.id == mission.id);
      if (idx != -1) _onetime[idx].isClaimed = true;
    });
  }

  // ── Ödül Popup ────────────────────────────────────────────────────────
  void _showRewardPopup(int energy, int xp, {String? extra}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color:        const Color(0xFF1B1F6A),
            borderRadius: BorderRadius.circular(28),
            border:       Border.all(
                color: const Color(0xFFFF9100), width: 2),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFFF9100)
                      .withValues(alpha: 0.3),
                  blurRadius:   24,
                  spreadRadius: 4),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎁', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 14),
              Text('Ödül Alındı!',
                  style: GoogleFonts.poppins(
                      color:      Colors.white,
                      fontSize:   22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              if (energy > 0)
                Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                  const Icon(Icons.flash_on_rounded,
                      color: Colors.orangeAccent),
                  const SizedBox(width: 8),
                  Text('+$energy Enerji',
                      style: GoogleFonts.poppins(
                          color:      Colors.orangeAccent,
                          fontSize:   18,
                          fontWeight: FontWeight.bold)),
                ]),

              if (energy > 0 && xp > 0)
                const SizedBox(height: 8),

              if (xp > 0)
                Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFF00E5FF)),
                  const SizedBox(width: 8),
                  Text('+$xp XP',
                      style: GoogleFonts.poppins(
                          color:      const Color(0xFF00E5FF),
                          fontSize:   18,
                          fontWeight: FontWeight.bold)),
                ]),

              if (extra != null) ...[
                const SizedBox(height: 12),
                Text(extra,
                    style: GoogleFonts.poppins(
                        color:    Colors.white70,
                        fontSize: 14),
                    textAlign: TextAlign.center),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9100),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text('Harika! 🙌',
                    style: GoogleFonts.poppins(
                        color:      Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize:   16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}