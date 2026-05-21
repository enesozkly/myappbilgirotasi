import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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

  List<VipPlanOption> _plans = <VipPlanOption>[];
  VipPlanOption? _selectedPlan;

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

        // En kritik iOS koruması:
        // Kullanıcı bu ekranda satın alma başlatmadıysa gelen transaction VIP açmaz.
        if (!_buying || selectedPlan == null) {
          setState(() {
            _purchaseMessage =
                'Önceki/restore işlem algılandı; güvenlik için otomatik VIP açılmadı.';
          });
          return;
        }

        if (purchase.productID != selectedPlan.productDetails.id) {
          setState(() {
            _buying = false;
            _purchaseMessage =
                'Satın alma ürünü seçilen planla eşleşmedi. VIP aktif edilmedi.';
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
            localVerificationData: purchase.verificationData.localVerificationData,
            source: Platform.isIOS ? 'app_store' : 'google_play',
          );

          if (!mounted) return;
          setState(() {
            _buying = false;
            _purchaseMessage = 'VIP üyeliğiniz başarıyla aktif edildi.';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('VIP üyeliğiniz aktif edildi!')),
          );

          await Future<void>.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const VipStatisticsPage(),
            ),
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
      onPending: (PurchaseDetails purchase) {
        if (!mounted) return;
        setState(() {
          _purchaseMessage =
              'Ödeme beklemede. Mağaza onaylayınca VIP üyeliğiniz aktif edilecek.';
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
              'Eski/restore satın alma otomatik VIP yapmadı. Yeni satın alma için plan seçin.';
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
      _purchaseMessage = '${plan.title} satın alma başlatılıyor...';
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
      backgroundColor: const Color(0xFF080B2E),
      body: Stack(
        children: <Widget>[
          _buildBackground(),
          SafeArea(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD700)),
      );
    }

    return Column(
      children: <Widget>[
        _buildTopBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPlans,
            color: const Color(0xFFFFD700),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: <Widget>[
                _buildHeroCard(),
                const SizedBox(height: 18),
                _buildBenefitsCard(),
                const SizedBox(height: 18),
                if (_purchaseMessage != null) ...<Widget>[
                  _buildMessageBox(_purchaseMessage!),
                  const SizedBox(height: 18),
                ],
                if (_buying) ...<Widget>[
                  const LinearProgressIndicator(
                    color: Color(0xFFFFD700),
                    backgroundColor: Colors.white24,
                  ),
                  const SizedBox(height: 18),
                ],
                if (_error != null)
                  _buildErrorState()
                else if (_plans.isEmpty)
                  _buildEmptyState()
                else
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
        children: <Widget>[
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
          IconButton(
            tooltip: 'Planları yenile',
            onPressed: _buying ? null : _loadPlans,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
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
          colors: <Color>[Color(0xFFFFD700), Color(0xFFFF9800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          const Text('👑', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 10),
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
            'Satın alma tamamlanmadan VIP açılmaz. iOS restore/eski transaction otomatik aktif edilmez.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsCard() {
    final List<_Benefit> benefits = <_Benefit>[
      _Benefit(Icons.analytics_rounded, 'Haftalık zayıf konu analizi'),
      _Benefit(Icons.fact_check_rounded, 'Kişisel test talebi'),
      _Benefit(Icons.picture_as_pdf_rounded, '1 konu anlatım PDF hakkı'),
      _Benefit(Icons.bolt_rounded, '2 kat enerji'),
      _Benefit(Icons.block_rounded, 'Reklamsız kullanım'),
      _Benefit(Icons.verified_rounded, 'VIP rozet'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Wrap(
        runSpacing: 10,
        spacing: 10,
        children: benefits
            .map(
              (_Benefit item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(item.icon, color: const Color(0xFFFFD700), size: 18),
                    const SizedBox(width: 7),
                    Text(
                      item.title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPlanCard(VipPlanOption plan) {
    final bool selected = _selectedPlan?.productDetails.id == plan.productDetails.id;
    final bool highlighted = plan.planKey == 'yearly';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _buying ? null : () => _buyPlan(plan),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: selected ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: highlighted
                  ? const Color(0xFFFFD700)
                  : Colors.white.withValues(alpha: 0.14),
              width: highlighted ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Color(0xFFFFD700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      plan.title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      plan.productDetails.id,
                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    plan.price,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFD700),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _buying && selected ? 'İşleniyor' : 'Satın Al',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF080B2E),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
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

  Widget _buildMessageBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.28)),
      ),
      child: Text(
        message,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
      ),
    );
  }

  Widget _buildErrorState() {
    return _stateBox(
      icon: Icons.error_outline_rounded,
      title: 'VIP planları yüklenemedi',
      desc: _error ?? 'Bilinmeyen hata',
      actionText: 'Tekrar Dene',
      onTap: _loadPlans,
    );
  }

  Widget _buildEmptyState() {
    return _stateBox(
      icon: Icons.storefront_rounded,
      title: 'Mağaza ürünü bulunamadı',
      desc:
          'App Store Connect / Play Console ürün ID’lerinin aktif ve build bundle id ile eşleştiğini kontrol et.',
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
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: const Color(0xFFFFD700), size: 36),
          const SizedBox(height: 10),
          Text(title,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(desc,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: onTap, child: Text(actionText)),
        ],
      ),
    );
  }

  Widget _buildFooterNote() {
    return Text(
      'Not: VIP sadece App Store / Google Play satın alma sonucu başarılı dönerse aktif edilir.',
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10.5),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF080B2E), Color(0xFF151A55), Color(0xFF071B3A)],
        ),
      ),
    );
  }
}

class _Benefit {
  final IconData icon;
  final String title;

  const _Benefit(this.icon, this.title);
}
