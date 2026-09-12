import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/sound_service.dart';
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
  final GlobalKey _plansKey = GlobalKey();

  static const Color _bg = Color(0xFF0A0A1A);
  static const Color _panel = Color(0xFF12122A);
  static const Color _panel2 = Color(0xFF181832);
  static const Color _violet = Color(0xFF6C4FFF);
  static const Color _violetLight = Color(0xFF8B6CFF);
  static const Color _gold = Color(0xFFF2B33D);
  static const Color _goldLight = Color(0xFFF7CB6E);
  static const Color _mint = Color(0xFF34D399);
  static const Color _ink = Color(0xFFEDEBFA);
  static const Color _dim = Color(0xFFA6A2C9);
  static const Color _faint = Color(0xFF6E6A93);
  static const Color _line = Color(0xFF28264A);

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
        final VipPlanOption? plan = _selectedPlan;

        if (!_buying || plan == null) {
          setState(() {
            _purchaseMessage =
                'Daha önce VIP satın aldıysan erişimini geri yükleyebilirsin.';
          });
          return;
        }

        if (purchase.productID != plan.productDetails.id) {
          setState(() {
            _buying = false;
            _purchaseMessage =
                'Satın alınan ürün seçilen planla eşleşmedi. VIP aktif edilmedi.';
          });
          return;
        }

        try {
          await VipUserService.instance.activateVip(
            planKey: plan.planKey,
            productId: purchase.productID,
            planPrice: plan.price,
            offerToken: plan.offerToken,
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
            _purchaseMessage = 'VIP üyeliğin başarıyla aktif edildi.';
          });
          unawaited(SoundService.instance.purchaseSuccess());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('VIP üyeliğin aktif edildi!')),
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
            _purchaseMessage =
                'Satın alma tamamlandı ancak VIP kaydı oluşturulamadı: $e';
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
              'Ödeme beklemede. Mağaza onay verdiğinde VIP üyeliğin aktif edilir.';
        });
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
              'Eski satın alma algılandı. Güvenlik için otomatik VIP açılmadı.';
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
        _selectedPlan = _defaultPlan(plans);
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

  Future<void> _buySelectedPlan() async {
    final VipPlanOption? plan = _selectedPlan;
    if (_buying || plan == null) return;

    setState(() {
      _buying = true;
      _purchaseMessage = '${_planTitle(plan)} satın alma işlemi açılıyor...';
    });

    try {
      await VipPurchaseService.instance.buyVipPlan(plan);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buying = false;
        _purchaseMessage = 'Satın alma başlatılamadı: $e';
      });
    }
  }

  VipPlanOption? _defaultPlan(List<VipPlanOption> plans) {
    if (plans.isEmpty) return null;
    for (final VipPlanOption plan in plans) {
      if (plan.planKey == 'yearly') return plan;
    }
    return plans.first;
  }

  bool _isSelected(VipPlanOption plan) {
    final VipPlanOption? selected = _selectedPlan;
    return selected != null && identical(selected, plan);
  }

  void _selectPlan(VipPlanOption plan) {
    if (_buying) return;
    setState(() {
      _selectedPlan = plan;
      _purchaseMessage = null;
    });
  }

  Future<void> _scrollToPlans() async {
    final BuildContext? target = _plansKey.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOutCubic,
      alignment: .04,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _topBar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _violetLight),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPlans,
                      color: _violetLight,
                      child: LayoutBuilder(
                        builder: (_, BoxConstraints constraints) {
                          final bool tablet = constraints.maxWidth >= 700;
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              tablet ? 28 : 16,
                              4,
                              tablet ? 28 : 16,
                              34,
                            ),
                            children: <Widget>[
                              Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 980),
                                  child: Column(
                                    children: <Widget>[
                                      _hero(tablet),
                                      SizedBox(height: tablet ? 32 : 25),
                                      _sectionHeader(
                                        eyebrow: 'VIP farkını gör',
                                        title:
                                            'Standart üyelikten çok daha fazlası',
                                        description:
                                            'Günlük çalışma akışında doğrudan hissedeceğin temel farklar.',
                                        tablet: tablet,
                                      ),
                                      const SizedBox(height: 14),
                                      _comparisonTable(tablet),
                                      SizedBox(height: tablet ? 30 : 25),
                                      _sectionHeader(
                                        eyebrow: 'Yalnızca VIP’te',
                                        title: 'Kişisel gelişim araçların',
                                        description:
                                            'Sınav hazırlığını kişiselleştiren aylık VIP hakların.',
                                        tablet: tablet,
                                      ),
                                      const SizedBox(height: 14),
                                      _featureList(tablet),
                                      const SizedBox(height: 17),
                                      _finePrint(),
                                      SizedBox(height: tablet ? 32 : 26),
                                      if (_purchaseMessage != null) ...<Widget>[
                                        _messageBox(_purchaseMessage!),
                                        const SizedBox(height: 16),
                                      ],
                                      if (_buying) ...<Widget>[
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(99),
                                          child:
                                              const LinearProgressIndicator(
                                            minHeight: 5,
                                            color: _gold,
                                            backgroundColor: _line,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      KeyedSubtree(
                                        key: _plansKey,
                                        child: _plansArea(tablet),
                                      ),
                                      const SizedBox(height: 18),
                                      _securityNote(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1020),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 12),
          child: Row(
            children: <Widget>[
              _topIcon(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Geri',
                onTap: () => Navigator.pop(context),
                filled: true,
              ),
              Expanded(
                child: Text(
                  'Bilgi Rotası VIP',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
                ),
              ),
              _topIcon(
                icon: Icons.refresh_rounded,
                tooltip: 'Planları yenile',
                onTap: _buying ? null : _loadPlans,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        backgroundColor: filled ? Colors.white.withOpacity(.06) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
      icon: Icon(icon, color: onTap == null ? _faint : _dim, size: 21),
    );
  }

  Widget _hero(bool tablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tablet ? 34 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tablet ? 32 : 28),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF8B6CFF),
            Color(0xFF5636D6),
            Color(0xFF241A5C),
            Color(0xFF140F3B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: <double>[0, .35, .72, 1],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _violet.withOpacity(.20),
            blurRadius: 30,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          Positioned(
            right: -80,
            top: -95,
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    _gold.withOpacity(.34),
                    _gold.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _gold.withOpacity(.12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _gold.withOpacity(.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: _goldLight,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'BİLGİ ROTASI VIP',
                      style: GoogleFonts.poppins(
                        color: _goldLight,
                        fontSize: tablet ? 11.5 : 10.5,
                        letterSpacing: .4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tablet ? 21 : 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(
                  'Rotanı hızlandır,\nhedefine önde ulaş.',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: tablet ? 36 : 27,
                    height: 1.20,
                    letterSpacing: -.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 11),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 690),
                child: Text(
                  'Daha fazla soru çözmen, kesintisiz odaklanman ve eksiklerini kişisel analizlerle kapatman için hazırlanmış kapsamlı çalışma paketi.',
                  style: GoogleFonts.poppins(
                    color: _ink.withOpacity(.82),
                    fontSize: tablet ? 14.5 : 13,
                    height: 1.55,
                  ),
                ),
              ),
              SizedBox(height: tablet ? 24 : 21),
              _statStrip(tablet),
              const SizedBox(height: 18),
              _heroActions(tablet),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statStrip(bool tablet) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF08061E).withOpacity(.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Row(
        children: <Widget>[
          _stat('100', 'Enerji', tablet),
          _verticalDivider(),
          _stat('2×', 'Yenilenme hızı', tablet),
          _verticalDivider(),
          _stat('0', 'Zorunlu reklam', tablet),
        ],
      ),
    );
  }

  Widget _stat(String number, String label, bool tablet) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 7,
          vertical: tablet ? 16 : 13,
        ),
        child: Column(
          children: <Widget>[
            Text(
              number,
              style: GoogleFonts.poppins(
                color: _goldLight,
                fontSize: tablet ? 21 : 18,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: _dim,
                fontSize: tablet ? 11 : 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 40, color: Colors.white10);
  }

  Widget _heroActions(bool tablet) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: tablet ? 54 : 50,
            child: ElevatedButton(
              onPressed: _plans.isEmpty ? null : _scrollToPlans,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _gold,
                disabledBackgroundColor: Colors.white24,
                foregroundColor: const Color(0xFF241703),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                shadowColor: _gold.withOpacity(.28),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'VIP’e Geç',
                    style: GoogleFonts.poppins(
                      fontSize: tablet ? 14.5 : 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: tablet ? 54 : 50,
          padding: EdgeInsets.symmetric(horizontal: tablet ? 18 : 13),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _mint.withOpacity(.25)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.check_rounded, color: _mint, size: 18),
              const SizedBox(width: 5),
              Text(
                '10 ayrıcalık',
                style: GoogleFonts.poppins(
                  color: _mint,
                  fontSize: tablet ? 13 : 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required String eyebrow,
    required String title,
    required String description,
    required bool tablet,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tablet ? 8 : 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              eyebrow,
              style: GoogleFonts.poppins(
                color: _goldLight,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: _ink,
                fontSize: tablet ? 23 : 18,
                height: 1.25,
                letterSpacing: -.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: GoogleFonts.poppins(
                color: _dim,
                fontSize: tablet ? 13.5 : 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _comparisonTable(bool tablet) {
    const List<_ComparisonItem> items = <_ComparisonItem>[
      _ComparisonItem(
        Icons.battery_charging_full_rounded,
        'Enerji kapasitesi',
        '50',
        '100',
      ),
      _ComparisonItem(
        Icons.timer_outlined,
        'Yenilenme',
        '2 saatte +5',
        '1 saatte +5',
      ),
      _ComparisonItem(
        Icons.block_rounded,
        'Zorunlu reklam',
        'Her 3 seviye',
        'Yok',
      ),
      _ComparisonItem(
        Icons.ondemand_video_rounded,
        'İzle-kazan enerjisi',
        '+5',
        '+10',
      ),
      _ComparisonItem(
        Icons.inventory_2_outlined,
        'Yanlış kutusu',
        '10 soru',
        '50 soru',
      ),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          _comparisonHeader(tablet),
          ...List<Widget>.generate(items.length, (int index) {
            return _comparisonRow(
              items[index],
              tablet,
              showDivider: index != items.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _comparisonHeader(bool tablet) {
    TextStyle headerStyle = GoogleFonts.poppins(
      color: _faint,
      fontSize: tablet ? 10.5 : 9,
      letterSpacing: .55,
      fontWeight: FontWeight.w700,
    );
    return Container(
      color: Colors.white.withOpacity(.02),
      padding: EdgeInsets.symmetric(
        horizontal: tablet ? 20 : 14,
        vertical: 11,
      ),
      child: Row(
        children: <Widget>[
          Expanded(flex: 5, child: Text('ÖZELLİK', style: headerStyle)),
          Expanded(
            flex: 3,
            child: Text(
              'STANDART',
              textAlign: TextAlign.center,
              style: headerStyle,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'VIP',
              textAlign: TextAlign.center,
              style: headerStyle.copyWith(color: _goldLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonRow(
    _ComparisonItem item,
    bool tablet, {
    required bool showDivider,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tablet ? 20 : 14,
        vertical: tablet ? 15 : 13,
      ),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: _line))
            : null,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Row(
              children: <Widget>[
                Container(
                  width: tablet ? 31 : 27,
                  height: tablet ? 31 : 27,
                  decoration: BoxDecoration(
                    color: _violet.withOpacity(.18),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    item.icon,
                    color: _violetLight,
                    size: tablet ? 18 : 15,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item.title,
                    style: GoogleFonts.poppins(
                      color: _ink,
                      fontSize: tablet ? 13 : 10.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              item.standard,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: _faint,
                fontSize: tablet ? 12.5 : 9.7,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    item.vip,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: _goldLight,
                      fontSize: tablet ? 12.5 : 9.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.check_rounded, color: _mint, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureList(bool tablet) {
    const List<_VipFeature> features = <_VipFeature>[
      _VipFeature(
        Icons.bar_chart_rounded,
        'Ayda 4 zayıf konu analizi',
        'Eksik konularını ve haftalık gelişimini ayrıntılı biçimde gör.',
        '4× AY',
        true,
      ),
      _VipFeature(
        Icons.auto_awesome_rounded,
        'VIP Analiz Merkezi',
        'Çalışma verilerinden kişisel öneriler ve odak noktaları oluştur.',
        'KİŞİSEL',
        true,
      ),
      _VipFeature(
        Icons.edit_note_rounded,
        'Ayda 1 kişisel test talebi',
        'Eksik olduğun konular için sana özel test desteği iste.',
        '1 TEST',
        false,
      ),
      _VipFeature(
        Icons.inventory_2_rounded,
        '50 soruluk yanlış kutusu',
        'Daha fazla yanlışını sakla, tekrar çöz ve kalıcı öğren.',
        '5× ALAN',
        false,
      ),
      _VipFeature(
        Icons.workspace_premium_rounded,
        'Özel VIP profil rozeti',
        'Profilinde ve sıralamada premium görünümle farkını göster.',
        'PRESTİJ',
        false,
      ),
    ];

    return LayoutBuilder(
      builder: (_, BoxConstraints constraints) {
        final int columns = tablet ? 2 : 1;
        const double gap = 10;
        final double width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: features
              .map(
                (_VipFeature feature) => SizedBox(
                  width: width,
                  child: _featureTile(feature, tablet),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _featureTile(_VipFeature feature, bool tablet) {
    return Container(
      constraints: BoxConstraints(minHeight: tablet ? 112 : 0),
      padding: EdgeInsets.all(tablet ? 17 : 15),
      decoration: BoxDecoration(
        color: feature.highlight ? null : _panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: feature.highlight
              ? _violetLight.withOpacity(.35)
              : _line,
        ),
        gradient: feature.highlight
            ? LinearGradient(
                colors: <Color>[
                  _violet.withOpacity(.14),
                  _panel,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: tablet ? 43 : 40,
            height: tablet ? 43 : 40,
            decoration: BoxDecoration(
              color: _violetLight.withOpacity(.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              feature.icon,
              color: _violetLight,
              size: tablet ? 22 : 20,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        feature.title,
                        style: GoogleFonts.poppins(
                          color: _ink,
                          fontSize: tablet ? 14 : 12.7,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        feature.badge,
                        style: GoogleFonts.poppins(
                          color: _goldLight,
                          fontSize: 8.5,
                          letterSpacing: .3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: GoogleFonts.poppins(
                    color: _dim,
                    fontSize: tablet ? 11.5 : 10.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _finePrint() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        'VIP sınırsız değildir — analiz ve kişisel test hakları aylık belirtilen adetlerle sınırlıdır.',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: _faint,
          fontSize: 10.8,
          height: 1.55,
        ),
      ),
    );
  }

  Widget _plansArea(bool tablet) {
    if (_error != null) {
      return _stateBox(
        icon: Icons.error_outline_rounded,
        title: 'VIP planları yüklenemedi',
        description: _error!,
        action: 'Tekrar dene',
      );
    }
    if (_plans.isEmpty) {
      return _stateBox(
        icon: Icons.storefront_rounded,
        title: 'Mağaza ürünü bulunamadı',
        description:
            'Mağaza ürünlerinin aktif ve doğru uygulamaya bağlı olduğunu kontrol et.',
        action: 'Yenile',
      );
    }

    final List<VipPlanOption> plans = _orderedPlans();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionHeader(
          eyebrow: 'Üyelik planları',
          title: 'Sana uygun planı seç',
          description:
              'Tüm planlar aynı VIP ayrıcalıklarını içerir; yalnızca üyelik süresi değişir.',
          tablet: tablet,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (_, BoxConstraints constraints) {
            final int columns = tablet
                ? (plans.length > 3 ? 3 : plans.length)
                : 1;
            const double gap = 10;
            final double width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: plans
                  .map(
                    (VipPlanOption plan) => SizedBox(
                      width: width,
                      child: _planTile(plan, tablet),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 15),
        _purchaseButton(tablet),
      ],
    );
  }

  Widget _planTile(VipPlanOption plan, bool tablet) {
    final bool selected = _isSelected(plan);
    final bool yearly = plan.planKey == 'yearly';

    return InkWell(
      onTap: _buying ? null : () => _selectPlan(plan),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: BoxConstraints(minHeight: tablet ? 166 : 0),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: selected ? _panel2 : _panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _violetLight : _line,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: _violet.withOpacity(.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _planTitle(plan),
                    style: GoogleFonts.poppins(
                      color: _ink,
                      fontSize: tablet ? 15 : 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (yearly)
                  _planBadge('EN AVANTAJLI')
                else if (plan.planKey == 'three_months')
                  _planBadge('AVANTAJLI'),
                const SizedBox(width: 7),
                Container(
                  width: 23,
                  height: 23,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? _violetLight : Colors.transparent,
                    border: Border.all(
                      color: selected ? _violetLight : _faint,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),
            if (tablet) const Spacer() else const SizedBox(height: 14),
            Text(
              plan.price,
              style: GoogleFonts.poppins(
                color: selected ? _goldLight : _ink,
                fontSize: tablet ? 23 : 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _planSubtitle(plan.planKey),
              style: GoogleFonts.poppins(
                color: _dim,
                fontSize: 10.3,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: _gold.withOpacity(.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: _goldLight,
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _purchaseButton(bool tablet) {
    final VipPlanOption? selected = _selectedPlan;
    return SizedBox(
      width: double.infinity,
      height: tablet ? 57 : 54,
      child: ElevatedButton(
        onPressed: _buying || selected == null ? null : _buySelectedPlan,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _gold,
          disabledBackgroundColor: _line,
          foregroundColor: const Color(0xFF241703),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_buying)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.3,
                  color: Color(0xFF241703),
                ),
              )
            else
              const Icon(Icons.lock_open_rounded, size: 20),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                _buying
                    ? 'Güvenli ödeme açılıyor…'
                    : selected == null
                        ? 'Önce bir plan seç'
                        : '${_planTitle(selected)} ile devam et',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: tablet ? 14.5 : 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _violetLight.withOpacity(.30)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline_rounded,
              color: _violetLight, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: _dim,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateBox({
    required IconData icon,
    required String title,
    required String description,
    required String action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: _violetLight, size: 34),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: _dim,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _loadPlans,
            style: ElevatedButton.styleFrom(
              backgroundColor: _violet,
              foregroundColor: Colors.white,
            ),
            child: Text(
              action,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.lock_outline_rounded, color: _faint, size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Ödeme Google Play veya App Store tarafından güvenle tamamlanır.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: _faint,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  List<VipPlanOption> _orderedPlans() {
    final List<VipPlanOption> result = List<VipPlanOption>.from(_plans);
    int rank(String key) {
      if (key == 'monthly') return 0;
      if (key == 'three_months') return 1;
      if (key == 'yearly') return 2;
      return 3;
    }

    result.sort(
      (VipPlanOption a, VipPlanOption b) =>
          rank(a.planKey).compareTo(rank(b.planKey)),
    );
    return result;
  }

  String _planTitle(VipPlanOption plan) {
    if (plan.planKey == 'monthly') return 'Aylık VIP';
    if (plan.planKey == 'three_months') return '3 Aylık VIP';
    if (plan.planKey == 'yearly') return 'Yıllık VIP';
    return plan.title;
  }

  String _planSubtitle(String planKey) {
    if (planKey == 'monthly') return 'Aylık yenilenen esnek plan';
    if (planKey == 'three_months') return 'Üç aylık avantajlı dönem';
    if (planKey == 'yearly') return 'En yüksek dönem avantajı';
    return 'Tüm VIP ayrıcalıkları dahil';
  }
}

class _ComparisonItem {
  final IconData icon;
  final String title;
  final String standard;
  final String vip;

  const _ComparisonItem(this.icon, this.title, this.standard, this.vip);
}

class _VipFeature {
  final IconData icon;
  final String title;
  final String description;
  final String badge;
  final bool highlight;

  const _VipFeature(
    this.icon,
    this.title,
    this.description,
    this.badge,
    this.highlight,
  );
}
