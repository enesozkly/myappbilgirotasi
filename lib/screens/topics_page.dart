import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'level_map_page.dart';

class TopicsPage extends StatefulWidget {
  final String examName;
  final String subjectName;

  const TopicsPage({
    super.key,
    required this.examName,
    required this.subjectName,
  });

  @override
  State<TopicsPage> createState() => _TopicsPageState();
}

class _TopicsPageState extends State<TopicsPage> with TickerProviderStateMixin {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late AnimationController _bgController;

  Map<String, int> _topicProgress = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
    _loadAllProgress();

    // Gecis reklamlari artik konu sayfasi acilisinda rastgele gosterilmiyor.
    // Reklam sayaci ReklamServisi.bolumTamamlandi/denemeTamamlandi uzerinden 4 tamamlamada 1 calisir.
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _loadAllProgress() async {
    if (_uid == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('progress')
          .get();

      final Map<String, int> tempProgress = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('currentSection')) {
          final String tName = data['topic'] ?? '';
          final int cSection = (data['currentSection'] ?? 1).toInt();
          if (tName.isNotEmpty) {
            tempProgress[tName] = cSection;
          }
        }
      }

      if (mounted) {
        setState(() {
          _topicProgress = tempProgress;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("İlerleme yükleme hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getTopics() {
    String sub = widget.subjectName;
    String exam = widget.examName;

    // ── TÜRKÇE ──────────────────────────────────
    if (sub == "Türkçe") {
      return [
        {"name": "Anlatım Bozuklukları", "total": 30},
        {"name": "Cümlede Anlam", "total": 30},
        {"name": "Cümlenin Ögeleri", "total": 30},
        {"name": "Cümle Türleri", "total": 30},
        {"name": "Dil Bilgisi Ses Olayları", "total": 30},
        {"name": "Mantık", "total": 30},
        {"name": "Noktalama İşaretleri", "total": 30},
        {"name": "Paragrafta Anlam", "total": 30},
        {"name": "Paragrafta Anlatım Biçimi", "total": 30},
        {"name": "Sözcükte Anlam", "total": 30},
        {"name": "Sözcükte Yapı", "total": 30},
        {"name": "Sözcük Türleri", "total": 30},
        {"name": "Yazım Kuralları", "total": 30},
      ];
    }
    // ── EDEBİYAT ────────────────────────────────────
    if (sub == "Edebiyat") {
      return [
        {"name": "Akımları", "total": 30},
        {"name": "Anlam Bilgisi", "total": 30},
        {"name": "Cumhuriyet Dönemi Edebiyatı", "total": 30},
        {"name": "Dil Bilgisi", "total": 30},
        {"name": "Divan Edebiyatı", "total": 30},
        {"name": "Edebi Sanatlar", "total": 30},
        {"name": "Halk Edebiyatı", "total": 30},
        {"name": "İslamiyet Öncesi Türk Edebiyatı ve Geçiş Dönemi", "total": 30},
        {"name": "Metinlerin Türleri", "total": 30},
        {"name": "Milli Edebiyat", "total": 30},
        {"name": "Servet i Fünun ve Fecr i Ati Edebiyatı", "total": 30},
        {"name": "Şiir Bilgisi", "total": 30},
        {"name": "Tanzimat Edebiyatı", "total": 30},
      ];
    }
    // ── MATEMATİK ─────────────────────────────────────────────────
    if (sub == "Matematik") {
      if (exam.contains("AYT")) {
        return [
          {"name": "Bölme ve Bölünebilme Kuralları", "total": 30},
          {"name": "Diziler", "total": 30},
          {"name": "EBOB EKOK", "total": 30},
          {"name": "İkinci Dereceden Denklemler Parabol ve Eşitsizlikler", "total": 30},
          {"name": "İntegral", "total": 30},
          {"name": "Karmaşık Sayılar", "total": 30},
          {"name": "Logaritma", "total": 30},
          {"name": "Parabol", "total": 30},
          {"name": "Permütasyon Kombinasyon Olasılık Binom", "total": 30},
          {"name": "Polinom", "total": 30},
          {"name": "Sayı Basamakları", "total": 30},
          {"name": "Trigonometri", "total": 30},
          {"name": "Türev", "total": 30},
        ];
      }
      return [
        {"name": "Basit Eşitsizlikler", "total": 30},
        {"name": "Çarpanlara Ayırma", "total": 30},
        {"name": "Denklem Çözme", "total": 30},
        {"name": "Fonksiyonlar", "total": 30},
        {"name": "İşlem", "total": 30},
        {"name": "Kümeler", "total": 30},
        {"name": "Mantık", "total": 30},
        {"name": "Mutlak Değer", "total": 30},
        {"name": "Olasılık", "total": 30},
        {"name": "Oran Orantı", "total": 30},
        {"name": "Permütasyon Kombinasyon", "total": 30},
        {"name": "Problemler", "total": 30},
        {"name": "Rasyonel Sayılar Ondalıklı Sayılar", "total": 30},
        {"name": "Temel Kavramlar", "total": 30},
      ];
    }
    // ── TARİH ─────────────────────────────────────
    if (sub == "Tarih") {
      if (exam.contains("AYT")) {
        return [
          {"name": "Atatürkçülük ve Türk İnkılabı", "total": 30},
          {"name": "Beylikten Devlete Osmanlı Medeniyeti", "total": 30},
          {"name": "Beylikten Devlete Osmanlı Siyaseti", "total": 30},
          {"name": "Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti", "total": 30},
          {"name": "Değişim Çağında Avrupa ve Osmanlı", "total": 30},
          {"name": "Devletleşme Sürecinde Savaşçılar ve Askerler", "total": 30},
          {"name": "Devrimler Çağında Değişen Devlet Toplum İlişkileri", "total": 30},
          {"name": "Dünya Gücü Osmanlı ve Türk İslam Tarihi", "total": 30},
          {"name": "II Dünya Savaşı Sonrasında Türkiye ve Dünya", "total": 30},
          {"name": "II Dünya Savaşı Sürecinde Türkiye ve Dünya", "total": 30},
          {"name": "İki Savaş Arasındaki Dönemde Türkiye ve Dünya", "total": 30},
          {"name": "İlk ve Orta Çağlarda Türk Dünyası", "total": 30},
          {"name": "İnsanlığın İlk Dönemleri", "total": 30},
          {"name": "İslam Medeniyetinin Doğuşu ve İlk İslam Devletleri", "total": 30},
          {"name": "Klasik Çağda Osmanlı Toplum Düzeni", "total": 30},
          {"name": "Milli Mücadele", "total": 30},
          {"name": "Orta Çağ da Dünya", "total": 30},
          {"name": "Sermaye ve Emek", "total": 30},
          {"name": "Sultan ve Osmanlı Merkez Teşkilatı", "total": 30},
          {"name": "Toplumsal Devrim Çağında Dünya ve Türkiye", "total": 30},
          {"name": "Türklerin İslamiyet i Kabulü ve İlk Türk İslam Devletleri", "total": 30},
          {"name": "Uluslararası İlişkilerde Denge Stratejisi 1774 1914", "total": 30},
          {"name": "Ve Zaman", "total": 30},
          {"name": "XIX ve XX Yüzyılda Değişen Gündelik Hayat", "total": 30},
          {"name": "XX Yüzyıl Başlarında Osmanlı Devleti ve Dünya", "total": 30},
          {"name": "XXI Yüzyılın Eşiğinde Türkiye ve Dünya", "total": 30},
          {"name": "Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi", "total": 30},
        ];
      }
      return [
        {"name": "17 Yüzyıl Osmanlı Devleti Duraklama Dönemi", "total": 30},
        {"name": "18 Yüzyıl Osmanlı Devleti Gerileme Dönemi", "total": 30},
        {"name": "19 Yüzyıl Osmanlı Devleti Dağılma Dönemi", "total": 30},
        {"name": "20 Yüzyıl Osmanlı Devleti", "total": 30},
        {"name": "Atatürk Dönemi İç ve Dış Politikalar", "total": 30},
        {"name": "Çağdaş Türk ve Dünya Tarihi", "total": 30},
        {"name": "İlk Türk İslam Devletleri", "total": 30},
        {"name": "İlk Türk İslam Devletlerinde Kültür ve Medeniyet", "total": 30},
        {"name": "İnkılap Tarihi", "total": 30},
        {"name": "İslamiyet Öncesi Türk Tarihi", "total": 30},
        {"name": "İslamiyet Öncesi Türk Tarihi Soru Bankası", "total": 30},
        {"name": "Milli Mücadele Dönemi", "total": 30},
        {"name": "Osmanlı Devleti Kültür ve Medeniyet", "total": 30},
        {"name": "Osmanlı Devleti Kuruluş ve Yükselme Dönemi", "total": 30},
      ];
    }
    // ── COĞRAFYA ──────────────────────────────────
    if (sub == "Coğrafya") {
      if (exam.contains("AYT")) {
        return [
          {"name": "Bölgeleri", "total": 30},
          {"name": "Bölgeler ve Ülkeler", "total": 30},
          {"name": "Çevre ve Toplum", "total": 30},
          {"name": "Dünya nın Şekli ve Hareketleri", "total": 30},
          {"name": "Ekonomik Faaliyetler ve Doğal Kaynaklar", "total": 30},
          {"name": "Ekosistem", "total": 30},
          {"name": "Göç ve Şehirleşme", "total": 30},
          {"name": "Harita Bilgisi", "total": 30},
          {"name": "İç ve Dış Kuvvetler", "total": 30},
          {"name": "İklim ve Yer Şekilleri", "total": 30},
          {"name": "Küresel Ticaret", "total": 30},
          {"name": "Nüfus Politikaları", "total": 30},
          {"name": "Türkiye de Ekonomi", "total": 30},
          {"name": "Türkiye de Nüfus ve Yerleşme", "total": 30},
          {"name": "Türkiye nin Coğrafi Konumu", "total": 30},
          {"name": "Türkiye nin İşlevsel Bölgeleri ve Kalkınma Projeleri", "total": 30},
          {"name": "Ülkeler Arası Etkileşimler", "total": 30},
          {"name": "Uluslararası Örgütler", "total": 30},
        ];
      }
      return [
        {"name": "Bölgeler Coğrafyası", "total": 30},
        {"name": "Hayvancılık", "total": 30},
        {"name": "Madenler ve Enerji", "total": 30},
        {"name": "Sanayi ve Endüstri", "total": 30},
        {"name": "Tarım", "total": 30},
        {"name": "Ticaret", "total": 30},
        {"name": "Turizm", "total": 30},
        {"name": "Türkiye de Nüfus ve Yerleşme", "total": 30},
        {"name": "Türkiye nin Coğrafi Konumu", "total": 30},
        {"name": "Türkiye nin Fiziki Özellikleri", "total": 30},
        {"name": "Türkiye nin İklimi ve Bitki Örtüsü", "total": 30},
        {"name": "Ulaşım", "total": 30},
      ];
    }
    // ── FİZİK ─────────────────────────────────────────────────────
    if (sub == "Fizik") {
      if (exam == "TYT") {
        return [
          {"name": "Basınç", "total": 30},
          {"name": "Bilimine Giriş", "total": 30},
          {"name": "Dalgalar", "total": 30},
          {"name": "Dinamik", "total": 30},
          {"name": "Elektriksel Enerji ve Güç", "total": 30},
          {"name": "Elektrik Akımı ve Devreler", "total": 30},
          {"name": "Elektrostatik", "total": 30},
          {"name": "Hareket ve Kuvvet", "total": 30},
          {"name": "Isı Sıcaklık ve Genleşme", "total": 30},
          {"name": "İş Güç ve Enerji", "total": 30},
          {"name": "Madde ve Özellikleri", "total": 30},
          {"name": "Manyetizma", "total": 30},
          {"name": "Optik", "total": 30},
          {"name": "Sıvıların Kaldırma Kuvveti", "total": 30},
        ];
      } else {
        return [
          {"name": "Atışlar", "total": 30},
          {"name": "Atom Modelleri", "total": 30},
          {"name": "Basit Harmonik Hareket", "total": 30},
          {"name": "Basit Makineler", "total": 30},
          {"name": "Büyük Patlama ve Parçacık Fiziği", "total": 30},
          {"name": "Dalga Mekaniği ve Elektromanyetik Dalgalar", "total": 30},
          {"name": "Dönme Yuvarlanma ve Açısal Momentum", "total": 30},
          {"name": "Düzgün Çembersel Hareket", "total": 30},
          {"name": "Elektrik Alan ve Potansiyel", "total": 30},
          {"name": "Fotoelektrik Olay ve Compton Olayı", "total": 30},
          {"name": "Hareket", "total": 30},
          {"name": "İndüksiyon Alternatif Akım ve Transformatörler", "total": 30},
          {"name": "İş Güç ve Enerji", "total": 30},
          {"name": "İtme ve Çizgisel Momentum", "total": 30},
          {"name": "Kara Cisim Işıması", "total": 30},
          {"name": "Kütle Çekim Merkezi ve Açısal Momentum", "total": 30},
          {"name": "Kütle Çekim ve Kepler Yasaları", "total": 30},
          {"name": "Kuvvet Tork ve Denge", "total": 30},
          {"name": "Manyetik Alan ve Manyetik Kuvvet", "total": 30},
          {"name": "Modern Fiziğin Teknolojideki Uygulamaları", "total": 30},
          {"name": "Newton un Hareket Yasaları", "total": 30},
          {"name": "Özel Görelilik", "total": 30},
          {"name": "Paralel Levhalar ve Sığa", "total": 30},
          {"name": "Vektörler", "total": 30},
        ];
      }
    }
    // ── KİMYA ─────────────────────────────────────────────────────
    if (sub == "Kimya") {
      if (exam == "TYT") {
        return [
          {"name": "Asit Baz Dengesi", "total": 30},
          {"name": "Atomun Yapısı", "total": 30},
          {"name": "Bilimi", "total": 30},
          {"name": "Her Yerde", "total": 30},
          {"name": "Karışımlar", "total": 30},
          {"name": "Kimyanın Temel Kanunları", "total": 30},
          {"name": "Kimyasal Hesaplamalar", "total": 30},
          {"name": "Kimyasal Türler Arası Etkileşim", "total": 30},
          {"name": "Maddenin Halleri", "total": 30},
          {"name": "Periyodik Sistem", "total": 30},
          {"name": "Sıvı Çözeltiler", "total": 30},
        ];
      } else {
        return [
          {"name": "Asit Baz Dengesi", "total": 30},
          {"name": "Atomun Yapısı", "total": 30},
          {"name": "Bilimi", "total": 30},
          {"name": "Çözünürlük Dengesi", "total": 30},
          {"name": "Gazlar", "total": 30},
          {"name": "Kimyasal Hesaplamalar", "total": 30},
          {"name": "Kimyasal Tepkimelerde Denge", "total": 30},
          {"name": "Kimyasal Tepkimelerde Enerji", "total": 30},
          {"name": "Kimyasal Tepkimelerde Hız", "total": 30},
          {"name": "Kimyasal Türler Arası Etkileşim", "total": 30},
          {"name": "Modern Atom Teorisi", "total": 30},
          {"name": "Organik Kimya", "total": 30},
          {"name": "Periyodik Sistem", "total": 30},
          {"name": "Sıvı Çözeltiler", "total": 30},
          {"name": "Ve Elektrik", "total": 30},
        ];
      }
    }
    // ── BİYOLOJİ ──────────────────────────────────────────────────
    if (sub == "Biyoloji") {
      if (exam == "TYT") {
        return [
          {"name": "Bitkiler Biyolojisi", "total": 30},
          {"name": "Canlıların Ortak Özellikleri", "total": 30},
          {"name": "Canlıların Sınıflandırılması", "total": 30},
          {"name": "Canlıların Temel Bileşenleri", "total": 30},
          {"name": "Ekosistem Ekolojisi", "total": 30},
          {"name": "Hücre Bölünmeleri ve Üreme", "total": 30},
          {"name": "Hücre ve Organelleri", "total": 30},
          {"name": "Kalıtım", "total": 30},
          {"name": "Madde Geçişleri", "total": 30},
        ];
      } else {
        return [
          {"name": "Bitki Biyolojisi", "total": 30},
          {"name": "Canlılar ve Çevre", "total": 30},
          {"name": "Canlılık ve Enerji", "total": 30},
          {"name": "Destek ve Hareket Sistemi", "total": 30},
          {"name": "Dolaşım ve Bağışıklık Sistemi", "total": 30},
          {"name": "Duyu Organları", "total": 30},
          {"name": "Endokrin Sistem", "total": 30},
          {"name": "Fotosentez ve Kemosentez", "total": 30},
          {"name": "Genetik Şifre ve Protein Sentezi", "total": 30},
          {"name": "Hücresel Solunum", "total": 30},
          {"name": "Komünite ve Popülasyon Ekolojisi", "total": 30},
          {"name": "Nükleik Asitler", "total": 30},
          {"name": "Sindirim Sistemi", "total": 30},
          {"name": "Sinir Sistemi", "total": 30},
          {"name": "Solunum Sistemi", "total": 30},
          {"name": "Üreme Sistemi ve Embriyonik Gelişim", "total": 30},
          {"name": "Üriner Sistem", "total": 30},
        ];
      }
    }
    // ── FELSEFE ───────────────────────────────────
    if (sub == "Felsefe") {
      return [
        {"name": "20 Yüzyıl Felsefesi", "total": 30},
        {"name": "Ahlak Felsefesi", "total": 30},
        {"name": "Bilgi Felsefesi", "total": 30},
        {"name": "Birey ve Toplum", "total": 30},
        {"name": "Felsefesi", "total": 30},
        {"name": "Klasik Mantık", "total": 30},
        {"name": "Mantığa Giriş", "total": 30},
        {"name": "Mantık ve Dil", "total": 30},
        {"name": "Öğrenme Bellek Düşünme", "total": 30},
        {"name": "Psikolojinin Temel Süreçleri", "total": 30},
        {"name": "Psikoloji Bilimini Tanıyalım", "total": 30},
        {"name": "Ruh Sağlığının Temelleri", "total": 30},
        {"name": "Sosyolojiye Giriş", "total": 30},
        {"name": "Toplumsal Değişme ve Gelişme", "total": 30},
        {"name": "Toplumsal Kurumlar", "total": 30},
        {"name": "Toplumsal Yapı", "total": 30},
        {"name": "Toplum ve Kültür", "total": 30},
        {"name": "Varlık Felsefesi", "total": 30},
        {"name": "Ve Bilim", "total": 30},
      ];
    }
    // ── DİN KÜLTÜRÜ ───────────────────────────────────────────────
    if (sub == "Din Kültürü") {
      return [
        {"name": "Allah İnsan İlişkisi", "total": 30},
        {"name": "Anadoluda İslam", "total": 30},
        {"name": "Dünya ve Ahiret", "total": 30},
        {"name": "Güncel Dini Meseleler", "total": 30},
        {"name": "Hint ve Çin Dinleri", "total": 30},
        {"name": "İnançla İlgili Meseleler", "total": 30},
        {"name": "İslam Düşüncesinde Tasavvufi Yorumlar ve Mezhepler", "total": 30},
        {"name": "İslam ve Bilim", "total": 30},
        {"name": "Kurana Göre Hz Muhammed", "total": 30},
        {"name": "Kurandan Mesajlar", "total": 30},
        {"name": "Kuranda Bazı Kavramlar", "total": 30},
        {"name": "Yahudilik ve Hristiyanlık", "total": 30},
      ];
    }
    // ── VATANDAŞLIK (KPSS) ───────────────────────────────
    if (sub == "Vatandaşlık") {
      return [
        {"name": "Anayasal Kavramlar", "total": 30},
        {"name": "İdare Hukuku", "total": 30},
        {"name": "Temel Hak ve Ödevler", "total": 30},
        {"name": "Temel Hukuk Kavramları", "total": 30},
        {"name": "Türk Anayasa Tarihi", "total": 30},
        {"name": "Yargı", "total": 30},
        {"name": "Yasama", "total": 30},
        {"name": "Yürütme", "total": 30},
      ];
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final topics = _getTopics();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0E43), Color(0xFF1B1F6A), Color(0xFF0A2342)],
              ),
            ),
          ),
          ..._buildStaticStars(size),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.subjectName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            Text("${widget.examName} Yolculuğu", style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.home_rounded, color: Colors.white60, size: 16),
                              const SizedBox(width: 5),
                              Text('Ana Ekran',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white60,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                      : topics.isEmpty
                          ? Center(child: Text("Henüz konu bulunamadı.", style: GoogleFonts.poppins(color: Colors.white54)))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                              itemCount: topics.length,
                              itemBuilder: (context, index) {
                                final item = topics[index];

                                if (item is String) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                                    child: Text(
                                      item.toUpperCase(),
                                      style: GoogleFonts.poppins(color: const Color(0xFF00E5FF), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                    ),
                                  );
                                }

                                final Map<String, dynamic> topic = item;
                                final String topicName = topic['name'];
                                final int currentSection = _topicProgress[topicName] ?? 1;
                                final int totalSections = topic['total'];
                                double progress = (currentSection - 1) / totalSections;
                                if (progress > 1.0) progress = 1.0;

                                final String actualSubject = topic.containsKey('ders') 
                                    ? topic['ders'] 
                                    : widget.subjectName;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 15),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LevelMapPage(
                                            subjectName: actualSubject, 
                                            topicName: topicName,
                                            examName: widget.examName,
                                          ),
                                        ),
                                      ).then((_) => _loadAllProgress());
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(topicName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                              ),
                                              Icon(currentSection > totalSections ? Icons.check_circle_rounded : Icons.chevron_right_rounded, color: currentSection > totalSections ? Colors.greenAccent : Colors.white38),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: LinearProgressIndicator(
                                                    value: progress,
                                                    backgroundColor: Colors.white10,
                                                    valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? Colors.greenAccent : const Color(0xFF00E5FF)),
                                                    minHeight: 8,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text("%${(progress * 100).toInt()} Tamamlandı", style: GoogleFonts.poppins(color: const Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStaticStars(Size size) {
    final rand = Random(42);
    return List.generate(35, (_) => Positioned(
      left: rand.nextDouble() * size.width, top: rand.nextDouble() * size.height, 
      child: Icon(Icons.star, size: rand.nextDouble() * 3 + 2, color: Colors.white.withValues(alpha: rand.nextDouble() * 0.4 + 0.1))
    ));
  }
}