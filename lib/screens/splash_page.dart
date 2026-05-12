import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import 'auth_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _opacityController;
  late AnimationController _logoController;
  late Animation<double> _opacityAnimation;
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();

    // Genelopaklık (fade-in) animasyonu
    _opacityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _opacityAnimation = CurvedAnimation(parent: _opacityController, curve: Curves.easeIn);

    // Logo parlatma ve hafif ölçeklendirme (nefes alma) animasyonu
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startNavigation();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _opacityController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _startNavigation() async {
    _opacityController.forward(); // Animasyonu başlat
    await Future.delayed(const Duration(seconds: 4)); // Ekranın görünme süresi

    if (!mounted) return;

    // Firebase Auth ile kullanıcı oturum durumunu kontrol et
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Oturum açık, ana sayfaya git
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      // Oturum kapalı, giriş sayfasına git
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF06092B), // Derin uzay mavisi
      body: Stack(
        children: [
          // 1. Arka Plan Gradyanı ve Hareketli Yıldızlar
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF06092B), Color(0xFF11144C), Color(0xFF0A2342)],
              ),
            ),
          ),
          ..._buildStaticStars(size),
          _buildMovingCloud(top: size.height * 0.1, scale: 0.8, speed: 0.4, moveRight: true),
          _buildMovingCloud(top: size.height * 0.7, scale: 1.2, speed: 0.3, moveRight: false),

          // 2. Ana İçerik (Logo ve İsim)
          Center(
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Profesyonel ve Parlayan Logo
                  _buildPulsingLogo(),
                  const SizedBox(height: 30),
                  
                  // Uygulama İsmi (Modern Tipografi)
                  Text(
                    'BİLGİ ROTASI',
                    style: GoogleFonts.comfortaa(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3.0,
                      shadows: [
                        Shadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Alt Metin
                  Text(
                    'Öğrenme Yolculuğun Burada Başlar',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF00E5FF),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 3. Alt Kısımda Yükleniyor Göstergesi
          const Positioned(
            bottom: 60, left: 0, right: 0,
            child: Center(
              child: SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                  minHeight: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        final double scale = 1.0 + (_logoController.value * 0.1); // Hafif büyüme/küçülme
        final double blur = 10.0 + (_logoController.value * 15.0); // Parlama değişimi
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1B1F6A).withValues(alpha: 0.3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  blurRadius: blur,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Center(
              // Burada uygulamanın ana logosu veya özel bir simge olabilir.
              // Simgesel bir "R" harfi ve pusula/rota teması:
              child: Icon(
                Icons.explore_rounded,
                size: 80,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: const Color(0xFF00E5FF),
                    blurRadius: 20 * _logoController.value,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildStaticStars(Size size) {
    final rand = Random(55);
    return List.generate(40, (_) => Positioned(
      left: rand.nextDouble() * size.width, 
      top: rand.nextDouble() * size.height, 
      child: Icon(Icons.star, size: rand.nextDouble() * 3 + 1, color: Colors.white.withValues(alpha: rand.nextDouble() * 0.4 + 0.1))));
  }

  Widget _buildMovingCloud({required double top, required double scale, required double speed, required bool moveRight}) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final cloudWidth = 120.0 * scale;
        double offset = (_bgController.value * speed * (screenWidth + cloudWidth)) % (screenWidth + cloudWidth);
        if (!moveRight) offset = screenWidth - offset;
        return Positioned(
          top: top, left: offset - cloudWidth,
          child: Icon(Icons.cloud_rounded, color: Colors.white.withValues(alpha: 0.15), size: 120 * scale)
        );
      },
    );
  }
}