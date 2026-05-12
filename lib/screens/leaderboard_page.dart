import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/avatar_frame_utils.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnimation;
  late TextEditingController _searchController;

  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  // false = Toplam XP, true = Haftalık XP
  bool _showWeekly = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _pulseController = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── XP değerini sekmeye göre seç ─────────────────────────────────────
  int _xpOf(Map<String, dynamic> data) => _showWeekly
      ? (data['weeklyXp'] ?? 0).toInt()
      : (data['totalXp']  ?? 0).toInt();

  String get _xpLabel    => _showWeekly ? 'Haftalık XP' : 'Toplam XP';
  String get _tabTitle   => _showWeekly ? 'Bu haftanın liderleri' : 'Tüm zamanların liderleri';
  String get _orderField => _showWeekly ? 'weeklyXp' : 'totalXp';

  // ── Tema sabitleri ────────────────────────────────────────────────────
  static const Color _bg1      = Color(0xFF0A0E43);
  static const Color _bg2      = Color(0xFF1B1F6A);
  static const Color _accent   = Color(0xFF00E5FF);
  static const Color _purple   = Color(0xFFD500F9);
  static const Color _gold     = Color(0xFFFFD700);
  static const Color _silver   = Color(0xFFB0BEC5);
  static const Color _bronze   = Color(0xFFFF8A65);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // ── Arka plan ────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
                colors: [_bg1, Color(0xFF0D1550), _bg2, Color(0xFF0A0A30)],
                stops:  [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),
          ..._buildStars(size),
          // Dekoratif orb'lar
          _orb(top: -70, left: -70, size: 220, color: _accent, opacity: 0.045),
          _orb(top: size.height * 0.28, right: -80, size: 190, color: _purple, opacity: 0.05),
          _orb(top: size.height * 0.65, left: -50, size: 160, color: _gold, opacity: 0.03),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                _buildTabSelector(),
                if (_showWeekly) _buildWeeklyResetNotice(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    key: ValueKey(_showWeekly),
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .orderBy(_orderField, descending: true)
                        .limit(200)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 38, height: 38,
                                child: CircularProgressIndicator(
                                  color: _accent,
                                  strokeWidth: 2,
                                  backgroundColor: _accent.withValues(alpha: 0.12),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text('Şampiyonlar yükleniyor...',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white38, fontSize: 13)),
                            ],
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi_off_rounded,
                                  color: Colors.white24, size: 52),
                              const SizedBox(height: 12),
                              Text('Sıralama yüklenemedi',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white38, fontSize: 14)),
                            ],
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyLeaderboard();
                      }

                      final baseUsers = snapshot.data!.docs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        return (data['role'] ?? 'student') == 'student';
                      }).toList();

                      final users = _showWeekly
                          ? baseUsers.where((d) {
                              final data = d.data() as Map<String, dynamic>;
                              return (data['weeklyXp'] ?? 0) > 0;
                            }).toList()
                          : baseUsers;

                      if (users.isEmpty) return _buildEmptyLeaderboard();
                      return _buildList(users);
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

  // ── Üst Bar ───────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color:        Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 16),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFFD500F9)],
              ).createShader(bounds),
              child: Text('Şampiyonlar',
                  style: GoogleFonts.poppins(
                      color:      Colors.white,
                      fontSize:   22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
            ),
            Text(_tabTitle,
                style: GoogleFonts.poppins(
                    color: Colors.white38, fontSize: 11)),
          ]),
        ),
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFF0096C7)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: _accent.withValues(alpha: 0.4),
                  blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: const Icon(Icons.emoji_events_rounded,
              color: Colors.white, size: 22),
        ),
      ]),
    );
  }

  // ── Sekme Seçici ──────────────────────────────────────────────────────
  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color:        Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(children: [
          _tabButton('🏆  Toplam XP',   isSelected: !_showWeekly,
              onTap: () => setState(() => _showWeekly = false)),
          _tabButton('⚡  Haftalık XP', isSelected: _showWeekly,
              onTap: () => setState(() => _showWeekly = true)),
        ]),
      ),
    );
  }

  Widget _buildWeeklyResetNotice() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Color(0xFFFFD700), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Haftalık sıralama her pazar 00.00’da sıfırlanır. İlk 3 öğrenci VIP ödül için admin paneline düşer.',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, height: 1.35),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tabButton(String label,
      {required bool isSelected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF0096C7)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(13),
            boxShadow: isSelected
                ? [BoxShadow(
                    color: _accent.withValues(alpha: 0.35),
                    blurRadius: 10, offset: const Offset(0, 3))]
                : null,
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.poppins(
                    color:      isSelected ? Colors.white : Colors.white30,
                    fontSize:   12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
          ),
        ),
      ),
    );
  }

  // ── Ana Liste ─────────────────────────────────────────────────────────
  Widget _buildList(List<QueryDocumentSnapshot> users) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool smallPhone = constraints.maxHeight < 560;
        final double initialSize = smallPhone ? 0.46 : 0.40;
        final double minSize = smallPhone ? 0.32 : 0.30;

        return Stack(
          children: [
            Positioned.fill(
              bottom: constraints.maxHeight * (initialSize - 0.05),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: users.length >= 3
                      ? _buildPodium(users)
                      : _buildSinglePodium(users),
                ),
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: initialSize,
              minChildSize: minSize,
              maxChildSize: 0.86,
              snap: true,
              snapSizes: const [0.40, 0.62, 0.86],
              builder: (context, scrollController) =>
                  _buildListSection(users, scrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSinglePodium(List<QueryDocumentSnapshot> users) {
    if (users.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 86, vertical: 10),
      child: _buildPodiumStep(users[0], 1, 150, _gold, const Color(0xFFFFE57F)),
    );
  }

  Widget _buildEmptyLeaderboard() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:  _accent.withValues(alpha: 0.07),
            border: Border.all(color: _accent.withValues(alpha: 0.2)),
          ),
          child: Icon(Icons.leaderboard_rounded,
              size: 42, color: _accent.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 20),
        Text('Henüz Kimse Yok',
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          _showWeekly
              ? 'Bu hafta henüz XP kazanılmadı!'
              : 'Soru çözerek XP kazan ve sıralamaya gir!',
          style: GoogleFonts.poppins(color: Colors.white30, fontSize: 13),
        ),
      ]),
    );
  }

  // ── Podyum ────────────────────────────────────────────────────────────
  Widget _buildPodium(List<QueryDocumentSnapshot> users) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top:   BorderSide(color: Colors.white.withValues(alpha: 0.07)),
          left:  BorderSide(color: Colors.white.withValues(alpha: 0.07)),
          right: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _buildPodiumStep(
              users[1], 2, 110, _silver, const Color(0xFFE0E0E0))),
          Expanded(flex: 2, child: _buildPodiumStep(
              users[0], 1, 152, _gold, const Color(0xFFFFE57F))),
          Expanded(child: _buildPodiumStep(
              users[2], 3, 85, _bronze, const Color(0xFFFFAB91))),
        ],
      ),
    );
  }

  Widget _buildPodiumStep(
    DocumentSnapshot userDoc,
    int rank, double colHeight,
    Color color, Color glowColor,
  ) {
    final data           = userDoc.data() as Map<String, dynamic>;
    String name          = data['name'] ?? 'İsimsiz';
    String displayName   = name.split(' ')[0];
    if (displayName.length > 8) { displayName = '${displayName.substring(0, 7)}..'; }
    final String initial     = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final String? avatarSeed = data['avatarSeed'];
    final int    xp          = _xpOf(data);
    final double avatarSize  = rank == 1 ? 72.0 : 54.0;
    final bool   isVip       = data['isVip'] == true;

    int avatarFrame = 0;
    final dynamic frameRaw = data['avatarFrame'];
    if (frameRaw is int) { avatarFrame = frameRaw; }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showPlayerProfile(userDoc, rank),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Taç
        if (rank == 1)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, child) => Transform.scale(
                scale: _pulseAnimation.value, child: child),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF6F00)],
              ).createShader(bounds),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 30),
            ),
          )
        else
          const SizedBox(height: 30),

        const SizedBox(height: 8),

        // Avatar
        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Glow halkası
            Container(
              width: avatarSize + 18, height: avatarSize + 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:        color.withValues(alpha: rank == 1 ? 0.6 : 0.3),
                    blurRadius:   rank == 1 ? 30 : 16,
                    spreadRadius: rank == 1 ? 4 : 1,
                  ),
                ],
              ),
            ),
            // Avatar çemberi
            Container(
              width: avatarSize, height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isVip
                      ? [getVipAvatarFrame(avatarFrame).glowColor,
                         getVipAvatarFrame(avatarFrame).glowColor.withValues(alpha: 0.4)]
                      : [color, color.withValues(alpha: 0.5)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: isVip
                      ? getVipAvatarFrame(avatarFrame).glowColor
                      : color,
                  width: rank == 1 ? 3 : 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: Container(
                    color: _bg2,
                    child: avatarSeed != null
                        ? Image.network(
                            'https://api.dicebear.com/9.x/bottts-neutral/png?seed=$avatarSeed',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                _buildInitialAvatar(initial, rank == 1 ? 24 : 17),
                          )
                        : _buildInitialAvatar(initial, rank == 1 ? 24 : 17),
                  ),
                ),
              ),
            ),
            // Sıra rozeti
            Positioned(
              bottom: -11,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)
                  ],
                ),
                child: Text(
                  rank == 1 ? '👑 KRAL' : '#$rank',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w800,
                      fontSize: 8, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        Text(displayName,
            style: GoogleFonts.poppins(
                color:      isVip ? _gold : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize:   rank == 1 ? 13 : 11),
            overflow: TextOverflow.ellipsis),

        if (isVip) ...[
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                _gold.withValues(alpha: 0.3), _gold.withValues(alpha: 0.1)
              ]),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _gold.withValues(alpha: 0.7)),
            ),
            child: Text('VIP',
                style: GoogleFonts.poppins(
                    color: _gold, fontSize: 8, fontWeight: FontWeight.w900)),
          ),
        ],

        const SizedBox(height: 4),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color:        color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text('$xp XP',
              style: GoogleFonts.poppins(
                  color: glowColor, fontWeight: FontWeight.w700, fontSize: 10)),
        ),

        const SizedBox(height: 10),

        // Podyum sütunu
        Container(
          width: double.infinity, height: colHeight,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.1)],
            ),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
            boxShadow: [
              BoxShadow(
                  color:      color.withValues(alpha: 0.35),
                  blurRadius: 20, offset: const Offset(0, -6)),
            ],
          ),
          child: Center(
            child: Text('$rank',
                style: GoogleFonts.poppins(
                    color:      Colors.white.withValues(alpha: 0.85),
                    fontSize:   rank == 1 ? 52 : 36,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: color.withValues(alpha: 0.9), blurRadius: 20),
                    ])),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildInitialAvatar(String initial, double fontSize) {
    return Container(
      color: _bg2,
      child: Center(
        child: Text(initial,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold,
                fontSize: fontSize)),
      ),
    );
  }

  // ── Liste Bölümü ──────────────────────────────────────────────────────
  Widget _buildListSection(
    List<QueryDocumentSnapshot> users,
    ScrollController scrollController,
  ) {
    final rows = _rankedRows(users);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF242C78),
              Color(0xFF1B225D),
              Color(0xFF141B4A),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 28,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 10),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accent.withValues(alpha: 0.2)),
              ),
              child: Text('Sıralama',
                  style: GoogleFonts.poppins(
                      color: _accent.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_xpLabel,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        _buildSearchBox(),
        const SizedBox(height: 8),
        Expanded(
          child: rows.isEmpty
              ? _buildNoSearchResult()
              : ListView.builder(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return _buildRankTile(row.user, row.rank, index);
                  },
                ),
        ),
        ]),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
          cursorColor: _accent,
          textInputAction: TextInputAction.search,
          onChanged: (value) =>
              setState(() => _searchQuery = value.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Oyuncu adı gir',
            hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
            prefixIcon:
                const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white38, size: 18),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildNoSearchResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded,
                color: Colors.white.withValues(alpha: 0.22), size: 54),
            const SizedBox(height: 12),
            Text('Oyuncu bulunamadı',
                style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Aradığın adı kontrol edip tekrar dene.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  List<_RankedUser> _rankedRows(List<QueryDocumentSnapshot> users) {
    final bool searching = _searchQuery.isNotEmpty;
    final rows = <_RankedUser>[];

    for (int i = 0; i < users.length; i++) {
      if (!searching && i < 3) continue;
      final data = users[i].data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();

      if (searching &&
          !name.contains(_searchQuery) &&
          !email.contains(_searchQuery)) {
        continue;
      }

      rows.add(_RankedUser(user: users[i], rank: i + 1));
    }

    return rows;
  }

  Widget _buildRankTile(
      DocumentSnapshot userDoc, int rank, int animIndex) {
    final data           = userDoc.data() as Map<String, dynamic>;
    final String? avatarSeed = data['avatarSeed'];
    final String name    = data['name'] ?? 'İsimsiz';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final int    xp      = _xpOf(data);
    final String league  = data['league'] ?? 'Bronz';
    final bool   isVip   = data['isVip'] == true;

    int avatarFrame = 0;
    final dynamic frameRaw = data['avatarFrame'];
    if (frameRaw is int) { avatarFrame = frameRaw; }

    final rankColors = {
      4: _accent,
      5: _purple,
      6: const Color(0xFFFF6B9D),
    };
    final Color accentColor =
        rankColors[rank] ?? Colors.white.withValues(alpha: 0.25);

    return TweenAnimationBuilder<double>(
      tween:    Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + animIndex * 50),
      curve:    Curves.easeOutCubic,
      builder:  (context, value, child) => Opacity(
        opacity: value,
        child:   Transform.translate(
            offset: Offset(0, 16 * (1 - value)), child: child),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showPlayerProfile(userDoc, rank),
        child: Container(
          margin:  const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: isVip
              ? LinearGradient(colors: [
                  _gold.withValues(alpha: 0.08),
                  _gold.withValues(alpha: 0.02),
                ])
              : rank <= 6
                  ? LinearGradient(colors: [
                      accentColor.withValues(alpha: 0.07),
                      Colors.transparent,
                    ])
                  : null,
          color: (!isVip && rank > 6)
              ? Colors.white.withValues(alpha: 0.04)
              : null,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isVip
                ? _gold.withValues(alpha: 0.4)
                : rank <= 6
                    ? accentColor.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.06),
            width: isVip ? 1.5 : 1,
          ),
          boxShadow: isVip
              ? [BoxShadow(
                  color: _gold.withValues(alpha: 0.1),
                  blurRadius: 12, offset: const Offset(0, 3))]
              : rank <= 6
                  ? [BoxShadow(
                      color: accentColor.withValues(alpha: 0.07),
                      blurRadius: 10, offset: const Offset(0, 3))]
                  : null,
        ),
        child: Row(children: [
          // Sıra numarası
          SizedBox(
            width: 26,
            child: Text('$rank',
                style: GoogleFonts.poppins(
                    color: rank <= 6 ? accentColor : Colors.white24,
                    fontSize: 14, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
          ),
          const SizedBox(width: 10),

          // Avatar
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(
                colors: isVip
                    ? [getVipAvatarFrame(avatarFrame).glowColor
                           .withValues(alpha: 0.4), _bg2]
                    : rank <= 6
                        ? [accentColor.withValues(alpha: 0.3), _bg2]
                        : [_bg2, _bg2],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isVip
                    ? getVipAvatarFrame(avatarFrame).glowColor
                        .withValues(alpha: 0.8)
                    : rank <= 6
                        ? accentColor.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.08),
                width: isVip ? 2 : 1.5,
              ),
              boxShadow: isVip
                  ? [BoxShadow(
                      color: getVipAvatarFrame(avatarFrame)
                          .glowColor.withValues(alpha: 0.4),
                      blurRadius: 10)]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: avatarSeed != null
                  ? Image.network(
                      'https://api.dicebear.com/9.x/bottts-neutral/png?seed=$avatarSeed',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(initial,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17)),
                      ),
                    )
                  : Center(
                      child: Text(initial,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17)),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // İsim + lig
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        color:      isVip ? _gold : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize:   13),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  if (isVip) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: _gold.withValues(alpha: 0.6)),
                      ),
                      child: Text('👑 VIP',
                          style: GoogleFonts.poppins(
                              color: _gold, fontSize: 8,
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Icon(Icons.local_fire_department_rounded,
                      color: Colors.orange.shade300, size: 11),
                  const SizedBox(width: 3),
                  Text(league,
                      style: GoogleFonts.poppins(
                          color: Colors.white30, fontSize: 10,
                          fontWeight: FontWeight.w500)),
                ]),
              ],
            ),
          ),

          // XP badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: rank <= 6
                  ? LinearGradient(colors: [
                      accentColor.withValues(alpha: 0.25),
                      accentColor.withValues(alpha: 0.1),
                    ])
                  : null,
              color: rank > 6 ? Colors.white.withValues(alpha: 0.05) : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: rank <= 6
                    ? accentColor.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text('$xp XP',
                style: GoogleFonts.poppins(
                    color:      rank <= 6 ? accentColor : Colors.white38,
                    fontWeight: FontWeight.w700,
                    fontSize:   11)),
          ),
        ]),
        ),
      ),
    );
  }


  // ── Oyuncu Profili & Takip ───────────────────────────────────────────
  void _showPlayerProfile(DocumentSnapshot userDoc, int rank) {
    final data = userDoc.data() as Map<String, dynamic>;
    final targetUid = userDoc.id;
    final String name = data['name'] ?? 'İsimsiz';
    final String email = data['email'] ?? '';
    final String league = data['league'] ?? 'Bronz';
    final int totalXp = (data['totalXp'] ?? 0).toInt();
    final int weeklyXp = (data['weeklyXp'] ?? 0).toInt();
    final int totalCorrect = (data['totalCorrect'] ?? 0).toInt();
    final int totalSections = (data['totalSections'] ?? 0).toInt();
    final int loginStreak = (data['loginStreak'] ?? 0).toInt();
    final int leagueLevel = (data['leagueLevel'] ?? 1).toInt();
    final int level = (totalXp / 100).floor();
    final bool isMe = targetUid == _currentUid;
    final bool isVip = data['isVip'] == true;
    final List badges =
        data['badges'] is List ? data['badges'] as List : const [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final followRef = _currentUid == null
            ? null
            : FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUid)
                .collection('following')
                .doc(targetUid);

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.82,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_bg1, Color(0xFF121A5C), Color(0xFF180B3E)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildPublicAvatar(data, size: 96),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                color: isVip ? _gold : Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                      ),
                      if (isVip) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.workspace_premium_rounded,
                            color: _gold, size: 20),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('#$rank · $league Ligi · Seviye $level',
                      style: GoogleFonts.poppins(
                          color: Colors.white54, fontSize: 12)),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            color: Colors.white24, fontSize: 10)),
                  ],
                  const SizedBox(height: 18),
                  if (!isMe && followRef != null)
                    StreamBuilder<DocumentSnapshot>(
                      stream: followRef.snapshots(),
                      builder: (context, snap) {
                        final following = snap.data?.exists == true;
                        return GestureDetector(
                          onTap: () => _toggleFollow(
                            targetUid: targetUid,
                            targetData: data,
                            isFollowing: following,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: following
                                  ? null
                                  : const LinearGradient(
                                      colors: [_accent, Color(0xFF0096C7)]),
                              color: following
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: following
                                    ? Colors.white.withValues(alpha: 0.16)
                                    : _accent.withValues(alpha: 0.7),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  following
                                      ? Icons.person_remove_alt_1_rounded
                                      : Icons.person_add_alt_1_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(following ? 'Takipten Çık' : 'Takip Et',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  if (isMe)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _accent.withValues(alpha: 0.25)),
                      ),
                      child: Text('Bu senin profilin',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              color: _accent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                        child: _profileStat(
                            'Toplam XP', '$totalXp', Icons.bolt_rounded, _gold)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _profileStat('Haftalık XP', '$weeklyXp',
                            Icons.flash_on_rounded, _accent)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: _profileStat('Doğru', '$totalCorrect',
                            Icons.check_circle_rounded,
                            const Color(0xFF00E676))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _profileStat('Bölüm', '$totalSections',
                            Icons.layers_rounded, _purple)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: _profileStat('Seri', '$loginStreak gün',
                            Icons.local_fire_department_rounded,
                            Colors.orangeAccent)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _profileStat('Lig Lv.', '$leagueLevel',
                            Icons.emoji_events_rounded, _bronze)),
                  ]),
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Başarımlar',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  if (badges.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Text('Henüz görünür başarım yok.',
                          style: GoogleFonts.poppins(
                              color: Colors.white38, fontSize: 12)),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: badges.take(12).map((badge) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: _gold.withValues(alpha: 0.28)),
                          ),
                          child: Text('🏅 ${badge.toString()}',
                              style: GoogleFonts.poppins(
                                  color: _gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleFollow({
    required String targetUid,
    required Map<String, dynamic> targetData,
    required bool isFollowing,
  }) async {
    final currentUid = _currentUid;
    if (currentUid == null || currentUid == targetUid) return;

    final db = FirebaseFirestore.instance;
    final followingRef = db
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUid);
    final followerRef = db
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(currentUid);

    try {
      final batch = db.batch();
      if (isFollowing) {
        batch.delete(followingRef);
        batch.delete(followerRef);
      } else {
        batch.set(followingRef, {
          'uid': targetUid,
          'name': targetData['name'] ?? 'İsimsiz',
          'email': targetData['email'] ?? '',
          'avatarSeed': targetData['avatarSeed'],
          'isVip': targetData['isVip'] == true,
          'followedAt': FieldValue.serverTimestamp(),
        });
        batch.set(followerRef, {
          'uid': currentUid,
          'followedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Takip işlemi tamamlanamadı: $e',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _buildPublicAvatar(Map<String, dynamic> data, {required double size}) {
    final String name = data['name'] ?? 'İsimsiz';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final String? avatarSeed = data['avatarSeed'];
    final bool isVip = data['isVip'] == true;
    final int avatarFrame =
        data['avatarFrame'] is int ? data['avatarFrame'] as int : 0;
    final Color frameColor =
        isVip ? getVipAvatarFrame(avatarFrame).glowColor : _accent;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [frameColor, frameColor.withValues(alpha: 0.35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: frameColor.withValues(alpha: 0.45),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          color: _bg2,
          child: avatarSeed != null
              ? Image.network(
                  'https://api.dicebear.com/9.x/bottts-neutral/png?seed=$avatarSeed',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _buildInitialAvatar(initial, 32),
                )
              : _buildInitialAvatar(initial, 32),
        ),
      ),
    );
  }

  Widget _profileStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.45), fontSize: 10)),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Arka Plan Yardımcıları ────────────────────────────────────────────
  Widget _orb({
    double? top, double? left, double? right,
    required double size, required Color color, required double opacity,
  }) {
    return Positioned(
      top: top, left: left, right: right,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: opacity * 2.5),
                blurRadius:   size * 0.8,
                spreadRadius: size * 0.05),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStars(Size size) {
    final rand = Random(77);
    return List.generate(40, (_) {
      final s = rand.nextDouble() * 2.5 + 0.8;
      return Positioned(
        left: rand.nextDouble() * size.width,
        top:  rand.nextDouble() * size.height,
        child: Container(
          width: s, height: s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(
                alpha: rand.nextDouble() * 0.3 + 0.07),
          ),
        ),
      );
    });
  }
}
class _RankedUser {
  final QueryDocumentSnapshot user;
  final int rank;

  const _RankedUser({required this.user, required this.rank});
}
