import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'topics_page.dart';

class SubjectsPage extends StatelessWidget {
  final String examName;

  const SubjectsPage({super.key, required this.examName});

  List<Map<String, dynamic>> _getSubjects() {
    // KPSS Lisans ve Önlisans için ortak dersler
    if (examName == "Lisans" || examName == "Önlisans") {
      return [
        {"name": "Türkçe", "icon": Icons.translate_rounded, "colors": [const Color(0xFFFF512F), const Color(0xFFF09819)]},
        {"name": "Matematik", "icon": Icons.calculate_rounded, "colors": [const Color(0xFF4CB8C4), const Color(0xFF3CD3AD)]},
        {"name": "Tarih", "icon": Icons.account_balance_rounded, "colors": [const Color(0xFF834D9B), const Color(0xFFD04ED6)]},
        {"name": "Coğrafya", "icon": Icons.public_rounded, "colors": [const Color(0xFF11998E), const Color(0xFF38EF7D)]},
        {"name": "Vatandaşlık", "icon": Icons.gavel_rounded, "colors": [const Color(0xFFEB3349), const Color(0xFFF45C43)]},
      ];
    }
    // AYT Branşları
    else if (examName == "AYT") {
      return [
        {"name": "Edebiyat", "icon": Icons.menu_book_rounded, "colors": [const Color(0xFFFF512F), const Color(0xFFF09819)]},
        {"name": "Matematik", "icon": Icons.calculate_rounded, "colors": [const Color(0xFF4CB8C4), const Color(0xFF3CD3AD)]},
        {"name": "Tarih", "icon": Icons.account_balance_rounded, "colors": [const Color(0xFF834D9B), const Color(0xFFD04ED6)]},
        {"name": "Coğrafya", "icon": Icons.public_rounded, "colors": [const Color(0xFF11998E), const Color(0xFF38EF7D)]},
        {"name": "Fizik", "icon": Icons.science_rounded, "colors": [const Color(0xFF396AFC), const Color(0xFF2979FF)]},
        {"name": "Kimya", "icon": Icons.biotech_rounded, "colors": [const Color(0xFFF09819), const Color(0xFFEDDE5D)]},
        {"name": "Biyoloji", "icon": Icons.eco_rounded, "colors": [const Color(0xFF1D976C), const Color(0xFF38EF7D)]},
        {"name": "Felsefe", "icon": Icons.psychology_rounded, "colors": [const Color(0xFF654ea3), const Color(0xFFeaafc8)]},
        // AYT Din Kültürü (Klasörde olduğu için menüye eklendi)
        {"name": "Din Kültürü", "icon": Icons.auto_stories_rounded, "colors": [const Color(0xFF5A189A), const Color(0xFF9D4EDD)]},
      ];
    }
    // TYT Branşları (Varsayılan)
    else {
      return [
        {"name": "Türkçe", "icon": Icons.translate_rounded, "colors": [const Color(0xFFFF512F), const Color(0xFFF09819)]},
        {"name": "Matematik", "icon": Icons.calculate_rounded, "colors": [const Color(0xFF4CB8C4), const Color(0xFF3CD3AD)]},
        {"name": "Tarih", "icon": Icons.account_balance_rounded, "colors": [const Color(0xFF834D9B), const Color(0xFFD04ED6)]},
        {"name": "Coğrafya", "icon": Icons.public_rounded, "colors": [const Color(0xFF11998E), const Color(0xFF38EF7D)]},
        {"name": "Fizik", "icon": Icons.science_rounded, "colors": [const Color(0xFF396AFC), const Color(0xFF2979FF)]},
        {"name": "Kimya", "icon": Icons.biotech_rounded, "colors": [const Color(0xFFF09819), const Color(0xFFEDDE5D)]},
        {"name": "Biyoloji", "icon": Icons.eco_rounded, "colors": [const Color(0xFF1D976C), const Color(0xFF38EF7D)]},
        {"name": "Felsefe", "icon": Icons.psychology_rounded, "colors": [const Color(0xFF654ea3), const Color(0xFFeaafc8)]},
        {"name": "Din Kültürü", "icon": Icons.auto_stories_rounded, "colors": [const Color(0xFF5A189A), const Color(0xFF9D4EDD)]},
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _getSubjects();
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0E43), Color(0xFF1B1F6A), Color(0xFF00C6FF)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "$examName Branşları",
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      return _buildSubjectCard(context, subjects[index]);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, Map<String, dynamic> subject) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TopicsPage(
              examName: examName,
              subjectName: subject["name"],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            colors: subject["colors"],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: subject["colors"][0].withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                subject["icon"],
                size: 90,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(subject["icon"], color: Colors.white, size: 28),
                  ),
                  const Spacer(),
                  Text(
                    subject["name"],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Başla 🚀",
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
