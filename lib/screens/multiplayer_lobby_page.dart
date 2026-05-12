// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'multiplayer_quiz_page.dart';

class MultiplayerLobbyPage extends StatefulWidget {
  const MultiplayerLobbyPage({super.key});
  @override
  State<MultiplayerLobbyPage> createState() =>
      _MultiplayerLobbyPageState();
}

class _MultiplayerLobbyPageState extends State<MultiplayerLobbyPage>
    with TickerProviderStateMixin {
  final TextEditingController _codeCtrl = TextEditingController();
  StreamSubscription<DocumentSnapshot>? _roomSub;

  late AnimationController _fadeCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _pulseAnim;

  bool   _creating = false;
  bool   _joining  = false;
  bool   _waiting  = false;
  String _roomCode = '';

  // 🔥 DÜZELTİLDİ: Tam sınav adları — klasör eşleşmesi için
  static const List<Map<String, String>> _subjects = [
    // TYT
    {'label': 'TYT - Türkçe',     'exam': 'TYT',         'ders': 'Türkçe'},
    {'label': 'TYT - Matematik',   'exam': 'TYT',         'ders': 'Matematik'},
    {'label': 'TYT - Tarih',       'exam': 'TYT',         'ders': 'Tarih'},
    {'label': 'TYT - Coğrafya',    'exam': 'TYT',         'ders': 'Coğrafya'},
    {'label': 'TYT - Fizik',       'exam': 'TYT',         'ders': 'Fizik'},
    {'label': 'TYT - Kimya',       'exam': 'TYT',         'ders': 'Kimya'},
    {'label': 'TYT - Biyoloji',    'exam': 'TYT',         'ders': 'Biyoloji'},
    {'label': 'TYT - Felsefe',     'exam': 'TYT',         'ders': 'Felsefe'},
    // AYT Sayısal
    {'label': 'AYT Sayısal - Matematik', 'exam': 'AYT Sayısal', 'ders': 'Matematik'},
    {'label': 'AYT Sayısal - Fizik',     'exam': 'AYT Sayısal', 'ders': 'Fizik'},
    {'label': 'AYT Sayısal - Kimya',     'exam': 'AYT Sayısal', 'ders': 'Kimya'},
    {'label': 'AYT Sayısal - Biyoloji',  'exam': 'AYT Sayısal', 'ders': 'Biyoloji'},
    // AYT Eşit Ağırlık
    {'label': 'AYT EA - Edebiyat',  'exam': 'AYT Eşit Ağırlık', 'ders': 'Edebiyat'},
    {'label': 'AYT EA - Matematik', 'exam': 'AYT Eşit Ağırlık', 'ders': 'Matematik'},
    {'label': 'AYT EA - Tarih',     'exam': 'AYT Eşit Ağırlık', 'ders': 'Tarih'},
    {'label': 'AYT EA - Coğrafya',  'exam': 'AYT Eşit Ağırlık', 'ders': 'Coğrafya'},
    // AYT Sözel
    {'label': 'AYT Sözel - Edebiyat', 'exam': 'AYT Sözel', 'ders': 'Edebiyat'},
    {'label': 'AYT Sözel - Tarih',    'exam': 'AYT Sözel', 'ders': 'Tarih'},
    {'label': 'AYT Sözel - Coğrafya', 'exam': 'AYT Sözel', 'ders': 'Coğrafya'},
    {'label': 'AYT Sözel - Felsefe',  'exam': 'AYT Sözel', 'ders': 'Felsefe'},
    // KPSS
    {'label': 'KPSS - Türkçe',       'exam': 'Lisans', 'ders': 'Türkçe'},
    {'label': 'KPSS - Matematik',     'exam': 'Lisans', 'ders': 'Matematik'},
    {'label': 'KPSS - Tarih',         'exam': 'Lisans', 'ders': 'Tarih'},
    {'label': 'KPSS - Coğrafya',      'exam': 'Lisans', 'ders': 'Coğrafya'},
    {'label': 'KPSS - Vatandaşlık',   'exam': 'Lisans', 'ders': 'Vatandaşlık'},
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _roomSub?.cancel();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _genCode() {
    final r = Random();
    return List.generate(6, (_) => r.nextInt(10).toString()).join();
  }

  Color _examColor(String exam) {
    if (exam.startsWith('TYT'))     return const Color(0xFF00E5FF);
    if (exam.startsWith('AYT'))     return const Color(0xFF00E676);
    if (exam.startsWith('Lisans') ||
        exam.startsWith('Önlisans')) return const Color(0xFFFF5252);
    return const Color(0xFFD500F9);
  }

  // ── Ders seçici ────────────────────────────────────────────────────────
  Future<Map<String, String>?> _pickSubject(String title) {
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.72,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1B1F6A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 14),
          Text(title,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Rakibine sormak istediğin dersi seç',
              style:
                  GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              itemCount: _subjects.length,
              itemBuilder: (_, i) {
                final s   = _subjects[i];
                final col = _examColor(s['exam']!);
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, s),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: col.withValues(alpha: 0.28)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(s['exam']!.split(' ').first,
                            style: GoogleFonts.poppins(
                                color: col,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(s['label']!,
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 13)),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: col, size: 13),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── Oda oluştur ───────────────────────────────────────────────────────
  Future<void> _createRoom() async {
    final subjectInfo =
        await _pickSubject('Sen hangi dersten soru sormak istersin?');
    if (subjectInfo == null) return;

    setState(() => _creating = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _creating = false);
      return;
    }
    final code = _genCode();

    try {
      String p1Name = user.displayName ?? 'Oyuncu 1';
      try {
        final uDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (uDoc.exists) p1Name = uDoc.data()?['name'] ?? p1Name;
      } catch (_) {}

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(code)
          .set({
        'roomCode':         code,
        'player1_id':       user.uid,
        'player1_name':     p1Name,
        // Tam bilgi — folder çözümü için
        'player1_exam':     subjectInfo['exam'],
        'player1_ders':     subjectInfo['ders'],
        'player1_subject':  subjectInfo['label'],
        'player1_score':    0,
        'player2_id':       null,
        'player2_name':     null,
        'player2_exam':     null,
        'player2_ders':     null,
        'player2_subject':  null,
        'player2_score':    0,
        'status':           'waiting',
        'createdAt':        FieldValue.serverTimestamp(),
      });

      setState(() {
        _creating  = false;
        _waiting   = true;
        _roomCode  = code;
      });

      _roomSub = FirebaseFirestore.instance
          .collection('rooms')
          .doc(code)
          .snapshots()
          .listen((snap) {
        if (!snap.exists) return;
        final d = snap.data()!;
        if (d['player2_id'] != null &&
            d['status'] == 'ready' &&
            mounted) {
          _roomSub?.cancel();
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      MultiplayerQuizPage(roomCode: code)));
        }
      });
    } catch (e) {
      setState(() => _creating = false);
      _err('Oda oluşturulamadı: $e');
    }
  }

  // ── Odaya katıl ───────────────────────────────────────────────────────
  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      _err('6 haneli kod gir!');
      return;
    }

    final subjectInfo =
        await _pickSubject('Sen hangi dersten soru sormak istersin?');
    if (subjectInfo == null) return;

    setState(() => _joining = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _joining = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(code)
          .get();
      if (!doc.exists) {
        _err('Oda bulunamadı!');
        setState(() => _joining = false);
        return;
      }
      final d = doc.data()!;
      if (d['status'] != 'waiting') {
        _err('Bu oda müsait değil!');
        setState(() => _joining = false);
        return;
      }
      if (d['player1_id'] == user.uid) {
        _err('Kendi odana katılamazsın!');
        setState(() => _joining = false);
        return;
      }

      String p2Name = user.displayName ?? 'Oyuncu 2';
      try {
        final uDoc2 = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (uDoc2.exists) p2Name = uDoc2.data()?['name'] ?? p2Name;
      } catch (_) {}

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(code)
          .update({
        'player2_id':      user.uid,
        'player2_name':    p2Name,
        'player2_exam':    subjectInfo['exam'],
        'player2_ders':    subjectInfo['ders'],
        'player2_subject': subjectInfo['label'],
        'player2_score':   0,
        'status':          'ready',
      });

      setState(() => _joining = false);
      if (mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    MultiplayerQuizPage(roomCode: code)));
      }
    } catch (e) {
      setState(() => _joining = false);
      _err('Odaya katılınamadı: $e');
    }
  }

  void _cancelWaiting() {
    _roomSub?.cancel();
    if (_roomCode.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('rooms')
          .doc(_roomCode)
          .delete();
    }
    setState(() {
      _waiting  = false;
      _roomCode = '';
    });
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg,
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) =>
      _waiting ? _waitScreen() : _lobbyScreen();

  // ── Bekleme ekranı ─────────────────────────────────────────────────────
  Widget _waitScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E43),
      body: SafeArea(
          child: Center(
              child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                      colors: [Color(0xFFD500F9), Color(0xFF5A189A)]),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFD500F9)
                            .withValues(alpha: 0.45),
                        blurRadius: 28,
                        spreadRadius: 4)
                  ],
                ),
                child: const Icon(Icons.sports_esports_rounded,
                    color: Colors.white, size: 55),
              ),
            ),
            const SizedBox(height: 28),
            Text('⚔️ Rakip Aranıyor',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Arkadaşın oda kodunu girince düello başlar',
                style: GoogleFonts.poppins(
                    color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFD500F9).withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFD500F9)
                        .withValues(alpha: 0.38)),
              ),
              child: Column(children: [
                Text('Oda Kodunu Paylaş',
                    style: GoogleFonts.poppins(
                        color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text(_roomCode,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6)),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: _roomCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Kod kopyalandı!',
                                  style: GoogleFonts.poppins()),
                              behavior: SnackBarBehavior.floating));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD500F9)
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.copy_rounded,
                          color: Color(0xFFD500F9), size: 18),
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 22),
            const CircularProgressIndicator(
                color: Color(0xFFD500F9), strokeWidth: 3),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _cancelWaiting,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color:
                          Colors.white.withValues(alpha: 0.18)),
                ),
                child: Text('İptal Et',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 14)),
              ),
            ),
          ],
        ),
      ))),
    );
  }

  // ── Lobi ekranı ────────────────────────────────────────────────────────
  Widget _lobbyScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E43),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E43),
              Color(0xFF1B1F6A),
              Color(0xFF3A0070),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Arkadaşınla Oyna',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Text('1v1 Canlı Düello ⚔️',
                        style: GoogleFonts.poppins(
                            color: const Color(0xFFD500F9),
                            fontSize: 12)),
                  ]),
                ]),
                const SizedBox(height: 28),
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [
                        Color(0xFFD500F9),
                        Color(0xFF7C4DFF)
                      ]),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFD500F9)
                                .withValues(alpha: 0.45),
                            blurRadius: 28,
                            spreadRadius: 4)
                      ],
                    ),
                    child: const Icon(Icons.sports_esports_rounded,
                        color: Colors.white, size: 50),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Düelloya Hazır mısın?',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  'Her oyuncu kendi dersini seçer. Her soruda 30 saniye!',
                  style: GoogleFonts.poppins(
                      color: Colors.white60, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                _rulesCard(),
                const SizedBox(height: 22),

                // Oda Oluştur
                GestureDetector(
                  onTap: _creating ? null : _createRoom,
                  child: Container(
                    width: double.infinity, height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFFD500F9),
                        Color(0xFF7C4DFF)
                      ]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFD500F9)
                                .withValues(alpha: 0.38),
                            blurRadius: 14,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: Center(
                      child: _creating
                          ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                          : Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_rounded,
                                    color: Colors.white, size: 22),
                                const SizedBox(width: 8),
                                Text('Yeni Oda Oluştur',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(children: [
                  Expanded(
                      child: Container(
                          height: 1, color: Colors.white12)),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('VEYA',
                        style: GoogleFonts.poppins(
                            color: Colors.white38, fontSize: 10)),
                  ),
                  Expanded(
                      child: Container(
                          height: 1, color: Colors.white12)),
                ]),
                const SizedBox(height: 16),

                // Odaya Katıl
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white
                            .withValues(alpha: 0.09)),
                  ),
                  child: Column(children: [
                    Text('Var Olan Odaya Katıl',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeCtrl,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6),
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: GoogleFonts.poppins(
                            color: Colors.white30,
                            fontSize: 22,
                            letterSpacing: 6),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.white
                                  .withValues(alpha: 0.18)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.white
                                  .withValues(alpha: 0.18)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFD500F9), width: 2),
                        ),
                        filled: true,
                        fillColor:
                            Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF1B1F6A),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            side: const BorderSide(
                                color: Color(0xFFD500F9)),
                          ),
                        ),
                        onPressed:
                            _joining ? null : _joinRoom,
                        child: _joining
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2)
                            : Text('Odaya Katıl ⚔️',
                                style: GoogleFonts.poppins(
                                    color:
                                        const Color(0xFFD500F9),
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rulesCard() {
    final rules = [
      ['🎯', '1. oyuncu dersini seçer, 2. oyuncu kendi dersini seçer'],
      ['⏱️', 'Her soruda 30 saniye vardır'],
      ['⚡', 'Doğru cevap +10 puan, hızlı cevap bonus puan'],
      ['🏆', 'En yüksek puanı alan kazanır'],
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFD500F9).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFD500F9).withValues(alpha: 0.22)),
      ),
      child: Column(
          children: rules
              .map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(children: [
                      Text(r[0],
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(r[1],
                              style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 11))),
                    ]),
                  ))
              .toList()),
    );
  }
}