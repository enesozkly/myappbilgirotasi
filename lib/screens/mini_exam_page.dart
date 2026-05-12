// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/reklam_servisi.dart';
import '../widgets/br_dialogs.dart';

class MiniExamPage extends StatefulWidget {
  final String examTitle;
  final List<Map<String, dynamic>> questions;
  final List<Color> colors;
  final String examType;

  const MiniExamPage({
    super.key,
    required this.examTitle,
    required this.questions,
    required this.colors,
    required this.examType,
  });

  @override
  State<MiniExamPage> createState() => _MiniExamPageState();
}

class _MiniExamPageState extends State<MiniExamPage> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final Map<int, String?> _selected = {};
  bool _isFinished = false;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _slideAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _pick(String opt) {
    if (_selected[_currentIndex] != null) return;
    setState(() => _selected[_currentIndex] = opt);
  }

  void _next() async {
    if (_currentIndex < widget.questions.length - 1) {
      _slideCtrl.reset();
      setState(() => _currentIndex++);
      _slideCtrl.forward();
    } else {
      // Deneme bitisinde de normal bolum mantigi kullanilir: 4 tamamlamada 1 reklam.
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final bool isVip = doc.data()?['isVip'] ?? false;
          ReklamServisi.denemeTamamlandi(isVip);
        }
      } catch (_) {}
      if (mounted) setState(() => _isFinished = true);
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      _slideCtrl.reset();
      setState(() => _currentIndex--);
      _slideCtrl.forward();
    }
  }

  Future<void> _addToBox(Map<String, dynamic> q) async {
    if (_uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(_uid).collection('yanlislar')
          .doc(q['soru'].toString().hashCode.toString())
          .set({
        'soru_metni': q['soru'] ?? '',
        'gelen_ders': q['ders'] ?? widget.examType.toUpperCase(),
        'gelen_konu': q['konu'] ?? widget.examTitle,
        'exam': widget.examType.toUpperCase(),
        'secenekler': q['secenekler'],
        'dogru_cevap': q['cevap'],
        'aciklama': q['aciklama'] ?? '',
        'kayit_tarihi': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata kutusuna eklendi! 📦', style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: const Color(0xFFD500F9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {}
  }

  int get _correctCount {
    int c = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      final ans = (widget.questions[i]['cevap'] as String? ?? '').toUpperCase();
      if (_selected[i] == ans) c++;
    }
    return c;
  }

  int get _unanswered {
    int c = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      if (_selected[i] == null) c++;
    }
    return c;
  }


  Future<bool> _confirmExitMiniExam() async {
    return BRDialogs.showExitConfirm(
      context,
      title: 'Mini denemeden çıkılsın mı?',
      message: 'Bu mini deneme için harcanan 15 enerji geri iade edilmeyecek. İlerlemen kaydedilmeden çıkarsan kaldığın yer korunmaz.',
    );
  }


  Future<void> _exitMiniExam() async {
    final canExit = await _confirmExitMiniExam();
    if (!canExit || !context.mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) return _resultPage();

    final q = widget.questions[_currentIndex];
    final opts = q['secenekler'];
    final correct = (q['cevap'] as String? ?? '').toUpperCase();
    final sel = _selected[_currentIndex];
    final answered = sel != null;

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _confirmExitMiniExam,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E43),
        body: SafeArea(
        child: Column(children: [
          // Üst bar
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              GestureDetector(
                onTap: _showExit,
                child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close, color: Colors.white, size: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.examTitle, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                Text('Soru ${_currentIndex + 1} / ${widget.questions.length}', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(gradient: LinearGradient(colors: widget.colors), borderRadius: BorderRadius.circular(18)),
                child: Text('${_currentIndex + 1}/${widget.questions.length}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / widget.questions.length,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(widget.colors[0]),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Ders etiketi
                  if (q['ders'] != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                      decoration: BoxDecoration(gradient: LinearGradient(colors: widget.colors), borderRadius: BorderRadius.circular(18)),
                      child: Text(q['ders'] ?? '', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  // Soru
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                    child: Text(q['soru'] ?? '', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, height: 1.5)),
                  ),
                  const SizedBox(height: 14),

                  // Şıklar
                  if (opts is Map) ...[
                    ...(opts as Map<String, dynamic>).entries.map((entry) {
                      final k = entry.key.toUpperCase();
                      final v = entry.value.toString();
                      Color? bg;
                      Color border = Colors.white.withValues(alpha: 0.13);
                      IconData? icon;

                      if (answered) {
                        if (k == correct) { bg = const Color(0xFF00E676).withValues(alpha: 0.13); border = const Color(0xFF00E676); icon = Icons.check_circle_rounded; }
                        else if (k == sel) { bg = Colors.redAccent.withValues(alpha: 0.13); border = Colors.redAccent; icon = Icons.cancel_rounded; }
                      }
                      return GestureDetector(
                        onTap: () => _pick(k),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.only(bottom: 9),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(color: bg ?? Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(13), border: Border.all(color: border, width: 1.4)),
                          child: Row(children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                gradient: answered && k == correct
                                    ? const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00C853)])
                                    : answered && k == sel
                                        ? const LinearGradient(colors: [Colors.redAccent, Colors.red])
                                        : LinearGradient(colors: [widget.colors[0].withValues(alpha: 0.25), widget.colors[1].withValues(alpha: 0.25)]),
                                shape: BoxShape.circle,
                              ),
                              child: Center(child: Text(k, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                            ),
                            const SizedBox(width: 11),
                            Expanded(child: Text(v, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13))),
                            if (icon != null) Icon(icon, color: border, size: 18),
                          ]),
                        ),
                      );
                    }),
                  ],

                  // Açıklama
                  if (answered && (q['aciklama'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF00E5FF).withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.25))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF00E5FF), size: 16),
                        const SizedBox(width: 7),
                        Expanded(child: Text(q['aciklama'] ?? '', style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11, height: 1.4))),
                      ]),
                    ),
                  ],

                  // Hata kutusuna ekle
                  if (answered && sel != correct) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _addToBox(q),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(color: const Color(0xFFD500F9).withValues(alpha: 0.09), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFFD500F9).withValues(alpha: 0.35))),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.bookmark_add_rounded, color: Color(0xFFD500F9), size: 16),
                          const SizedBox(width: 7),
                          Text('Hata Kutusuna Ekle', style: GoogleFonts.poppins(color: const Color(0xFFD500F9), fontSize: 12, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ),

          // Alt butonlar
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              if (_currentIndex > 0)
                GestureDetector(
                  onTap: _prev,
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
              Expanded(
                child: GestureDetector(
                  onTap: answered ? _next : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: answered ? LinearGradient(colors: widget.colors) : const LinearGradient(colors: [Color(0xFF232766), Color(0xFF232766)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: answered ? [BoxShadow(color: widget.colors[0].withValues(alpha: 0.38), blurRadius: 10, offset: const Offset(0, 4))] : [],
                    ),
                    child: Center(child: Text(
                      _currentIndex == widget.questions.length - 1 ? 'Sonuçları Gör 🏆' : 'Sonraki →',
                      style: GoogleFonts.poppins(color: answered ? Colors.white : Colors.white30, fontSize: 14, fontWeight: FontWeight.bold),
                    )),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ),
    );
  }

  // ─── SONUÇ SAYFASI ────────────────────────────────────────────────────────
  Widget _resultPage() {
    final total = widget.questions.length;
    final correct = _correctCount;
    final wrong = total - correct - _unanswered;
    final pct = total == 0 ? 0.0 : correct / total;

    String emoji; String label; Color col;
    if (pct >= 0.8) { emoji = '🏆'; label = 'Mükemmel!'; col = const Color(0xFF00E676); }
    else if (pct >= 0.5) { emoji = '💪'; label = 'İyi Gidiyorsun!'; col = const Color(0xFFFFD700); }
    else { emoji = '📚'; label = 'Çalışmaya Devam!'; col = Colors.redAccent; }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E43),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            const SizedBox(height: 16),
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 10),
            Text(label, style: GoogleFonts.poppins(color: col, fontSize: 26, fontWeight: FontWeight.bold)),
            Text(widget.examTitle, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 24),

            Container(
              width: 130, height: 130,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: widget.colors),
                  boxShadow: [BoxShadow(color: widget.colors[0].withValues(alpha: 0.45), blurRadius: 28, spreadRadius: 4)]),
              child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$correct/$total', style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                Text('Doğru', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
              ])),
            ),
            const SizedBox(height: 24),

            Row(children: [
              _statTile('✅ Doğru', correct.toString(), const Color(0xFF00E676)),
              const SizedBox(width: 10),
              _statTile('❌ Yanlış', wrong.toString(), Colors.redAccent),
              const SizedBox(width: 10),
              _statTile('⏭️ Boş', _unanswered.toString(), Colors.white38),
            ]),
            const SizedBox(height: 20),

            // Soru detay listesi
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withValues(alpha: 0.09))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Soru Detayları', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...List.generate(widget.questions.length, (i) {
                  final q = widget.questions[i];
                  final cor = (q['cevap'] as String? ?? '').toUpperCase();
                  final s = _selected[i];
                  final isOk = s == cor;
                  final isEmpty = s == null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(children: [
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(color: isEmpty ? Colors.white10 : isOk ? const Color(0xFF00E676).withValues(alpha: 0.18) : Colors.redAccent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(7)),
                        child: Center(child: Text('${i + 1}', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10))),
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Text(
                        (q['soru']?.toString() ?? '').length > 48 ? '${q['soru'].toString().substring(0, 48)}…' : q['soru']?.toString() ?? '',
                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10),
                      )),
                      Icon(isEmpty ? Icons.remove_circle_outline : isOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: isEmpty ? Colors.white30 : isOk ? const Color(0xFF00E676) : Colors.redAccent, size: 16),
                      if (!isOk && !isEmpty)
                        GestureDetector(
                          onTap: () => _addToBox(q),
                          child: Container(
                            margin: const EdgeInsets.only(left: 5),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFD500F9).withValues(alpha: 0.13), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFD500F9).withValues(alpha: 0.35))),
                            child: const Text('📦', style: TextStyle(fontSize: 10)),
                          ),
                        ),
                    ]),
                  );
                }),
              ]),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: widget.colors[0], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => Navigator.pop(context),
                child: Text('Listeye Dön', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  Widget _statTile(String label, String val, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.28))),
      child: Column(children: [
        Text(val, style: GoogleFonts.poppins(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
      ]),
    ));
  }

  void _showExit() {
    _exitMiniExam();
  }
}
