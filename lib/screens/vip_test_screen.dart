import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/vip_purchase_service.dart';
import '../services/vip_user_service.dart';
import 'vip_statistics_page.dart';

class VipTestScreen extends StatefulWidget {
  const VipTestScreen({super.key});

  @override
  State<VipTestScreen> createState() => _VipTestScreenState();
}

class _VipTestScreenState extends State<VipTestScreen> {
  bool _loading = true;
  bool _buying = false;

  String? _error;
  String? _purchaseMessage;

  List<VipPlanOption> _plans = [];
  VipPlanOption? _selectedPlan;

  @override
  void initState() {
    super.initState();

    VipPurchaseService.instance.startListening(
      onPurchased: (purchase) async {
        if (!mounted) return;

        final VipPlanOption? selectedPlan = _selectedPlan;

        if (selectedPlan == null) {
          setState(() {
            _buying = false;
            _purchaseMessage =
                'Satın alma başarılı ama seçilen plan bulunamadı.';
          });
          return;
        }

        try {
          await VipUserService.instance.activateVip(
            planKey: selectedPlan.planKey,
            productId: purchase.productID,
            purchaseId: purchase.purchaseID ??
                purchase.verificationData.serverVerificationData,
          );

          if (!mounted) return;

          setState(() {
            _buying = false;
            _purchaseMessage = 'VIP üyeliğiniz başarıyla aktif edildi.';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('VIP üyeliğiniz aktif edildi!'),
            ),
          );

          await Future.delayed(const Duration(milliseconds: 800));

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const VipStatisticsPage(),
            ),
          );
        } catch (e) {
          if (!mounted) return;

          setState(() {
            _buying = false;
            _purchaseMessage =
                'Satın alma oldu ama VIP kaydı başarısız: $e';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('VIP kaydı başarısız: $e'),
            ),
          );
        }
      },
      onPending: (purchase) {
        if (!mounted) return;

        setState(() {
          _buying = false;
          _purchaseMessage =
              'Ödeme beklemede. Onaylanınca VIP üyeliğiniz aktif edilecek.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ödeme beklemede.'),
          ),
        );
      },
      onError: (message) {
        if (!mounted) return;

        setState(() {
          _buying = false;
          _purchaseMessage = message;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );
      },
    );

    _loadPlans();
  }

  @override
  void dispose() {
    VipPurchaseService.instance.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plans = await VipPurchaseService.instance.loadVipPlans();

      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _buyPlan(VipPlanOption plan) async {
    if (_buying) return;

    setState(() {
      _buying = true;
      _selectedPlan = plan;
      _purchaseMessage =
          '${_titleForPlan(plan.planKey)} satın alma başlatılıyor...';
    });

    try {
      await VipPurchaseService.instance.buyVipPlan(plan);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _buying = false;
        _purchaseMessage = 'Satın alma başlatılamadı: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satın alma başlatılamadı: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06092B),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF06092B),
            Color(0xFF10164A),
            Color(0xFF061C3C),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: _glowCircle(
              color: const Color(0xFFFFD700),
              size: 260,
              opacity: 0.18,
            ),
          ),
          Positioned(
            top: 240,
            left: -120,
            child: _glowCircle(
              color: const Color(0xFF00E5FF),
              size: 240,
              opacity: 0.12,
            ),
          ),
          Positioned(
            bottom: -130,
            right: -80,
            child: _glowCircle(
              color: const Color(0xFFD500F9),
              size: 260,
              opacity: 0.11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle({
    required Color color,
    required double size,
    required double opacity,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: opacity),
            blurRadius: 110,
            spreadRadius: 45,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            child: Column(
              children: [
                _buildHeroCard(),
                const SizedBox(height: 16),
                _buildQuickValueGrid(),
                const SizedBox(height: 16),
                _buildBenefitsCard(),
                const SizedBox(height: 16),
                _buildProcessCard(),
                const SizedBox(height: 16),

                if (_purchaseMessage != null) ...[
                  _buildMessageBox(),
                  const SizedBox(height: 16),
                ],

                if (_buying) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: const LinearProgressIndicator(
                      minHeight: 7,
                      color: Color(0xFFFFD700),
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                _buildPlansSection(),
                const SizedBox(height: 14),
                _buildFooterNote(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 6, 4),
      child: Row(
        children: [
          _roundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'VIP Üyelik',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Sınav Kazandıran Paket',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.88),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          _roundIconButton(
            icon: Icons.refresh_rounded,
            onTap: _loadPlans,
          ),
        ],
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFE082),
            Color(0xFFFFB300),
            Color(0xFFFF7A00),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.34),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -28,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 126,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2100).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.34),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'PREMIUM SINAV MODU',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '👑',
                    style: TextStyle(fontSize: 42),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Bilgi Rotası VIP',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Zayıf konularını gör, sana özel çalışma desteği al, enerjini ikiye katla ve sınava daha güçlü hazırlan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.94),
                  fontSize: 13.2,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildHeroMiniStat(
                      value: '100',
                      label: 'Enerji limiti',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeroMiniStat(
                      value: '4',
                      label: 'Analiz hakkı',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeroMiniStat(
                      value: '0',
                      label: 'Zorunlu reklam',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2100).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  'Satın alma tamamlanmadan VIP açılmaz. Paket yalnızca App Store / Google Play satın alma sonucu başarılı dönerse aktif edilir.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMiniStat({
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.26),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 9.8,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickValueGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.15,
      children: [
        _buildValuePill(Icons.analytics_rounded, 'Haftalık analiz', 'Ayda 4 hak'),
        _buildValuePill(Icons.fact_check_rounded, 'Kişisel test', 'Ayda 1 hak'),
        _buildValuePill(Icons.picture_as_pdf_rounded, 'PDF talebi', '1 konu anlatım'),
        _buildValuePill(Icons.verified_rounded, 'VIP rozet', 'Sıralamada görünür'),
      ],
    );
  }

  Widget _buildValuePill(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFFD700),
              size: 20,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 9.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard() {
    return _buildGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.auto_awesome_rounded,
            title: 'VIP ile gelen güçlü avantajlar',
            subtitle: 'Sınav temposunu hızlandıran premium paket',
          ),
          const SizedBox(height: 16),
          _buildBenefitTile(
            icon: Icons.emoji_events_rounded,
            title: 'Sınav Kazandıran Paket',
            desc:
                'Analiz, kişisel test, PDF notları, enerji avantajı, reklamsız kullanım ve rozet ayrıcalığı tek pakette.',
            accent: const Color(0xFFFFD700),
          ),
          _buildBenefitTile(
            icon: Icons.analytics_rounded,
            title: 'Haftalık zayıf konu analizi',
            desc:
                'Ayda 4 hak ile her hafta zayıf olduğun konular netleşir. Nereye çalışacağını daha kolay görürsün.',
            accent: const Color(0xFFD500F9),
          ),
          _buildBenefitTile(
            icon: Icons.fact_check_rounded,
            title: 'Yanlışlarına göre kişisel test',
            desc:
                'Ayda 1 hak ile eksiklerinden özel test talep edebilirsin. Test 24 saat içinde e-posta ile gönderilir.',
            accent: const Color(0xFF8A52FF),
          ),
          _buildBenefitTile(
            icon: Icons.picture_as_pdf_rounded,
            title: '1 konu anlatım PDF hakkı',
            desc:
                'İstediğin bir konu için sınav odaklı notlar ve konu anlatım PDF talebi oluşturabilirsin.',
            accent: const Color(0xFFFFAB40),
          ),
          _buildBenefitTile(
            icon: Icons.bolt_rounded,
            title: '2 kat enerji',
            desc:
                '50 yerine 100 enerji limitiyle daha uzun süre test çözebilir, çalışma akışını daha az bölersin.',
            accent: const Color(0xFFFFD54F),
          ),
          _buildBenefitTile(
            icon: Icons.flash_on_rounded,
            title: '2 kat enerji yenileme hızı',
            desc:
                'Enerjin daha hızlı yenilenir. Gün içinde daha fazla pratik yapma şansı yakalarsın.',
            accent: const Color(0xFFFF9100),
          ),
          _buildBenefitTile(
            icon: Icons.task_alt_rounded,
            title: 'Görevlerden x2 enerji kazanımı',
            desc:
                'Görevlerden daha yüksek enerji kazanarak uygulama içindeki ilerlemeni hızlandırırsın.',
            accent: const Color(0xFF69F0AE),
          ),
          _buildBenefitTile(
            icon: Icons.inventory_2_rounded,
            title: 'Yanlış kutusu limiti 50 soru',
            desc:
                'Daha fazla yanlışını sakla, tekrar çöz ve eksiklerini düzenli takip et.',
            accent: const Color(0xFF00E5FF),
          ),
          _buildBenefitTile(
            icon: Icons.block_rounded,
            title: 'Reklamsız kullanım',
            desc:
                'Zorunlu reklam olmadan daha akıcı, odaklı ve kesintisiz çalışma deneyimi yaşarsın.',
            accent: const Color(0xFFFF7043),
          ),
          _buildBenefitTile(
            icon: Icons.verified_rounded,
            title: 'Sıralamada VIP rozet',
            desc:
                'Profilinde ve sıralama alanlarında özel VIP görünümü aktif olur.',
            accent: const Color(0xFFFFD700),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProcessCard() {
    return _buildGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.route_rounded,
            title: 'VIP nasıl çalışır?',
            subtitle: 'Talep oluştur, analiz al, eksiklerini kapat',
          ),
          const SizedBox(height: 14),
          _buildStepTile('1', 'Zayıf konularını analiz ettir',
              'Haftalık analiz hakkınla eksik alanlarını netleştir.'),
          _buildStepTile('2', 'Yanlışlarından test iste',
              'Sana özel test talebi oluştur, 24 saat içinde e-postanı kontrol et.'),
          _buildStepTile('3', 'PDF not talebi oluştur',
              'İstediğin bir konu için sınav odaklı notlarını talep et.'),
          _buildStepTile('4', 'Daha fazla enerjiyle ilerle',
              '100 enerji limiti ve hızlı yenileme ile daha çok pratik yap.',
              isLast: true),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFD700),
                Color(0xFFFF9800),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.20),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitTile({
    required IconData icon,
    required String title,
    required String desc,
    required Color accent,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accent.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              icon,
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13.6,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 11.3,
                    fontWeight: FontWeight.w500,
                    height: 1.37,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTile(
    String number,
    String title,
    String desc, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2B2100),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_rounded,
            color: Color(0xFF00E5FF),
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _purchaseMessage!,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12.3,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansSection() {
    if (_loading) {
      return _buildStoreStatusCard(
        icon: Icons.hourglass_top_rounded,
        title: 'VIP planları yükleniyor',
        message: 'App Store / Google Play plan bilgileri hazırlanıyor...',
        showRetry: false,
      );
    }

    if (_error != null) {
      return _buildStoreStatusCard(
        icon: Icons.error_outline_rounded,
        title: 'VIP planları yüklenemedi',
        message: _error!,
        showRetry: true,
      );
    }

    if (_plans.isEmpty) {
      return _buildStoreStatusCard(
        icon: Icons.workspace_premium_rounded,
        title: 'VIP planı bulunamadı',
        message:
            'Mağaza planları şu anda listelenemedi. Lütfen biraz sonra tekrar deneyin.',
        showRetry: true,
      );
    }

    return Column(
      children: [
        _buildPlansHeader(),
        const SizedBox(height: 12),
        ..._plans.map(_buildPlanCard),
      ],
    );
  }

  Widget _buildPlansHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Planını seç, VIP’i başlat',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.30),
            ),
          ),
          child: Text(
            'Güvenli ödeme',
            style: GoogleFonts.poppins(
              color: const Color(0xFFFFD700),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreStatusCard({
    required IconData icon,
    required String title,
    required String message,
    required bool showRetry,
  }) {
    return _buildGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFFD700),
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          if (showRetry) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadPlans,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar dene'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF211A74),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanCard(VipPlanOption plan) {
    final bool isSelected = _selectedPlan?.planKey == plan.planKey;
    final bool highlighted = plan.planKey == 'yearly';
    final String badge = _badgeForPlan(plan.planKey);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: _buying ? null : () => _buyPlan(plan),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: highlighted
                ? const Color(0xFFFFD700).withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFFD700)
                  : highlighted
                      ? const Color(0xFFFFD700).withValues(alpha: 0.68)
                      : Colors.white.withValues(alpha: 0.12),
              width: isSelected ? 2 : 1.2,
            ),
            boxShadow: [
              if (highlighted)
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.17),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD700),
                      Color(0xFFFF9800),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _iconForPlan(plan.planKey),
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _titleForPlan(plan.planKey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (badge.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              badge,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF2B2100),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitleForPlan(plan.planKey),
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.price,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFD700),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'Satın al',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFooterNote() {
    return Text(
      'Not: VIP yalnızca App Store / Google Play satın alma sonucu başarılı dönerse aktif edilir. Aboneliğinizi mağaza hesabınız üzerinden yönetebilirsiniz.',
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        color: Colors.white.withValues(alpha: 0.52),
        fontSize: 10.8,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
    );
  }

  String _titleForPlan(String planKey) {
    switch (planKey) {
      case 'monthly':
        return 'Aylık VIP';
      case 'three_months':
        return '3 Aylık VIP';
      case 'yearly':
        return 'Yıllık VIP';
      default:
        return 'VIP Planı';
    }
  }

  String _subtitleForPlan(String planKey) {
    switch (planKey) {
      case 'monthly':
        return 'Her ay yenilenir • tüm VIP avantajları aktif olur';
      case 'three_months':
        return '3 ayda bir yenilenir • daha avantajlı kullanım';
      case 'yearly':
        return 'Yılda bir yenilenir • en güçlü sınav paketi';
      default:
        return 'VIP avantajları aktif olur';
    }
  }

  String _badgeForPlan(String planKey) {
    switch (planKey) {
      case 'three_months':
        return 'AVANTAJLI';
      case 'yearly':
        return 'EN İYİ';
      default:
        return '';
    }
  }

  IconData _iconForPlan(String planKey) {
    switch (planKey) {
      case 'monthly':
        return Icons.calendar_month_rounded;
      case 'three_months':
        return Icons.auto_awesome_rounded;
      case 'yearly':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.workspace_premium_rounded;
    }
  }
}
