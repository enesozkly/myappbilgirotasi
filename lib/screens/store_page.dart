// ignore_for_file: unused_element

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path_provider/path_provider.dart';

import '../services/pdf_purchase_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MAĞAZA SAYFASI
/// PDF satın alma mantığı:
/// - Her PDF ayrı Google Play tek seferlik üründür.
/// - Satın alınan PDF users/{uid}/pdf_purchases/{productId} içine yazılır.
/// - Sadece satın alınan PDF indirilebilir.
/// ─────────────────────────────────────────────────────────────────────────────
class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> with TickerProviderStateMixin {
  late AnimationController _bgController;

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  final PdfPurchaseService _purchaseService = PdfPurchaseService.instance;

  bool _loading = true;
  bool _productsLoading = true;
  String? _buyingProductId;
  String? _storeMessage;

  final Set<String> _ownedPdfIds = {};
  Map<String, PdfProductOption> _productOptions = {};

  // ── İndirilebilir PDF'ler ─────────────────────────────
  static const List<Map<String, dynamic>> _pdfs = [
    {
      'id': 'pdf_ayt_biyoloji',
      'title': 'AYT Biyoloji',
      'subtitle': 'AYT Biyoloji konu özetleri ve tekrar materyali',
      'desc': 'AYT Biyoloji için hazırlanmış indirilebilir PDF materyali.',
      'pages': 'PDF Materyali',
      'topics': 'Canlılık · Sistemler · Kalıtım · Ekoloji',
      'icon': Icons.biotech_rounded,
      'colors': [Color(0xFF43CEA2), Color(0xFF185A9D)],
      'badge': 'Yeni',
      'badgeColor': Color(0xFF00E5FF),
      'fileName': 'ayt_biyoloji.pdf',
      'fallbackPrice': '₺79,99',
    },
    {
      'id': 'pdf_ayt_edebiyat',
      'title': 'AYT Edebiyat',
      'subtitle': 'Tüm AYT Edebiyat konuları ve özetler',
      'desc': 'AYT Edebiyat müfredatının tamamını kapsayan özet kitap. İndirilebilir PDF formatındadır.',
      'pages': 'PDF Materyali',
      'topics': 'Edebiyat · Şiir · Roman · Tiyatro',
      'icon': Icons.menu_book_rounded,
      'colors': [Color(0xFFFF512F), Color(0xFFF09819)],
      'badge': 'Popüler',
      'badgeColor': Color(0xFFFFD700),
      'fileName': 'ayt_edebiyat.pdf',
      'fallbackPrice': '₺69,99',
    },
    {
      'id': 'pdf_kpss_cografya',
      'title': 'KPSS Coğrafya',
      'subtitle': 'Tüm Coğrafya konuları ve haritalar',
      'desc': 'KPSS Coğrafya müfredatının tamamını kapsayan özet PDF materyali.',
      'pages': 'PDF Materyali',
      'topics': 'Fiziki Coğrafya · Beşeri Coğrafya · Harita Bilgisi',
      'icon': Icons.map_rounded,
      'colors': [Color(0xFF1D976C), Color(0xFF38EF7D)],
      'badge': 'Kaynak',
      'badgeColor': Color(0xFF00E676),
      'fileName': 'cografya_kpss.pdf',
      'fallbackPrice': '₺79,99',
    },
    {
      'id': 'pdf_kpss_tarih',
      'title': 'KPSS Tarih',
      'subtitle': 'Tarih konularını kapsayan tam kaynak',
      'desc': 'KPSS Tarih sınavına özel hazırlanmış özet PDF materyali.',
      'pages': 'PDF Materyali',
      'topics': 'Osmanlı Tarihi · İnkılap Tarihi · Çağdaş Tarih',
      'icon': Icons.history_edu_rounded,
      'colors': [Color(0xFF00BCD4), Color(0xFF007BFF)],
      'badge': 'Yeni',
      'badgeColor': Color(0xFF00E5FF),
      'fileName': 'tarih_kpss.pdf',
      'fallbackPrice': '₺69,99',
    },
    {
      'id': 'pdf_tyt_biyoloji',
      'title': 'TYT Biyoloji',
      'subtitle': 'TYT Biyoloji konu özetleri ve tekrar materyali',
      'desc': 'TYT Biyoloji için hazırlanmış indirilebilir PDF materyali.',
      'pages': 'PDF Materyali',
      'topics': 'Canlılar · Hücre · Ekoloji · Kalıtım',
      'icon': Icons.eco_rounded,
      'colors': [Color(0xFF56AB2F), Color(0xFFA8E063)],
      'badge': 'Yeni',
      'badgeColor': Color(0xFF00E676),
      'fileName': 'tyt_biyoloji.pdf',
      'fallbackPrice': '₺69,99',
    },
    {
      'id': 'pdf_felsefe',
      'title': 'Felsefe',
      'subtitle': 'Felsefe konu özetleri ve tekrar materyali',
      'desc': 'Felsefe için hazırlanmış indirilebilir PDF materyali.',
      'pages': 'PDF Materyali',
      'topics': 'Felsefe · Mantık · Bilgi · Varlık',
      'icon': Icons.psychology_rounded,
      'colors': [Color(0xFF654EA3), Color(0xFFEAAFC8)],
      'badge': 'Yeni',
      'badgeColor': Color(0xFFD500F9),
      'fileName': 'felsefe.pdf',
      'fallbackPrice': '₺49,99',
    },
  ];

  @override
  void initState() {
    super.initState();
    _bgController =
        AnimationController(vsync: this, duration: const Duration(seconds: 30))
          ..repeat();

    _purchaseService.startListening(
      onPurchased: _handlePurchasedPdf,
      onPending: (purchase) {
        if (!mounted) return;
        setState(() {
          _buyingProductId = purchase.productID;
          _storeMessage = 'Ödeme beklemede. Onaylanınca PDF erişiminiz açılacak.';
        });
        _showSnack('Ödeme beklemede.', Colors.orangeAccent);
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _buyingProductId = null;
          _storeMessage = message;
        });
        _showSnack(message, Colors.redAccent);
      },
    );

    _loadStoreData();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _purchaseService.dispose();
    super.dispose();
  }

  Future<void> _loadStoreData() async {
    setState(() {
      _loading = true;
      _productsLoading = true;
      _storeMessage = null;
    });

    await Future.wait([
      _loadOwnedPdfs(),
      _loadProducts(),
    ]);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _productsLoading = false;
    });
  }

  Future<void> _loadOwnedPdfs() async {
    if (_uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('pdf_purchases')
          .get();

      _ownedPdfIds
        ..clear()
        ..addAll(snapshot.docs.map((doc) => doc.id));
    } catch (e) {
      debugPrint('PDF sahiplikleri okunamadı: $e');
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _purchaseService.loadPdfProducts();
      _productOptions = products;

      final missing = PdfPurchaseService.pdfProductIds.difference(products.keys.toSet());
      if (missing.isNotEmpty) {
        _storeMessage =
            'Bazı PDF ürünleri mağaza tarafında henüz görünmüyor: ${missing.join(', ')}';
      }
    } catch (e) {
      _storeMessage = 'Satın alma ürünleri yüklenemedi: $e';
      debugPrint(_storeMessage);
    }
  }

  Map<String, dynamic>? _pdfById(String productId) {
    for (final pdf in _pdfs) {
      if (pdf['id'] == productId) return pdf;
    }
    return null;
  }

  String _priceFor(Map<String, dynamic> pdf) {
    final productId = pdf['id'] as String;
    return _productOptions[productId]?.price ?? pdf['fallbackPrice'] as String;
  }

  bool _isOwned(String productId) => _ownedPdfIds.contains(productId);

  bool _isBuying(String productId) => _buyingProductId == productId;

  Future<void> _buyPdf(Map<String, dynamic> pdf) async {
    final uid = _uid;
    if (uid == null) {
      _showSnack('PDF satın almak için önce giriş yapmalısınız.', Colors.orange);
      return;
    }

    final productId = pdf['id'] as String;
    if (_isOwned(productId)) {
      await _downloadPdf(
        productId: productId,
        fileName: pdf['fileName'] as String,
        displayName: pdf['title'] as String,
      );
      return;
    }

    final option = _productOptions[productId];
    if (option == null) {
      _showSnack(
        'Bu PDF ürünü şu an satın alma servisi tarafından döndürülmedi. Ürün ID, fiyat ve aktiflik durumunu kontrol edin.',
        Colors.redAccent,
      );
      return;
    }

    if (_buyingProductId != null) return;

    setState(() {
      _buyingProductId = productId;
      _storeMessage = '${pdf['title']} satın alma başlatılıyor...';
    });

    try {
      await _purchaseService.buyPdf(option);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buyingProductId = null;
        _storeMessage = 'Satın alma başlatılamadı: $e';
      });
      _showSnack('Satın alma başlatılamadı: $e', Colors.redAccent);
    }
  }

  Future<void> _restorePurchases() async {
    if (_uid == null) {
      _showSnack('Satın alımları geri yüklemek için önce giriş yapmalısınız.', Colors.orange);
      return;
    }

    setState(() {
      _storeMessage = 'Satın alımlar geri yükleniyor...';
    });

    try {
      await _purchaseService.restorePdfPurchases();
      _showSnack('Geri yükleme başlatıldı. Satın alınmış PDF varsa birazdan açılacak.', Colors.blueAccent);
    } catch (e) {
      _showSnack('Geri yükleme başlatılamadı: $e', Colors.redAccent);
    }
  }

  Future<void> _handlePurchasedPdf(PurchaseDetails purchase) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Kullanıcı girişi yok.');
    }

    final pdf = _pdfById(purchase.productID);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('pdf_purchases')
        .doc(purchase.productID)
        .set({
      'productId': purchase.productID,
      'title': pdf?['title'] ?? purchase.productID,
      'fileName': pdf?['fileName'] ?? '',
      'purchaseId': purchase.purchaseID ?? '',
      'verificationData': purchase.verificationData.serverVerificationData,
      'source': 'google_play',
      'status': purchase.status.name,
      'purchasedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    setState(() {
      _ownedPdfIds.add(purchase.productID);
      _buyingProductId = null;
      _storeMessage = '${pdf?['title'] ?? 'PDF'} erişimi aktif edildi.';
    });

    _showSnack('✅ ${pdf?['title'] ?? 'PDF'} erişiminiz aktif edildi.', Colors.green);
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── PDF İndirme Metodu ───────────────────────────────────────────────────
  Future<void> _downloadPdf({
    required String productId,
    required String fileName,
    required String displayName,
  }) async {
    if (!_isOwned(productId)) {
      _showSnack('Bu PDF materyalini indirmek için önce satın almalısınız.', Colors.orange);
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F6A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'PDF Nereye İndirilsin?',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$displayName dosyasını nereye kaydetmek istersiniz?',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _dialogOption(
              ctx,
              'downloads',
              Icons.download_rounded,
              'İndirilenler Klasörü',
              'Telefonun İndirilenler klasörüne kaydet',
              const Color(0xFF00E5FF),
            ),
            const SizedBox(height: 10),
            _dialogOption(
              ctx,
              'documents',
              Icons.folder_open_rounded,
              'Uygulama Belgelerim',
              'Uygulamanın kendi klasörüne kaydet',
              const Color(0xFFFFD700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'İptal',
              style: GoogleFonts.poppins(color: Colors.white38),
            ),
          ),
        ],
      ),
    );

    if (choice == null) return;

    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$displayName indiriliyor...',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 60),
        ),
      );

      final byteData = await rootBundle.load('assets/pdfs/$fileName');
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      late File savedFile;

      if (choice == 'downloads') {
        if (Platform.isAndroid) {
          const path = '/storage/emulated/0/Download';
          final dir = Directory(path);
          if (!await dir.exists()) await dir.create(recursive: true);
          savedFile = File('$path/$fileName');
        } else {
          final dir = await getApplicationDocumentsDirectory();
          savedFile = File('${dir.path}/$fileName');
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        savedFile = File('${dir.path}/$fileName');
      }

      await savedFile.writeAsBytes(bytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ $displayName indirildi!\n📁 ${savedFile.path}',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'İndirme hatası: $e',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Dialog konum seçim satırı
  Widget _dialogOption(
    BuildContext ctx,
    String value,
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
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
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0E43), Color(0xFF1B1F6A), Color(0xFF0D1B3E)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          _cloud(top: size.height * 0.07, scale: 1.0, speed: 0.5, right: true),
          _cloud(top: size.height * 0.5, scale: 1.3, speed: 0.4, right: false),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PDF Materyalleri',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Satın aldığın PDF hesabına kalıcı eklenir',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Satın alımları geri yükle',
                        onPressed: _restorePurchases,
                        icon: const Icon(
                          Icons.restore_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Text('📚', style: TextStyle(fontSize: 26)),
                    ],
                  ),
                ),
                if (_loading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                    ),
                  )
                else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadStoreData,
                      color: const Color(0xFF00E5FF),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          _sectionHeader(
                            '📚',
                            'PDF Materyalleri',
                            'Satın alınan PDF’ler bu hesaba kalıcı tanımlanır',
                          ),
                          if (_storeMessage != null) ...[
                            const SizedBox(height: 12),
                            _messageBox(_storeMessage!),
                          ],
                          if (_productsLoading) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(
                              color: Color(0xFF00E5FF),
                              backgroundColor: Colors.white12,
                            ),
                          ],
                          const SizedBox(height: 12),
                          ..._pdfs.map((p) => _pdfCard(p)),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String emoji, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _messageBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF00E5FF), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pdfCard(Map<String, dynamic> p) {
    final colors = p['colors'] as List<Color>;
    final badgeColor = p['badgeColor'] as Color;
    final productId = p['id'] as String;
    final owned = _isOwned(productId);
    final buying = _isBuying(productId);

    return GestureDetector(
      onTap: () => _showPdfDetailSheet(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors[0].withValues(alpha: 0.35), width: 1.4),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors[0].withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(p['icon'] as IconData, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            p['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (owned ? Colors.greenAccent : badgeColor).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: (owned ? Colors.greenAccent : badgeColor).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            owned ? 'ALINDI' : p['badge'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: owned ? Colors.greenAccent : badgeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      p['subtitle'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.picture_as_pdf_rounded,
                          color: colors[0].withValues(alpha: 0.8),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          p['pages'] as String,
                          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    owned ? 'Aktif' : _priceFor(p),
                    style: GoogleFonts.poppins(
                      color: owned ? Colors.greenAccent : colors[0],
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: buying
                        ? null
                        : () async {
                            if (owned) {
                              await _downloadPdf(
                                productId: productId,
                                fileName: p['fileName'] as String,
                                displayName: p['title'] as String,
                              );
                            } else {
                              await _buyPdf(p);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: buying
                              ? [Colors.grey, Colors.grey.shade700]
                              : owned
                                  ? [Colors.greenAccent.shade400, Colors.green.shade700]
                                  : colors,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: colors[0].withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: buying
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              owned ? 'İndir' : 'Satın Al',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
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

  void _showPdfDetailSheet(Map<String, dynamic> p) {
    final colors = p['colors'] as List<Color>;
    final productId = p['id'] as String;
    final owned = _isOwned(productId);
    final buying = _isBuying(productId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1B1F6A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: colors[0].withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(p['icon'] as IconData, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['title'] as String,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          owned ? 'Satın alındı · İndirilebilir' : p['pages'] as String,
                          style: GoogleFonts.poppins(color: owned ? Colors.greenAccent : colors[0], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  p['desc'] as String,
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, height: 1.6),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'İçerdiği Konular',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (p['topics'] as String)
                    .split('·')
                    .map(
                      (t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: colors[0].withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors[0].withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          t.trim(),
                          style: GoogleFonts.poppins(
                            color: colors[0],
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (owned ? Colors.greenAccent : const Color(0xFF00E5FF)).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (owned ? Colors.greenAccent : const Color(0xFF00E5FF)).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      owned ? Icons.verified_rounded : Icons.lock_rounded,
                      color: owned ? Colors.greenAccent : const Color(0xFF00E5FF),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        owned
                            ? 'Bu PDF hesabınıza tanımlı. İstediğiniz zaman indirebilirsiniz.'
                            : 'Satın alma tamamlanınca bu PDF hesabınıza kalıcı tanımlanır.',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        owned ? 'Durum' : 'Fiyat',
                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                      ),
                      Text(
                        owned ? 'Aktif' : _priceFor(p),
                        style: GoogleFonts.poppins(
                          color: owned ? Colors.greenAccent : colors[0],
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: owned ? Colors.green.shade600 : colors[0],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 6,
                      shadowColor: colors[0].withValues(alpha: 0.4),
                    ),
                    icon: buying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(owned ? Icons.download_rounded : Icons.shopping_cart_rounded, size: 20),
                    label: Text(
                      buying ? 'İşleniyor' : owned ? 'İndir' : 'Satın Al',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    onPressed: buying
                        ? null
                        : () async {
                            Navigator.pop(context);
                            if (owned) {
                              await _downloadPdf(
                                productId: productId,
                                fileName: p['fileName'] as String,
                                displayName: p['title'] as String,
                              );
                            } else {
                              await _buyPdf(p);
                            }
                          },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cloud({
    required double top,
    required double scale,
    required double speed,
    required bool right,
  }) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (ctx, _) {
        final sw = MediaQuery.of(ctx).size.width;
        final cw = 120.0 * scale;
        double off = (_bgController.value * speed * (sw + cw)) % (sw + cw);
        if (!right) off = sw - off;
        return Positioned(
          top: top,
          left: off - cw,
          child: Icon(
            Icons.cloud_rounded,
            color: Colors.white.withValues(alpha: 0.06),
            size: 120 * scale,
          ),
        );
      },
    );
  }
}
