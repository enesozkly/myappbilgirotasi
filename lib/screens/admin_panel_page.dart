// ignore_for_file: unused_element, unused_local_variable

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/upload_service.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;

  // -- Soru Yükleme Değişkenleri --
  bool _isUploading = false;
  final List<String> _logMessages = [];
  final ScrollController _logScrollController = ScrollController();
  Map<String, int> _soruSayilari = {};
  bool _loadingSayilar = false;

  // -- Bildirim Değişkenleri --
  final TextEditingController _notifTitleController = TextEditingController();
  final TextEditingController _notifMsgController = TextEditingController();
  bool _isSendingNotif = false;

  // -- Kullanıcı Arama --
  final TextEditingController _userSearchController = TextEditingController();
  String _userSearchQuery = '';

  @override
  void initState() {
    super.initState();
    // SEKME SAYISI 6'YA ÇIKARILDI
    _tabController = TabController(length: 10, vsync: this);
    _loadSoruSayilari();
    _checkAdminAccess();
    _checkWeeklyLeaderboardRollover();
  }

  Future<void> _checkWeeklyLeaderboardRollover() async {
    try {
      final now = DateTime.now();
      // Müşteri isteği: pazar 00.00'da haftalık sıralama sıfırlansın.
      // Bu kontrol admin panel açıldığında çalışır; tam otomatik garanti için
      // aynı mantık Cloud Functions zamanlayıcısına taşınmalıdır.
      if (now.weekday != DateTime.sunday) return;

      final key = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final rolloverRef = _db.collection('weekly_leaderboard_rollovers').doc(key);
      final existing = await rolloverRef.get();
      if (existing.exists) return;

      final top = await _db
          .collection('users')
          .where('role', isEqualTo: 'student')
          .orderBy('weeklyXp', descending: true)
          .limit(3)
          .get();

      final winners = top.docs.map((d) {
        final data = d.data();
        return {
          'uid': d.id,
          'name': data['name'] ?? 'İsimsiz',
          'email': data['email'] ?? '',
          'weeklyXp': data['weeklyXp'] ?? 0,
        };
      }).toList();

      await rolloverRef.set({
        'weekEnding': key,
        'winners': winners,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final all = await _db.collection('users').where('role', isEqualTo: 'student').get();
      final batch = _db.batch();
      for (final doc in all.docs) {
        batch.update(doc.reference, {'weeklyXp': 0});
      }
      await batch.commit();

      await _db.collection('global_notifications').add({
        'title': 'Haftalık sıralama sıfırlandı 🏆',
        'message': winners.isEmpty
            ? 'Bu hafta kazanan bulunamadı.'
            : 'Haftanın ilk 3 öğrencisi admin paneline kaydedildi.',
        'type': 'weekly_leaderboard_rollover',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Haftalık sıralama sıfırlama hatası: $e');
    }
  }

  Future<void> _checkAdminAccess() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists || doc.data()?['role'] != 'admin') {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu sayfaya erişim yetkiniz yok.')),
          );
        }
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    _tabController.dispose();
    _notifTitleController.dispose();
    _notifMsgController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SORU YÜKLEME METOTLARI (MEVCUT SİSTEM KORUNDU)
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _loadSoruSayilari() async {
    setState(() => _loadingSayilar = true);
    final sayilar = await QuestionUploader.getSoruSayilari();
    if (mounted) {
      setState(() {
        _soruSayilari = sayilar;
        _loadingSayilar = false;
      });
    }
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() => _logMessages.add(message));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleUploadAll() async {
    setState(() {
      _isUploading = true;
      _logMessages.clear();
    });
    _addLog('🚀 Tüm sorular yükleniyor...');

    final result = await QuestionUploader.uploadAll(onProgress: _addLog);

    _addLog('');
    _addLog('════════════════════════');
    _addLog('✅ Toplam: ${result.totalUploaded} soru yüklendi');
    if (result.hasErrors) {
      for (final err in result.errors) {
        _addLog(err);
      }
    }

    if (mounted) setState(() => _isUploading = false);
    await _loadSoruSayilari();
    _showSnackbar(
      result.hasErrors
          ? '⚠️ ${result.totalUploaded} soru yüklendi, ${result.errors.length} hata'
          : '✅ ${result.totalUploaded} soru başarıyla yüklendi!',
      result.hasErrors ? Colors.orange : Colors.green,
    );
  }

  Future<void> _handleUploadDers(String ders) async {
    setState(() {
      _isUploading = true;
      _logMessages.clear();
    });
    _addLog('🚀 $ders soruları yükleniyor...');

    final result = await QuestionUploader.uploadByDers(
      ders,
      onProgress: _addLog,
    );

    _addLog('════════════════════════');
    _addLog('✅ ${result.totalUploaded} soru yüklendi');
    if (mounted) setState(() => _isUploading = false);
    await _loadSoruSayilari();
    _showSnackbar(
      '✅ $ders: ${result.totalUploaded} soru yüklendi',
      Colors.green,
    );
  }

  void _showSnackbar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ANA BUILD & TAB BAR
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E43),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1F6A),
        elevation: 10,
        shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
        title: Text(
          'Sistem Kontrol Merkezi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E5FF),
          indicatorWeight: 4,
          labelColor: const Color(0xFF00E5FF),
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Dashboard'),
            Tab(icon: Icon(Icons.analytics_rounded), text: 'Analizler'), // YENİ EKLENDİ
            Tab(icon: Icon(Icons.smart_toy_rounded), text: 'Otomasyon'), // YENİ EKLENDİ
            Tab(icon: Icon(Icons.manage_accounts_rounded), text: 'Kullanıcılar'),
            Tab(icon: Icon(Icons.campaign_rounded), text: 'Bildirimler'),
            Tab(icon: Icon(Icons.flag_rounded), text: 'Hatalı Sorular'),
            Tab(icon: Icon(Icons.feedback_rounded), text: 'Geri Bildirimler'),
            Tab(icon: Icon(Icons.workspace_premium_rounded), text: 'VIP Talepleri'),
            Tab(icon: Icon(Icons.assignment_rounded), text: 'VIP İçerik'),
            Tab(icon: Icon(Icons.insights_rounded), text: 'VIP Analizleri'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0E43), Color(0xFF1B1F6A)],
              ),
            ),
          ),

          TabBarView(
            controller: _tabController,
            children: [
              _buildDashboardTab(),
              _buildAnalyticsTab(), // YENİ EKLENDİ
              _buildAutomationTab(), // YENİ EKLENDİ
              _buildUserManagementTab(),
              _buildNotificationTab(),
              _buildReportedQuestionsTab(),
              _buildFeedbacksTab(),
              _buildVipRequestsTab(),
              _buildVipContentRequestsTab(),
              _buildVipAnalysisRequestsTab(),
            ],
          ),

          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1F6A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00E5FF)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF00E5FF)),
                      const SizedBox(height: 20),
                      Text(
                        'Sisteme İşleniyor...',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lütfen uygulamayı kapatmayın.',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEKMELER (TABS)
  // ══════════════════════════════════════════════════════════════════════════

  // ── 1. DASHBOARD SEKME ──
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Platform Verileri', Icons.analytics_rounded),
          const SizedBox(height: 15),
          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('users').where('role', isEqualTo: 'student').snapshots(),
            builder: (ctx, snapshot) {
              final int totalUsers = snapshot.hasData ? snapshot.data!.docs.length : 0;
              final int vipUsers = snapshot.hasData
                  ? snapshot.data!.docs.where((d) => (d.data() as Map)['isVip'] == true).length
                  : 0;

              final now = DateTime.now();
              int dailyActive = 0;
              if (snapshot.hasData) {
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final ts = data['lastLoginDate'];
                  if (ts != null && ts is Timestamp) {
                    final d = ts.toDate();
                    if (d.year == now.year && d.month == now.month && d.day == now.day) {
                      dailyActive++;
                    }
                  }
                }
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Toplam Üye', '$totalUsers', Icons.people_alt_rounded, Colors.purpleAccent)),
                      const SizedBox(width: 15),
                      Expanded(child: _buildStatCard('VIP Üye', '$vipUsers', Icons.workspace_premium_rounded, const Color(0xFFFFD700))),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Bugün Aktif', '$dailyActive', Icons.visibility_rounded, Colors.greenAccent)),
                      const SizedBox(width: 15),
                      Expanded(child: _buildLigDagilimi(snapshot.data?.docs ?? [])),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          _buildSectionTitle('Bugün Test Çözenler (00:00 İtibariyle)', Icons.today_rounded),
          const SizedBox(height: 15),
          _buildTodayActiveUsers(),
          const SizedBox(height: 30),
          _buildSectionTitle('Sona Yaklaşan Şampiyonlar', Icons.emoji_events_rounded),
          const SizedBox(height: 15),
          _buildTopStudents(),
        ],
      ),
    );
  }

  Widget _buildLigDagilimi(List<QueryDocumentSnapshot> docs) {
    final Map<String, int> ligler = {};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lig = data['league'] ?? 'Bronz';
      ligler[lig] = (ligler[lig] ?? 0) + 1;
    }
    final topLig = ligler.entries.isEmpty ? 'Bronz' : ligler.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return _buildStatCard('En Kalabalık Lig', topLig, Icons.emoji_events_rounded, Colors.orangeAccent);
  }

  // ── YENİ: 2. ANALİZ MERKEZİ SEKME ──
  Widget _buildAnalyticsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').where('role', isEqualTo: 'student').snapshots(),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
        
        final docs = snapshot.data!.docs;
        final totalUsers = docs.length;
        if (totalUsers == 0) return const Center(child: Text('Veri bulunamadı.', style: TextStyle(color: Colors.white)));

        final now = DateTime.now();
        
        // --- Değişkenleri Toplama ---
        int baslayanlar = 0;
        int enerjisiBitenler = 0;
        int cokAktif = 0;
        int pasif = 0;
        int yeniKullanici = 0;
        int vipKullanici = 0;
        int gunlukGorevYapan = 0;
        int haftalikGorevYapan = 0;
        int eldeTutulan = 0; // Cohort (Son 3 gün içinde girenler)

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          
          final totalSections = (data['totalSections'] ?? 0) as int;
          final energy = (data['energy'] ?? 50) as int;
          final loginStreak = (data['loginStreak'] ?? 0) as int;
          final dailyQuestions = (data['dailyQuestions'] ?? 0) as int;
          final weeklySections = (data['weeklySections'] ?? 0) as int;
          final isVip = data['isVip'] == true;
          
          DateTime? lastLogin;
          if (data['lastLoginDate'] is Timestamp) lastLogin = (data['lastLoginDate'] as Timestamp).toDate();
          
          DateTime? createdAt;
          if (data['createdAt'] is Timestamp) createdAt = (data['createdAt'] as Timestamp).toDate();

          // 1. Funnel (Akış) Verileri
          if (totalSections > 0) baslayanlar++;
          if (energy < 15 && !isVip) enerjisiBitenler++; // 15 enerjinin altını riskli/bitmiş sayalım
          
          // 2. Segmentasyon Verileri
          if (loginStreak >= 3) cokAktif++;
          if (lastLogin != null && now.difference(lastLogin).inDays >= 2) pasif++;
          if (createdAt != null && now.difference(createdAt).inDays <= 3) yeniKullanici++;
          if (isVip) vipKullanici++;

          // 3. Görev Tamamlama Analizi
          if (dailyQuestions >= 10) gunlukGorevYapan++; 
          if (weeklySections >= 3) haftalikGorevYapan++;

          // 4. Cohort Analizi (Retention: 3 gün önce kayıt olup, bugün veya dün girenler)
          if (createdAt != null && lastLogin != null) {
            if (now.difference(createdAt).inDays >= 3 && now.difference(lastLogin).inDays <= 1) {
              eldeTutulan++;
            }
          }
        }

        // Yüzdeleri Hesaplama
        final pBaslayanlar = totalUsers > 0 ? (baslayanlar / totalUsers * 100).toInt() : 0;
        final pEnerjisiBitenler = baslayanlar > 0 ? (enerjisiBitenler / baslayanlar * 100).toInt() : 0;
        final pGunlukGorev = totalUsers > 0 ? (gunlukGorevYapan / totalUsers * 100).toInt() : 0;
        final pHaftalikGorev = totalUsers > 0 ? (haftalikGorevYapan / totalUsers * 100).toInt() : 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('1️⃣ Funnel (Akış) Analizi', Icons.filter_alt_rounded),
              const SizedBox(height: 10),
              _buildAnalizCard('Kayıtlı Öğrenci', '$totalUsers Kişi', 'Uygulamayı indirenler', Colors.blueAccent),
              _buildAnalizCard('Test Çözmeye Başlayan', '%$pBaslayanlar ($baslayanlar Kişi)', 'Kayıt olanların testi başlatma oranı', Colors.greenAccent),
              _buildAnalizCard('Enerjisi Biten/Tükenen', '%$pEnerjisiBitenler ($enerjisiBitenler Kişi)', 'Çözmeye başlayıp enerjisi tükenenler (VIP hariç)', Colors.orangeAccent),
              const SizedBox(height: 25),

              _buildSectionTitle('4️⃣ Enerji Tüketim & Satış Noktası', Icons.bolt_rounded),
              const SizedBox(height: 10),
              _buildAnalizCard('VIP Dönüşüm Potansiyeli', '$enerjisiBitenler Kullanıcı', 'Şu an enerjisi tükenmiş ve VIP teklifine en açık olan kitle.', const Color(0xFFFFD700)),
              const SizedBox(height: 25),

              _buildSectionTitle('5️⃣ Görev Tamamlama Analizi', Icons.task_alt_rounded),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildAnalizCard('Günlük Görev', '%$pGunlukGorev', 'Tamamlama Oranı', Colors.purpleAccent)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildAnalizCard('Haftalık Görev', '%$pHaftalikGorev', 'Tamamlama Oranı', Colors.pinkAccent)),
                ],
              ),
              const SizedBox(height: 25),

              _buildSectionTitle('🔟 Kullanıcı Segmentleme', Icons.pie_chart_rounded),
              const SizedBox(height: 10),
              Wrap(
                spacing: 15,
                runSpacing: 15,
                children: [
                  SizedBox(width: MediaQuery.of(context).size.width / 2 - 28, child: _buildAnalizCard('Çok Aktif', '$cokAktif', 'Streak > 3', Colors.green)),
                  SizedBox(width: MediaQuery.of(context).size.width / 2 - 28, child: _buildAnalizCard('Pasif', '$pasif', '2 gündür girmiyor', Colors.redAccent)),
                  SizedBox(width: MediaQuery.of(context).size.width / 2 - 28, child: _buildAnalizCard('VIP Kullanıcı', '$vipKullanici', 'Aktif VIP', const Color(0xFFFFD700))),
                  SizedBox(width: MediaQuery.of(context).size.width / 2 - 28, child: _buildAnalizCard('Yeni Kullanıcı', '$yeniKullanici', 'Son 3 gün', Colors.cyan)),
                  SizedBox(width: MediaQuery.of(context).size.width / 2 - 28, child: _buildAnalizCard('Elde Tutulan', '$eldeTutulan', 'Cohort: 3+ gün önce kayıt, son 2 gün aktif', Colors.tealAccent)),
                ],
              ),
              const SizedBox(height: 50),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalizCard(String title, String value, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(value, style: GoogleFonts.poppins(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(subtitle, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  // ── YENİ: 3. OTOMASYON (AKSİYON) SEKME ──
  Widget _buildAutomationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('🎯 Otomatik Aksiyon Sistemi', Icons.smart_toy_rounded),
          const SizedBox(height: 20),
          Text(
            'Belirli kullanıcı segmentlerine otomatik olarak tetiklenecek eylemleri buradan başlatabilirsiniz.',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 30),

          _buildAutomationAction(
            title: 'Pasif Kullanıcıları Uyandır',
            desc: '2 günden uzun süredir uygulamaya girmeyen kullanıcılara motive edici "Seni Özledik" bildirimi gönder.',
            icon: Icons.notifications_active_rounded,
            color: Colors.redAccent,
            onTap: () => _tetikleOtomasyon('pasif'),
          ),
          const SizedBox(height: 15),

          _buildAutomationAction(
            title: 'VIP Teklifi Sun',
            desc: 'Enerjisi tamamen tükenmiş olan standart kullanıcılara %50 İndirimli VIP teklifi bildirimi gönder.',
            icon: Icons.workspace_premium_rounded,
            color: const Color(0xFFFFD700),
            onTap: () => _tetikleOtomasyon('vip_teklif'),
          ),
          const SizedBox(height: 15),

          _buildAutomationAction(
            title: 'Kolay Test Öner',
            desc: 'Başarı oranı düşük (Yanlış sayısı fazla) olan kullanıcılara "Temel Seviye Tekrarı" testi öner.',
            icon: Icons.health_and_safety_rounded,
            color: Colors.greenAccent,
            onTap: () => _tetikleOtomasyon('dusuk_performans'),
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationAction({required String title, required String desc, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(desc, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.send_rounded, color: color),
          ],
        ),
      ),
    );
  }

  Future<void> _tetikleOtomasyon(String tip) async {
    try {
      final title = tip == 'pasif'
          ? 'Seni Özledik! 🥺'
          : tip == 'vip_teklif'
              ? 'Sınırları Kaldır! 🚀'
              : 'Kendini Geliştir! 🧠';
      final message = tip == 'pasif'
          ? 'Rakiplerin çalışmaya devam ediyor, arayı kapatma zamanı geldi!'
          : tip == 'vip_teklif'
              ? 'Enerjin azaldıysa VIP paketle daha uzun ve reklamsız çalışabilirsin.'
              : 'Temelini güçlendirmek için bugün kolay bir tekrar testi çözmeyi dene!';

      final users = await _db
          .collection('users')
          .where('role', isEqualTo: 'student')
          .limit(400)
          .get();

      final now = DateTime.now();
      final batch = _db.batch();
      int targetCount = 0;

      for (final userDoc in users.docs) {
        final data = userDoc.data();
        bool match = false;

        if (tip == 'pasif') {
          final ts = data['lastLoginDate'];
          if (ts is Timestamp) {
            match = now.difference(ts.toDate()).inDays >= 2;
          } else {
            match = true;
          }
        } else if (tip == 'vip_teklif') {
          final isVip = data['isVip'] == true;
          final energy = (data['energy'] ?? 0).toInt();
          final bonus = (data['bonusEnergy'] ?? 0).toInt();
          match = !isVip && energy + bonus < 10;
        } else {
          final correct = (data['totalCorrect'] ?? 0).toInt();
          final sections = (data['totalSections'] ?? 0).toInt();
          match = sections > 0 && correct / (sections * 10).clamp(1, 9999) < 0.45;
        }

        if (!match) continue;
        final notifRef = userDoc.reference.collection('notifications').doc();
        batch.set(notifRef, {
          'title': title,
          'message': message,
          'type': 'automation_$tip',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        targetCount++;
      }

      await batch.commit();
      await _db.collection('automation_logs').add({
        'type': tip,
        'targetCount': targetCount,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSnackbar('$targetCount kullanıcıya uygulama içi bildirim oluşturuldu.', Colors.green);
    } catch (e) {
      _showSnackbar('Hata oluştu: $e', Colors.redAccent);
    }
  }

  // ── 4. KULLANICI YÖNETİMİ SEKME ──
  Widget _buildUserManagementTab() {
    return Column(
      children: [
        // 🔍 Arama Kutusu
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: TextField(
              controller: _userSearchController,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              onChanged: (val) =>
                  setState(() => _userSearchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'İsme göre ara...',
                hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                suffixIcon: _userSearchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _userSearchController.clear();
                          setState(() => _userSearchQuery = '');
                        },
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white38, size: 18),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Kullanıcıya tıklayarak VIP yapabilir, enerji verebilir veya ligini sıfırlayabilirsiniz.',
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('users')
                .where('role', isEqualTo: 'student')
                .snapshots(),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF00E5FF)));
              }
              if (!snapshot.hasData ||
                  snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Text('Kullanıcı bulunamadı.',
                        style: TextStyle(color: Colors.white)));
              }

              // 🔍 İsme göre filtrele
              final allDocs = snapshot.data!.docs;
              final filteredDocs = _userSearchQuery.isEmpty
                  ? allDocs
                  : allDocs.where((doc) {
                      final data =
                          doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '')
                          .toString()
                          .toLowerCase();
                      return name.contains(_userSearchQuery);
                    }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🔍',
                          style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      Text(
                        '"$_userSearchQuery" ile eşleşen kullanıcı bulunamadı.',
                        style: GoogleFonts.poppins(
                            color: Colors.white54, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredDocs.length,
                itemBuilder: (listCtx, index) {
                  final doc = filteredDocs[index];
                  final data =
                      doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'İsimsiz';
                  final email =
                      data['email'] ?? 'E-posta yok';
                  final bool isVip = data['isVip'] ?? false;
                  final String league =
                      data['league'] ?? 'Bronz';
                  final int totalXp =
                      (data['totalXp'] ?? 0).toInt();

                  return Container(
                    margin:
                        const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isVip
                          ? const Color(0xFFFFD700)
                              .withValues(alpha: 0.1)
                          : Colors.white
                              .withValues(alpha: 0.05),
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                          color: isVip
                              ? const Color(0xFFFFD700)
                                  .withValues(alpha: 0.5)
                              : Colors.white12),
                    ),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                      leading: CircleAvatar(
                        backgroundColor: isVip
                            ? const Color(0xFFFFD700)
                            : const Color(0xFF00E5FF),
                        child: Icon(
                          isVip
                              ? Icons.workspace_premium_rounded
                              : Icons.person,
                          color:
                              const Color(0xFF1B1F6A),
                        ),
                      ),
                      title: Row(children: [
                        Expanded(
                            child: Text(name,
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight:
                                        FontWeight.bold))),
                        if (isVip)
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2),
                            decoration: BoxDecoration(
                                color:
                                    const Color(0xFFFFD700),
                                borderRadius:
                                    BorderRadius.circular(
                                        8)),
                            child: const Text('VIP',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight:
                                        FontWeight.bold)),
                          ),
                      ]),
                      subtitle: Text(
                        '$email\nLig: $league · XP: $totalXp',
                        style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 11),
                      ),
                      trailing: const Icon(
                          Icons.settings_suggest_rounded,
                          color: Colors.white54),
                      onTap: () => _showUserActionModal(
                          doc.id, name, isVip),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 5. BİLDİRİM SEKME ──
  Widget _buildNotificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Manuel Duyurular', Icons.campaign_rounded),
          const SizedBox(height: 20),
          Text(
            'Tüm kullanıcılara uygulama içi duyuru gönderin. Aktif duyuruları aşağıdan görebilir ve silebilirsiniz.',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          _buildTextField('Bildirim Başlığı', _notifTitleController, Icons.title_rounded),
          const SizedBox(height: 15),
          _buildTextField('Bildirim İçeriği', _notifMsgController, Icons.message_rounded, maxLines: 4),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: _isSendingNotif ? null : _sendNotification,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFD500F9), Color(0xFF7B2FF7)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFFD500F9).withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Center(
                child: _isSendingNotif
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, color: Colors.white),
                          const SizedBox(width: 10),
                          Text('Duyuruyu Gönder', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionTitle('Aktif Duyurular', Icons.notifications_active_rounded),
          const SizedBox(height: 14),
          _buildGlobalAnnouncementsPanel(),
        ],
      ),
    );
  }

  // ── 6. SORU YÜKLEME SEKME ──
  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Soru Yönetim Merkezi', Icons.cloud_upload_rounded),
          const SizedBox(height: 15),
          _buildUploadButton(
            title: 'TÜM SORULARI GÜNCELLE',
            subtitle: 'Tüm ders ve konuları Firebase\'e yükler',
            icon: Icons.sync_rounded,
            color: const Color(0xFF00E5FF),
            onTap: _isUploading ? null : _handleUploadAll,
            isMain: true,
          ),
          const SizedBox(height: 15),
          Text('Ders Bazlı Yükleme', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 10),
          ..._buildDersButtons(),
          const SizedBox(height: 20),
          if (_logMessages.isNotEmpty) ...[
            _buildSectionTitle('Yükleme Logu', Icons.terminal_rounded),
            const SizedBox(height: 10),
            _buildLogPanel(),
            const SizedBox(height: 30),
          ],
          Row(
            children: [
              Expanded(child: _buildSectionTitle('Sistemdeki Sorular', Icons.storage_rounded)),
              IconButton(icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF)), onPressed: _loadSoruSayilari),
            ],
          ),
          const SizedBox(height: 10),
          _buildSoruSayilariPanel(),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // YARDIMCI WIDGET'LAR VE FONKSİYONLAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF00E5FF), size: 24),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }


  // ── Bugün aktif kullanıcılar (00:00'dan itibaren) ──
  Widget _buildTodayActiveUsers() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').where('role', isEqualTo: 'student').snapshots(),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
        }
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final docs = snapshot.data!.docs;
        final todayUsers = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['lastLoginDate'];
          if (ts == null || ts is! Timestamp) return false;
          return ts.toDate().isAfter(todayStart);
        }).toList();

        if (todayUsers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Text('Bugün henüz aktif kullanıcı yok.',
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
          );
        }

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.people_rounded, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Text('Bugün ${todayUsers.length} kullanıcı giriş yaptı',
                    style: GoogleFonts.poppins(
                        color: Colors.greenAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
            ...todayUsers.take(20).map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'İsimsiz';
              final email = data['email'] ?? '';
              final sections = (data['dailySections'] ?? 0).toString();
              final questions = (data['dailyQuestions'] ?? 0).toString();
              final tsRaw = data['lastLoginDate'];
              final t = tsRaw is Timestamp ? tsRaw.toDate() : DateTime.now();
              final timeStr = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
              final isVip = data['isVip'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isVip
                        ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                        : const Color(0xFF00E5FF).withValues(alpha: 0.2),
                    child: Icon(
                        isVip ? Icons.workspace_premium_rounded : Icons.person,
                        color: isVip ? const Color(0xFFFFD700) : const Color(0xFF00E5FF),
                        size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      Text(email,
                          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10),
                          overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Giriş: $timeStr',
                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
                    Text('$sections bölüm • $questions soru',
                        style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
                  ]),
                ]),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildTopStudents() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').where('role', isEqualTo: 'student').orderBy('totalSections', descending: true).limit(5).snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Text('Henüz aktif öğrenci bulunmuyor.', style: GoogleFonts.poppins(color: Colors.white70));

        return Column(
          children: snapshot.data!.docs.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final data = entry.value.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'İsimsiz';
            final sections = (data['totalSections'] ?? 0).toInt();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
              child: Row(
                children: [
                  Text('#$index', style: GoogleFonts.poppins(color: const Color(0xFF00E5FF), fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('$sections Bölüm Bitirdi', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  List<Widget> _buildDersButtons() {
    final List<Map<String, dynamic>> dersler = [
      {'ad': 'Türkçe', 'icon': Icons.translate_rounded, 'renk': Colors.orange},
      {'ad': 'Matematik', 'icon': Icons.calculate_rounded, 'renk': Colors.cyan},
      {'ad': 'Biyoloji', 'icon': Icons.biotech_rounded, 'renk': Colors.green},
      {'ad': 'Fizik', 'icon': Icons.science_rounded, 'renk': Colors.blue},
      {'ad': 'Kimya', 'icon': Icons.opacity_rounded, 'renk': Colors.pink},
      {'ad': 'Tarih', 'icon': Icons.account_balance_rounded, 'renk': Colors.purple},
      {'ad': 'Coğrafya', 'icon': Icons.public_rounded, 'renk': Colors.teal},
    ];

    return dersler.map((ders) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _buildUploadButton(
        title: '${ders['ad']} Sorularını Yükle',
        subtitle: 'Sadece ${ders['ad']} dersini günceller',
        icon: ders['icon'] as IconData,
        color: ders['renk'] as Color,
        onTap: _isUploading ? null : () => _handleUploadDers(ders['ad'] as String),
      ),
    )).toList();
  }

  Widget _buildUploadButton({required String title, required String subtitle, required IconData icon, required Color color, VoidCallback? onTap, bool isMain = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.all(isMain ? 18 : 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isMain ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withValues(alpha: isMain ? 0.7 : 0.4), width: isMain ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle), child: Icon(icon, color: color, size: isMain ? 30 : 24)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: isMain ? 16 : 14, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.upload_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogPanel() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
      child: ListView.builder(
        controller: _logScrollController,
        itemCount: _logMessages.length,
        itemBuilder: (logCtx, index) {
          final msg = _logMessages[index];
          Color color = Colors.white70;
          if (msg.startsWith('✅')) color = Colors.greenAccent;
          if (msg.startsWith('❌')) color = Colors.redAccent;
          if (msg.startsWith('🚀')) color = const Color(0xFF00E5FF);
          if (msg.startsWith('🗑️')) color = Colors.orange;
          return Text(msg, style: GoogleFonts.sourceCodePro(color: color, fontSize: 11));
        },
      ),
    );
  }

  Widget _buildSoruSayilariPanel() {
    if (_loadingSayilar) return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    if (_soruSayilari.isEmpty) return Text('Firebase\'de henüz soru yok.', style: GoogleFonts.poppins(color: Colors.white54));

    return Column(
      children: _soruSayilari.entries.map((entry) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
        child: Row(
          children: [
            Expanded(child: Text(entry.key, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF00E5FF).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text('${entry.value} soru', style: GoogleFonts.poppins(color: const Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.poppins(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.white30),
          prefixIcon: maxLines == 1 ? Icon(icon, color: Colors.white54) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildGlobalAnnouncementsPanel() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('global_notifications')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              'Şu anda aktif duyuru yok.',
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Column(
          children: docs.map((doc) => _buildAnnouncementCard(doc)).toList(),
        );
      },
    );
  }

  Widget _buildAnnouncementCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = (data['title'] ?? 'Başlıksız duyuru').toString();
    final message = (data['message'] ?? '').toString();
    final type = (data['type'] ?? 'admin_announcement').toString();
    final createdAt = data['createdAt'];
    String dateText = 'Tarih yok';

    if (createdAt is Timestamp) {
      final date = createdAt.toDate();
      dateText = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign_rounded, color: Color(0xFF00E5FF), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$dateText · $type',
                      style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Duyuruyu sil',
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                onPressed: () => _deleteGlobalAnnouncement(doc.id, title),
              ),
            ],
          ),
          if (message.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12.5, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteGlobalAnnouncement(String docId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F6A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Duyuru silinsin mi?',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '“$title” duyurusu pasif hale getirilecek ve artık kullanıcılara gösterilmeyecek.',
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç', style: GoogleFonts.poppins(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sil', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.collection('global_notifications').doc(docId).set({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showSnackbar('Duyuru silindi. Artık kullanıcılara gösterilmeyecek.', Colors.green);
    } catch (e) {
      _showSnackbar('Duyuru silinemedi: $e', Colors.redAccent);
    }
  }

  Future<void> _sendNotification() async {
    if (_notifTitleController.text.isEmpty || _notifMsgController.text.isEmpty) {
      _showSnackbar('Başlık ve içerik boş olamaz!', Colors.orange);
      return;
    }

    setState(() => _isSendingNotif = true);
    try {
      await _db.collection('global_notifications').add({
        'title': _notifTitleController.text,
        'message': _notifMsgController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'admin_announcement',
        'isActive': true,
      });
      _notifTitleController.clear();
      _notifMsgController.clear();
      _showSnackbar('Duyuru tüm kullanıcılara gönderildi! 📢', Colors.green);
    } catch (e) {
      _showSnackbar('Hata: $e', Colors.redAccent);
    } finally {
      setState(() => _isSendingNotif = false);
    }
  }

  void _showUserActionModal(String uid, String name, bool currentVipStatus) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1F6A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$name Yönetimi', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(currentVipStatus ? Icons.remove_circle_outline : Icons.workspace_premium_rounded, color: const Color(0xFFFFD700)),
                title: Text(currentVipStatus ? 'VIP Üyeliği İptal Et' : 'VIP Üye Yap (100 Enerji Tanımla)', style: GoogleFonts.poppins(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _db.collection('users').doc(uid).update({
                    'isVip': !currentVipStatus,
                    'maxEnergy': currentVipStatus ? 50 : 100,
                    'energy': currentVipStatus ? 50 : 100,
                    'vipWeakTopicRights': currentVipStatus ? 0 : 4,
                    'vipTestRights': currentVipStatus ? 0 : 1,
                    'vipPdfRights': currentVipStatus ? 0 : 1,
                    'vipRightsMonth': currentVipStatus ? null : '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
                  });
                  _showSnackbar('$name ${currentVipStatus ? "artık VIP değil" : "VIP yapıldı!"}', Colors.green);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flash_on_rounded, color: Colors.yellowAccent),
                title: Text('Bonus Enerjiyi 20 Yap', style: GoogleFonts.poppins(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final userRef = _db.collection('users').doc(uid);
                  final userDoc = await userRef.get();
                  final currentBonus = ((userDoc.data()?['bonusEnergy'] ?? 0) as num).toInt();
                  final newBonus = 20;
                  await userRef.update({'bonusEnergy': newBonus});
                  _showSnackbar('$name adlı öğrencinin bonus enerjisi 20 limite göre güncellendi!', Colors.green);
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                title: Text('Ligini ve XP\'sini Sıfırla', style: GoogleFonts.poppins(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _db.collection('users').doc(uid).update({'league': 'Bronz', 'totalXp': 0, 'weeklyXp': 0});
                  _showSnackbar('$name adlı kullanıcının ligi sıfırlandı.', Colors.orange);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HATALI SORULAR SEKMESİ
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildReportedQuestionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('reported_questions')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
        }
        final docs = snapshot.data?.docs ?? [];

        return Column(
          children: [
            // Başlık + Sayaç
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.flag_rounded,
                        color: Colors.redAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hatalı Soru Bildirimleri',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        Text('${docs.length} bildirim bekliyor',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (docs.isNotEmpty)
                    GestureDetector(
                      onTap: () => _confirmDeleteAll(docs),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: Text('Tümünü Sil',
                            style: GoogleFonts.poppins(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),

            if (docs.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 64, color: Color(0xFF00E676)),
                      const SizedBox(height: 16),
                      Text('Bildirilmiş soru yok!',
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 16)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc  = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final ts   = data['timestamp'] as Timestamp?;
                    final date = ts != null
                        ? '${ts.toDate().day}.${ts.toDate().month}.${ts.toDate().year} '
                          '${ts.toDate().hour.toString().padLeft(2, '0')}:'
                          '${ts.toDate().minute.toString().padLeft(2, '0')}'
                        : 'Tarih yok';

                    final isFromTrial =
                        (data['source'] ?? '') == 'deneme';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Üst satır: kaynak badge + tarih + sil
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isFromTrial
                                      ? const Color(0xFFFF9800)
                                          .withValues(alpha: 0.18)
                                      : const Color(0xFF00E5FF)
                                          .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isFromTrial
                                        ? const Color(0xFFFF9800)
                                            .withValues(alpha: 0.5)
                                        : const Color(0xFF00E5FF)
                                            .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  isFromTrial ? '📝 Deneme' : '📚 Normal',
                                  style: GoogleFonts.poppins(
                                    color: isFromTrial
                                        ? const Color(0xFFFF9800)
                                        : const Color(0xFF00E5FF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(date,
                                    style: GoogleFonts.poppins(
                                        color: Colors.white38,
                                        fontSize: 10)),
                              ),
                              GestureDetector(
                                onTap: () => _resolveReport(doc.id, data),
                                child: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: Color(0xFF00E676),
                                    size: 20),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () => _deleteReport(doc.id),
                                child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Soru metni
                          if ((data['soru_metni'] ?? '').isNotEmpty) ...[
                            Text('Soru:',
                                style: GoogleFonts.poppins(
                                    color: Colors.white54,
                                    fontSize: 11)),
                            const SizedBox(height: 4),
                            Text(
                              data['soru_metni'].toString(),
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 13),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Bilgi satırı
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if ((data['exam'] ?? '').isNotEmpty)
                                _infoBadge(
                                    Icons.school_rounded,
                                    data['exam'].toString()),
                              if ((data['subject'] ?? '').isNotEmpty)
                                _infoBadge(
                                    Icons.book_rounded,
                                    data['subject'].toString()),
                              if ((data['topic'] ?? '').isNotEmpty)
                                _infoBadge(
                                    Icons.topic_rounded,
                                    data['topic'].toString()),
                              if ((data['trial'] ?? '').isNotEmpty)
                                _infoBadge(
                                    Icons.quiz_rounded,
                                    data['trial'].toString()),
                              if ((data['userName'] ?? data['userEmail'] ?? data['uid'] ?? '').toString().isNotEmpty)
                                _infoBadge(
                                    Icons.person_rounded,
                                    (data['userName'] ?? data['userEmail'] ?? data['uid']).toString()),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }


  // ── 8. GERİ BİLDİRİMLER SEKME ──
  Widget _buildFeedbacksTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('feedbacks').orderBy('createdAt', descending: true).snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.feedback_outlined, size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                Text('Henüz geri bildirim yok.',
                    style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.feedback_rounded, color: Colors.greenAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Geri Bildirimler',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('${docs.length} geri bildirim',
                      style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                ]),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final String status = data['status'] ?? 'new';
                  final bool isNew = status == 'new';
                  final ts = data['createdAt'];
                  String dateStr = '';
                  if (ts is Timestamp) {
                    final d = ts.toDate();
                    dateStr = '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isNew
                          ? Colors.greenAccent.withValues(alpha: 0.07)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isNew
                              ? Colors.greenAccent.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          if (isNew)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('YENİ',
                                  style: GoogleFonts.poppins(
                                      color: Colors.greenAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          Expanded(
                            child: Text(data['email'] ?? 'Anonim',
                                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                          ),
                          Text(dateStr,
                              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              await _db.collection('feedbacks').doc(doc.id).delete();
                              _showSnackbar('Silindi.', Colors.orange);
                            },
                            child: const Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent, size: 18),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text(data['message'] ?? '',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            await _db.collection('feedbacks').doc(doc.id).update({'status': 'read'});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isNew
                                  ? Colors.greenAccent.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isNew ? '✓ Okundu Olarak İşaretle' : '✓ Okundu',
                              style: GoogleFonts.poppins(
                                  color: isNew ? Colors.greenAccent : Colors.white38,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
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
        );
      },
    );
  }
  // ══════════════════════════════════════════════════════════════════════════
  // VIP TALEPLERİ SEKMESİ
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildVipAnalysisRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('vip_analysis_requests')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFD500F9)));
        }
        final docs = snapshot.data?.docs ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD500F9).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD500F9).withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.insights_rounded, color: Color(0xFFD500F9), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('VIP Haftalık Analiz Talepleri',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text('${docs.length} analiz kaydı',
                          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ]),
            ),
            if (docs.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.analytics_outlined, size: 64, color: Color(0xFFD500F9)),
                      const SizedBox(height: 16),
                      Text('Henüz VIP analiz talebi yok.',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildVipAnalysisCard(doc.id, data);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildVipAnalysisCard(String docId, Map<String, dynamic> data) {
    final String name = (data['name'] ?? 'İsimsiz').toString();
    final String email = (data['email'] ?? '').toString();
    final String weakestTopic = (data['weakestTopic'] ?? 'Veri yetersiz').toString();
    final String advice = (data['advice'] ?? '').toString();
    final String status = (data['status'] ?? 'pending').toString();
    final int total = ((data['totalQuestions'] ?? 0) as num).toInt();
    final int correct = ((data['correct'] ?? 0) as num).toInt();
    final int wrong = ((data['wrong'] ?? 0) as num).toInt();
    final List weakTopics = (data['weakTopics'] is List) ? data['weakTopics'] as List : [];
    final List strongTopics = (data['strongTopics'] is List) ? data['strongTopics'] as List : [];
    final ts = data['createdAt'] as Timestamp?;
    final String dateStr = ts != null
        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year} '
          '${ts.toDate().hour.toString().padLeft(2, '0')}:'
          '${ts.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD500F9).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD500F9).withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFD500F9).withValues(alpha: 0.20),
              child: const Icon(Icons.person_search_rounded, color: Color(0xFFD500F9), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                Text(email,
                    style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: status == 'test_sent'
                    ? const Color(0xFF00E676).withValues(alpha: 0.16)
                    : Colors.orangeAccent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(status == 'test_sent' ? 'Test Gönderildi' : 'Bekliyor',
                  style: GoogleFonts.poppins(
                      color: status == 'test_sent' ? const Color(0xFF00E676) : Colors.orangeAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 12),
          _infoLine(Icons.warning_amber_rounded, 'En zayıf konu', weakestTopic, Colors.redAccent),
          const SizedBox(height: 6),
          _infoLine(Icons.quiz_rounded, 'Son 7 gün', '$total soru • $correct doğru • $wrong yanlış', const Color(0xFF00E5FF)),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoLine(Icons.schedule_rounded, 'Tarih', dateStr, Colors.white54),
          ],
          if (weakTopics.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Zayıf Konular', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: weakTopics.map((t) => _smallChip(t.toString(), Colors.redAccent)).toList()),
          ],
          if (strongTopics.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('İyi Konular', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: strongTopics.map((t) => _smallChip(t.toString(), const Color(0xFF00E676))).toList()),
          ],
          if (advice.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(advice,
                style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11, height: 1.45)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: status == 'test_sent' ? Colors.white12 : const Color(0xFFD500F9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: status == 'test_sent'
                    ? null
                    : () async {
                        await _db.collection('vip_analysis_requests').doc(docId).update({
                          'status': 'test_sent',
                          'testSentAt': FieldValue.serverTimestamp(),
                        });
                      },
                icon: const Icon(Icons.mark_email_read_rounded, size: 18),
                label: Text(status == 'test_sent' ? 'Tamamlandı' : 'Test Gönderildi İşaretle',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _smallChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: GoogleFonts.poppins(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }


  Widget _buildVipContentRequestsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildVipContentSection(
          title: 'PDF Talepleri',
          icon: Icons.description_rounded,
          color: const Color(0xFFFFD700),
          collection: 'vip_pdf_requests',
          emptyText: 'Henüz PDF talebi yok.',
        ),
        const SizedBox(height: 18),
        _buildVipContentSection(
          title: 'Kişisel Test Talepleri',
          icon: Icons.edit_note_rounded,
          color: const Color(0xFF8A52FF),
          collection: 'vip_personal_test_requests',
          emptyText: 'Henüz kişisel test talebi yok.',
        ),
      ],
    );
  }

  Widget _buildVipContentSection({
    required String title,
    required IconData icon,
    required Color color,
    required String collection,
    required String emptyText,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection(collection).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
                Text('${docs.length}',
                    style: GoogleFonts.poppins(
                        color: color, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                Center(child: CircularProgressIndicator(color: color))
              else if (docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(emptyText,
                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                  ),
                )
              else
                ...docs.map((d) => _buildVipContentRequestCard(
                      collection: collection,
                      docId: d.id,
                      data: d.data() as Map<String, dynamic>,
                      color: color,
                    )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVipContentRequestCard({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    required Color color,
  }) {
    final name = (data['name'] ?? data['userName'] ?? 'İsimsiz').toString();
    final email = (data['email'] ?? data['userEmail'] ?? '').toString();
    final topic = (data['topic'] ?? 'Konu belirtilmemiş').toString();
    final note = (data['note'] ?? '').toString();
    final mailInstruction = (data['mailInstruction'] ?? '').toString();
    final List requestedTopics = data['requestedTopics'] is List ? data['requestedTopics'] as List : [];
    final List wrongSummary = data['wrongSummary'] is List ? data['wrongSummary'] as List : [];
    final status = (data['status'] ?? 'pending').toString();
    final ts = data['createdAt'] as Timestamp?;
    final date = ts != null
        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year} '
          '${ts.toDate().hour.toString().padLeft(2, '0')}:'
          '${ts.toDate().minute.toString().padLeft(2, '0')}'
        : 'Tarih yok';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              if (email.isNotEmpty)
                Text(email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'completed'
                  ? const Color(0xFF00E676).withValues(alpha: 0.15)
                  : Colors.orangeAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(status == 'completed' ? 'Tamamlandı' : 'Bekliyor',
                style: GoogleFonts.poppins(
                    color: status == 'completed'
                        ? const Color(0xFF00E676)
                        : Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        _infoLine(Icons.topic_rounded, 'Konu', topic, color),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 5),
          _infoLine(Icons.notes_rounded, 'Not', note, Colors.white54),
        ],
        if (mailInstruction.isNotEmpty) ...[
          const SizedBox(height: 5),
          _infoLine(Icons.mark_email_read_rounded, 'Mail', mailInstruction, const Color(0xFF00E5FF)),
        ],
        if (requestedTopics.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: requestedTopics
                .map((t) => _smallChip(t.toString(), color))
                .toList(),
          ),
        ],
        if (wrongSummary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yanlış Özeti',
                    style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                ...wrongSummary.take(5).map((item) => Text(
                      '• ${item.toString()}',
                      style: GoogleFonts.poppins(
                          color: Colors.white54, fontSize: 10, height: 1.35),
                    )),
              ],
            ),
          ),
        ],
        const SizedBox(height: 5),
        _infoLine(Icons.schedule_rounded, 'Tarih', date, Colors.white54),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'completed' ? Colors.white12 : color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: status == 'completed'
                  ? null
                  : () async {
                      await _db.collection(collection).doc(docId).update({
                        'status': 'completed',
                        'completedAt': FieldValue.serverTimestamp(),
                      });
                    },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(status == 'completed' ? 'Tamamlandı' : 'Tamamlandı İşaretle',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildVipRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('vip_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)));
        }
 
        final docs = snapshot.data?.docs ?? [];
 
        return Column(
          children: [
            // Başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: Color(0xFFFFD700), size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VIP Talepleri',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text('${docs.length} onay bekliyor',
                        style: GoogleFonts.poppins(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ]),
            ),
 
            if (docs.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 64, color: Color(0xFF00E676)),
                      const SizedBox(height: 16),
                      Text('Bekleyen VIP talebi yok!',
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 16)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc  = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildVipRequestCard(doc.id, data);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
 
  Widget _buildVipRequestCard(String docId, Map<String, dynamic> data) {
    final String uid       = data['uid']       ?? '';
    final String name      = data['name']      ?? 'İsimsiz';
    final String email     = data['email']     ?? '';
    final String planLabel = data['planLabel'] ?? '';
    final String paymentStatus = data['paymentStatus'] ?? 'manual_pending';
    final int durationDays = (data['durationDays'] ?? (data['plan'] == 'yearly' ? 365 : 30)).toInt();
    final ts               = data['createdAt'] as Timestamp?;
    final String dateStr   = ts != null
        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year} '
          '${ts.toDate().hour.toString().padLeft(2, '0')}:'
          '${ts.toDate().minute.toString().padLeft(2, '0')}'
        : '';
 
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst satır
          Row(children: [
            CircleAvatar(
              backgroundColor:
                  const Color(0xFFFFD700).withValues(alpha: 0.2),
              child: const Icon(Icons.person,
                  color: Color(0xFFFFD700), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.poppins(
                          color:      Colors.white,
                          fontSize:   14,
                          fontWeight: FontWeight.bold)),
                  Text(email,
                      style: GoogleFonts.poppins(
                          color:    Colors.white54,
                          fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(dateStr,
                style: GoogleFonts.poppins(
                    color: Colors.white38, fontSize: 10)),
          ]),
          const SizedBox(height: 10),
 
          // Plan bilgisi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        const Color(0xFFFFD700).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
            ),
            child: Text('$planLabel • ${durationDays == 365 ? '1 yıl' : '1 ay'} • ${paymentStatus == 'paid' ? 'ödendi' : 'manuel'}',
                style: GoogleFonts.poppins(
                    color:      const Color(0xFFFFD700),
                    fontSize:   12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
 
          // Aksiyon butonları
          Row(children: [
            // ONAYLA
            Expanded(
              child: GestureDetector(
                onTap: () => _approveVipRequest(docId, uid, name),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('✅ Onayla',
                        style: GoogleFonts.poppins(
                            color:      const Color(0xFF0A0E43),
                            fontSize:   13,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // REDDET
            Expanded(
              child: GestureDetector(
                onTap: () => _rejectVipRequest(docId, uid, name),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color:        Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: Text('❌ Reddet',
                        style: GoogleFonts.poppins(
                            color:      Colors.redAccent,
                            fontSize:   13,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
 
  Future<void> _approveVipRequest(
      String docId, String uid, String name) async {
    try {
      final reqDoc = await _db.collection('vip_requests').doc(docId).get();
      final req = reqDoc.data() ?? <String, dynamic>{};
      final int durationDays = (req['durationDays'] ?? (req['plan'] == 'yearly' ? 365 : 30)).toInt();
      final expiry = DateTime.now().add(Duration(days: durationDays));

      // 1. Kullanıcıyı VIP yap (user_service ile aynı mantık)
      await _db.collection('users').doc(uid).update({
        'isVip':    true,
        'maxEnergy': 100,
        'energy':    100,
        'vipWeakTopicRights': 4,
        'vipTestRights':      1,
        'vipPdfRights':       1,
        'vipRightsMonth':     '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
        'vipActivatedAt':     FieldValue.serverTimestamp(),
        'vipExpiresAt':       Timestamp.fromDate(expiry),
      });
 
      // 2. Talebi "approved" olarak işaretle
      await _db.collection('vip_requests').doc(docId).update({
        'status':     'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'durationDays': durationDays,
        'expiresAt': Timestamp.fromDate(expiry),
      });
 
      await _db.collection('users').doc(uid).collection('notifications').add({
        'title': 'VIP Üyeliğiniz Aktif 👑',
        'message': 'VIP üyeliğiniz onaylandı. Bitiş tarihi: ${expiry.day}/${expiry.month}/${expiry.year}.',
        'type': 'vip_approved',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _showSnackbar('$name → $durationDays gün VIP yapıldı! 👑', Colors.green);
    } catch (e) {
      _showSnackbar('Hata: $e', Colors.redAccent);
    }
  }
 
  Future<void> _rejectVipRequest(
      String docId, String uid, String name) async {
    try {
      await _db.collection('vip_requests').doc(docId).update({
        'status':     'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      _showSnackbar('$name talebi reddedildi.', Colors.orange);
    } catch (e) {
      _showSnackbar('Hata: $e', Colors.redAccent);
    }
  }

  Widget _infoBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }

  Future<void> _resolveReport(String docId, Map<String, dynamic> data) async {
    try {
      final uid = data['uid']?.toString();
      await _db.collection('reported_questions').doc(docId).set({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (uid != null && uid.isNotEmpty) {
        await _db.collection('users').doc(uid).collection('notifications').add({
          'title': 'Sorun Bildiriminiz Çözüldü ✅',
          'message': 'Soruyu bildirdiğiniz için teşekkür ederiz. Bildiriminizi aldık ve hatalı soruyu düzelttik. Başarılar dileriz — Bilgi Rotası Ailesi',
          'type': 'reported_question_resolved',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      _showSnackbar('Bildirim çözüldü olarak işaretlendi ve kullanıcıya mesaj gönderildi.', Colors.green);
    } catch (e) {
      _showSnackbar('Hata: $e', Colors.redAccent);
    }
  }

  Future<void> _deleteReport(String docId) async {
    await _db.collection('reported_questions').doc(docId).delete();
    _showSnackbar('Bildirim silindi.', Colors.green);
  }

  Future<void> _confirmDeleteAll(List<QueryDocumentSnapshot> docs) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F6A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tümünü Sil',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '${docs.length} bildirimi silmek istediğine emin misin?',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal',
                style: GoogleFonts.poppins(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sil',
                style: GoogleFonts.poppins(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final batch = _db.batch();
    for (final doc in docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    _showSnackbar('Tüm bildirimler silindi.', Colors.green);
  }
}