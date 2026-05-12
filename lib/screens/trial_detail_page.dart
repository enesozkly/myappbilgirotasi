// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/energy_service.dart';
import '../widgets/br_dialogs.dart';
import 'trial_quiz_page.dart';

class TrialDetailPage extends StatefulWidget {
  final String      examTitle;
  final String      folder;   // ör: 'tyt_deneme'
  final String      suffix;   // ör: 'tyt'
  final bool        padded;   // true → deneme_01_tyt.json, false → deneme_1_tyt.json
  final int         count;    // toplam deneme sayısı
  final List<Color> colors;

  const TrialDetailPage({
    super.key,
    required this.examTitle,
    required this.folder,
    required this.suffix,
    required this.padded,
    required this.count,
    required this.colors,
  });

  @override
  State<TrialDetailPage> createState() => _TrialDetailPageState();
}

class _TrialDetailPageState extends State<TrialDetailPage> {

  // Her deneme için yüklenme durumu ve soru sayısı önbelleği
  final Map<int, int> _questionCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _preloadCounts();
  }

  /// Tüm denemelerin soru sayılarını arka planda yükler
  Future<void> _preloadCounts() async {
    for (int i = 1; i <= widget.count; i++) {
      try {
        final path = _buildPath(i);
        final raw  = await rootBundle.loadString(path);
        final data = json.decode(raw);
        int count  = 0;
        if (data is List) {
          count = data.length;
        } else if (data is Map && data.containsKey('sorular')) {
          count = (data['sorular'] as List).length;
        } else if (data is Map && data.containsKey('questions')) {
          count = (data['questions'] as List).length;
        }
        if (mounted) setState(() => _questionCounts[i] = count);
      } catch (_) {
        if (mounted) setState(() => _questionCounts[i] = -1); // yüklenemedi
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }


  Map<String, dynamic> _shuffleTrialQuestion(Map<String, dynamic> q) {
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

  /// Dosya yolunu oluşturur
  /// padded=true  → assets/denemeler/tyt_deneme/deneme_01_tyt.json
  /// padded=false → assets/denemeler/ayt_sayisal_deneme/deneme_1_ayt_sayisal.json
  String _buildPath(int index) {
    final num = widget.padded
        ? index.toString().padLeft(2, '0')
        : index.toString();
    return 'assets/denemeler/${widget.folder}/deneme_${num}_${widget.suffix}.json';
  }

  /// JSON'u okuyup soruları TrialQuizPage formatına çevirir
  Future<List<Map<String, dynamic>>?> _loadQuestions(int index) async {
    try {
      final path = _buildPath(index);
      final raw  = await rootBundle.loadString(path);
      final data = json.decode(raw);

      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data.containsKey('sorular')) {
        list = data['sorular'] as List;
      } else if (data is Map && data.containsKey('questions')) {
        list = data['questions'] as List;
      }

      return list.map<Map<String, dynamic>>((item) {
        // Seçenekleri Map<String,String> formatına normalize et
        Map<String, String> secenekler = {};
        final rawSec = item['secenekler'] ?? item['siklar'] ?? item['options'];
        if (rawSec is Map) {
          rawSec.forEach((k, v) => secenekler[k.toString()] = v.toString());
        } else if (rawSec is List) {
          final harfler = ['A', 'B', 'C', 'D', 'E'];
          for (int i = 0; i < rawSec.length; i++) {
            secenekler[harfler[i]] = rawSec[i].toString();
          }
        }

        // dogru_cevap int index olarak gelebilir (0→A, 1→B...) veya harf olarak ('B')
        final harfler = ['A', 'B', 'C', 'D', 'E'];
        String cevap = '';
        final rawCevap = item['cevap'] ?? item['dogru_cevap'] ?? item['answer'];
        if (rawCevap is int) {
          cevap = (rawCevap >= 0 && rawCevap < harfler.length) ? harfler[rawCevap] : 'A';
        } else if (rawCevap != null) {
          final s = rawCevap.toString().trim().toUpperCase();
          final idx = int.tryParse(s);
          if (idx != null) {
            cevap = (idx >= 0 && idx < harfler.length) ? harfler[idx] : 'A';
          } else {
            cevap = s;
          }
        }

        return _shuffleTrialQuestion({
          // trial_quiz_page 'soru' key'ini okuyor
          'soru':     (item['soru'] ?? item['soru_metni'] ?? item['question'] ?? '').toString(),
          'secenekler': secenekler,
          'cevap':    cevap,
          'aciklama': (item['aciklama'] ?? item['explanation'] ?? '').toString(),
          'ders':     (item['ders_adi'] ?? item['ders'] ?? '').toString(),
          'svg_kod':  (item['gorsel_url'] ?? item['svg_kod'] ?? '').toString(),
        });
      }).toList();
    } catch (e) {
      debugPrint('Deneme $index yüklenemedi: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c0 = widget.colors[0];
    final c1 = widget.colors[1];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E43),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.examTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading && _questionCounts.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: widget.count,
              itemBuilder: (context, index) {
                final num = index + 1;
                final qCount = _questionCounts[num];
                return _buildCard(context, num, qCount, c0, c1);
              },
            ),
    );
  }


  Future<void> _startTrialWithEnergy(BuildContext context, int num) async {
    const int cost = 15;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final nav = Navigator.of(context);
    final energyService = EnergyService();
    await energyService.checkAndRegenEnergy(uid);

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final int mainEnergy = (userDoc.data()?['energy'] ?? 0).toInt();
    final int bonusEnergy = (userDoc.data()?['bonusEnergy'] ?? 0).toInt();

    if (mainEnergy + bonusEnergy < cost) {
      await BRDialogs.showInfo(
        context,
        title: 'Enerji Gerekli',
        message: 'Denemeye başlamak için 15 enerji gerekiyor. Görevlerden veya reklamdan bonus enerji kazanabilirsin.',
        icon: Icons.flash_off_rounded,
        accent: const Color(0xFFFF9100),
      );
      return;
    }

    final confirmed = await _confirmEnergySpend(
      title: 'Denemeye Başla',
      amount: cost,
      description: 'Bu denemeye başlamak için 15 enerji kullanılacak. Denemeden erken çıkarsan harcanan enerji geri gelmez.',
    );
    if (!confirmed || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
    final questions = await _loadQuestions(num);
    if (!mounted) return;
    nav.pop();

    if (questions == null || questions.isEmpty) {
      await BRDialogs.showInfo(
        context,
        title: 'Deneme Yüklenemedi',
        message: 'Bu deneme dosyası şu anda okunamadı. Lütfen daha sonra tekrar dene.',
        icon: Icons.error_outline_rounded,
        accent: Colors.redAccent,
      );
      return;
    }

    final spent = await energyService.spendEnergy(uid, amount: cost);
    if (!spent) {
      await BRDialogs.showInfo(
        context,
        title: 'Enerji Gerekli',
        message: 'Yeterli enerjin yok. Görevlerden veya reklamdan bonus enerji kazanabilirsin.',
        icon: Icons.flash_off_rounded,
        accent: const Color(0xFFFF9100),
      );
      return;
    }

    if (!mounted) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => TrialQuizPage(
          examTitle: widget.examTitle,
          trialName: 'Deneme $num',
          questions: questions,
          colors: widget.colors,
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


  Widget _buildCard(BuildContext context, int num, int? qCount, Color c0, Color c1) {
    final isLoaded  = qCount != null && qCount > 0;
    final isFailed  = qCount == -1;
    final isWaiting = qCount == null;

    return GestureDetector(
      onTap: isLoaded
          ? () async => _startTrialWithEnergy(context, num)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withValues(alpha: isLoaded ? 0.06 : 0.03),
          border: Border.all(
            color: isFailed
                ? Colors.redAccent.withValues(alpha: 0.3)
                : c0.withValues(alpha: isLoaded ? 0.3 : 0.15),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // Numara balonu
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: isLoaded
                    ? LinearGradient(colors: [c0, c1], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: isLoaded ? null : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isLoaded
                    ? [BoxShadow(color: c0.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Center(
                child: Text(
                  '$num',
                  style: GoogleFonts.poppins(
                    color: isLoaded ? Colors.white : Colors.white38,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deneme $num',
                    style: GoogleFonts.poppins(
                      color: isLoaded ? Colors.white : Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isFailed
                        ? 'Yüklenemedi'
                        : isWaiting
                            ? 'Yükleniyor...'
                            : '${widget.examTitle} Denemesi',
                    style: GoogleFonts.poppins(
                      color: isFailed ? Colors.redAccent.withValues(alpha: 0.7) : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isWaiting)
                  SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c0.withValues(alpha: 0.5),
                    ),
                  )
                else if (isFailed)
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 22)
                else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: c0.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c0.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '$qCount Soru',
                      style: GoogleFonts.poppins(color: c0, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(Icons.play_arrow_rounded, color: c0, size: 22),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}