// ignore_for_file: use_build_context_synchronously

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/reklam_servisi.dart';
import '../widgets/br_dialogs.dart';

class TrialQuizPage extends StatefulWidget {
  final String                     examTitle;
  final String                     trialName;
  final List<Map<String, dynamic>> questions;
  final List<Color>                colors;

  const TrialQuizPage({
    super.key,
    required this.examTitle,
    required this.trialName,
    required this.questions,
    required this.colors,
  });

  @override
  State<TrialQuizPage> createState() => _TrialQuizPageState();
}

class _TrialQuizPageState extends State<TrialQuizPage>
    with TickerProviderStateMixin {

  int     _currentIndex    = 0;
  String? _selectedAnswer;
  bool    _answered        = false;
  bool    _showExplanation = false;

  // Kullanıcının seçimlerini sakla: soru index → seçilen şık
  final Map<int, String> _userAnswers = {};

  late AnimationController _cardController;
  late Animation<double>   _cardAnimation;

  // isVip initState'te bir kez okunur — deneme bitişinde tekrar Firestore'a gitme
  bool _isVip = false;
  bool _resultAdCounted = false;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // ── Yardımcı getter'lar ───────────────────────────────────────────────
  Map<String, dynamic> get _currentQ =>
      widget.questions[_currentIndex];
  int get _totalQ => widget.questions.length;

  Map<String, String> get _options {
    final raw = _currentQ['secenekler'];
    if (raw is Map) {
      return Map<String, String>.from(
          raw.map((k, v) => MapEntry(k.toString(), v.toString())));
    }
    return {};
  }

  String get _correctAnswer =>
      (_currentQ['cevap'] ?? '').toString().toUpperCase();

  String get _explanation {
    final raw = (_currentQ['aciklama'] ?? '').toString();
    // Jenerik/anlamsız açıklamaları filtrele
    if (raw.isEmpty ||
        raw.contains('verilen koşullara') ||
        raw.contains('en uygun ol') ||
        raw.contains('en iyi şekilde özetl') ||
        raw.contains('mantıklı çöz')) {
      return 'Doğru cevap: $_correctAnswer';
    }
    return raw;
  }

  String get _ders => (_currentQ['ders'] ?? '')
      .toString()
      .replaceAll('_', ' ')
      .replaceAll('AYT ', '');

  int get _correctCount {
    int count = 0;
    for (int i = 0; i < _totalQ; i++) {
      if (!_userAnswers.containsKey(i)) continue;
      final correct = (widget.questions[i]['cevap'] ?? '')
          .toString()
          .toUpperCase();
      if (_userAnswers[i] == correct) count++;
    }
    return count;
  }

  double _calcNet() {
    int correct = 0;
    int wrong   = 0;
    for (int i = 0; i < _totalQ; i++) {
      if (!_userAnswers.containsKey(i)) continue;
      final c = (widget.questions[i]['cevap'] ?? '')
          .toString()
          .toUpperCase();
      if (_userAnswers[i] == c) {
        correct++;
      } else {
        wrong++;
      }
    }
    return correct - (wrong / 4);
  }

  // ── Init / Dispose ────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _cardController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 350),
    );
    _cardAnimation = CurvedAnimation(
        parent: _cardController, curve: Curves.easeOut);
    _cardController.forward();

    // isVip'i bir kez oku — deneme bitişinde tekrar okumak yerine
    // bu değer kullanılacak
    _loadIsVip();
  }

  Future<void> _loadIsVip() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (mounted) {
        _isVip = doc.data()?['isVip'] == true;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }


  Future<bool> _confirmExitTrial() async {
    return BRDialogs.showExitConfirm(
      context,
      title: 'Denemeden çıkılsın mı?',
      message: 'Bu deneme için harcanan 15 enerji geri iade edilmeyecek. Cevapların kaydedilmeden çıkarsan ilerlemen korunmaz.',
    );
  }


  Future<void> _exitTrial({bool toHome = false}) async {
    final canExit = await _confirmExitTrial();
    if (!canExit || !context.mounted) return;
    if (toHome) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.pop(context);
    }
  }

  // ── Cevap Seç ─────────────────────────────────────────────────────────
  void _selectAnswer(String key) {
    if (_answered) return;
    setState(() {
      _selectedAnswer        = key;
      _answered              = true;
      _userAnswers[_currentIndex] = key;
    });
  }

  // ── Sonraki Soru ─────────────────────────────────────────────────────
  // ── Hatalı Soru Bildir ────────────────────────────────────────────────────
  Future<void> _reportQuestion() async {
    if (_uid == null) return;
    final confirm = await BRDialogs.showConfirm(
      context,
      title: 'Soruyu Bildir',
      message: 'Bu soruyu hatalı olarak bildirmek istiyor musun? Bildirimin incelenmek üzere admin paneline düşecek.',
      icon: Icons.flag_rounded,
      accent: Colors.orangeAccent,
      cancelText: 'İptal',
      confirmText: 'Bildir',
      confirmColor: Colors.orangeAccent,
    );
    if (confirm != true) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      final userData = userDoc.data() ?? {};
      final fullName = (userData['name'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'İsimsiz').toString();
      final email = (userData['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '').toString();
      await FirebaseFirestore.instance
          .collection('reported_questions')
          .add({
        'uid': _uid,
        'userName': fullName,
        'userEmail': email,
        'soru_metni': (_currentQ['soru'] ?? '').toString(),
        'exam': widget.examTitle,
        'trial': widget.trialName,
        'questionIndex': _currentIndex,
        'source': 'deneme',
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sorun bildirildi, teşekkürler! 🙏',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.deepPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Soru bildirme hatası: $e');
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _totalQ - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer  = _userAnswers[_currentIndex];
        _answered        = _userAnswers.containsKey(_currentIndex);
        _showExplanation = false;
      });
      _cardController.reset();
      _cardController.forward();
    } else {
      _showResultSheet(countAsCompletion: true);
    }
  }

  // ── Önceki Soru ──────────────────────────────────────────────────────
  void _prevQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _selectedAnswer  = _userAnswers[_currentIndex];
        _answered        = _userAnswers.containsKey(_currentIndex);
        _showExplanation = false;
      });
      _cardController.reset();
      _cardController.forward();
    }
  }

  // ── Sonuç Sayfası ─────────────────────────────────────────────────────
  void _showResultSheet({bool countAsCompletion = false}) {
    // Deneme gercekten bittiginde yalnizca 1 kez sayac artar.
    // Sayac normal quiz bolumleriyle aynidir: toplam 4 tamamlamada 1 reklam.
    if (countAsCompletion && !_resultAdCounted) {
      ReklamServisi.denemeTamamlandi(_isVip);
      _resultAdCounted = true;
    }

    if (!mounted) return;

    final double net      = _calcNet();
    final int    correct  = _correctCount;
    final int    answered = _userAnswers.length;
    final int    wrong    = answered - correct;

    // Ders bazlı analiz
    final Map<String, int> dersDogru  = {};
    final Map<String, int> dersYanlis = {};
    for (int i = 0; i < _totalQ; i++) {
      final q    = widget.questions[i];
      final ders = (q['ders'] ?? '')
          .toString()
          .replaceAll('_', ' ')
          .replaceAll('AYT ', '');
      final c    = (q['cevap'] ?? '').toString().toUpperCase();

      dersDogru.putIfAbsent(ders,  () => 0);
      dersYanlis.putIfAbsent(ders, () => 0);

      if (_userAnswers.containsKey(i)) {
        if (_userAnswers[i] == c) {
          dersDogru[ders] = dersDogru[ders]! + 1;
        } else {
          dersYanlis[ders] = dersYanlis[ders]! + 1;
        }
      }
    }

    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _ResultSheet(
        examTitle:  widget.examTitle,
        trialName:  widget.trialName,
        totalQ:     _totalQ,
        answered:   answered,
        correct:    correct,
        wrong:      wrong,
        net:        net,
        dersDogru:  dersDogru,
        dersYanlis: dersYanlis,
        colors:     widget.colors,
        onReview: () {
          Navigator.pop(context);
          setState(() {
            _currentIndex    = 0;
            _selectedAnswer  = _userAnswers[0];
            _answered        = _userAnswers.containsKey(0);
            _showExplanation = false;
          });
        },
        onExit: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final Color c0   = widget.colors[0];
    final Color c1   = widget.colors[1];
    final Size  size = MediaQuery.of(context).size;

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _confirmExitTrial,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E43),
      body: Stack(
        children: [
          // Arka plan
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                colors: [Color(0xFF0A0E43), Color(0xFF1B1F6A)],
              ),
            ),
          ),
          ..._buildStars(size),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(c0),
                _buildProgressBar(c0),
                Expanded(
                  child: FadeTransition(
                    opacity: _cardAnimation,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Column(
                        children: [
                          _buildDersBadge(c0),
                          const SizedBox(height: 12),
                          _buildQuestionCard(),
                          const SizedBox(height: 16),
                          ..._buildOptions(c0),
                          if (_answered && _showExplanation) ...[
                            const SizedBox(height: 14),
                            _buildExplanationCard(),
                          ],
                          if (_answered) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _reportQuestion,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.flag_outlined,
                                      color: Colors.white38, size: 16),
                                  const SizedBox(width: 6),
                                  Text('Hatalı Soruyu Bildir',
                                      style: GoogleFonts.poppins(
                                          color: Colors.white38,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildBottomBar(c0, c1),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ── Üst Bar ───────────────────────────────────────────────────────────
  Widget _buildTopBar(Color c0) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        GestureDetector(
          onTap: () => _exitTrial(),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        // ── Ana Ekran Butonu ──────────────────────────────────────────
        GestureDetector(
          onTap: () => _exitTrial(toHome: true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color:        Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.home_rounded,
                    color: Colors.white60, size: 16),
                const SizedBox(width: 5),
                Text('Ana Ekran',
                    style: GoogleFonts.poppins(
                        color:      Colors.white60,
                        fontSize:   11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.examTitle,
                  style: GoogleFonts.poppins(
                      color:      Colors.white,
                      fontSize:   14,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(widget.trialName,
                  style: GoogleFonts.poppins(
                      color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
        // Soru sayacına tıklayınca sonuç ekranı açılır
        GestureDetector(
          onTap: () => _showResultSheet(),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color:        c0.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c0.withValues(alpha: 0.5)),
            ),
            child: Text(
              '${_currentIndex + 1} / $_totalQ',
              style: GoogleFonts.poppins(
                  color:      c0,
                  fontSize:   13,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ]),
    );
  }

  // ── İlerleme Barı ─────────────────────────────────────────────────────
  Widget _buildProgressBar(Color c0) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value:           (_currentIndex + 1) / _totalQ,
          backgroundColor: Colors.white12,
          valueColor:      AlwaysStoppedAnimation(c0),
          minHeight:       6,
        ),
      ),
    );
  }

  // ── Ders Badge ────────────────────────────────────────────────────────
  Widget _buildDersBadge(Color c0) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color:        c0.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c0.withValues(alpha: 0.4)),
        ),
        child: Text(_ders,
            style: GoogleFonts.poppins(
                color:      c0,
                fontSize:   12,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── Soru Kartı ────────────────────────────────────────────────────────
  Widget _buildQuestionCard() {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        _currentQ['soru']?.toString() ?? '',
        style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 15, height: 1.6),
      ),
    );
  }

  // ── Seçenekler ────────────────────────────────────────────────────────
  List<Widget> _buildOptions(Color c0) {
    return _options.entries.map((entry) {
      final String key       = entry.key;
      final String text      = entry.value;
      final bool   isSelected = _selectedAnswer == key;
      final bool   isCorrect  = key == _correctAnswer;

      Color    borderColor = Colors.white12;
      Color    bgColor     =
          Colors.white.withValues(alpha: 0.05);
      Color    textColor   = Colors.white;
      IconData? trailingIcon;

      if (_answered) {
        if (isCorrect) {
          borderColor  = const Color(0xFF00E676);
          bgColor      = const Color(0xFF00E676)
              .withValues(alpha: 0.12);
          textColor    = const Color(0xFF00E676);
          trailingIcon = Icons.check_circle_rounded;
        } else if (isSelected) {
          borderColor  = Colors.redAccent;
          bgColor      = Colors.redAccent.withValues(alpha: 0.12);
          textColor    = Colors.redAccent;
          trailingIcon = Icons.cancel_rounded;
        }
      } else if (isSelected) {
        borderColor = c0;
        bgColor     = c0.withValues(alpha: 0.12);
        textColor   = c0;
      }

      return GestureDetector(
        onTap: () => _selectAnswer(key),
        child: Container(
          margin:  const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color:        bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color:  borderColor.withValues(alpha: 0.2),
                shape:  BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Text(key,
                    style: GoogleFonts.poppins(
                        color:      textColor,
                        fontSize:   13,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.poppins(
                      color:    textColor,
                      fontSize: 13,
                      height:   1.4)),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(trailingIcon, color: textColor, size: 20),
            ],
          ]),
        ),
      );
    }).toList();
  }

  // ── Açıklama Kartı ────────────────────────────────────────────────────
  Widget _buildExplanationCard() {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFF00E676).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lightbulb_outline_rounded,
                color: Color(0xFF00E676), size: 18),
            const SizedBox(width: 8),
            Text('Açıklama',
                style: GoogleFonts.poppins(
                    color:      const Color(0xFF00E676),
                    fontSize:   13,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(_explanation,
              style: GoogleFonts.poppins(
                  color:    Colors.white70,
                  fontSize: 13,
                  height:   1.5)),
        ],
      ),
    );
  }

  // ── Alt Bar ───────────────────────────────────────────────────────────
  Widget _buildBottomBar(Color c0, Color c1) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F6A),
        border: Border(
            top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(children: [
        // Geri
        GestureDetector(
          onTap: _prevQuestion,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 10),

        // Açıklama toggle (sadece cevaplanmışsa)
        if (_answered)
          Expanded(
            child: GestureDetector(
              onTap: () => setState(
                  () => _showExplanation = !_showExplanation),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF00E676)
                          .withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Text(
                    _showExplanation
                        ? 'Açıklamayı Gizle'
                        : 'Açıklamayı Gör',
                    style: GoogleFonts.poppins(
                        color:      const Color(0xFF00E676),
                        fontSize:   13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          )
        else
          const Spacer(),

        const SizedBox(width: 10),

        // İleri / Bitir
        Expanded(
          child: GestureDetector(
            onTap: _nextQuestion,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient:     LinearGradient(colors: [c0, c1]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color:      c0.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset:     const Offset(0, 4)),
                ],
              ),
              child: Center(
                child: Text(
                  _currentIndex == _totalQ - 1
                      ? 'Bitir 🏆'
                      : 'Sonraki →',
                  style: GoogleFonts.poppins(
                      color:      Colors.white,
                      fontSize:   14,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Arka plan yıldızları ──────────────────────────────────────────────
  List<Widget> _buildStars(Size size) {
    final rand = Random(99);
    return List.generate(
      20,
      (_) => Positioned(
        left: rand.nextDouble() * size.width,
        top:  rand.nextDouble() * size.height,
        child: Icon(Icons.star,
            size:  rand.nextDouble() * 4 + 2,
            color: Colors.white.withValues(alpha: 0.15)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SONUÇ SAYFASI
// ═══════════════════════════════════════════════════════════════════════════

class _ResultSheet extends StatelessWidget {
  final String          examTitle;
  final String          trialName;
  final int             totalQ;
  final int             answered;
  final int             correct;
  final int             wrong;
  final double          net;
  final Map<String, int> dersDogru;
  final Map<String, int> dersYanlis;
  final List<Color>     colors;
  final VoidCallback    onReview;
  final VoidCallback    onExit;

  const _ResultSheet({
    required this.examTitle,
    required this.trialName,
    required this.totalQ,
    required this.answered,
    required this.correct,
    required this.wrong,
    required this.net,
    required this.dersDogru,
    required this.dersYanlis,
    required this.colors,
    required this.onReview,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final Color c0    = colors[0];
    final Color c1    = colors[1];
    final int   empty = totalQ - answered;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color:        Color(0xFF1B1F6A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(children: [
          // Tutamaç
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color:        Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),

          // Başlık
          Text('🏆 Deneme Tamamlandı!',
              style: GoogleFonts.poppins(
                  color:      Colors.white,
                  fontSize:   22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$examTitle — $trialName',
              style: GoogleFonts.poppins(
                  color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),

          // Net skoru
          Container(
            padding: const EdgeInsets.symmetric(
                vertical: 20, horizontal: 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c0, c1]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color:      c0.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset:     const Offset(0, 6)),
              ],
            ),
            child: Column(children: [
              Text('NET',
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 13)),
              Text(
                net.toStringAsFixed(2),
                style: GoogleFonts.poppins(
                    color:      Colors.white,
                    fontSize:   48,
                    fontWeight: FontWeight.w900),
              ),
              Text('$totalQ Sorudan',
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 20),

          // Doğru / Yanlış / Boş
          Row(children: [
            _statBox('Doğru', correct, const Color(0xFF00E676)),
            const SizedBox(width: 10),
            _statBox('Yanlış', wrong,  Colors.redAccent),
            const SizedBox(width: 10),
            _statBox('Boş',    empty,  Colors.white38),
          ]),
          const SizedBox(height: 20),

          // Ders bazlı analiz
          if (dersDogru.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Ders Analizi',
                  style: GoogleFonts.poppins(
                      color:      Colors.white70,
                      fontSize:   13,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            ...dersDogru.keys.map((ders) {
              final int    d        = dersDogru[ders]  ?? 0;
              final int    y        = dersYanlis[ders] ?? 0;
              final int    total    = d + y;
              final double progress =
                  total == 0 ? 0.0 : d / total;

              return Container(
                margin:  const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:        Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ders,
                          style: GoogleFonts.poppins(
                              color:      Colors.white,
                              fontSize:   13,
                              fontWeight: FontWeight.w600)),
                      Text('$d D / $y Y',
                          style: GoogleFonts.poppins(
                              color:    Colors.white54,
                              fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value:           progress,
                      backgroundColor:
                          Colors.redAccent.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF00E676)),
                      minHeight: 6,
                    ),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 10),
          ],

          // Butonlar
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon:    const Icon(Icons.rate_review_rounded,
                    size: 18),
                label:   Text('İncele',
                    style: GoogleFonts.poppins(fontSize: 13)),
                onPressed: onReview,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: c0,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon:  const Icon(Icons.exit_to_app_rounded,
                    size: 18),
                label: Text('Çıkış',
                    style: GoogleFonts.poppins(
                        fontSize:   13,
                        fontWeight: FontWeight.bold)),
                onPressed: onExit,
              ),
            ),
          ]),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  Widget _statBox(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(children: [
          Text('$value',
              style: GoogleFonts.poppins(
                  color:      color,
                  fontSize:   24,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: GoogleFonts.poppins(
                  color:    color.withValues(alpha: 0.8),
                  fontSize: 12)),
        ]),
      ),
    );
  }
}