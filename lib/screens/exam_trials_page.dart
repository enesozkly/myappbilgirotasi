import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'trial_detail_page.dart';

class ExamTrialsPage extends StatelessWidget {
  const ExamTrialsPage({super.key});

  static const List<Map<String, dynamic>> _examTypes = [
    {
      'title': 'TYT',
      'subtitle': 'Temel Yeterlilik Testi',
      'folder': 'tyt_deneme',
      'suffix': 'tyt',
      'padded': true,  // deneme_01_tyt.json (sıfır dolgulu)
      'count': 20,
      'icon': Icons.school_rounded,
      'colors': [Color(0xFF00E5FF), Color(0xFF007BFF)],
    },
    {
      'title': 'AYT Sayısal',
      'subtitle': 'Matematik, Fizik, Kimya, Biyoloji',
      'folder': 'ayt_sayisal_deneme',
      'suffix': 'ayt_sayisal',
      'padded': false, // deneme_1_ayt_sayisal.json
      'count': 20,
      'icon': Icons.calculate_rounded,
      'colors': [Color(0xFF1D976C), Color(0xFF38EF7D)],
    },
    {
      'title': 'AYT Eşit Ağırlık',
      'subtitle': 'Edebiyat, Matematik, Tarih, Coğrafya',
      'folder': 'ayt_esitagirlik_deneme',
      'suffix': 'ayt_esit_agirlik',
      'padded': false,
      'count': 20,
      'icon': Icons.menu_book_rounded,
      'colors': [Color(0xFFD500F9), Color(0xFF9C27B0)],
    },
    {
      'title': 'AYT Sözel',
      'subtitle': 'Edebiyat, Tarih, Coğrafya, Felsefe',
      'folder': 'sozel_deneme',
      'suffix': 'ayt_sozel',
      'padded': false,
      'count': 20,
      'icon': Icons.auto_stories_rounded,
      'colors': [Color(0xFFFF6D00), Color(0xFFFFAB40)],
    },
    {
      'title': 'KPSS Lisans',
      'subtitle': 'Türkçe, Matematik, Tarih, Coğrafya...',
      'folder': 'kpss_lisans',
      'suffix': 'kpss_lisans',
      'padded': false,
      'count': 20,
      'icon': Icons.gavel_rounded,
      'colors': [Color(0xFFFF5252), Color(0xFFFF8A65)],
    },
    {
      'title': 'KPSS Önlisans / Ortaöğretim',
      'subtitle': 'Türkçe, Matematik, Vatandaşlık...',
      'folder': 'kpss_önlisans',   // klasör adı Türkçe ö içeriyor
      'suffix': 'kpss_onlisans',
      'padded': false,
      'count': 20,
      'icon': Icons.account_balance_rounded,
      'colors': [Color(0xFFFFA000), Color(0xFFFFC107)],
    },
  ];

  @override
  Widget build(BuildContext context) {
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
          'Denemeler',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Her sınav türü için 20 tam deneme sınavı!',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _examTypes.length,
              itemBuilder: (context, index) => _buildCard(context, _examTypes[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> exam) {
    final colors = exam['colors'] as List<Color>;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TrialDetailPage(
            examTitle: exam['title'] as String,
            folder:    exam['folder'] as String,
            suffix:    exam['suffix'] as String,
            padded:    exam['padded'] as bool,
            count:     exam['count'] as int,
            colors:    colors,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [colors[0].withValues(alpha: 0.15), colors[1].withValues(alpha: 0.08)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: colors[0].withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 58, height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: colors[0].withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Icon(exam['icon'] as IconData, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exam['title'] as String,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(exam['subtitle'] as String,
                      style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors[0].withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${exam['count']} Deneme',
                  style: GoogleFonts.poppins(color: colors[0], fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}