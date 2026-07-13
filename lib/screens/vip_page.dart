import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'vip_statistics_page.dart';

/// Uygulama ücretli mağaza modeliyle dağıtıldığı için Premium erişim
/// bütün hesaplara otomatik olarak açıktır.
class VipPage extends StatelessWidget {
  const VipPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C35),
      appBar: AppBar(
        backgroundColor: const Color(0xFF11185A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Premium',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF11185A),
              Color(0xFF101B50),
              Color(0xFF07122F),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFD54F),
                        Color(0xFFFF9100),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.35),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFF4B2D00),
                    size: 58,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Premium erişimin açık',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Uygulamayı mağazadan alan her hesap bütün Premium '
                  'özelliklere ek ücret ödemeden erişir.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 26),
                _FeatureTile(
                  icon: Icons.insights_rounded,
                  title: 'VIP Analiz Merkezi',
                  description:
                      'Her ay 4 analiz hakkı. Zayıf konuların ve raporun '
                      'sisteme otomatik iletilir.',
                ),
                const SizedBox(height: 12),
                _FeatureTile(
                  icon: Icons.mail_rounded,
                  title: 'E-postayla kişisel test',
                  description:
                      'Her analizden sonra ekibimiz zayıf konuna uygun testi '
                      'kayıtlı e-posta adresine manuel olarak gönderir.',
                ),
                const SizedBox(height: 12),
                const _FeatureTile(
                  icon: Icons.block_rounded,
                  title: 'Reklamsız ve enerjisiz',
                  description:
                      'Reklam izleme ve enerji bekleme zorunluluğu yoktur.',
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VipStatisticsPage(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      foregroundColor: const Color(0xFF352300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.auto_graph_rounded),
                    label: Text(
                      'Analiz Merkezini Aç',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFFD54F),
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
