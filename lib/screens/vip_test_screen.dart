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

  final Map<String, String> _lastPlanKeyByProductId = {};
  String? _lastSelectedPlanKey;

  @override
  void initState() {
    super.initState();

    VipPurchaseService.instance.startListening(
      onPurchased: (purchase) async {
        if (!mounted) return;

        final String planKey = _resolvePlanKeyForPurchase(purchase.productID);

        try {
          await VipUserService.instance.activateVip(
            planKey: planKey,
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
            const SnackBar(content: Text('VIP üyeliğiniz aktif edildi!')),
          );

          await Future.delayed(const Duration(milliseconds: 800));
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VipStatisticsPage()),
          );
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _buying = false;
            _purchaseMessage = 'Satın alma oldu ama VIP kaydı başarısız: $e';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('VIP kaydı başarısız: $e')),
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
          const SnackBar(content: Text('Ödeme beklemede.')),
        );
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _buying = false;
          _purchaseMessage = message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
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
      _lastPlanKeyByProductId
        ..clear()
        ..addEntries(
          plans.map((plan) => MapEntry(plan.productDetails.id, plan.planKey)),
        );

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

    _lastSelectedPlanKey = plan.planKey;
    _lastPlanKeyByProductId[plan.productDetails.id] = plan.planKey;

    setState(() {
      _buying = true;
      _selectedPlan = plan;
      _purchaseMessage = '${_titleForPlan(plan.planKey)} satın alma başlatılıyor...';
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
        SnackBar(content: Text('Satın alma başlatılamadı: $e')),
      );
    }
  }

  String _resolvePlanKeyForPurchase(String productId) {
    switch (productId) {
      case 'vip_monthly':
        return 'monthly';
      case 'vip_3_months':
        return 'three_months';
      case 'vip_yearly':
        return 'yearly';
    }

    final cachedByProductId = _lastPlanKeyByProductId[productId];
    if (cachedByProductId != null && cachedByProductId.isNotEmpty) {
      return cachedByProductId;
    }

    if (_selectedPlan != null) return _selectedPlan!.planKey;
    if (_lastSelectedPlanKey != null && _lastSelectedPlanKey!.isNotEmpty) {
      return _lastSelectedPlanKey!;
    }

    return 'monthly';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B2E),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(child: _buildBody()),
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
          colors: [Color(0xFF080B2E), Color(0xFF151A55), Color(0xFF071B3A)],
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
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }

    if (_error != null) return _buildErrorState();
    if (_plans.isEmpty) return _buildEmptyState();

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
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
          colors: [Color(0xFFFFD700), Color(0xFFFF9800)],
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
            child: const Center(child: Text('👑', style: TextStyle(fontSize: 40))),
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
            'VIP “Sınav Kazandıran Paket” ile sınav hazırlığını premium seviyeye taşı.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard() {
    final benefits = [
      _Benefit(Icons.emoji_events_rounded, 'Sınav Kazandıran Paket', 'Analiz, kişisel test, PDF notları, enerji avantajı, reklamsız kullanım ve rozet ayrıcalığını tek pakette sunar.', const Color(0xFFFFD700)),
      _Benefit(Icons.analytics_rounded, 'Haftalık zayıf konu analizi', 'Ayda 4 hak ile zayıf konularını analiz ettir, çalışman gereken alanları net gör.', const Color(0xFFD500F9)),
      _Benefit(Icons.fact_check_rounded, 'Eksik konulardan test oluşturma', 'Ayda 4 hak ile eksik konularından kişisel test talep et. Testin 24 saat içinde e-posta ile gönderilir.', const Color(0xFF8A52FF)),
      _Benefit(Icons.picture_as_pdf_rounded, '1 konu anlatım PDF hakkı', 'İstediğin bir konu için sınav odaklı notlar ve konu anlatım PDF talebi oluştur. 24 saat içinde e-posta ile gönderilir.', const Color(0xFFFFAB40)),
      _Benefit(Icons.bolt_rounded, '2 kat enerji', 'Standart 50 enerji yerine 100 enerji limitiyle daha uzun süre kesintisiz çalış.', const Color(0xFFFFD54F)),
      _Benefit(Icons.flash_on_rounded, '2 kat enerji yenileme hızı', 'VIP kullanıcıların enerjisi daha hızlı yenilenir; çalışma temposu daha az kesilir.', const Color(0xFFFF9100)),
      _Benefit(Icons.task_alt_rounded, 'Görevlerden x2 enerji kazanımı', 'Görev ve ödül sistemindeki enerji kazanımlarında VIP avantajıyla daha güçlü ilerle.', const Color(0xFF69F0AE)),
      _Benefit(Icons.inventory_2_rounded, 'Yanlış kutusu limiti 50 soru', 'Yanlış yaptığın daha fazla soruyu sakla, tekrar çöz ve eksiklerini düzenli takip et.', const Color(0xFF00E5FF)),
      _Benefit(Icons.block_rounded, 'Reklamsız uygulama', 'Reklam zorunluluğu olmadan dikkatini dağıtmadan öğrenmeye devam et.', const Color(0xFFFF7043)),
      _Benefit(Icons.verified_rounded, 'Sıralamada VIP rozet', 'Profilinde ve sıralama alanlarında VIP görünümü, özel rozet ve premium kullanıcı ayrıcalıkları aktif olur.', const Color(0xFFFFD700)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VIP ile neler kazanırsın?',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < benefits.length; i++)
            _buildBenefitTile(
              icon: benefits[i].icon,
              title: benefits[i].title,
              desc: benefits[i].desc,
              accent: benefits[i].accent,
              isLast: i == benefits.length - 1,
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
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: accent, size: 20),
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
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.28)),
      ),
      child: Text(
        _purchaseMessage!,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF9800)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(_iconForPlan(plan.planKey), color: Colors.white, size: 25),
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
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (badge.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              badge,
                              style: GoogleFonts.poppins(color: const Color(0xFF2B2100), fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitleForPlan(plan.planKey),
                      style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.70), fontSize: 12, fontWeight: FontWeight.w500),
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
                    style: GoogleFonts.poppins(color: const Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Satın al',
                    style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.68), fontSize: 10, fontWeight: FontWeight.w600),
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
      'Abonelikler mağaza hesabınız üzerinden yönetilir. İstediğiniz zaman mağaza abonelikler bölümünden iptal edebilirsiniz.',
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
    );
  }

  Widget _buildErrorState() {
    return _stateBox(
      icon: Icons.error_outline_rounded,
      title: 'VIP planları çekilemedi',
      message: _error ?? 'Bilinmeyen hata',
      buttonText: 'Tekrar dene',
      onTap: _loadPlans,
    );
  }

  Widget _buildEmptyState() {
    return _stateBox(
      icon: Icons.workspace_premium_rounded,
      title: 'Hiç VIP planı bulunamadı',
      message: 'VIP planları şu anda yüklenemedi. Lütfen daha sonra tekrar deneyin.',
      buttonText: 'Tekrar dene',
      onTap: _loadPlans,
    );
  }

  Widget _stateBox({
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onTap,
  }) {
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
              Icon(icon, color: const Color(0xFFFFD700), size: 42),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onTap, child: Text(buttonText)),
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
        return '3 ay boyunca VIP avantajları';
      case 'yearly':
        return 'En avantajlı yıllık paket';
      default:
        return 'VIP avantajları';
    }
  }

  String _badgeForPlan(String planKey) {
    switch (planKey) {
      case 'yearly':
        return 'EN AVANTAJLI';
      case 'three_months':
        return 'POPÜLER';
      default:
        return '';
    }
  }

  IconData _iconForPlan(String planKey) {
    switch (planKey) {
      case 'monthly':
        return Icons.calendar_month_rounded;
      case 'three_months':
        return Icons.bolt_rounded;
      case 'yearly':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}

class _Benefit {
  final IconData icon;
  final String title;
  final String desc;
  final Color accent;

  const _Benefit(this.icon, this.title, this.desc, this.accent);
}
