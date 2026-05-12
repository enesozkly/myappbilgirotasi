import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quiz_page.dart';

class MistakeBoxPage extends StatefulWidget {
  const MistakeBoxPage({super.key});

  @override
  State<MistakeBoxPage> createState() => _MistakeBoxPageState();
}

class _MistakeBoxPageState extends State<MistakeBoxPage>
    with TickerProviderStateMixin {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late AnimationController _bgController;
  bool _isVip = false;

  /// Normal kullanıcı: 10 soru limiti
  /// VIP kullanıcı:    50 soru limiti
  static const int normalLimit = 10;
  static const int vipLimit    = 50;

  int get _mistakeLimit => _isVip ? vipLimit : normalLimit;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _loadVip();
  }

  Future<void> _loadVip() async {
    if (_uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      if (doc.exists && mounted) {
        setState(() => _isVip = doc.data()?['isVip'] == true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  // ── Derse göre kart rengi ─────────────────────────────────────────────
  Color _cardColor(String? dersAdi) {
    switch (dersAdi) {
      case 'Biyoloji':    return const Color(0xFF00E676);
      case 'Matematik':   return const Color(0xFF00E5FF);
      case 'Geometri':    return const Color(0xFF00B0FF);
      case 'Türkçe':      return const Color(0xFFFF9100);
      case 'Tarih':       return const Color(0xFFD500F9);
      case 'Coğrafya':    return const Color(0xFF1DE9B6);
      case 'Fizik':       return const Color(0xFF536DFE);
      case 'Kimya':       return const Color(0xFFFFD600);
      case 'Felsefe':     return const Color(0xFFAB47BC);
      case 'Edebiyat':    return const Color(0xFFFF7043);
      case 'Vatandaşlık': return const Color(0xFF26C6DA);
      default:            return const Color(0xFFFF512F);
    }
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
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                colors: [
                  Color(0xFF152C5B),
                  Color(0xFF223A70),
                  Color(0xFF5A189A),
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),

          ..._buildStaticStars(size),
          _buildMovingCloud(top: size.height * 0.1, scale: 1.0, speed: 0.5, moveRight: true),
          _buildMovingCloud(top: size.height * 0.6, scale: 1.2, speed: 0.7, moveRight: false),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 14, 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Yanlış Kutusu',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Hatalarından öğren, şampiyon ol!',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Limit göstergesi — dar ekranlarda taşmayı önlemek için sabit ve kompakt tutuldu.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: (_isVip
                                    ? const Color(0xFFFFD700)
                                    : const Color(0xFF00E5FF))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (_isVip
                                      ? const Color(0xFFFFD700)
                                      : const Color(0xFF00E5FF))
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isVip
                                    ? Icons.workspace_premium_rounded
                                    : Icons.bookmark_rounded,
                                color: _isVip
                                    ? const Color(0xFFFFD700)
                                    : const Color(0xFF00E5FF),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_mistakeLimit',
                                style: GoogleFonts.poppins(
                                  color: _isVip
                                      ? const Color(0xFFFFD700)
                                      : const Color(0xFF00E5FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Limit bilgi bandı
                if (!_isVip)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.25)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            color: Color(0xFFFFD700), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'VIP ile yanlış kutusu limitin 10\'dan 50\'ye çıkar ve AI Çözüm açılır!',
                            style: GoogleFonts.poppins(
                                color: Colors.white60, fontSize: 11),
                          ),
                        ),
                      ]),
                    ),
                  ),

                // Liste
                Expanded(
                  child: _uid == null
                      ? _buildEmptyState()
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(_uid)
                              .collection('yanlislar')
                              .orderBy('kayit_tarihi', descending: true)
                              // Limiti Firestore'da uygula
                              .limit(_mistakeLimit)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline_rounded,
                                        size:  60,
                                        color: Colors.white54),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Veriler yüklenemedi.\nLütfen tekrar dene.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                          color:    Colors.white70,
                                          fontSize: 14),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return _buildEmptyState();
                            }

                            final docs = snapshot.data!.docs;

                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final data = docs[index].data()
                                    as Map<String, dynamic>;
                                return _buildMistakeCard(
                                    data, docs[index].id);
                              },
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

  // ── Yanlış Kartı ──────────────────────────────────────────────────────
  Widget _buildMistakeCard(Map<String, dynamic> mistake, String docId) {
    final String? dersAdi   = mistake['gelen_ders'];
    final Color   cardColor = _cardColor(dersAdi);

    return Container(
      margin:  const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset:     const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ders badge + konu + sil butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color:        cardColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: cardColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      dersAdi ?? 'Ders',
                      style: GoogleFonts.poppins(
                          color:      cardColor,
                          fontSize:   12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      mistake['gelen_konu'] ?? '',
                      style: GoogleFonts.poppins(
                          color:    Colors.white70,
                          fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.white54, size: 20),
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(_uid)
                        .collection('yanlislar')
                        .doc(docId)
                        .delete();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Silinemedi, tekrar dene.',
                            style: GoogleFonts.poppins(
                                color: Colors.white)),
                        backgroundColor: Colors.redAccent,
                        behavior:        SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            mistake['soru_metni'] ?? 'Soru yüklenemedi',
            style: GoogleFonts.poppins(
                color:      Colors.white,
                fontSize:   15,
                fontWeight: FontWeight.w500),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 20),

          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF00E5FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Tekrar Çöz',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizPage(
                        subjectName:    mistake['gelen_ders'] ?? 'Ders',
                        topicName:      mistake['gelen_konu'] ?? 'Konu',
                        sectionNumber:  1,
                        examName:       mistake['exam'] ?? 'TYT',
                        singleQuestion: mistake,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isVip
                      ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  foregroundColor:
                      _isVip ? const Color(0xFFFFD700) : Colors.white38,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                    color: _isVip
                        ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                  elevation: 0,
                ),
                icon: Icon(
                    _isVip ? Icons.psychology_rounded : Icons.lock_rounded,
                    size: 18),
                label: Text(_isVip ? 'AI Çözüm' : 'AI Çözüm (VIP)',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: _isVip
                    ? () => _showAiSolution(context, mistake)
                    : () => _showVipRequired(context),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _showVipRequired(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F6A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('🔒 ', style: TextStyle(fontSize: 20)),
          Text('VIP Özelliği',
              style: GoogleFonts.poppins(
                  color:      Colors.white,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Text(
            'AI Çözüm özelliği yalnızca VIP üyelere özeldir. VIP olarak tüm soruların yapay zeka destekli çözümlerine ulaşabilirsin!',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Tamam',
                  style: GoogleFonts.poppins(
                      color:      const Color(0xFF00E5FF),
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showAiSolution(BuildContext context, Map<String, dynamic> mistake) {
    final soru      = mistake['soru_metni'] ?? '';
    final dogruRaw  = mistake['dogru_cevap'];
    final harfler   = ['A', 'B', 'C', 'D', 'E'];
    final dogru     = dogruRaw is int && dogruRaw < harfler.length
        ? harfler[dogruRaw]
        : dogruRaw?.toString() ?? '';
    final aciklama  = mistake['aciklama'] ?? '';

    showModalBottomSheet(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color:         Color(0xFF1B1F6A),
          borderRadius:  BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize:      MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width:  40,
                  height: 4,
                  decoration: BoxDecoration(
                      color:        Colors.white30,
                      borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.psychology_rounded,
                    color: Color(0xFFFFD700), size: 22),
              ),
              const SizedBox(width: 10),
              Text('AI Çözüm Analizi',
                  style: GoogleFonts.poppins(
                      color:      Colors.white,
                      fontSize:   17,
                      fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border:       Border.all(color: Colors.white12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Soru',
                    style: GoogleFonts.poppins(
                        color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 4),
                Text(soru,
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        const Color(0xFF00E676).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF00E676).withValues(alpha: 0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('✅ Doğru Cevap',
                    style: GoogleFonts.poppins(
                        color:      const Color(0xFF00E676),
                        fontSize:   11,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(dogru,
                    style: GoogleFonts.poppins(
                        color:      Colors.white,
                        fontSize:   15,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
            if (aciklama.toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:        const Color(0xFF00E5FF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                ),
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('🤖 AI Açıklama',
                      style: GoogleFonts.poppins(
                          color:      const Color(0xFF00E5FF),
                          fontSize:   11,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(aciklama.toString(),
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 13)),
                ]),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size:  100,
              color: Colors.greenAccent.withValues(alpha: 0.5)),
          const SizedBox(height: 20),
          Text('Harikasın!',
              style: GoogleFonts.poppins(
                  color:      Colors.white,
                  fontSize:   24,
                  fontWeight: FontWeight.bold)),
          Text('Çözülememiş yanlış sorun bulunmuyor.',
              style: GoogleFonts.poppins(
                  color:    Colors.white70,
                  fontSize: 15)),
        ],
      ),
    );
  }

  List<Widget> _buildStaticStars(Size size) {
    final rand = Random(42);
    return List.generate(
      30,
      (_) => Positioned(
        left: rand.nextDouble() * size.width,
        top:  rand.nextDouble() * size.height,
        child: Icon(Icons.star,
            size:  rand.nextDouble() * 4 + 2,
            color: Colors.white.withValues(
                alpha: rand.nextDouble() * 0.4 + 0.1)),
      ),
    );
  }

  Widget _buildMovingCloud({
    required double top,
    required double scale,
    required double speed,
    required bool   moveRight,
  }) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final double sw = MediaQuery.of(context).size.width;
        final double cw = 150.0 * scale;
        double offset   = (_bgController.value * speed * (sw + cw)) % (sw + cw);
        if (!moveRight) offset = sw - offset;
        return Positioned(
          top:  top,
          left: offset - cw,
          child: Transform.scale(
            scale: scale,
            child: Icon(Icons.cloud_rounded,
                color: Colors.white.withValues(alpha: 0.15), size: 100),
          ),
        );
      },
    );
  }
}