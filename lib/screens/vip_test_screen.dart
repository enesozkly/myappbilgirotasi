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
  String? _lastSelectedPlanKey;

  VipPlanOption? _planByKey(String planKey) {
    for (final plan in _plans) {
      if (plan.planKey == planKey) return plan;
    }
    return null;
  }

  String _planKeyFromPurchaseId(String productId) {
    switch (productId) {
      case 'vip_monthly':
        return 'monthly';
      case 'vip_3_months':
        return 'three_months';
      case 'vip_yearly':
        return 'yearly';
      default:
        return _lastSelectedPlanKey ?? _selectedPlan?.planKey ?? 'monthly';
    }
  }

  @override
  void initState() {
    super.initState();

    VipPurchaseService.instance.startListening(
      onPurchased: (purchase) async {
        if (!mounted) return;

        final String resolvedPlanKey = _selectedPlan?.planKey ??
            _lastSelectedPlanKey ??
            _planKeyFromPurchaseId(purchase.productID);
        final VipPlanOption? selectedPlan =
            _selectedPlan ?? _planByKey(resolvedPlanKey);

        try {
          await VipUserService.instance.activateVip(
            planKey: selectedPlan?.planKey ?? resolvedPlanKey,
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
      _lastSelectedPlanKey = plan.planKey;
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
      backgroundColor: const Color(0xFF080B2E),
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
            Color(0xFF080B2E),
            Color(0xFF151A55),
            Color(0xFF071B3A),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -80,
            child: _glowCircle(
              color: const Color(0xFFFFD700),
              size: 210,
              opacity: 0.18,
            ),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: _glowCircle(
              color: const Color(0xFF00E5FF),
              size: 240,
              opacity: 0.16,
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
            blurRadius: 90,
            spreadRadius: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFD700),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_plans.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                _buildHeroCard(),
                const SizedBox(height: 18),
                _buildBenefitsCard(),
                const SizedBox(height: 18),

                if (_purchaseMessage != null) ...[
                  _buildMessageBox(),
                  const SizedBox(height: 18),
                ],

                if (_buying) ...[
                  const LinearProgressIndicator(
                    color: Color(0xFFFFD700),
                    backgroundColor: Colors.white24,
                  ),
                  const SizedBox(height: 18),
                ],

                ..._plans.map(_buildPlanCard),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Text(
              'VIP Üyelik',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD700),
            Color(0xFFFF9800),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Text(
                '👑',
                style: TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bilgi Rotası VIP',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Daha hızlı ilerle, daha çok çalış, daha net analiz gör. VIP ile sınav hazırlığını premium seviyeye taşı.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildHeroMiniStat(
                  value: '100',
                  label: 'Enerji Limiti',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeroMiniStat(
                  value: '0',
                  label: 'Reklam Zorunluluğu',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeroMiniStat(
                  value: 'VIP',
                  label: 'Analiz Alanı',
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
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
              fontSize: 16,
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
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD700),
                      Color(0xFFFF9800),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'VIP ile neler kazanırsın?',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildBenefitTile(
            icon: Icons.emoji_events_rounded,
            title: 'Sınav Kazandıran Paket',
            desc:
                'VIP; analiz, kişisel test, PDF notları, enerji avantajı, reklamsız kullanım ve rozet ayrıcalığını tek pakette sunar.',
            accent: const Color(0xFFFFD700),
          ),
          _buildBenefitTile(
            icon: Icons.analytics_rounded,
            title: 'Haftalık zayıf konu analizi',
            desc:
                'Ayda 4 hak ile her hafta zayıf konularını analiz ettir, çalışman gereken alanları net gör.',
            accent: const Color(0xFFD500F9),
          ),
          _buildBenefitTile(
            icon: Icons.fact_check_rounded,
            title: 'Eksik konulardan test oluşturma',
            desc:
                'Ayda 1 hak ile yanlışlarına göre kişisel test talep et. Testin 24 saat içerisinde e-posta ile gönderilir.',
            accent: const Color(0xFF8A52FF),
          ),
          _buildBenefitTile(
            icon: Icons.picture_as_pdf_rounded,
            title: '1 konu anlatım PDF hakkı',
            desc:
                'İstediğin bir konu için sınav odaklı notlar ve konu anlatım PDF talebi oluştur. 24 saat içinde e-posta ile gönderilir.',
            accent: const Color(0xFFFFAB40),
          ),
          _buildBenefitTile(
            icon: Icons.bolt_rounded,
            title: '2 kat enerji',
            desc:
                'Standart 50 enerji yerine 100 enerji limitiyle daha uzun süre kesintisiz çalış.',
            accent: const Color(0xFFFFD54F),
          ),
          _buildBenefitTile(
            icon: Icons.flash_on_rounded,
            title: '2 kat enerji yenileme hızı',
            desc:
                'VIP kullanıcıların enerjisi daha hızlı yenilenir; çalışma temposu daha az kesilir.',
            accent: const Color(0xFFFF9100),
          ),
          _buildBenefitTile(
            icon: Icons.task_alt_rounded,
            title: 'Görevlerden x2 enerji kazanımı',
            desc:
                'Görev ve ödül sistemindeki enerji kazanımlarında VIP avantajıyla daha güçlü ilerle.',
            accent: const Color(0xFF69F0AE),
          ),
          _buildBenefitTile(
            icon: Icons.inventory_2_rounded,
            title: 'Yanlış kutusu limiti 50 soru',
            desc:
                'Yanlış yaptığın daha fazla soruyu sakla, tekrar çöz ve eksiklerini düzenli takip et.',
            accent: const Color(0xFF00E5FF),
          ),
          _buildBenefitTile(
            icon: Icons.block_rounded,
            title: 'Reklamsız uygulama',
            desc:
                'Reklam zorunluluğu olmadan dikkatini dağıtmadan öğrenmeye devam et.',
            accent: const Color(0xFFFF7043),
          ),
          _buildBenefitTile(
            icon: Icons.verified_rounded,
            title: 'Sıralamada VIP rozet',
            desc:
                'Profilinde ve sıralama alanlarında VIP görünümü, özel rozet ve premium kullanıcı ayrıcalıkları aktif olur.',
            accent: const Color(0xFFFFD700),
            isLast: true,
          ),
        ],
      ),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(13),
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 11.4,
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
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        _purchaseMessage!,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
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
        borderRadius: BorderRadius.circular(24),
        onTap: _buying ? null : () => _buyPlan(plan),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: highlighted
                ? const Color(0xFFFFD700).withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFFD700)
                  : highlighted
                      ? const Color(0xFFFFD700).withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.12),
              width: isSelected ? 2 : 1.2,
            ),
            boxShadow: [
              if (highlighted)
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD700),
                      Color(0xFFFF9800),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  _iconForPlan(plan.planKey),
                  color: Colors.white,
                  size: 25,
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
                              fontWeight: FontWeight.w800,
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
                        fontWeight: FontWeight.w500,
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
                  const SizedBox(height: 3),
                  Text(
                    'Satın al',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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

  Widget _buildFooterNote() {
    return Text(
      'Abonelikler mağaza hesabınız üzerinden yönetilir. İstediğiniz zaman App Store veya Google Play abonelikler bölümünden iptal edebilirsiniz.',
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 11,
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFFD700),
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                'VIP planları çekilemedi',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPlans,
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFFD700),
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                'Hiç VIP planı bulunamadı',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'VIP planları şu anda yüklenemedi. Lütfen daha sonra tekrar deneyin.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPlans,
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
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
        return 'Her ay yenilenir';
      case 'three_months':
        return '3 ayda bir yenilenir • %15 avantaj';
      case 'yearly':
        return 'Yılda bir yenilenir • %15 avantaj';
      default:
        return 'VIP avantajları aktif olur';
    }
  }

  String _badgeForPlan(String planKey) {
    switch (planKey) {
      case 'three_months':
        return '%15';
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