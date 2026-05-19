// ignore_for_file: unused_element

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/widget_sync_service.dart';
import 'subjects_page.dart';
import 'mistake_box_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'net_calculator_page.dart';
import '../models/user_model.dart';
import '../services/mission_service.dart';
import 'leaderboard_page.dart';
import 'multiplayer_lobby_page.dart';
import 'streak_calendar_sheet.dart';
import 'missions_sheet.dart';
import 'admin_panel_page.dart';
import 'vip_statistics_page.dart';
import '../services/energy_service.dart';
import '../services/reklam_servisi.dart';
import '../widgets/avatar_frame_utils.dart';
import '../widgets/br_dialogs.dart';
import 'store_page.dart';
import 'exam_trials_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  late AnimationController _bgController;
  StreamSubscription? _notifSub;
  StreamSubscription? _userNotifSub;
  bool _showYksCountdown = true;
  bool _notificationDialogOpen = false;

  // Stream'den gelen güncel veriler — tek kaynak
  UserModel? _userModel;
  bool _isAdmin = false;
  bool _isVip = false;
  String? _avatarSeed;
  int _avatarFrame = 0;
  int _energy = 50;
  int _maxEnergy = 50;
  int _bonusEnergy = 0;
  String _displayName = 'Şampiyon';
  String _level = '1';

  // Ana ekran widget'ını aynı veriyle tekrar tekrar güncellememek için
  // son gönderilen değerlerin imzasını tutuyoruz.
  String? _lastWidgetSyncSignature;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    if (user != null) {
      MissionService().recordDailyLogin(user!.uid);
      EnergyService().regenEnergy(user!.uid);
      _checkVipExpiry(user!.uid);
      // Günlük aktif kullanıcı takibi için lastLoginDate güncelle
      FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'lastLoginDate': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }
    _listenForNewNotifications();
  }

  Future<void> _checkVipExpiry(String uid) async {
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      final doc = await ref.get();
      final data = doc.data();
      if (data == null) return;
      final expiresAt = data['vipExpiresAt'];
      if (data['isVip'] == true &&
          expiresAt is Timestamp &&
          expiresAt.toDate().isBefore(DateTime.now())) {
        await ref.set({
          'isVip': false,
          'vipActive': false,
          'maxEnergy': 50,
          'energy': 50,
          'vipWeakTopicRights': 0,
          'vipTestRights': 0,
          'vipPdfRights': 0,
          'vipUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await ref.collection('notifications').add({
          'title': 'VIP Üyeliğiniz Sona Erdi',
          'message':
              'VIP süreniz doldu. Dilediğiniz zaman tekrar VIP üyelik satın alabilirsiniz.',
          'type': 'vip_expired',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('VIP süre kontrol hatası: $e');
    }
  }

  // ── Bildirim dinleyici ────────────────────────────────
  void _listenForNewNotifications() {
    final uid = user?.uid;
    if (uid == null) return;

    // Admin duyuruları artık sadece ilk 10 saniyede değil,
    // kullanıcı uygulamaya ne zaman girerse girsin bir kez gösterilir.
    _notifSub = FirebaseFirestore.instance
        .collection('global_notifications')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) async {
      if (!mounted || snapshot.docs.isEmpty) return;
      try {
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final userDoc = await userRef.get();
        final seen = List<String>.from(
            userDoc.data()?['seenGlobalNotifications'] ?? const []);

        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data['isActive'] != true) continue;
          if (seen.contains(doc.id)) continue;

          final title = (data['title'] ?? 'Hoş geldin!').toString();
          final message = (data['message'] ??
                  'Bugün hedeflerine bir adım daha yaklaşmaya hazır mısın?')
              .toString();
          if (!mounted) return;
          await _showCenterNotification(
            title: title.trim().isEmpty ? 'Hoş geldin!' : title,
            message: message.trim().isEmpty
                ? 'Bugün hedeflerine bir adım daha yaklaşmaya hazır mısın?'
                : message,
            icon: Icons.campaign_rounded,
            accent: const Color(0xFF00E5FF),
          );
          await userRef.set({
            'seenGlobalNotifications': FieldValue.arrayUnion([doc.id]),
          }, SetOptions(merge: true));
          break;
        }
      } catch (e) {
        debugPrint('Duyuru dinleyici hatası: $e');
      }
    }, onError: (e) {
      debugPrint('Duyuru dinleyici hatası: $e');
    });

    // Kullanıcıya özel bildirimler: otomasyon, hatalı soru düzeltildi,
    // VIP hak talepleri gibi mesajlar burada gösterilir.
    _userNotifSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots()
        .listen((snapshot) async {
      if (!mounted || snapshot.docs.isEmpty) return;
      final doc = snapshot.docs.first;
      final data = doc.data();
      final title = (data['title'] ?? 'Bilgi Rotası').toString();
      final message =
          (data['message'] ?? 'Yeni bir bildirimin var.').toString();
      await _showCenterNotification(
        title: title.trim().isEmpty ? 'Bilgi Rotası' : title,
        message: message.trim().isEmpty ? 'Yeni bir bildirimin var.' : message,
        icon: Icons.notifications_active_rounded,
        accent: const Color(0xFFFFD700),
      );
      await doc.reference.set({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }, onError: (e) {
      debugPrint('Kullanıcı bildirim dinleyici hatası: $e');
    });
  }

  Future<void> _showCenterNotification({
    required String title,
    required String message,
    required IconData icon,
    required Color accent,
  }) async {
    if (!mounted || _notificationDialogOpen) return;
    _notificationDialogOpen = true;
    try {
      await BRDialogs.showInfo(
        context,
        title: title,
        message: message,
        icon: icon,
        accent: accent,
        buttonText: 'Harika',
      );
    } finally {
      _notificationDialogOpen = false;
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _notifSub?.cancel();
    _userNotifSub?.cancel();
    super.dispose();
  }

  // ── Firestore'dan gelen ham veriyi state'e yaz ─────────────────────────
  void _updateFromData(Map<String, dynamic> data, String uid) {
    _avatarSeed = data['avatarSeed'];
    _isVip = data['isVip'] == true;
    _isAdmin = data['role'] == 'admin';

    final dynamic frameRaw = data['avatarFrame'] ?? 0;
    _avatarFrame = frameRaw is int ? frameRaw : 0;

    String name = data['name'] ?? 'Şampiyon';
    if (name.length > 10) name = '${name.substring(0, 9)}..';
    _displayName = name;

    final int xp = (data['totalXp'] ?? 0).toInt();
    _level = (xp / 100).floor().toString();

    _energy = (data['energy'] ?? 50).toInt();
    _maxEnergy = (data['maxEnergy'] ?? 50).toInt();
    _bonusEnergy = min(
        (data['bonusEnergy'] ?? 0).toInt(), EnergyService.maxBonusEnergyWallet);
    unawaited(EnergyService().normalizeEnergy(uid));

    final model =
        UserModel.fromMap({...data, 'bonusEnergy': _bonusEnergy}, uid);
    _userModel = model;
    _syncHomeWidgetIfNeeded(model);
  }

  // ── Android Ana Ekran Widget Verisini Güncelle ───────────────────────
  void _syncHomeWidgetIfNeeded(UserModel model) {
    final signature = [
      model.uid,
      model.name,
      model.energy,
      model.maxEnergy,
      model.bonusEnergy,
      model.totalXp,
      model.league,
      model.loginStreak,
    ].join('|');

    if (_lastWidgetSyncSignature == signature) return;
    _lastWidgetSyncSignature = signature;

    unawaited(
      WidgetSyncService.updateUserWidget(model).catchError((e) {
        debugPrint('Ana ekran widget güncelleme hatası: $e');
      }),
    );
  }

  Future<void> _onAdRewarded(String uid) async {
    try {
      await EnergyService().addAdEnergy(uid);
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.flash_on_rounded, color: Colors.yellowAccent),
        const SizedBox(width: 8),
        Text(
          '+5 Enerji kazandın!',
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ]),
      backgroundColor: const Color(0xFF1B1F6A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showYksBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Color(0xFF1B1F6A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            Text('Hangi Oturum?',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: _buildExamTypeCard('TYT',
                      [const Color(0xFF00E5FF), const Color(0xFF00B0FF)])),
              const SizedBox(width: 15),
              Expanded(
                  child: _buildExamTypeCard('AYT',
                      [const Color(0xFFD500F9), const Color(0xFF9C27B0)])),
            ]),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showKpssBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Color(0xFF1B1F6A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            Text('KPSS Türünü Seç',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: _buildExamTypeCard('Lisans',
                      [const Color(0xFFFF5252), const Color(0xFFFF8A65)])),
              const SizedBox(width: 15),
              Expanded(
                  child: _buildExamTypeCard('Önlisans',
                      [const Color(0xFFFFA000), const Color(0xFFFFC107)])),
            ]),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildExamTypeCard(String label, List<Color> colors) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => SubjectsPage(examName: label)));
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: colors.first.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
        ),
        child: Center(
          child: Text(label,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0E43),
                  Color(0xFF1B1F6A),
                  Color(0xFF00C6FF)
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          ..._buildTinyStars(size),
          ..._buildStars(size),
          _buildMovingCloud(top: 120, scale: 0.9, speed: 0.6, moveRight: true),
          _buildMovingCloud(top: 250, scale: 1.1, speed: 0.4, moveRight: false),
          _buildMovingCloud(
              top: size.height * 0.6, scale: 1.0, speed: 0.5, moveRight: true),
          SafeArea(
            bottom: false,
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists && user != null) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  _updateFromData(data, user!.uid);
                }

                return Column(
                  children: [
                    _buildTopStatusBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            _buildCountdownBanner(),
                            const SizedBox(height: 15),
                            _buildStreakHeader(),
                            const SizedBox(height: 15),
                            _buildMotivationWidget(),
                            const SizedBox(height: 15),
                            _buildMainExamCards(),
                            const SizedBox(height: 15),
                            _buildDailyMissionCard(),
                            const SizedBox(height: 15),
                            _buildQuickActionCards(),
                            const SizedBox(height: 15),
                            _buildMultiplayerButton(),
                            const SizedBox(height: 15),
                            if (_isAdmin) ...[
                              _buildAdminPanelButton(context),
                              const SizedBox(height: 15),
                            ],
                            const SizedBox(height: 110),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
              left: 0, right: 0, bottom: 0, child: _buildBottomNav(context)),
        ],
      ),
    );
  }

  // ── Üst Status Bar ────────────────────────────────────────────────────
  Widget _buildTopStatusBar() {
    final double energyProgress =
        _maxEnergy == 0 ? 0 : (_energy / _maxEnergy).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  ),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: _isVip
                        ? BoxDecoration(
                            gradient: LinearGradient(
                              colors: getVipAvatarFrame(_avatarFrame).colors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: getVipAvatarFrame(_avatarFrame)
                                    .glowColor
                                    .withValues(alpha: 0.6),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          )
                        : BoxDecoration(
                            color: const Color(0xFF1B1F6A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF00E5FF),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF)
                                    .withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B1F6A),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: _avatarSeed != null
                            ? Image.network(
                                'https://api.dicebear.com/9.x/bottts-neutral/png?seed=$_avatarSeed',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Seviye $_level',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF00E5FF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IntrinsicWidth(
            child: Container(
              constraints: const BoxConstraints(minWidth: 210, maxWidth: 238),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0B1F53).withValues(alpha: 0.98),
                    const Color(0xFF12306E).withValues(alpha: 0.94),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF1ED6FF).withValues(alpha: 0.16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 145,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildEnergyCompactRow(
                          icon: Icons.bolt_rounded,
                          label: 'Temel Enerji',
                          value: '$_energy/$_maxEnergy',
                          iconColor: const Color(0xFFFFD54F),
                          valueColor: Colors.white,
                        ),
                        const SizedBox(height: 6),
                        _buildEnergyCompactRow(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Bonus Enerji',
                          value: _bonusEnergy > 0 ? '+$_bonusEnergy' : '0',
                          iconColor: const Color(0xFF2EDBFF),
                          valueColor: const Color(0xFF9DEEFF),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            value: energyProgress,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFFD54F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      final uid = user?.uid;
                      if (uid == null) return;

                      if (_isVip) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'VIP üyeler reklam izlemez; enerjin otomatik daha hızlı dolar.',
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                            backgroundColor: const Color(0xFFFFD700),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                        return;
                      }

                      ReklamServisi.odulluReklamGoster(_isVip, () {
                        _onAdRewarded(uid);
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFA726), Color(0xFFFF6D00)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFF8C00).withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          Text(
                            '+5',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyCompactRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 12),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.90),
              fontSize: 9.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ── Motivasyon + Streak Widget ────────────────────────────────────────
  Widget _buildMotivationWidget() {
    final int streak = _userModel?.loginStreak ?? 0;
    final int totalXp = _userModel?.totalXp ?? 0;
    final String league = _userModel?.league ?? 'Bronz';

    final List<String> motivationMessages = [
      '🚀 Harika gidiyorsun! Durma!',
      '💪 Her soru seni hedefe yaklaştırıyor!',
      '🎯 Odaklan, başarı yakın!',
      '⭐ $streak günlük serin devam ediyor, süper!',
      '🏆 $league liginde parlıyorsun!',
      '📚 Bugün öğrendiğin her şey fark yaratır!',
    ];
    final msg = motivationMessages[streak % motivationMessages.length];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7B2FF7).withValues(alpha: 0.25),
            const Color(0xFF00E5FF).withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9100).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Text('🔥', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: Color(0xFFFF9100), size: 14),
              const SizedBox(width: 3),
              Text('$streak gün seri',
                  style: GoogleFonts.poppins(
                      color: const Color(0xFFFF9100),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              const Icon(Icons.star_rounded,
                  color: Color(0xFFFFD700), size: 14),
              const SizedBox(width: 3),
              Text('$totalXp XP',
                  style: GoogleFonts.poppins(
                      color: const Color(0xFFFFD700),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ],
        )),
      ]),
    );
  }

  // ── Geri Sayım Banner ─────────────────────────────────────────────────
  Widget _buildCountdownBanner() {
    final now = DateTime.now();
    final target =
        _showYksCountdown ? DateTime(2026, 6, 20) : DateTime(2026, 9, 6);
    final daysLeft = target.difference(now).inDays;
    final glowColor =
        _showYksCountdown ? const Color(0xFF00E5FF) : const Color(0xFFFF5252);

    return GestureDetector(
      onTap: () => setState(() => _showYksCountdown = !_showYksCountdown),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: glowColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: glowColor.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(children: [
          Icon(Icons.hourglass_bottom_rounded, color: glowColor, size: 35),
          const SizedBox(width: 15),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _showYksCountdown ? "YKS 2026'ya Son" : "KPSS 2026'ya Son",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              Text('$daysLeft GÜN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.swap_horiz_rounded, color: Colors.white70, size: 20),
        ]),
      ),
    );
  }

  // ── Streak Header ─────────────────────────────────────────────────────
  Widget _buildStreakHeader() {
    final int streak = _userModel?.loginStreak ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          const Text('🔥', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text('$streak Günlük Seri',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ]),
        GestureDetector(
          onTap: () => StreakCalendarSheet.show(context),
          child: Text('Takvimi Gör >',
              style: GoogleFonts.poppins(
                  color: const Color(0xFFFF9100),
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // ── Ana Sınav Kartları ────────────────────────────────────────────────
  Widget _buildMainExamCards() {
    final int completedSections = _userModel?.totalSections ?? 0;
    final double progress = (completedSections / 300.0).clamp(0.0, 1.0);
    final int percentage = (progress * 100).toInt();

    return Row(children: [
      Expanded(
        child: _buildSquareExamCard(
          'KPSS',
          '%$percentage Tamamlandı',
          Icons.auto_stories_rounded,
          progress,
          [const Color(0xFFFF5252), const Color(0xFFFF8A65)],
          () => _showKpssBottomSheet(context),
        ),
      ),
      const SizedBox(width: 15),
      Expanded(
        child: _buildSquareExamCard(
          'YKS',
          '%$percentage Tamamlandı',
          Icons.school_rounded,
          progress,
          [const Color(0xFF00BFA5), const Color(0xFF00B0FF)],
          () => _showYksBottomSheet(context),
        ),
      ),
    ]);
  }

  Widget _buildSquareExamCard(
    String title,
    String subtitle,
    IconData icon,
    double progress,
    List<Color> colors,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(
                color: colors.first.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 35),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style:
                      GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  minHeight: 6,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Günlük Görev Kartı ────────────────────────────────────────────────
  Widget _buildDailyMissionCard() {
    return FutureBuilder<List<Mission>>(
      future: user != null
          ? MissionService().getDailyMissions(user!.uid)
          : Future.value([]),
      builder: (context, snapshot) {
        final missions = snapshot.data ?? [];
        final total = missions.isEmpty ? 3 : missions.length;
        int completedCount = 0;

        if (_userModel != null && missions.isNotEmpty) {
          for (final m in missions) {
            int current = 0;
            switch (m.trackField) {
              case 'dailyCorrect':
                current = _userModel!.dailyCorrect;
                break;
              case 'dailyQuestions':
                current = _userModel!.dailyQuestions;
                break;
              case 'dailySections':
                current = _userModel!.dailySections;
                break;
              case 'dailyAds':
                current = _userModel!.dailyAds;
                break;
              case 'dailyLogin':
                current = _userModel!.dailyLogin;
                break;
            }
            if (m.isClaimed || current >= m.targetCount) completedCount++;
          }
        }

        return GestureDetector(
          onTap: () => MissionsSheet.show(context),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('⚡ Görevler',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text('$completedCount / $total günlük görev tamamlandı',
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 15),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (completedCount / total).clamp(0.0, 1.0),
                          backgroundColor: Colors.white12,
                          valueColor:
                              const AlwaysStoppedAnimation(Color(0xFFFF9100)),
                          minHeight: 8,
                        ),
                      ),
                    ]),
              ),
              const SizedBox(width: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFFFF9100).withValues(alpha: 0.8),
                    const Color(0xFFFF6B00),
                  ]),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: Colors.white, size: 28),
              ),
            ]),
          ),
        );
      },
    );
  }

  // ── Hızlı Eylem Kartları (ÖSYM Denemeleri Güncellendi) ────────────────
  Widget _buildQuickActionCards() {
    return Column(children: [
      Row(children: [
        Expanded(
          child: _buildSmallActionCard(
            title: 'Yanlışlarım',
            icon: Icons.assignment_late_rounded,
            colors: [const Color(0xFFD500F9), const Color(0xFF651FFF)],
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MistakeBoxPage())),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildSmallActionCard(
            title: 'Net Hesapla',
            icon: Icons.calculate_rounded,
            colors: [const Color(0xFF00E5FF), const Color(0xFF007BFF)],
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NetCalculatorPage())),
          ),
        ),
      ]),
      const SizedBox(height: 15),
      Row(children: [
        Expanded(
          child: _buildSmallActionCard(
            title: 'ÖSYM Denemeleri',
            icon: Icons.emoji_events_rounded,
            colors: [const Color(0xFF1D976C), const Color(0xFF38EF7D)],
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ExamTrialsPage())),
          ),
        ),
      ]),
    ]);
  }

  Widget _buildSmallActionCard({
    required String title,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
    bool isComingSoon = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, // Kartın içini tam doldurması için
        clipBehavior:
            Clip.antiAlias, // ŞERİDİN DIŞARI TAŞMASINI JİLET GİBİ KESER!
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(
                color: colors.first.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Stack(
          children: [
            // Ana İçerik (Yakındaysa soluklaşır)
            Opacity(
              opacity: isComingSoon ? 0.4 : 1.0,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                            color: Colors.white24, shape: BoxShape.circle),
                        child: Icon(icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(title,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ),
                    ]),
              ),
            ),

            // "ÇOK YAKINDA" Kırmızı Şerit
            if (isComingSoon)
              Positioned(
                top: 13,
                right: -30,
                child: Transform.rotate(
                  angle: 0.785, // 45 derece eğim
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                    color: Colors.redAccent,
                    child: Text(
                      'YAKINDA',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Multiplayer Butonu ────────────────────────────────────────────────
  Widget _buildMultiplayerButton() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MultiplayerLobbyPage())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF7B2FF7), Color(0xFFD500F9), Color(0xFF5A189A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFD500F9).withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 6)),
            BoxShadow(
                color: const Color(0xFF7B2FF7).withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 2),
          ],
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.15), width: 1.5),
        ),
        child: Row(children: [
          Stack(children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 1.5),
              ),
              child: const Icon(Icons.sports_esports_rounded,
                  color: Colors.white, size: 28),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                    color: Color(0xFF00E676), shape: BoxShape.circle),
                child: const Center(
                    child: Text('⚔️', style: TextStyle(fontSize: 8))),
              ),
            ),
          ]),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text('Arkadaşınla Oyna',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('CANLI',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
              ]),
              const SizedBox(height: 3),
              Text('1v1 Düello • Her soruda 30 sn ⏱️',
                  style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 20),
          ),
        ]),
      ),
    );
  }

  // ── VIP Butonu ────────────────────────────────────────────────────────
  Widget _buildVipAiButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const VipStatisticsPage())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('VIP Yapay Zeka',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text('Analiz Merkezi & AI Koçluk',
                  style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white, size: 20),
        ]),
      ),
    );
  }

  // ── Admin Butonu ──────────────────────────────────────────────────────
  Widget _buildAdminPanelButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AdminPanelPage())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          border: Border.all(
              color: Colors.redAccent.withValues(alpha: 0.5), width: 2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.redAccent, size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sistem Kontrol Paneli',
                  style: GoogleFonts.poppins(
                      color: Colors.redAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text('Kullanıcılar ve Soruları Yönet',
                  style: GoogleFonts.poppins(
                      color: Colors.redAccent.withValues(alpha: 0.8),
                      fontSize: 13)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.redAccent, size: 20),
        ]),
      ),
    );
  }

  // ── Alt Navigasyon ────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(left: 14, right: 14, bottom: bottomPad + 16),
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF141840), Color(0xFF0E1230)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(34),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.09), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 32,
                spreadRadius: 0,
                offset: const Offset(0, 12)),
            BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.07),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, -2)),
          ],
        ),
        child: Row(children: [
          _navItem(
            icon: Icons.person_rounded,
            label: 'Profil',
            iconColor: const Color(0xFFFF6B6B),
            glowColor: const Color(0xFFFF5252),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
          _navItem(
            icon: Icons.leaderboard_rounded,
            label: 'Sıralama',
            iconColor: const Color(0xFF00E5FF),
            glowColor: const Color(0xFF00B8D9),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LeaderboardPage())),
          ),
          _vipNavItem(context),
          _navItem(
            icon: Icons.storefront_rounded,
            label: 'Mağaza',
            iconColor: const Color(0xFFFFD54F),
            glowColor: const Color(0xFFFFAB00),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const StorePage())),
          ),
          _navItem(
            icon: Icons.tune_rounded,
            label: 'Ayarlar',
            iconColor: const Color(0xFF80DEEA),
            glowColor: const Color(0xFF00BCD4),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ]),
      ),
    );
  }

  Widget _vipNavItem(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isVip) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VipStatisticsPage(),
              ),
            );
          } else {
            Navigator.pushNamed(context, '/vip-test');
          }
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 76,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE57A), Color(0xFFFF9800)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                      blurRadius: 22,
                      spreadRadius: 0,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('👑', style: TextStyle(fontSize: 25)),
                ),
              ),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFFE57A), Color(0xFFFF9800)],
                ).createShader(b),
                child: Text(
                  'VIP',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 76,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withValues(alpha: 0.22),
                      glowColor.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: iconColor.withValues(alpha: 0.35), width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: glowColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(height: 5),
              Text(label,
                  style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  // ── Arka Plan Yardımcıları ─────────────────────────────────────────────
  Widget _buildMovingCloud({
    required double top,
    required double scale,
    required double speed,
    required bool moveRight,
  }) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final double sw = MediaQuery.of(context).size.width;
        final double cw = 90.0 * scale;
        double offset = (_bgController.value * speed * (sw + cw)) % (sw + cw);
        if (!moveRight) offset = sw - offset;
        return Positioned(
          top: top,
          left: offset - cw,
          child: Opacity(
            opacity: 0.15,
            child: Icon(Icons.cloud_rounded,
                color: Colors.white, size: 90 * scale),
          ),
        );
      },
    );
  }

  List<Widget> _buildStars(Size size) {
    final rand = Random(42);
    return List.generate(
      15,
      (_) => Positioned(
        left: rand.nextDouble() * size.width,
        top: rand.nextDouble() * size.height,
        child: Icon(Icons.star,
            size: rand.nextDouble() * 5 + 2,
            color: Colors.white.withValues(alpha: 0.3)),
      ),
    );
  }

  List<Widget> _buildTinyStars(Size size) {
    final rand = Random(12);
    return List.generate(
      20,
      (_) => Positioned(
        left: rand.nextDouble() * size.width,
        top: rand.nextDouble() * size.height,
        child: Icon(Icons.star,
            size: 1.5, color: Colors.white.withValues(alpha: 0.2)),
      ),
    );
  }
}
