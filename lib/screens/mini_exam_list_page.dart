import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/energy_service.dart';
import '../widgets/br_dialogs.dart';
import 'mini_exam_page.dart';

class MiniExamListPage extends StatefulWidget {
  const MiniExamListPage({super.key});

  @override
  State<MiniExamListPage> createState() => _MiniExamListPageState();
}

class _MiniExamListPageState extends State<MiniExamListPage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _bgController;

  // Her kategori için yüklenen denemeler:
  // key = kategori 'key', value = [{title, questions}]
  final Map<String, List<Map<String, dynamic>>> _loadedExams = {};

  // ── Kategori tanımları ──────────────────────────────────────────────────
  static const List<Map<String, dynamic>> _categories = [
    {
      'key': 'tyt',
      'title': 'TYT Denemeleri',
      'icon': Icons.school_rounded,
      'colors': [Color(0xFF00E5FF), Color(0xFF007BFF)],
      'count': 20,
      // assets/denemeler/tyt_deneme/deneme_01_tyt.json  (sıfır dolgulu 01-20)
      'pathPattern': 'assets/denemeler/tyt_deneme/deneme_{n}_tyt.json',
      'padded': true, // 01, 02 ... şeklinde
    },
    {
      'key': 'ayt_sayisal',
      'title': 'AYT Sayısal Denemeleri',
      'icon': Icons.calculate_rounded,
      'colors': [Color(0xFF1D976C), Color(0xFF38EF7D)],
      'count': 20,
      'pathPattern':
          'assets/denemeler/ayt_sayisal_deneme/deneme_{n}_ayt_sayisal.json',
      'padded': false,
    },
    {
      'key': 'ayt_esitagirlik',
      'title': 'AYT Eşit Ağırlık Denemeleri',
      'icon': Icons.menu_book_rounded,
      'colors': [Color(0xFFD500F9), Color(0xFF9C27B0)],
      'count': 20,
      'pathPattern':
          'assets/denemeler/ayt_esitagirlik_deneme/deneme_{n}_ayt_esit_agirlik.json',
      'padded': false,
    },
    {
      'key': 'ayt_sozel',
      'title': 'AYT Sözel Denemeleri',
      'icon': Icons.auto_stories_rounded,
      'colors': [Color(0xFFFF9800), Color(0xFFFF5722)],
      'count': 20,
      'pathPattern':
          'assets/denemeler/sozel_deneme/deneme_{n}_ayt_sozel.json',
      'padded': false,
    },
    {
      'key': 'kpss_lisans',
      'title': 'KPSS Lisans Denemeleri',
      'icon': Icons.gavel_rounded,
      'colors': [Color(0xFFFF5252), Color(0xFFFF8A65)],
      'count': 20,
      'pathPattern':
          'assets/denemeler/kpss_lisans/deneme_{n}_kpss_lisans.json',
      'padded': false,
    },
    {
      'key': 'kpss_onlisans',
      'title': 'KPSS Önlisans / Ortaöğretim Denemeleri',
      'icon': Icons.account_balance_rounded,
      'colors': [Color(0xFFFFA000), Color(0xFFFFC107)],
      'count': 20,
      'pathPattern':
          'assets/denemeler/kpss_onlisans/deneme_{n}_kpss_onlisans.json',
      'padded': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _bgController =
        AnimationController(vsync: this, duration: const Duration(seconds: 30))
          ..repeat();
    _loadAll();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  // ── JSON Yükleyici ──────────────────────────────────────────────────────
  Future<void> _loadAll() async {
    for (final cat in _categories) {
      final key = cat['key'] as String;
      final count = cat['count'] as int;
      final pattern = cat['pathPattern'] as String;
      final padded = cat['padded'] as bool;
      final list = <Map<String, dynamic>>[];

      for (int i = 1; i <= count; i++) {
        final nStr = padded ? i.toString().padLeft(2, '0') : i.toString();
        final path = pattern.replaceAll('{n}', nStr);
        try {
          final raw = await rootBundle.loadString(path);
          final decoded = json.decode(raw);
          final questions = _extractAndNormalize(decoded);
          if (questions.isNotEmpty) {
            list.add({'title': 'Deneme $i', 'questions': questions});
          }
        } catch (_) {
          // Dosya yoksa sessizce geç
        }
      }
      _loadedExams[key] = list;
    }
    if (mounted) setState(() => _isLoading = false);
  }


  Map<String, dynamic> _shuffleMiniQuestion(Map<String, dynamic> q) {
    final options = Map<String, String>.from(q['secenekler'] ?? {});
    final correct = (q['cevap'] ?? '').toString().toUpperCase();
    if (options.length < 2 || !options.containsKey(correct)) return q;

    const letters = ['A', 'B', 'C', 'D', 'E'];
    final correctText = options[correct]!;
    final values = options.values.toList()
      ..shuffle(Random('${q['soru'] ?? DateTime.now().microsecondsSinceEpoch}'.hashCode));
    final shuffled = <String, String>{};
    for (int i = 0; i < values.length && i < letters.length; i++) {
      shuffled[letters[i]] = values[i];
    }
    return {
      ...q,
      'secenekler': shuffled,
      'cevap': shuffled.entries.firstWhere((e) => e.value == correctText).key,
    };
  }

  // ── JSON Normalizasyonu ─────────────────────────────────────────────────
  /// Farklı JSON formatlarını mini_exam_page'in beklediği formata çevirir.
  /// mini_exam_page şunları bekler:
  ///   q['soru']       → String soru metni
  ///   q['secenekler'] → Map(String, String)  {'A': '...', 'B': '...', ...}
  ///   q['cevap']      → String harf ('A', 'B', ...)
  ///   q['aciklama']   → String (opsiyonel)
  ///   q['ders']       → String ders adı (opsiyonel)
  List<Map<String, dynamic>> _extractAndNormalize(dynamic decoded) {
    List<dynamic> rawList = [];

    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map) {
      // {sorular: [...]} veya {deneme_id:..., sorular:[...]} formatı
      if (decoded['sorular'] is List) {
        rawList = decoded['sorular'] as List;
      }
    }

    const letters = ['A', 'B', 'C', 'D', 'E'];
    final result = <Map<String, dynamic>>[];

    for (final raw in rawList) {
      if (raw is! Map) continue;
      final q = Map<String, dynamic>.from(raw);

      // ── Şıkları normalize et ──────────────────────────────────────────
      Map<String, String> secenekler = {};

      if (q['siklar'] is List) {
        // Format: "siklar": ["...", "...", ...]  + "dogru_cevap": int (index)
        final siklar = q['siklar'] as List;
        for (int i = 0; i < siklar.length && i < letters.length; i++) {
          secenekler[letters[i]] = siklar[i].toString();
        }
        // dogru_cevap index → harf
        final idx = q['dogru_cevap'];
        if (idx is int && idx >= 0 && idx < letters.length) {
          q['cevap'] = letters[idx];
        } else if (idx is String && idx.length == 1) {
          q['cevap'] = idx.toUpperCase();
        }
      } else if (q['secenekler'] is Map) {
        // Zaten Map formatında
        final raw2 = q['secenekler'] as Map;
        raw2.forEach((k, v) => secenekler[k.toString().toUpperCase()] = v.toString());
      }

      q['secenekler'] = secenekler;

      // ── Ders adını normalize et ────────────────────────────────────────
      q['ders'] = q['ders_adi'] ?? q['ders'] ?? '';

      result.add(_shuffleMiniQuestion(q));
    }
    return result;
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // Arka plan gradyanı
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0E43),
                  Color(0xFF1B1F6A),
                  Color(0xFF0A2342),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          _cloud(top: size.height * 0.08, scale: 1.0, speed: 0.5, right: true),
          _cloud(
              top: size.height * 0.55, scale: 1.2, speed: 0.4, right: false),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst bar
                Padding(
                  padding: const EdgeInsets.all(20),
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mini Denemeler',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            Text('Alana göre 20\'şer deneme',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    color: Colors.white60, fontSize: 12)),
                          ]),
                    ),
                  ]),
                ),

                // Bilgi bandı
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF00E5FF).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF00E5FF)
                              .withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFF00E5FF), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Her deneme 30 soru. Alana göre seç, sırayla çöz!',
                          style: GoogleFonts.poppins(
                              color: Colors.white60, fontSize: 11),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),

                // Liste
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF00E5FF)))
                      : ListView(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          children: _categories
                              .map((cat) => _buildCategory(cat))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Kategori Bölümü ─────────────────────────────────────────────────────
  Widget _buildCategory(Map<String, dynamic> cat) {
    final key = cat['key'] as String;
    final colors = List<Color>.from(cat['colors'] as List);
    final exams = _loadedExams[key] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık satırı
        Container(
          margin: const EdgeInsets.only(bottom: 10, top: 4),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              colors[0].withValues(alpha: 0.2),
              colors[1].withValues(alpha: 0.08),
            ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors[0].withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(cat['icon'] as IconData,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(cat['title'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                  color: colors[0].withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18)),
              child: Text(
                '${exams.length} deneme',
                style: GoogleFonts.poppins(
                    color: colors[0],
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        ),

        // Deneme kartları
        if (exams.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 6),
            child: Text(
              '📁 JSON dosyaları yüklenemedi.',
              style: GoogleFonts.poppins(
                  color: Colors.white30, fontSize: 10),
            ),
          )
        else
          ...exams.asMap().entries.map((e) => _buildCard(
                label: e.value['title'] as String,
                questions: List<Map<String, dynamic>>.from(
                    e.value['questions'] as List),
                index: e.key,
                colors: colors,
                examType: key,
              )),

        const SizedBox(height: 6),
      ],
    );
  }


  Future<void> _startMiniExamWithEnergy({
    required String label,
    required List<Map<String, dynamic>> questions,
    required List<Color> colors,
    required String examType,
  }) async {
    const int cost = 15;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final energyService = EnergyService();
    await energyService.checkAndRegenEnergy(uid);

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final int mainEnergy = (userDoc.data()?['energy'] ?? 0).toInt();
    final int bonusEnergy = (userDoc.data()?['bonusEnergy'] ?? 0).toInt();

    if (mainEnergy + bonusEnergy < cost) {
      _showEnergyMessage('Mini denemeye başlamak için 15 enerji gerekiyor.');
      return;
    }

    final confirmed = await _confirmEnergySpend(
      title: 'Mini Denemeye Başla',
      amount: cost,
      description: 'Bu mini denemeye başlamak için 15 enerji kullanılacak. Denemeden erken çıkarsan harcanan enerji geri gelmez.',
    );
    if (!confirmed) return;

    final spent = await energyService.spendEnergy(uid, amount: cost);
    if (!spent) {
      _showEnergyMessage('Yeterli enerjin yok. Görevlerden veya reklamdan bonus enerji kazanabilirsin.');
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MiniExamPage(
          examTitle: label,
          questions: questions,
          colors: colors,
          examType: examType,
        ),
      ),
    );
  }

  Future<bool> _confirmEnergySpend({
    required String title,
    required int amount,
    required String description,
  }) async {
    return BRDialogs.showEnergyConfirm(
      context,
      title: title,
      amount: amount,
      message: description,
    );
  }


  void _showEnergyMessage(String message) {
    if (!mounted) return;
    BRDialogs.showInfo(
      context,
      title: 'Enerji Gerekli',
      message: message,
      icon: Icons.flash_off_rounded,
      accent: const Color(0xFFFF9100),
      buttonText: 'Tamam',
    );
  }

  // ── Deneme Kartı ────────────────────────────────────────────────────────
  Widget _buildCard({
    required String label,
    required List<Map<String, dynamic>> questions,
    required int index,
    required List<Color> colors,
    required String examType,
  }) {
    return GestureDetector(
      onTap: () => _startMiniExamWithEnergy(
        label: label,
        questions: questions,
        colors: colors,
        examType: examType,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors[0].withValues(alpha: 0.22)),
        ),
        child: Row(children: [
          // Numara
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: colors[0].withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Başlık + soru sayısı
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              Text('${questions.length} soru',
                  style: GoogleFonts.poppins(
                      color: Colors.white54, fontSize: 11)),
            ]),
          ),
          // Başlat butonu
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: colors[0].withValues(alpha: 0.15),
                shape: BoxShape.circle),
            child:
                Icon(Icons.play_arrow_rounded, color: colors[0], size: 18),
          ),
        ]),
      ),
    );
  }

  // ── Hareketli bulut ─────────────────────────────────────────────────────
  Widget _cloud(
      {required double top,
      required double scale,
      required double speed,
      required bool right}) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (ctx, _) {
        final sw = MediaQuery.of(ctx).size.width;
        final cw = 120.0 * scale;
        double off =
            (_bgController.value * speed * (sw + cw)) % (sw + cw);
        if (!right) off = sw - off;
        return Positioned(
          top: top,
          left: off - cw,
          child: Icon(Icons.cloud_rounded,
              color: Colors.white.withValues(alpha: 0.07),
              size: 120 * scale),
        );
      },
    );
  }
}