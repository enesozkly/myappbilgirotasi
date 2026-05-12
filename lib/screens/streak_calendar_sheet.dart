import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Modern Streak Takvim Bottom Sheet
/// Ana ekranda _showStreakCalendar yerine bu çağrılır:
/// StreakCalendarSheet.show(context);
class StreakCalendarSheet {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _StreakCalendarContent(),
    );
  }
}

class _StreakCalendarContent extends StatefulWidget {
  const _StreakCalendarContent();

  @override
  State<_StreakCalendarContent> createState() => _StreakCalendarContentState();
}

class _StreakCalendarContentState extends State<_StreakCalendarContent>
    with TickerProviderStateMixin {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  late AnimationController _entryController;
  late AnimationController _pulseController;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;

  // Giriş yapılan günler (Firestore'dan çekilecek)
  Set<String> _loginDays = {};
  int _currentStreak = 0;
  int _longestStreak = 0;
  bool _loading = true;

  DateTime _viewMonth = DateTime.now();

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _slideAnim = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadLoginDays();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadLoginDays() async {
    if (_uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Firestore'dan tüm daily_logins belgelerini çek
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('daily_logins')
          .get();

      final days = <String>{};
      for (final doc in snapshot.docs) {
        days.add(doc.id); // "2025-01-24" formatında
      }

      // Streak hesapla
      final streaks = _calculateStreaks(days);

      setState(() {
        _loginDays = days;
        _currentStreak = streaks['current']!;
        _longestStreak = streaks['longest']!;
        _loading = false;
      });

      _entryController.forward();
    } catch (e) {
      debugPrint('Streak verisi yüklenemedi: $e');
      setState(() => _loading = false);
      _entryController.forward();
    }
  }

  Map<String, int> _calculateStreaks(Set<String> days) {
    if (days.isEmpty) return {'current': 0, 'longest': 0};

    final sortedDays = days.toList()..sort();
    int longest = 1;
    int current = 1;
    int tempStreak = 1;

    for (int i = 1; i < sortedDays.length; i++) {
      final prev = DateTime.parse(sortedDays[i - 1]);
      final curr = DateTime.parse(sortedDays[i]);
      final diff = curr.difference(prev).inDays;

      if (diff == 1) {
        tempStreak++;
        if (tempStreak > longest) longest = tempStreak;
      } else {
        tempStreak = 1;
      }
    }

    // Bugün veya dün giriş yapıldıysa mevcut seri devam ediyor
    final today = _dateKey(DateTime.now());
    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));
    if (days.contains(today) || days.contains(yesterday)) {
      current = tempStreak;
    } else {
      current = 0;
    }

    return {'current': current, 'longest': longest};
  }

  String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  bool _isLoginDay(int day) {
    final key = _dateKey(DateTime(_viewMonth.year, _viewMonth.month, day));
    return _loginDays.contains(key);
  }

  bool _isToday(int day) {
    final now = DateTime.now();
    return now.year == _viewMonth.year &&
        now.month == _viewMonth.month &&
        now.day == day;
  }

  int _daysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  String _monthName(int month) {
    const names = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return names[month];
  }

  void _prevMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_viewMonth.year, _viewMonth.month + 1);
    if (!next.isAfter(DateTime(now.year, now.month + 1))) {
      setState(() => _viewMonth = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: AnimatedBuilder(
        animation: _entryController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnim.value),
            child: Opacity(
              opacity: _fadeAnim.value,
              child: child,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D1B4B),
                Color(0xFF0A0E43),
                Color(0xFF1A0A3B),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: _loading
                ? const SizedBox(
                    height: 300,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF9100),
                      ),
                    ),
                  )
                : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final daysInMonth = _daysInMonth(_viewMonth);
    final firstWeekday = DateTime(_viewMonth.year, _viewMonth.month, 1).weekday; // 1=Pzt
    final paddingDays = firstWeekday - 1; // Pazartesi başlangıçlı

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── İstatistik Rozetleri ──────────────────────────
            Row(
              children: [
                Expanded(
                  child: _buildStatBadge(
                    icon: '🔥',
                    label: 'Mevcut Seri',
                    value: '$_currentStreak gün',
                    color: const Color(0xFFFF6B00),
                    glowColor: const Color(0xFFFF9100),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBadge(
                    icon: '🏆',
                    label: 'En Uzun Seri',
                    value: '$_longestStreak gün',
                    color: const Color(0xFFFFD700),
                    glowColor: const Color(0xFFFFD700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBadge(
                    icon: '📅',
                    label: 'Toplam Giriş',
                    value: '${_loginDays.length} gün',
                    color: const Color(0xFF00E5FF),
                    glowColor: const Color(0xFF00B0FF),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Ay Başlığı & Navigasyon ───────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _prevMonth,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 22),
                  ),
                ),

                Column(
                  children: [
                    Text(
                      _monthName(_viewMonth.month),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${_viewMonth.year}',
                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                GestureDetector(
                  onTap: _nextMonth,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 22),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── Haftanın Günleri Başlığı ─────────────────────
            Row(
              children: ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: GoogleFonts.poppins(
                            color: d == 'Ct' || d == 'Pz'
                                ? const Color(0xFFFF6B6B).withValues(alpha: 0.7)
                                : Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 10),

            // ── Takvim Grid ───────────────────────────────────
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 0.85,
              ),
              itemCount: paddingDays + daysInMonth,
              itemBuilder: (context, index) {
                if (index < paddingDays) {
                  return const SizedBox.shrink();
                }
                final day = index - paddingDays + 1;
                final isLogin = _isLoginDay(day);
                final isToday = _isToday(day);
                final isFuture = DateTime(_viewMonth.year, _viewMonth.month, day)
                    .isAfter(DateTime.now());

                return _buildDayCell(
                  day: day,
                  isLogin: isLogin,
                  isToday: isToday,
                  isFuture: isFuture,
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Lejant ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(
                  color: const Color(0xFFFF9100),
                  label: 'Giriş yapıldı',
                  icon: '🔥',
                ),
                const SizedBox(width: 24),
                _buildLegendItem(
                  color: const Color(0xFF00E5FF),
                  label: 'Bugün',
                  isToday: true,
                ),
                const SizedBox(width: 24),
                _buildLegendItem(
                  color: Colors.white12,
                  label: 'Girilmedi',
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge({
    required String icon,
    required String label,
    required String value,
    required Color color,
    required Color glowColor,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: icon == '🔥' && _currentStreak > 0 ? _pulseAnim.value : 1.0,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white38,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell({
    required int day,
    required bool isLogin,
    required bool isToday,
    required bool isFuture,
  }) {
    Color bgColor;
    Color borderColor;
    Widget dayContent;

    if (isLogin && isToday) {
      // Bugün giriş yapıldı — özel parlak hali
      bgColor = const Color(0xFFFF6B00).withValues(alpha: 0.25);
      borderColor = const Color(0xFFFF9100);
      dayContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          const Text('🔥', style: TextStyle(fontSize: 14)),
        ],
      );
    } else if (isLogin) {
      bgColor = const Color(0xFFFF6B00).withValues(alpha: 0.15);
      borderColor = const Color(0xFFFF9100).withValues(alpha: 0.6);
      dayContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: GoogleFonts.poppins(
              color: const Color(0xFFFF9100),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text('🔥', style: TextStyle(fontSize: 12)),
        ],
      );
    } else if (isToday) {
      bgColor = const Color(0xFF00E5FF).withValues(alpha: 0.15);
      borderColor = const Color(0xFF00E5FF);
      dayContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: GoogleFonts.poppins(
              color: const Color(0xFF00E5FF),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFF00E5FF),
              shape: BoxShape.circle,
            ),
          ),
        ],
      );
    } else if (isFuture) {
      bgColor = Colors.transparent;
      borderColor = Colors.white.withValues(alpha: 0.04);
      dayContent = Text(
        '$day',
        style: GoogleFonts.poppins(
          color: Colors.white.withValues(alpha: 0.15),
          fontSize: 12,
        ),
      );
    } else {
      // Geçmiş, giriş yapılmamış
      bgColor = Colors.white.withValues(alpha: 0.03);
      borderColor = Colors.white.withValues(alpha: 0.08);
      dayContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: GoogleFonts.poppins(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isLogin || isToday
            ? [
                BoxShadow(
                  color: (isLogin
                          ? const Color(0xFFFF9100)
                          : const Color(0xFF00E5FF))
                      .withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Center(child: dayContent),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    String? icon,
    bool isToday = false,
  }) {
    return Row(
      children: [
        if (icon != null)
          Text(icon, style: const TextStyle(fontSize: 12))
        else if (isToday)
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color, width: 1.5),
            ),
          )
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white38,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}