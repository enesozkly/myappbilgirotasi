import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'quiz_page.dart';
import '../services/reklam_servisi.dart';
import '../services/energy_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart' as excel_lib;

class LevelMapPage extends StatefulWidget {
  final String subjectName;
  final String topicName;
  final String examName;

  const LevelMapPage({
    super.key,
    required this.subjectName,
    required this.topicName,
    required this.examName,
  });

  @override
  State<LevelMapPage> createState() => _LevelMapPageState();
}

class _LevelMapPageState extends State<LevelMapPage>
    with TickerProviderStateMixin {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // 🔥 30 seviye — 10 soru × 30 = 300 soru
  int _totalLevels = 1;
  int _availableQuestionCount = 0;
  bool _isLoadingLevels = true;
  int _userCurrentLevel = 1;
  Map<int, int> _levelStars = {};
  bool _isVip = false;
  bool _isRewardAdLoading = false;

  late AnimationController _bgController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late ScrollController _scrollController;

  // Harita ölçüleri
  double get _nodeSpacing => 130.0;
  double get _topPadding => 180.0;
  double get _bottomPadding => 150.0;
  double get _mapHeight =>
      ((_totalLevels - 1) * _nodeSpacing) + _topPadding + _bottomPadding;

  // Snake-like path x sapmaları — 30 node için tekrar eder
  static const List<double> _xOffsets = [
    0.0,
    -0.25,
    -0.35,
    -0.15,
    0.15,
    0.35,
    0.25,
    0.0,
    -0.25,
    -0.35,
    -0.15,
    0.15,
    0.35,
    0.25,
    0.0,
    0.0,
    -0.25,
    -0.35,
    -0.15,
    0.15,
    0.35,
    0.25,
    0.0,
    -0.25,
    -0.35,
    -0.15,
    0.15,
    0.35,
    0.25,
    0.0,
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadUserProgress();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bgController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<int> _loadQuestionCountForCurrentTopic() async {
    try {
      final String? filePath = await QuizLocalRegistry.findFilePath(
  widget.examName,
  widget.subjectName,
  widget.topicName,
);

      if (filePath == null) {
        debugPrint(
          '❌ DOSYA BULUNAMADI: ${widget.examName} - ${widget.subjectName} - ${widget.topicName}',
        );
        return 0;
      }

      if (filePath.endsWith('.json')) {
        final String jsonString = await rootBundle.loadString(filePath);
        final dynamic decoded = json.decode(jsonString);

        if (decoded is List) {
          return decoded.length;
        }

        if (decoded is Map && decoded.containsKey('questions')) {
          final list = decoded['questions'];
          if (list is List) return list.length;
        }

        if (decoded is Map && decoded.containsKey('sorular')) {
          final list = decoded['sorular'];
          if (list is List) return list.length;
        }

        return 0;
      }

      if (filePath.endsWith('.xlsx')) {
        final ByteData byteData = await rootBundle.load(filePath);
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );

        final excel = excel_lib.Excel.decodeBytes(bytes);
        int count = 0;

        for (final table in excel.tables.keys) {
          final rows = excel.tables[table]!.rows;

          for (int i = 1; i < rows.length; i++) {
            final row = rows[i];
            if (row.isEmpty) continue;

            final firstCell = row[0];
            final text = firstCell?.value?.toString().trim() ?? '';

            if (text.isNotEmpty) {
              count++;
            }
          }
        }

        return count;
      }

      return 0;
    } catch (e) {
      debugPrint('Soru sayısı okunamadı: $e');
      return 0;
    }
  }

  // ── Kullanıcı ilerlemesini yükle ─────────────────────────────────────
  Future<void> _loadUserProgress() async {
    if (_uid == null) {
      if (mounted) {
        setState(() => _isLoadingLevels = false);
      }
      return;
    }

    try {
      final int questionCount = await _loadQuestionCountForCurrentTopic();
      final int calculatedTotalLevels =
          questionCount <= 0 ? 1 : (questionCount / 10).ceil();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get()
          .timeout(const Duration(seconds: 8));

      _isVip = userDoc.data()?['isVip'] == true;

      final progressQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('progress')
          .get()
          .timeout(const Duration(seconds: 8));

      final Map<int, int> starsMap = {};

      for (final doc in progressQuery.docs) {
        final data = doc.data();
        final String? subject = data['subject'];
        final String? topic = data['topic'];
        final int? section =
            data['section'] != null ? (data['section'] as num).toInt() : null;
        final int? stars =
            data['stars'] != null ? (data['stars'] as num).toInt() : null;

        if (subject == widget.subjectName &&
            topic == widget.topicName &&
            section != null &&
            stars != null) {
          starsMap[section] = stars;
        }
      }

      final String topicDocId =
          '${widget.subjectName}_${widget.topicName}'.replaceAll(' ', '_');
      final topicDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('progress')
          .doc(topicDocId)
          .get()
          .timeout(const Duration(seconds: 8));

      int currentSection = 1;
      if (topicDoc.exists) {
        currentSection = (topicDoc.data()?['currentSection'] ?? 1).toInt();
      }

      if (mounted) {
        setState(() {
          _availableQuestionCount = questionCount;
          _totalLevels = calculatedTotalLevels.clamp(1, 60).toInt();
          _levelStars = starsMap;
          _userCurrentLevel = currentSection.clamp(1, _totalLevels);
          _isLoadingLevels = false;
        });
        _scheduleScrollToCurrentLevel();
      }
    } catch (e) {
      debugPrint('Progress yüklenirken hata: $e');
      if (mounted) setState(() => _isLoadingLevels = false);
    }
  }

  void _scheduleScrollToCurrentLevel() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToCurrentLevel(animate: false);
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _scrollToCurrentLevel();
      });
      Future.delayed(const Duration(milliseconds: 360), () {
        if (mounted) _scrollToCurrentLevel();
      });
    });
  }

  void _scrollToCurrentLevel({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    final int idx = (_userCurrentLevel - 1).clamp(0, _totalLevels - 1);
    final double nodeY = _mapHeight - _bottomPadding - (idx * _nodeSpacing);

    final double screenHeight = MediaQuery.of(context).size.height;
    final double topOverlay = MediaQuery.of(context).padding.top + 96;
    final double usableHeight =
        (screenHeight - topOverlay).clamp(320.0, screenHeight);

    final double targetScroll = nodeY - (usableHeight * 0.52);
    final double safeScroll = targetScroll
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();

    if (!animate) {
      _scrollController.jumpTo(safeScroll);
      return;
    }

    _scrollController.animateTo(
      safeScroll,
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
    );
  }

  // ── Seviyeye tıklama ─────────────────────────────────────────────────
  Future<void> _onLevelTap(int level, bool isUnlocked) async {
    if (!isUnlocked) {
      _showLockedDialog(level);
      return;
    }
    await _showLevelIntroDialog(level);
  }

  Future<void> _showLevelIntroDialog(int level) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'level_intro',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) {
        return _LevelIntroDialog(
          topicName: widget.topicName,
          level: level,
          energyCost: EnergyService.energyPerLevel,
          totalQuestions: 10,
          estimatedMinutes: 5,
          onClose: () => Navigator.of(context).pop(),
          onStart: () async {
            Navigator.of(context).pop();
            await _startLevel(level);
          },
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
              child: child),
        );
      },
    );
  }

  Future<void> _startLevel(int level) async {
    final uid = _uid;
    if (uid == null) return;

    final energyService = EnergyService();
    final int startIndex = (level - 1) * 10;

    if (_availableQuestionCount > 0 && startIndex >= _availableQuestionCount) {
      _showNoQuestionDialog();
      return;
    }
    await energyService.checkAndRegenEnergy(uid);

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final int mainEnergy = (userDoc.data()?['energy'] ?? 0).toInt();
    final int bonusEnergy = (userDoc.data()?['bonusEnergy'] ?? 0).toInt();

    if (mainEnergy + bonusEnergy < EnergyService.energyPerLevel) {
      _showNoEnergyDialog();
      return;
    }

    final bool spent = await energyService.spendEnergy(uid);
    if (!spent) {
      _showNoEnergyDialog();
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizPage(
          examName: widget.examName,
          subjectName: widget.subjectName,
          topicName: widget.topicName,
          sectionNumber: level,
        ),
      ),
    ).then((_) => _loadUserProgress());
  }

  void _showLockedDialog(int level) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F6A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Text('🔒', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Text('Seviye Kilitli',
              style: GoogleFonts.poppins(
                  color: const Color(0xFFEAF2FF), fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'Bu seviyeyi açmak için önceki seviyeleri tamamla!',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Tamam',
                  style: GoogleFonts.poppins(color: const Color(0xFF00E5FF)))),
        ],
      ),
    );
  }

  void _showNoQuestionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F6A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Soru Bulunamadı',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          'Bu seviyede henüz soru yok. Lütfen önceki seviyeleri çöz veya farklı bir konu seç.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Tamam',
              style: GoogleFonts.poppins(
                color: const Color(0xFF00E5FF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNoEnergyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F6A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⚡ Enerjin Bitti!',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Text(
          'Reklam izleyerek enerji kazanabilirsin.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('İptal', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9100)),
            onPressed: () async {
              Navigator.pop(ctx);
              final uid = _uid;
              if (uid == null) return;
              setState(() => _isRewardAdLoading = true);
              final rewarded = await ReklamServisi.reklamIzletFuture(uid: uid);
              if (rewarded) {
                await EnergyService().addAdEnergy(uid);
                await _loadUserProgress();
              }
              if (mounted) {
                setState(() => _isRewardAdLoading = false);
              }
            },
            child: Text('Reklam İzle 📺',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF060B2B),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF060B2B),
                  Color(0xFF0D1545),
                  Color(0xFF060B2B),
                ],
              ),
            ),
          ),
          _buildMovingCloud(
              top: size.height * 0.1, scale: 1.2, speed: 0.3, right: true),
          _buildMovingCloud(
              top: size.height * 0.5, scale: 0.9, speed: 0.2, right: false),
          _buildMovingCloud(
              top: size.height * 0.8, scale: 1.0, speed: 0.25, right: true),
          if (_isLoadingLevels)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            )
          else
            SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: size.width,
                height: _mapHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: MapPathPainter(
                          totalLevels: _totalLevels,
                          currentLevel: _userCurrentLevel,
                          isVip: _isVip,
                          xOffsets: _xOffsets,
                          nodeSpacing: _nodeSpacing,
                          bottomPadding: _bottomPadding,
                          mapHeight: _mapHeight,
                        ),
                      ),
                    ),
                    ...List.generate(_totalLevels, (index) {
                      final int level = index + 1;
                      final bool isUnlocked = level <= _userCurrentLevel;
                      final bool isCurrent = level == _userCurrentLevel;
                      final int stars = _levelStars[level] ?? 0;

                      final double centerX = size.width / 2 +
                          (_xOffsets[index % _xOffsets.length] * size.width);
                      final double centerY =
                          _mapHeight - _bottomPadding - (index * _nodeSpacing);

                      return Positioned(
                        left: centerX - 35,
                        top: centerY - 35,
                        child:
                            _buildMapNode(level, isUnlocked, isCurrent, stars),
                      );
                    }),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 10,
                    bottom: 15,
                    left: 20,
                    right: 20,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E43).withValues(alpha: 0.7),
                    border: Border(
                      bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                  ),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.topicName,
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                          Text(
                            '${widget.subjectName} · $_userCurrentLevel / $_totalLevels Seviye',
                            style: GoogleFonts.poppins(
                                color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '%${(((_userCurrentLevel - 1) / _totalLevels) * 100).round()}',
                        style: GoogleFonts.poppins(
                            color: const Color(0xFF00E5FF),
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          if (_isRewardAdLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF9100)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapNode(int level, bool isUnlocked, bool isCurrent, int stars) {
    Color nodeColor;
    Color glowColor;
    Widget innerWidget;

    if (isUnlocked && stars > 0) {
      nodeColor = const Color(0xFF00E676);
      glowColor = const Color(0xFF00E676);
      innerWidget = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Icon(Icons.star_rounded,
                  size: 14,
                  color: i < stars
                      ? const Color(0xFFFFD700)
                      : Colors.white.withValues(alpha: 0.2)),
            ),
          ),
          const SizedBox(height: 2),
          Text('$level',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      );
    } else if (isCurrent) {
      nodeColor = const Color(0xFF00E5FF);
      glowColor = const Color(0xFF00E5FF);
      innerWidget = ScaleTransition(
        scale: _pulseAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
            Text('$level',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else if (isUnlocked) {
      nodeColor = const Color(0xFF7C5CFC);
      glowColor = const Color(0xFF7C5CFC);
      innerWidget = Text('$level',
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
    } else {
      nodeColor = Colors.white.withValues(alpha: 0.1);
      glowColor = Colors.transparent;
      innerWidget = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_rounded, color: Colors.white38, size: 18),
          Text('$level',
              style: GoogleFonts.poppins(color: Colors.white24, fontSize: 11)),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _onLevelTap(level, isUnlocked),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: nodeColor.withValues(alpha: isUnlocked ? 0.2 : 0.08),
          border: Border.all(
              color: nodeColor.withValues(alpha: isUnlocked ? 0.8 : 0.2),
              width: isCurrent ? 3 : 2),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                      color: glowColor.withValues(alpha: 0.35),
                      blurRadius: isCurrent ? 20 : 10,
                      spreadRadius: isCurrent ? 4 : 1),
                ]
              : [],
        ),
        child: Center(child: innerWidget),
      ),
    );
  }

  Widget _buildMovingCloud({
    required double top,
    required double scale,
    required double speed,
    required bool right,
  }) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, _) {
        final sw = MediaQuery.of(context).size.width;
        final cw = 150.0 * scale;
        double offset = (_bgController.value * speed * (sw + cw)) % (sw + cw);
        if (!right) offset = sw - offset;
        return Positioned(
          top: top,
          left: offset - cw,
          child: Opacity(
            opacity: 0.1,
            child: Icon(Icons.cloud_rounded,
                color: Colors.white, size: 150 * scale),
          ),
        );
      },
    );
  }
}

class _LevelIntroDialog extends StatelessWidget {
  final String topicName;
  final int level;
  final int energyCost;
  final int totalQuestions;
  final int estimatedMinutes;
  final VoidCallback onClose;
  final VoidCallback onStart;

  const _LevelIntroDialog({
    required this.topicName,
    required this.level,
    required this.energyCost,
    required this.totalQuestions,
    required this.estimatedMinutes,
    required this.onClose,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double cardWidth = size.width > 460 ? 380 : size.width * 0.88;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: Container(
            width: cardWidth,
            constraints: BoxConstraints(maxHeight: size.height * 0.88),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF08122F),
                  Color(0xFF102A62),
                  Color(0xFF182C72),
                  Color(0xFF2A2D8F),
                ],
              ),
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF081B45).withValues(alpha: 0.45),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: -18,
                  top: 74,
                  child: _glassCircle(66, Colors.white.withValues(alpha: 0.12)),
                ),
                Positioned(
                  right: 30,
                  bottom: 110,
                  child: _glassCircle(78, Colors.white.withValues(alpha: 0.10)),
                ),
                SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: onClose,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Color(0xFF5673F5),
                                  size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        topicName,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.75),
                              width: 2),
                        ),
                        child: Text(
                          'Level $level',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hazır mısın? Bu seviyede seni 10 soruluk bir mini meydan okuma bekliyor!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Quiz Detayları',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.22)),
                            const SizedBox(height: 16),
                            _detailRow(
                              Icons.quiz_outlined,
                              'Toplam Soru',
                              '$totalQuestions',
                            ),
                            const SizedBox(height: 12),
                            _detailRow(
                              Icons.schedule_rounded,
                              'Tahmini Süre',
                              '$estimatedMinutes Dakika',
                            ),
                            const SizedBox(height: 12),
                            _detailRow(
                              Icons.bolt_rounded,
                              'Kullanılacak Enerji',
                              '$energyCost Enerji',
                              valueColor: const Color(0xFFFFD54F),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                3,
                                (_) => const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 3),
                                  child: Icon(Icons.star_rounded,
                                      color: Color(0xFFFFD54F), size: 42),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Kazanılacak Yıldız: 3',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      GestureDetector(
                        onTap: onStart,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1FE2D7),
                                Color(0xFF53C8F2),
                                Color(0xFFAA5BFF),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF18D8E8)
                                    .withValues(alpha: 0.28),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Text(
                            'Başla',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: valueColor ?? Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _glassCircle(double size, Color color) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class MapPathPainter extends CustomPainter {
  final int totalLevels;
  final int currentLevel;
  final bool isVip;
  final List<double> xOffsets;
  final double nodeSpacing;
  final double bottomPadding;
  final double mapHeight;

  MapPathPainter({
    required this.totalLevels,
    required this.currentLevel,
    required this.isVip,
    required this.xOffsets,
    required this.nodeSpacing,
    required this.bottomPadding,
    required this.mapHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;

    for (int i = 0; i < totalLevels - 1; i++) {
      final int level = i + 1;
      final bool isPathUnlocked = level < currentLevel;

      final double startX =
          centerX + (xOffsets[i % xOffsets.length] * size.width);
      final double startY = mapHeight - bottomPadding - (i * nodeSpacing);

      final double endX =
          centerX + (xOffsets[(i + 1) % xOffsets.length] * size.width);
      final double endY = mapHeight - bottomPadding - ((i + 1) * nodeSpacing);

      _drawDottedLine(
          canvas, Offset(startX, startY), Offset(endX, endY), isPathUnlocked);
    }
  }

  void _drawDottedLine(Canvas canvas, Offset p1, Offset p2, bool isUnlocked) {
    final Paint dotPaint = Paint()
      ..color = isUnlocked
          ? const Color(0xFF00E5FF)
          : Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    if (isUnlocked) {
      dotPaint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
    }

    final double distance = (p2 - p1).distance;
    final double dotRadius = isUnlocked ? 4.0 : 3.0;
    final double spacing = 18.0;
    final int dotCount = (distance / spacing).floor();
    final Offset direction = (p2 - p1) / distance;

    for (int i = 1; i < dotCount; i++) {
      final Offset dotCenter = p1 + (direction * (spacing * i));
      canvas.drawCircle(dotCenter, dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
