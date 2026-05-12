import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  // Giriş mi, kayıt mı?
  bool _isLogin = false;

  late AnimationController _mainController;

  final _nameController            = TextEditingController();
  final _emailController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading           = false;
  bool _showPassword        = false;
  bool _showConfirmPassword = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Hata mesajı ──────────────────────────────────────────────────────
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Basit e-posta format kontrolü ────────────────────────────────────
  bool _isValidEmail(String email) {
    final trimmed = email.trim();
    return trimmed.contains('@') &&
        trimmed.contains('.') &&
        trimmed.length > 5;
  }

  // ── Şifre sıfırlama e-postası ───────────────────────────────────────
  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      _showError('Şifre sıfırlama için geçerli e-posta adresini yaz.');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Şifre sıfırlama bağlantısı e-posta adresine gönderildi.',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: const Color(0xFF00C853),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.code == 'user-not-found'
          ? 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.'
          : 'Şifre sıfırlama e-postası gönderilemedi.');
    }
  }


  // ── Kayıt / Giriş işlemi ─────────────────────────────────────────────
  Future<void> _handleAuth() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name     = _nameController.text.trim();

    // ── Validasyon ────────────────────────────────────────────────────
    if (email.isEmpty || password.isEmpty) {
      _showError('Lütfen tüm alanları doldurun.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showError('Geçerli bir e-posta adresi girin.');
      return;
    }

    if (!_isLogin) {
      if (name.isEmpty) {
        _showError('İsim alanı boş bırakılamaz.');
        return;
      }
      if (password != _confirmPasswordController.text.trim()) {
        _showError('Şifreler uyuşmuyor!');
        return;
      }
      if (password.length < 6) {
        _showError('Şifre en az 6 karakter olmalı.');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // ── GİRİŞ ─────────────────────────────────────────────────────
        await _auth.signInWithEmailAndPassword(
          email:    email,
          password: password,
        );
      } else {
        // ── KAYIT ─────────────────────────────────────────────────────
        final UserCredential cred =
            await _auth.createUserWithEmailAndPassword(
          email:    email,
          password: password,
        );

        // Ekran adını güncelle
        await cred.user?.updateDisplayName(name);

        // Firestore profili oluştur — user_service.createUserProfile
        // ile birebir alan eşleşmesi
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'uid':   cred.user!.uid,
          'name':  name,
          'email': email,
          // Rol ve VIP
          'role':       'student',
          'isVip':      false,
          // XP ve lig
          'totalXp':    0,
          'weeklyXp':   0,
          'league':     'Bronz',
          'leagueLevel': 1,
          // Enerji
          'energy':          50,
          'maxEnergy':       50,
          'bonusEnergy':     0,
          // Günlük sayaçlar
          'dailyQuestions':  0,
          'dailyCorrect':    0,
          'dailySections':   0,
          'dailyAds':        0,
          'dailyBonusEarned': 0,
          'dailyLogin':      0,
          // Haftalık sayaçlar
          'weeklyCorrect':   0,
          'weeklySections':  0,
          'weeklyAds':       0,
          // Toplam sayaçlar
          'totalBioQuestions': 0,
          'totalCorrect':      0,
          'totalSections':     0,
          // Streak
          'loginStreak': 0,
          'createdAt':   FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()));
    } on FirebaseAuthException catch (e) {
      String msg = 'Bir hata oluştu.';
      switch (e.code) {
        case 'network-request-failed':
          msg = 'İnternet bağlantınızı kontrol edin.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'E-posta veya şifre hatalı.';
          break;
        case 'user-not-found':
          msg = 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
          break;
        case 'email-already-in-use':
          msg = 'Bu e-posta zaten kullanımda.';
          break;
        case 'weak-password':
          msg = 'Şifre çok zayıf (en az 6 karakter olmalı).';
          break;
        case 'invalid-email':
          msg = 'Geçersiz e-posta formatı.';
          break;
        case 'too-many-requests':
          msg = 'Çok fazla deneme yapıldı. Lütfen biraz bekleyin.';
          break;
        case 'user-disabled':
          msg = 'Bu hesap devre dışı bırakılmış.';
          break;
      }
      _showError(msg);
    } catch (e) {
      _showError('Beklenmeyen bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Arka plan gradyanı
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                colors: [
                  Color(0xFF152C5B),
                  Color(0xFF223A70),
                  Color(0xFF5A189A)
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // Yıldızlar ve bulutlar
          ..._buildStaticStars(size),
          _buildMovingCloud(
              top: size.height * 0.05,
              scale: 1.2, speed: 0.8, moveRight: true),
          _buildMovingCloud(
              top: size.height * 0.18,
              scale: 0.8, speed: 0.5, moveRight: false),
          _buildMovingCloud(
              top: size.height * 0.35,
              scale: 1.0, speed: 0.7, moveRight: true),
          _buildMovingCloud(
              top: size.height * 0.55,
              scale: 1.3, speed: 0.6, moveRight: false),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left:   30,
                  right:  30,
                  top:    20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:        Colors.blueAccent
                                    .withValues(alpha: 0.5),
                                blurRadius:   40,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                        ),
                        const Icon(Icons.psychology_rounded,
                            size: 80, color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Text('Bilgi Rotası',
                        style: GoogleFonts.poppins(
                            color:      Colors.white,
                            fontSize:   34,
                            fontWeight: FontWeight.bold)),
                    Text(
                      _isLogin
                          ? 'Tekrar Hoş Geldin!'
                          : 'Maceraya Katıl!',
                      style: GoogleFonts.poppins(
                          color:    Colors.white70,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 40),

                    // İsim alanı (sadece kayıtta)
                    if (!_isLogin) ...[
                      _buildTextField(
                        hint:       'Ad Soyad',
                        icon:       Icons.person_outline_rounded,
                        controller: _nameController,
                      ),
                      const SizedBox(height: 15),
                    ],

                    // E-posta
                    _buildTextField(
                      hint:       'E-posta',
                      icon:       Icons.email_outlined,
                      controller: _emailController,
                    ),
                    const SizedBox(height: 15),

                    // Şifre
                    _buildTextField(
                      hint:           'Şifre',
                      icon:           Icons.lock_outline_rounded,
                      controller:     _passwordController,
                      isPassword:     true,
                      showPassword:   _showPassword,
                      onToggle: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),

                    // Şifre tekrar (sadece kayıtta)
                    if (!_isLogin) ...[
                      const SizedBox(height: 15),
                      _buildTextField(
                        hint:           'Şifre Tekrar',
                        icon:           Icons.lock_outline_rounded,
                        controller:     _confirmPasswordController,
                        isPassword:     true,
                        showPassword:   _showConfirmPassword,
                        onToggle: () => setState(
                            () => _showConfirmPassword =
                                !_showConfirmPassword),
                      ),
                    ],

                    if (_isLogin) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _sendPasswordResetEmail,
                          child: Text('Şifremi Unuttum',
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFF00E5FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Giriş / Kayıt butonu
                    _buildNeonButton(
                      text:      _isLogin ? 'GİRİŞ YAP' : 'KAYIT OL',
                      onTap:     _handleAuth,
                      isLoading: _isLoading,
                    ),

                    const SizedBox(height: 30),

                    // Geçiş satırı
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isLogin
                              ? 'Hesabın yok mu?'
                              : 'Zaten hesabın var mı?',
                          style: GoogleFonts.poppins(
                              color:    Colors.white70,
                              fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _emailController.clear();
                              _passwordController.clear();
                              _confirmPasswordController.clear();
                              _nameController.clear();
                              _showPassword        = false;
                              _showConfirmPassword = false;
                            });
                          },
                          child: Text(
                            _isLogin ? 'Kayıt Ol' : 'Giriş Yap',
                            style: GoogleFonts.poppins(
                                color:      const Color(0xFF00E5FF),
                                fontSize:   15,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TextField ─────────────────────────────────────────────────────────
  Widget _buildTextField({
    required String                hint,
    required IconData              icon,
    required TextEditingController controller,
    bool         isPassword   = false,
    bool         showPassword = false,
    VoidCallback? onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller:   controller,
        obscureText:  isPassword && !showPassword,
        keyboardType: isPassword
            ? TextInputType.visiblePassword
            : hint == 'E-posta'
                ? TextInputType.emailAddress
                : TextInputType.name,
        style: GoogleFonts.poppins(color: Colors.white),
        decoration: InputDecoration(
          hintText:        hint,
          hintStyle:       GoogleFonts.poppins(color: Colors.white54),
          prefixIcon:      Icon(icon, color: Colors.white70),
          // Şifre alanlarında göster/gizle butonu
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white54,
                    size:  20,
                  ),
                  onPressed: onToggle,
                )
              : null,
          border:          InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  // ── Neon Buton ────────────────────────────────────────────────────────
  Widget _buildNeonButton({
    required String       text,
    required VoidCallback onTap,
    required bool         isLoading,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width:  double.infinity,
        height: 65,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFFD500F9)]),
          boxShadow: [
            BoxShadow(
              color:      const Color(0xFF00E5FF).withValues(alpha: 0.5),
              blurRadius: 20,
              offset:     const Offset(-4, 4),
            )
          ],
        ),
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(text,
                  style: GoogleFonts.poppins(
                      color:      Colors.white,
                      fontSize:   22,
                      fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ── Arka Plan ─────────────────────────────────────────────────────────
  List<Widget> _buildStaticStars(Size size) {
    final rand = Random(42);
    return List.generate(
      20,
      (_) => Positioned(
        left: rand.nextDouble() * size.width,
        top:  rand.nextDouble() * size.height,
        child: Icon(Icons.star,
            size:  rand.nextDouble() * 5 + 3,
            color: Colors.white.withValues(alpha: 0.3)),
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
      animation: _mainController,
      builder: (context, child) {
        final double sw  = MediaQuery.of(context).size.width;
        final double cw  = 150.0 * scale;
        double offset    =
            (_mainController.value * speed * (sw + cw)) % (sw + cw);
        if (!moveRight) offset = sw - offset;
        return Positioned(
          top:  top,
          left: offset - cw,
          child: Transform.scale(
            scale: scale,
            child: Icon(Icons.cloud_rounded,
                color: Colors.white.withValues(alpha: 0.30),
                size:  100),
          ),
        );
      },
    );
  }
}