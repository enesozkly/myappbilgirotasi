import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vip_statistics_page.dart';

/// VIP Satın Alma / Yönetim Sayfası
/// Navbar'daki 👑 VIP butonundan açılır.
///
/// AKIŞ:
///   1. Kullanıcı "VIP Ol" tuşuna basar → Firestore'da vip_requests belgesi oluşur
///   2. Admin, uygulama içi Admin Paneli (VIP Talepleri sekmesi) VEYA
///      Firebase Console üzerinden talebi onaylar → isVip: true yazılır
///   3. Sayfa, kullanıcı belgesini gerçek zamanlı dinler → VIP durumu otomatik güncellenir
class VipPage extends StatefulWidget {
  const VipPage({super.key});

  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> with TickerProviderStateMixin {
  late AnimationController _bgController;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  final String? _email = FirebaseAuth.instance.currentUser?.email;

  // Durumlar
  bool _isVip = false;
  bool _loading = true;
  bool _requestPending = false; // Onay bekleyen talep var mı?
  bool _submitting = false; // Talep gönderiliyor mu?
  bool _yearly = true; // Seçili plan
  final TextEditingController _pdfTopicController = TextEditingController();
  bool _sendingPdfTopic = false;
  bool _sendingPersonalTest = false;
  int _vipWeakTopicRights = 0;
  int _vipPdfRights = 0;
  int _vipTestRights = 0;
  String _userName = 'İsimsiz';

  String? _pendingDocId; // Mevcut talep belgesi ID'si

  // Fiyatlar
  static const String _monthlyPrice = '₺79,99 / ay';
  static const String _yearlyPrice = '₺599,99 / yıl';
  static const String _yearlyNote = 'Aylığa göre %38 tasarruf';

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _loadStatus();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _pdfTopicController.dispose();
    super.dispose();
  }

  String _currentVipRightsMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>> _ensureMonthlyVipRights(
      Map<String, dynamic> data) async {
    if (_uid == null || data['isVip'] != true) return data;
    final monthKey = _currentVipRightsMonth();
    final needsReset = data['vipRightsMonth'] != monthKey ||
        !data.containsKey('vipWeakTopicRights') ||
        !data.containsKey('vipPdfRights') ||
        !data.containsKey('vipTestRights');
    if (!needsReset) return data;

    final updates = <String, dynamic>{
      'vipWeakTopicRights': 4,
      'vipPdfRights': 1,
      'vipTestRights': 1,
      'vipRightsMonth': monthKey,
    };
    await _db
        .collection('users')
        .doc(_uid)
        .set(updates, SetOptions(merge: true));
    return {...data, ...updates};
  }

  Future<bool> _consumeVipRight(String field, int defaultMonthlyValue) async {
    if (_uid == null) return false;
    final ref = _db.collection('users').doc(_uid);
    final monthKey = _currentVipRightsMonth();
    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || data['isVip'] != true) return false;

      var rights = ((data[field] ?? defaultMonthlyValue) as num).toInt();
      final updates = <String, dynamic>{};
      if (data['vipRightsMonth'] != monthKey) {
        updates.addAll({
          'vipWeakTopicRights': 4,
          'vipPdfRights': 1,
          'vipTestRights': 1,
          'vipRightsMonth': monthKey,
        });
        rights = defaultMonthlyValue;
      }
      if (rights <= 0) {
        if (updates.isNotEmpty) tx.set(ref, updates, SetOptions(merge: true));
        return false;
      }
      updates[field] = rights - 1;
      tx.set(ref, updates, SetOptions(merge: true));
      return true;
    });
  }

  // ── Durum Yükle: VIP mi? Bekleyen talep var mı? ───────────────────────
  Future<void> _loadStatus() async {
    if (_uid == null) {
      setState(() => _loading = false);
      return;
    }

    // Kullanıcı belgesi
    final userDoc = await _db.collection('users').doc(_uid).get();
    final userData = userDoc.exists
        ? await _ensureMonthlyVipRights(userDoc.data()!)
        : <String, dynamic>{};
    final bool isVip = userData['isVip'] == true;

    // Bekleyen talep
    final requests = await _db
        .collection('vip_requests')
        .where('uid', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (mounted) {
      setState(() {
        _isVip = isVip;
        _requestPending = requests.docs.isNotEmpty;
        _pendingDocId =
            requests.docs.isNotEmpty ? requests.docs.first.id : null;
        _userName = (userData['name'] ??
                FirebaseAuth.instance.currentUser?.displayName ??
                'İsimsiz')
            .toString();
        _vipWeakTopicRights =
            isVip ? ((userData['vipWeakTopicRights'] ?? 4) as num).toInt() : 0;
        _vipPdfRights =
            isVip ? ((userData['vipPdfRights'] ?? 1) as num).toInt() : 0;
        _vipTestRights =
            isVip ? ((userData['vipTestRights'] ?? 1) as num).toInt() : 0;
        _loading = false;
      });
    }
  }

  // ── VIP Talebi Gönder ─────────────────────────────────────────────────
  Future<void> _sendVipRequest({bool paymentCompleted = false}) async {
    if (_uid == null || _submitting) return;

    // Kullanıcı adını al
    final userDoc = await _db.collection('users').doc(_uid).get();
    final String name = userDoc.data()?['name'] ?? 'İsimsiz';

    setState(() => _submitting = true);

    try {
      // Zaten bekleyen talep var mı? (çift gönderimi önle)
      final existing = await _db
          .collection('vip_requests')
          .where('uid', isEqualTo: _uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (mounted) setState(() => _requestPending = true);
        return;
      }

      // Yeni talep belgesi oluştur
      final docRef = await _db.collection('vip_requests').add({
        'uid': _uid,
        'name': name,
        'email': _email ?? '',
        'plan': _yearly ? 'yearly' : 'monthly',
        'planLabel':
            _yearly ? 'Yıllık ($_yearlyPrice)' : 'Aylık ($_monthlyPrice)',
        'status': 'pending', // pending | approved | rejected
        'paymentStatus': paymentCompleted ? 'paid' : 'manual_pending',
        'paymentMessage': paymentCompleted
            ? 'VIP ödemesi başarıyla gerçekleşti; admin onayı bekleniyor.'
            : 'Manuel VIP talebi oluşturuldu.',
        'durationDays': _yearly ? 365 : 30,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _requestPending = true;
          _pendingDocId = docRef.id;
        });
        _showSnack(
          paymentCompleted
              ? '✅ VIP ödemeniz başarıyla gerçekleşmiştir. Talebiniz 24 saat içinde admin tarafından onaylanacaktır.'
              : '✅ Talebiniz alındı! En kısa sürede onaylanacak.',
          const Color(0xFF00C853),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Hata oluştu: $e', Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Ödeme Ekranı Simülasyonu / Entegrasyon Noktası ─────────────────────
  Future<void> _startVipPurchase() async {
    if (_submitting) return;
    final planLabel =
        _yearly ? 'Yıllık ($_yearlyPrice)' : 'Aylık ($_monthlyPrice)';
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1B1F6A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('VIP Üyelik Satın Al',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(planLabel,
                  style: GoogleFonts.poppins(
                      color: const Color(0xFFFFD700),
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Text(
                'Bu ekran ödeme sağlayıcısı bağlanana kadar güvenli bir satın alma onayı oluşturur. Gerçek ödeme altyapısı eklendiğinde burada Iyzico/RevenueCat/Play Billing akışı başlatılmalıdır.',
                style: GoogleFonts.poppins(
                    color: Colors.white60, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: const Color(0xFF0A0E43),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Ödemeyi Tamamla',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Vazgeç',
                      style: GoogleFonts.poppins(color: Colors.white54)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await _sendVipRequest(paymentCompleted: true);
    }
  }

  Future<void> _submitPdfTopicRequest() async {
    if (_uid == null || _sendingPdfTopic) return;
    final topic = _pdfTopicController.text.trim();
    if (topic.length < 3) {
      _showSnack(
          'Lütfen istediğiniz PDF adını veya konusunu yazın.', Colors.orange);
      return;
    }

    setState(() => _sendingPdfTopic = true);
    try {
      final hasRight = await _consumeVipRight('vipPdfRights', 1);
      if (!hasRight) {
        _showSnack(
            'Bu ayki konu anlatım PDF hakkınız tükenmiş.', Colors.orange);
        return;
      }

      // Admin paneline tam istenen formatta düşmesi için:
      await _db.collection('vip_pdf_requests').add({
        'uid': _uid,
        'name': _userName,
        'email': _email ?? '',
        'pdfTitle': topic,
        'topic': topic,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted)
        setState(
            () => _vipPdfRights = _vipPdfRights > 0 ? _vipPdfRights - 1 : 0);
      _pdfTopicController.clear();
      _showSnack(
          'PDF talebiniz VIP İçerik > PDF Talepleri bölümüne düştü! En kısa sürede gönderilecektir.',
          const Color(0xFF00C853));
    } catch (e) {
      _showSnack('Hata: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _sendingPdfTopic = false);
    }
  }

  Future<void> _showPdfTopicQuickDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101B49),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text("PDF Talebi",
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "İstediğin konuyu yaz",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Vazgeç",
                  style: GoogleFonts.poppins(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: const Color(0xFF0A0E43)),
            onPressed: () async {
              final topic = controller.text.trim();
              if (topic.length < 3) return;
              Navigator.pop(ctx);
              _pdfTopicController.text = topic;
              await _submitPdfTopicRequest();
            },
            child: Text("Gönder",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showPersonalTestDialog() async {
    if (_uid == null || _sendingPersonalTest) return;
    final topicController = TextEditingController();
    final noteController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101B49),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text("Kişisel Test Talebi",
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: topicController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Zorlandığın konu / ders",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "İstersen kısa not ekle",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Vazgeç",
                  style: GoogleFonts.poppins(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF0A0E43)),
            onPressed: () async {
              final topic = topicController.text.trim();
              final note = noteController.text.trim();
              if (topic.length < 3) return;
              Navigator.pop(ctx);
              setState(() => _sendingPersonalTest = true);
              try {
                final hasRight = await _consumeVipRight('vipTestRights', 1);
                if (!hasRight) {
                  if (mounted)
                    _showSnack('Bu ayki kişisel test talebi hakkınız tükenmiş.',
                        Colors.orange);
                  return;
                }
                await _db.collection("vip_personal_test_requests").add({
                  "uid": _uid,
                  "name": _userName,
                  "email": _email ?? "",
                  "topic": topic,
                  "note": note,
                  "status": "pending",
                  "createdAt": FieldValue.serverTimestamp(),
                });
                if (mounted)
                  setState(() => _vipTestRights =
                      _vipTestRights > 0 ? _vipTestRights - 1 : 0);
                if (mounted) {
                  _showSnack(
                      "Kişisel test talebiniz alındı. En kısa sürede hazırlanacaktır.",
                      const Color(0xFF00C853));
                }
              } catch (e) {
                if (mounted) _showSnack("Hata: $e", Colors.redAccent);
              } finally {
                if (mounted) setState(() => _sendingPersonalTest = false);
              }
            },
            child: Text("Talep Gönder",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Talebi İptal Et ───────────────────────────────────────────────────
  Future<void> _cancelRequest() async {
    if (_pendingDocId == null) return;
    try {
      await _db.collection('vip_requests').doc(_pendingDocId).update({
        'status': 'cancelled',
      });
      if (mounted) {
        setState(() {
          _requestPending = false;
          _pendingDocId = null;
        });
        _showSnack('Talep iptal edildi.', Colors.orange);
      }
    } catch (e) {
      if (mounted) _showSnack('Hata: $e', Colors.redAccent);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Kullanıcı belgesini gerçek zamanlı dinle → VIP onaylandığında otomatik güncellenir
    return StreamBuilder<DocumentSnapshot>(
      stream: _uid != null
          ? _db.collection('users').doc(_uid).snapshots()
          : const Stream.empty(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final bool vipNow = data['isVip'] == true;
          // VIP onaylandıysa state güncelle
          // vip_page.dart içindeki StreamBuilder kısmını bu şekilde güncelle:
          if (vipNow && !_isVip) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isVip = true;
                  _requestPending = false;
                  // VIP haklarını da burada güncellemezsek butonlar görünmeyebilir veya 0 hakkın var diyebilir
                  _vipPdfRights = (data['vipPdfRights'] ?? 1).toInt();
                  _vipWeakTopicRights =
                      (data['vipWeakTopicRights'] ?? 4).toInt();
                  _vipTestRights = (data['vipTestRights'] ?? 1).toInt();
                });
                _showSnack(
                    '🎉 VIP Üyeliğiniz aktif edildi!', const Color(0xFF00C853));
              }
            });
          }
        }

        return Scaffold(
          body: Stack(
            children: [
              // Arka plan
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0A0E43),
                      Color(0xFF1B1F6A),
                      Color(0xFF0D1B3E)
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              _cloud(
                  top: size.height * 0.08, scale: 1.0, speed: 0.5, right: true),
              _cloud(
                  top: size.height * 0.55,
                  scale: 1.3,
                  speed: 0.4,
                  right: false),

              SafeArea(
                child: Column(children: [
                  // ── Üst Bar ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('VIP Üyelik',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 42),
                    ]),
                  ),

                  if (_loading)
                    const Expanded(
                      child: Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFFFFD700)),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const BouncingScrollPhysics(),
                        child: Column(children: [
                          // ── Aktif VIP Bandı ──────────────────────
                          if (_isVip) ...[
                            _buildActiveVipBanner(),
                            const SizedBox(height: 16),
                            _buildVipActionHub(),
                            const SizedBox(height: 20),
                            _buildPdfTopicRequestCard(),
                            const SizedBox(height: 20),
                          ],

                          // ── Bekleyen Talep Bandı ─────────────────
                          if (!_isVip && _requestPending) ...[
                            _buildPendingBanner(),
                            const SizedBox(height: 20)
                          ],

                          // ── Hero Banner ──────────────────────────
                          _buildHeroBanner(),
                          const SizedBox(height: 24),

                          // ── Avantajlar ───────────────────────────
                          _buildAdvantagesList(),
                          const SizedBox(height: 24),

                          // ── Plan Seçimi & Buton ──────────────────
                          if (!_isVip && !_requestPending) ...[
                            _buildPlanSelector(),
                            const SizedBox(height: 20),
                            _buildRequestButton(),
                            const SizedBox(height: 12),
                            Text(
                              '* Talebiniz admin tarafından onaylandıktan sonra\n  VIP üyeliğiniz aktif edilir.',
                              style: GoogleFonts.poppins(
                                  color: Colors.white38, fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          // ── İptal Butonu ─────────────────────────
                          if (!_isVip && _requestPending) ...[
                            _buildCancelButton(),
                            const SizedBox(height: 12),
                          ],

                          const SizedBox(height: 30),
                        ]),
                      ),
                    ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Aktif VIP Bandı ────────────────────────────────────────────────────
  Widget _buildActiveVipBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF00C853).withValues(alpha: 0.2),
          const Color(0xFF00E676).withValues(alpha: 0.1),
        ]),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.verified_rounded, color: Color(0xFF00E676), size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VIP Üyeliğin Aktif! 👑',
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF00E676),
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              Text('Tüm ayrıcalıklardan yararlanıyorsun.',
                  style:
                      GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Bekleyen Talep Bandı ───────────────────────────────────────────────
  Widget _buildPendingBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFFFD700).withValues(alpha: 0.15),
          const Color(0xFFFF8C00).withValues(alpha: 0.08),
        ]),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFFFFD700),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Talebiniz Onay Bekliyor ⏳',
                  style: GoogleFonts.poppins(
                      color: const Color(0xFFFFD700),
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              Text('Admin onayladığında VIP üyeliğiniz otomatik aktif olur.',
                  style:
                      GoogleFonts.poppins(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Hero Banner ────────────────────────────────────────────────────────
  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF8C00), Color(0xFFFF5722)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.4),
              blurRadius: 25,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Text('👑', style: TextStyle(fontSize: 40)),
        ),
        const SizedBox(height: 16),
        Text(
          'Sınav Kazandıran Paket',
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'VIP üyelikle eğitimini bir üst seviyeye taşı!',
          style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  // ── Avantajlar Listesi ─────────────────────────────────────────────────
  Widget _buildAdvantagesList() {
    final advantages = [
      {
        'icon': '🔍',
        'title': 'Haftalık Zayıf Konu Analizi',
        'desc':
            'Ayda 4 kez, son çözdüğün sorulara göre en çok zorlandığın konular belirlenir. Hangi derse odaklanman gerektiğini net görürsün.'
      },
      {
        'icon': '📝',
        'title': 'Kişisel Test Oluşturma',
        'desc':
            'Eksik olduğun konular bize düşer; sana özel tekrar testi hazırlanıp mail adresine gönderilmek üzere işleme alınır.'
      },
      {
        'icon': '📄',
        'title': '1 Konu Anlatım PDF',
        'desc':
            'Her ay istediğin bir konuda özet, anlaşılır ve sınav odaklı PDF talep edebilirsin. Talebin admin paneline düşer.'
      },
      {
        'icon': '🤖',
        'title': 'Yanlış Kutusunda AI Çözüm',
        'desc':
            'Kaydettiğin yanlış sorularda yalnızca cevabı değil, mantığı da görürsün. AI destekli çözümle aynı hatayı tekrar yapmaman hedeflenir.'
      },
      {
        'icon': '⚡',
        'title': '2 Kat Enerji Kapasitesi',
        'desc':
            '100 ana enerjiyle daha uzun ve kesintisiz çalışma seansları yaparsın. Normal kullanıcı limiti 50 enerjidir.'
      },
      {
        'icon': '🔄',
        'title': '2 Kat Enerji Yenileme Hızı',
        'desc':
            'Enerjin daha hızlı dolar: VIP kullanıcıda 1 saatte +10 enerji, normal kullanıcıda 2 saatte +5 enerji yenilenir.'
      },
      {
        'icon': '🎯',
        'title': 'Görevlerden Bonus Enerji',
        'desc':
            'Günlük ve haftalık görevlerde daha verimli ilerlersin; çalışma temponu düşürmeden daha fazla pratik yaparsın.'
      },
      {
        'icon': '📦',
        'title': 'Yanlış Kutusu 50 Soru Limiti',
        'desc':
            'Daha çok hatanı saklayıp tekrar çözebilirsin. Normal kullanıcı 10 soru, VIP kullanıcı 50 soru tutabilir.'
      },
      {
        'icon': '🚫',
        'title': 'Reklamsız Uygulama',
        'desc':
            'Ders akışın bölünmez. Bölüm bitişlerinde veya denemelerde reklam görmeden çalışmaya devam edersin.'
      },
      {
        'icon': '🏅',
        'title': 'Sıralamada VIP Rozet',
        'desc':
            'Profilin ve sıralamadaki görünümün özel VIP çerçevesiyle ayrışır; motivasyon ve prestij tarafı güçlenir.'
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VIP Ayrıcalıkları',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...advantages
              .map((a) => _advantageRow(a['icon']!, a['title']!, a['desc']!)),
        ],
      ),
    );
  }

  Widget _advantageRow(String icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            Text(desc,
                style:
                    GoogleFonts.poppins(color: Colors.white60, fontSize: 11)),
          ]),
        ),
        const Icon(Icons.check_circle_rounded,
            color: Color(0xFFFFD700), size: 18),
      ]),
    );
  }

  Widget _buildVipActionHub() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("VIP Hızlı Erişim",
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
              "VIP ayrıcalıklarını tek dokunuşla kullanabilmen için hızlı işlem alanı.",
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _quickActionButton(
                icon: Icons.analytics_rounded,
                title: "Zayıf Konu\nAnalizi",
                footer: "Kalan hak: $_vipWeakTopicRights",
                accent: const Color(0xFFFFD700),
                onTap: () {
                  Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const VipStatisticsPage()))
                      .then((_) => _loadStatus());
                },
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _quickActionButton(
                icon: Icons.description_rounded,
                title: "PDF\nTalebi",
                footer: "Kalan hak: $_vipPdfRights",
                accent: const Color(0xFF00E5FF),
                onTap: _showPdfTopicQuickDialog,
              )),
              const SizedBox(width: 10),
              Expanded(
                  child: _quickActionButton(
                icon: Icons.edit_note_rounded,
                title: "Kişisel Test\nTalebi",
                footer: "Kalan hak: $_vipTestRights",
                accent: const Color(0xFF8A52FF),
                onTap: _showPersonalTestDialog,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton(
      {required IconData icon,
      required String title,
      required String footer,
      required Color accent,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 26),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.3)),
            const SizedBox(height: 6),
            Text(footer,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    color: accent, fontSize: 9.5, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfTopicRequestCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bu Ayki Konu Anlatım PDF Hakkın · Kalan: $_vipPdfRights',
              style: GoogleFonts.poppins(
                  color: const Color(0xFFFFD700),
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
              'İstediğin konuyu yaz; talebin admin paneline düşsün ve PDF mail adresine gönderilsin.',
              style: GoogleFonts.poppins(
                  color: Colors.white60, fontSize: 12, height: 1.4)),
          const SizedBox(height: 12),
          TextField(
            controller: _pdfTopicController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Örn: Paragrafta Anlam, Türev, KPSS Tarih...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: const Color(0xFF0A0E43),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _sendingPdfTopic ? null : _submitPdfTopicRequest,
              icon: _sendingPdfTopic
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: Text('PDF Talebi Gönder',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Plan Seçimi ────────────────────────────────────────────────────────
  Widget _buildPlanSelector() {
    return Row(children: [
      Expanded(child: _planCard(isYearly: false)),
      const SizedBox(width: 12),
      Expanded(child: _planCard(isYearly: true)),
    ]);
  }

  Widget _planCard({required bool isYearly}) {
    final bool selected = _yearly == isYearly;
    final Color accent =
        isYearly ? const Color(0xFFFFD700) : const Color(0xFF00E5FF);

    return GestureDetector(
      onTap: () => setState(() => _yearly = isYearly),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : Colors.white.withValues(alpha: 0.15),
            width: selected ? 2.0 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: accent.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Column(children: [
          if (isYearly)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Tavsiye Edilir',
                  style: GoogleFonts.poppins(
                      color: const Color(0xFFFFD700),
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            )
          else
            const SizedBox(height: 20),
          const SizedBox(height: 10),
          Text(isYearly ? 'Yıllık Plan' : 'Aylık Plan',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            isYearly ? _yearlyPrice : _monthlyPrice,
            style: GoogleFonts.poppins(
                color: accent,
                fontSize: isYearly ? 13 : 14,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          if (isYearly) ...[
            const SizedBox(height: 4),
            Text(_yearlyNote,
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ]),
      ),
    );
  }

  // ── Talep Gönder Butonu ────────────────────────────────────────────────
  Widget _buildRequestButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
        ),
        onPressed: _submitting ? null : _startVipPurchase,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: _submitting
                ? const CircularProgressIndicator(color: Colors.white)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('👑', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Text(
                        'VIP Üyelik Satın Al',
                        style: GoogleFonts.poppins(
                            color: const Color(0xFF0A0E43),
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Talebi İptal Et Butonu ─────────────────────────────────────────────
  Widget _buildCancelButton() {
    return GestureDetector(
      onTap: _cancelRequest,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(
          child: Text('Talebi İptal Et',
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
        ),
      ),
    );
  }

  // ── Arka plan bulutu ───────────────────────────────────────────────────
  Widget _cloud({
    required double top,
    required double scale,
    required double speed,
    required bool right,
  }) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (ctx, _) {
        final sw = MediaQuery.of(ctx).size.width;
        final cw = 120.0 * scale;
        double off = (_bgController.value * speed * (sw + cw)) % (sw + cw);
        if (!right) off = sw - off;
        return Positioned(
          top: top,
          left: off - cw,
          child: Icon(Icons.cloud_rounded,
              color: Colors.white.withValues(alpha: 0.06), size: 120 * scale),
        );
      },
    );
  }
}
