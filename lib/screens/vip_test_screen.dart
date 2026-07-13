import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/vip_purchase_service.dart';
import '../services/vip_user_service.dart';
import 'vip_statistics_page.dart';
import 'dart:async';
import '../services/sound_service.dart';

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

  static const Color _bgTop = Color(0xFF05082D);
  static const Color _bgMid = Color(0xFF09114A);
  static const Color _bgBottom = Color(0xFF071636);
  static const Color _gold = Color(0xFFFFD400);
  static const Color _goldDark = Color(0xFFFFA000);
  static const Color _purple = Color(0xFF6B36FF);
  static const Color _card = Color(0xFF11194E);

  @override
  void initState() {
    super.initState();
    _startPurchaseListener();
    _loadPlans();
  }

  void _startPurchaseListener() {
    VipPurchaseService.instance.startListening(
      onPurchased: (PurchaseDetails purchase) async {
        if (!mounted) return;

        final VipPlanOption? selectedPlan = _selectedPlan;

        if (!_buying || selectedPlan == null) {
          setState(() {
            _purchaseMessage =
                'Daha önce VIP satın aldıysan erişimini geri yükleyebilirsin. Yeni satın alma için plan seçmen yeterli.';
          });
          return;
        }

        if (purchase.productID != selectedPlan.productDetails.id) {
          setState(() {
            _buying = false;
            _purchaseMessage =
                'Satın alınan ürün seçilen planla eşleşmedi. VIP aktif edilmedi.';
          });
          return;
        }

        try {
          await VipUserService.instance.activateVip(
            planKey: selectedPlan.planKey,
            productId: purchase.productID,
            purchaseId: purchase.purchaseID ??
                purchase.verificationData.serverVerificationData,
            serverVerificationData:
                purchase.verificationData.serverVerificationData,
            localVerificationData:
                purchase.verificationData.localVerificationData,
            source: Platform.isIOS ? 'app_store' : 'google_play',
          );

          if (!mounted) return;

          setState(() {
            _buying = false;
            _purchaseMessage = 'VIP üyeliğiniz başarıyla aktif edildi.';
          });

          unawaited(SoundService.instance.purchaseSuccess());
      ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('VIP üyeliğiniz aktif edildi!')),
          );

          await Future.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VipStatisticsPage()),
          );
        } catch (e) {
          if (!mounted) return;

          setState(() {
            _buying = false;
            _purchaseMessage =
                'Satın alma başarılı oldu ama VIP kaydı başarısız: $e';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('VIP kaydı başarısız: $e')),
          );
        }
      },
      onPending: (PurchaseDetails purchase) {
        if (!mounted) return;

        setState(() {
          _purchaseMessage =
              'Ödeme beklemede. Mağaza onay verince VIP üyeliğiniz aktif edilir.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ödeme beklemede.')),
        );
      },
      onError: (String message) {
        if (!mounted) return;

        setState(() {
          _buying = false;
          _purchaseMessage = message;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
      onIgnored: (PurchaseDetails purchase) {
        if (!mounted) return;

        setState(() {
          _purchaseMessage =
              'Daha önceki satın alma algılandı. Güvenlik için otomatik VIP açılmadı.';
        });
      },
    );
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
      final List<VipPlanOption> plans =
          await VipPurchaseService.instance.loadVipPlans();

      if (!mounted) return;

      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

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
      _purchaseMessage = '${_displayTitle(plan)} satın alma işlemi başlatılıyor...';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTop,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _gold),
                  )
                : _buildBody(),
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
          child: RefreshIndicator(
            onRefresh: _loadPlans,
            color: _gold,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
              children: [
                _buildHero(),
                const SizedBox(height: 16),
                _buildBenefitsGrid(),
                const SizedBox(height: 14),
                _buildRestoreBanner(),
                const SizedBox(height: 14),

                if (_purchaseMessage != null) ...[
                  _buildMessageBox(_purchaseMessage!),
                  const SizedBox(height: 14),
                ],

                if (_buying) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(
                      minHeight: 6,
                      color: _gold,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                if (_error != null)
                  _buildErrorState()
                else if (_plans.isEmpty)
                  _buildEmptyState()
                else
                  ..._orderedPlans().map(_buildPlanCard),

                const SizedBox(height: 16),
                _buildFooterNote(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<VipPlanOption> _orderedPlans() {
    final copied = List<VipPlanOption>.from(_plans);
    int rank(String key) {
      switch (key) {
        case 'monthly':
          return 0;
        case 'three_months':
          return 1;
        case 'yearly':
          return 2;
        default:
          return 3;
      }
    }

    copied.sort((a, b) => rank(a.planKey).compareTo(rank(b.planKey)));
    return copied;
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          Expanded(
            child: Text(
              'VIP Üyelik',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Planları yenile',
            onPressed: _buying ? null : _loadPlans,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _gold.withValues(alpha: .18)),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF11174A),
            Color(0xFF182165),
            Color(0xFF101747),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: _gold.withValues(alpha: .10),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: .14),
              border: Border.all(color: _gold.withValues(alpha: .42), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: .28),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: _gold,
              size: 34,
            ),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: .1,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 12),
                  ],
                ),
                children: const [
                  TextSpan(
                    text: 'Bilgi Rotası ',
                    style: TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: 'VIP',
                    style: TextStyle(color: _gold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: .10)),
            ),
            child: Text(
              'Daha akıllı çalış, daha hızlı ilerle.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: .88),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sınav yolculuğunda en güçlü yardımcın.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: .68),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsGrid() {
    final features = <_VipTile>[
      const _VipTile(
        Icons.query_stats_rounded,
        'Haftalık zayıf\nkonu analizi',
      ),
      const _VipTile(
        Icons.edit_note_rounded,
        'Eksik konulardan\nkişisel test talebi',
      ),
      const _VipTile(
        Icons.picture_as_pdf_rounded,
        'Konu anlatım\nPDF hakkı',
      ),
      const _VipTile(
        Icons.bolt_rounded,
        '2 kat\nenerji',
      ),
      const _VipTile(
        Icons.change_circle_rounded,
        '2 kat hızlı\nenerji yenilenme',
      ),
      const _VipTile(
        Icons.gps_fixed_rounded,
        'Görev ve ödül \nsistemi avantajları',
      ),
      const _VipTile(
        Icons.inventory_2_rounded,
        'Daha fazla yanlış kutusu\nsoru hakkı',
      ),
      const _VipTile(
        Icons.block_rounded,
        'Reklamsız\nkullanım',
      ),
      const _VipTile(
        Icons.shield_rounded,
        'Sıralamada\nVIP rozet',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1040).withValues(alpha: .70),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _gold.withValues(alpha: .24)),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: _gold,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'VIP Ayrıcalıkları',
                style: GoogleFonts.poppins(
                  color: _gold,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Text(
              'Sınav başarını katla, rakiplerinin önüne geç.',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: .78),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            itemCount: features.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: .98,
            ),
            itemBuilder: (context, index) {
              final item = features[index];
              return _buildBenefitTile(item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitTile(_VipTile item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151A55).withValues(alpha: .74),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: .060),
            _purple.withValues(alpha: .035),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.icon,
            color: _gold,
            size: 30,
            shadows: [
              Shadow(color: _gold.withValues(alpha: .35), blurRadius: 14),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 10.5,
              height: 1.22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF101B55).withValues(alpha: .72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4D8BFF).withValues(alpha: .20)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF265DFF).withValues(alpha: .18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF7BB7FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Daha önce VIP satın aldıysan erişimini geri yükleyebilirsin.\nAynı hesapla giriş yapman yeterli.',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: .86),
                fontSize: 12.2,
                height: 1.42,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white54,
            size: 30,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(VipPlanOption plan) {
    final bool isSelected =
        _selectedPlan?.productDetails.id == plan.productDetails.id;
    final bool isYearly = plan.planKey == 'yearly';
    final bool isThreeMonths = plan.planKey == 'three_months';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _buying ? null : () => _buyPlan(plan),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: _card.withValues(alpha: .80),
            border: Border.all(
              color: isYearly
                  ? _gold
                  : isSelected
                      ? const Color(0xFF7BB7FF)
                      : Colors.white.withValues(alpha: .11),
              width: isYearly ? 1.8 : 1.15,
            ),
            boxShadow: [
              BoxShadow(
                color: isYearly
                    ? _gold.withValues(alpha: .18)
                    : Colors.black.withValues(alpha: .16),
                blurRadius: isYearly ? 18 : 14,
                offset: const Offset(0, 7),
              ),
            ],
            gradient: LinearGradient(
              colors: isYearly
                  ? [
                      const Color(0xFF1C256B),
                      const Color(0xFF10184E),
                    ]
                  : [
                      const Color(0xFF172062),
                      const Color(0xFF101747),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (isYearly)
                Positioned(
                  right: 8,
                  top: -22,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: _gold.withValues(alpha: .30),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFF442C00),
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'En Avantajlı',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF442C00),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  _planIcon(plan),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayTitle(plan),
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
                            _subtitleForPlan(plan.planKey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: isYearly
                                  ? _gold.withValues(alpha: .90)
                                  : Colors.white.withValues(alpha: .65),
                              fontSize: 11.2,
                              fontWeight:
                                  isYearly ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              _miniPlanIcon(Icons.bolt_rounded),
                              _miniPlanIcon(Icons.change_circle_rounded),
                              _miniPlanIcon(Icons.gps_fixed_rounded),
                              _miniPlanIcon(Icons.inventory_2_rounded),
                              _miniPlanIcon(Icons.block_rounded),
                              _miniPlanIcon(Icons.workspace_premium_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        plan.price,
                        style: GoogleFonts.poppins(
                          color: _gold,
                          fontSize: isYearly ? 22 : 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 43,
                        child: ElevatedButton(
                          onPressed: _buying ? null : () => _buyPlan(plan),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: _gold,
                            foregroundColor: const Color(0xFF08112E),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            _buying && isSelected ? 'İşleniyor' : 'Satın Al',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isThreeMonths)
                Positioned(
                  left: 2,
                  bottom: -4,
                  child: Text(
                    'Avantajlı paket',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: .18),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planIcon(VipPlanOption plan) {
    final bool yearly = plan.planKey == 'yearly';
    final bool three = plan.planKey == 'three_months';

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: yearly
            ? _gold.withValues(alpha: .16)
            : _purple.withValues(alpha: three ? .24 : .18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: yearly ? _gold.withValues(alpha: .55) : _purple.withValues(alpha: .35),
        ),
        boxShadow: [
          if (yearly)
            BoxShadow(
              color: _gold.withValues(alpha: .22),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Center(
        child: three
            ? Text(
                '3\nAY',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: _gold,
                  fontSize: 17,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              )
            : Icon(
                yearly
                    ? Icons.workspace_premium_rounded
                    : Icons.bookmark_rounded,
                color: _gold,
                size: yearly ? 34 : 30,
              ),
      ),
    );
  }

  Widget _miniPlanIcon(IconData icon) {
    return Container(
      width: 23,
      height: 23,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .05)),
      ),
      child: Icon(
        icon,
        color: _gold.withValues(alpha: .78),
        size: 14,
      ),
    );
  }

  Widget _buildMessageBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF16285F).withValues(alpha: .72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF56D9FF).withValues(alpha: .30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF56D9FF),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12.1,
                height: 1.42,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return _stateBox(
      icon: Icons.error_outline_rounded,
      title: 'VIP planları yüklenemedi',
      desc: _error ?? 'Bilinmeyen hata oluştu.',
      actionText: 'Tekrar Dene',
      onTap: _loadPlans,
    );
  }

  Widget _buildEmptyState() {
    return _stateBox(
      icon: Icons.storefront_rounded,
      title: 'Mağaza ürünü bulunamadı',
      desc:
          'App Store Connect / Play Console ürünlerinin aktif, satışa açık ve doğru bundle id ile bağlı olduğundan emin olun.',
      actionText: 'Yenile',
      onTap: _loadPlans,
    );
  }

  Widget _stateBox({
    required IconData icon,
    required String title,
    required String desc,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _gold, size: 38),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: const Color(0xFF08112E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              actionText,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF154B8A).withValues(alpha: .42),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF56D9FF).withValues(alpha: .18)),
          ),
          child: const Icon(
            Icons.lock_rounded,
            color: Color(0xFF8BC7FF),
            size: 17,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'VIP yalnızca App Store / Google Play üzerinden yapılan başarılı satın alma sonrasında aktif olur.',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: .48),
              fontSize: 11.2,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgMid, _bgBottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 48,
            left: 26,
            right: 26,
            child: Container(
              height: 155,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(120),
                border: Border.all(color: _gold.withValues(alpha: .08)),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: .12),
                    blurRadius: 60,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -70,
            right: -65,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withValues(alpha: .055),
              ),
            ),
          ),
          Positioned(
            bottom: 220,
            left: -90,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _purple.withValues(alpha: .07),
              ),
            ),
          ),
          Positioned(
            bottom: 70,
            right: -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _goldDark.withValues(alpha: .045),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _displayTitle(VipPlanOption plan) {
    switch (plan.planKey) {
      case 'monthly':
        return 'Aylık VIP';
      case 'three_months':
        return '3 Aylık VIP';
      case 'yearly':
        return 'Yıllık VIP';
      default:
        return plan.title;
    }
  }

  String _subtitleForPlan(String planKey) {
    switch (planKey) {
      case 'monthly':
        return 'Aylık erişim • Esnek kullanım';
      case 'three_months':
        return 'Avantajlı paket • Daha uygun fiyat';
      case 'yearly':
        return 'En popüler seçim • Maksimum tasarruf';
      default:
        return 'VIP avantajlarını hemen aktif eder';
    }
  }
}

class _VipTile {
  final IconData icon;
  final String title;

  const _VipTile(this.icon, this.title);
}
