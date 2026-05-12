import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with TickerProviderStateMixin {
  late AnimationController _bgController;
  bool _isLoaded = false;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isLoaded = true);
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  /// Haftanın son 7 günü için soru verisi (progress koleksiyonundan)
  Future<Map<String, int>> _fetchWeeklyData() async {
    if (_uid == null) return {};
    final Map<String, int> data = {};
    try {
      final now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final key = "${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}";
        data[key] = 0;
      }

      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('daily_missions')
          .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo)
          .get();

      for (final doc in snapshot.docs) {
        final docDate = doc.id; // "2025-06-15" formatında
        if (data.containsKey(docDate)) {
          // O gün tamamlanan görev sayısını say
          final List missions = doc.data()['missions'] ?? [];
          int claimed = missions.where((m) => m['isClaimed'] == true).length;
          data[docDate] = claimed;
        }
      }
    } catch (e) {
      debugPrint("Haftalık veri hatası: $e");
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF152C5B), Color(0xFF223A70), Color(0xFF5A189A)],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          ..._buildStaticStars(size),
          _buildMovingCloud(top: size.height * 0.05, scale: 1.2, speed: 0.8, moveRight: true),
          _buildMovingCloud(top: size.height * 0.65, scale: 1.5, speed: 0.5, moveRight: false),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Text("İstatistikler", style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(_uid).snapshots(),
                    builder: (context, snapshot) {
                      int totalXp = 0;
                      int weeklyXp = 0;
                      int dailyQuestions = 0;
                      int totalBioQuestions = 0;

                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        totalXp = (data['totalXp'] ?? 0).toInt();
                        weeklyXp = (data['weeklyXp'] ?? 0).toInt();
                        dailyQuestions = (data['dailyQuestions'] ?? 0).toInt();
                        totalBioQuestions = (data['totalBioQuestions'] ?? 0).toInt();
                      }

                      int totalSolved = totalXp ~/ 10; // Her doğru 10 XP

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            // ÖZET KARTLARI
                            Row(
                              children: [
                                Expanded(child: _buildSummaryCard("Toplam XP", totalXp.toString(), Icons.bolt_rounded, Colors.amber)),
                                const SizedBox(width: 15),
                                Expanded(child: _buildSummaryCard("Haftalık XP", weeklyXp.toString(), Icons.trending_up_rounded, Colors.greenAccent)),
                                const SizedBox(width: 15),
                                Expanded(child: _buildSummaryCard("Bugün", "$dailyQuestions Soru", Icons.today_rounded, Colors.cyanAccent)),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // BİYOLOJİ VE SEVİYE KARTI
                            Row(
                              children: [
                                Expanded(child: _buildSummaryCard("Biyoloji", "$totalBioQuestions Soru", Icons.biotech_rounded, Colors.lightGreenAccent)),
                                const SizedBox(width: 15),
                                Expanded(child: _buildSummaryCard("Seviye", (totalXp ~/ 100).toString(), Icons.military_tech_rounded, Colors.purpleAccent)),
                                const SizedBox(width: 15),
                                Expanded(child: _buildSummaryCard("Çözülen", "$totalSolved Soru", Icons.done_all_rounded, const Color(0xFF00E5FF))),
                              ],
                            ),

                            const SizedBox(height: 30),

                            // HAFTALIK GRAFİK
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Haftalık Görev Performansı", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 5),
                                  Text("Bu hafta tamamladığın görev sayısı", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
                                  const SizedBox(height: 30),
                                  FutureBuilder<Map<String, int>>(
                                    future: _fetchWeeklyData(),
                                    builder: (context, weekSnap) {
                                      final weekData = weekSnap.data ?? {};
                                      final days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                                      final values = weekData.values.toList();
                                      final maxVal = values.isEmpty ? 1 : (values.reduce((a, b) => a > b ? a : b) == 0 ? 1 : values.reduce((a, b) => a > b ? a : b));

                                      return SizedBox(
                                        height: 240,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: List.generate(7, (i) {
                                            final val = i < values.length ? values[i] : 0;
                                            final factor = val / maxVal;
                                            return _buildChartBar(
                                              days[i],
                                              factor.clamp(0.0, 1.0),
                                              val.toString(),
                                            );
                                          }),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 30),

                            // XP DURUMU KARTI
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00E5FF), Color(0xFFD500F9)],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [BoxShadow(color: const Color(0xFFD500F9).withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 5))],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Toplam XP", maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                                        Text("$totalXp XP", maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  Text("Seviye ${totalXp ~/ 100}", maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      );
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

  Widget _buildSummaryCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Text(title, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildChartBar(String day, double heightFactor, String value) {
    const double maxBarHeight = 140.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedOpacity(
          opacity: _isLoaded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 800),
          child: Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(width: 14, height: maxBarHeight, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutQuart,
              width: 14,
              height: _isLoaded ? (maxBarHeight * heightFactor).clamp(4.0, maxBarHeight) : 0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFFD500F9)],
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                ),
                boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 2))],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(day, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  List<Widget> _buildStaticStars(Size size) {
    final rand = Random(42);
    return List.generate(30, (_) => Positioned(
      left: rand.nextDouble() * size.width,
      top: rand.nextDouble() * size.height,
      child: Icon(Icons.star, size: rand.nextDouble() * 4 + 2, color: Colors.white.withValues(alpha: rand.nextDouble() * 0.4 + 0.1)),
    ));
  }

  Widget _buildMovingCloud({required double top, required double scale, required double speed, required bool moveRight}) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final cloudWidth = 150.0 * scale;
        double offset = (_bgController.value * speed * (screenWidth + cloudWidth)) % (screenWidth + cloudWidth);
        if (!moveRight) offset = screenWidth - offset;
        return Positioned(
          top: top, left: offset - cloudWidth,
          child: Transform.scale(scale: scale, child: Icon(Icons.cloud_rounded, color: Colors.white.withValues(alpha: 0.10), size: 100)),
        );
      },
    );
  }
}