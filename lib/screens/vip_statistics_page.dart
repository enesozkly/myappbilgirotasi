// ignore_for_file: avoid_types_as_parameter_names, unused_element

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VipStatisticsPage extends StatefulWidget {
  const VipStatisticsPage({super.key});

  @override
  State<VipStatisticsPage> createState() => _VipStatisticsPageState();
}

class _VipStatisticsPageState extends State<VipStatisticsPage>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _pulseController;

  bool _isLoadingAi = false;
  bool _hasAiData = false;
  bool _isLoadingData = true;

  // Firestore verileri
  Map<String, dynamic> _userData = {};
  List<Map<String, dynamic>> _konuIstatistik = []; // konu_istatistik koleksiyonu
  List<int> _thirtyDaysData = List.filled(30, 0);

  // Haftalık analiz sonuçları (API kullanmadan hesaplanır)
  String _estimatedScore = '--';
  List<String> _weakTopics = [];
  List<String> _strongTopics = [];
  String _aiAdvice = 'Haftalık analiz için butona dokun.';
  int _weeklyTotalQuestions = 0;
  int _weeklyCorrect = 0;
  int _weeklyWrong = 0;

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  final TextEditingController _pdfTopicController = TextEditingController();
  bool _sendingPdfTopic = false;

  int get _pdfTopicRights {
    if (_userData['isVip'] != true) return 0;
    final value = _userData['vipPdfRights'];
    if (value is num) {
      final rights = value.toInt();
      if (rights < 0) return 0;
      if (rights > 1) return 1;
      return rights;
    }
    return 1;
  }

  bool _sendingPersonalTest = false;

  int get _personalTestRights {
    if (_userData['isVip'] != true) return 0;
    final value = _userData['vipTestRights'];
    if (value is num) {
      final rights = value.toInt();
      if (rights < 0) return 0;
      if (rights > 1) return 1;
      return rights;
    }
    return 1;
  }

  static const List<Map<String, dynamic>> _pdfSets = [
    {'title': 'KPSS Türkçe Soru Bankası 2024', 'pages': '320 sayfa', 'icon': Icons.translate_rounded, 'color': Color(0xFFFF512F)},
    {'title': 'KPSS Matematik Formüller & Kısayollar', 'pages': '180 sayfa', 'icon': Icons.calculate_rounded, 'color': Color(0xFF4CB8C4)},
    {'title': 'KPSS Tarih Özet Notları', 'pages': '240 sayfa', 'icon': Icons.account_balance_rounded, 'color': Color(0xFF834D9B)},
    {'title': 'KPSS Coğrafya Harita Seti', 'pages': '150 sayfa', 'icon': Icons.public_rounded, 'color': Color(0xFF11998E)},
    {'title': 'KPSS Vatandaşlık & Güncel Bilgiler', 'pages': '200 sayfa', 'icon': Icons.gavel_rounded, 'color': Color(0xFF2C3E50)},
  ];

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _loadAllData();
  }

  @override
  void dispose() {
    _pdfTopicController.dispose();
    _bgController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ─── TÜM VERİYİ FIRESTORE'DAN ÇEK ────────────────────────────────────
  Future<void> _loadAllData() async {
    if (_uid == null) return;
    setState(() => _isLoadingData = true);
    try {
      // Ana kullanıcı dokümanı
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(_uid).get();
      if (userDoc.exists) {
        _userData = await _ensureMonthlyVipRights(userDoc.data()!);
      }

      // Konu istatistikleri (quiz bitince kaydediliyor)
      final konuSnap = await FirebaseFirestore.instance
          .collection('users').doc(_uid)
          .collection('konu_istatistik').get();
      _konuIstatistik = konuSnap.docs.map((d) => d.data()).toList();

      // Son 30 günlük aktivite
      await _load30DaysData();
    } catch (e) {
      debugPrint('VIP veri yükleme hatası: $e');
    }
    if (mounted) setState(() => _isLoadingData = false);
  }


  String _currentVipRightsMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>> _ensureMonthlyVipRights(Map<String, dynamic> data) async {
    if (_uid == null || data['isVip'] != true) return data;
    final monthKey = _currentVipRightsMonth();
    final needsReset = data['vipRightsMonth'] != monthKey ||
        !data.containsKey('vipWeakTopicRights') ||
        !data.containsKey('vipPdfRights') ||
        !data.containsKey('vipTestRights');
    if (!needsReset) return data;

    final updates = <String, dynamic>{
      'vipWeakTopicRights': 4,
      'vipPdfRights': 1,
      'vipTestRights': 1,
      'vipRightsMonth': monthKey,
    };
    await FirebaseFirestore.instance.collection('users').doc(_uid).set(updates, SetOptions(merge: true));
    return {...data, ...updates};
  }

  Future<bool> _consumeWeakTopicRight() async {
    if (_uid == null) return false;
    final ref = FirebaseFirestore.instance.collection('users').doc(_uid);
    final monthKey = _currentVipRightsMonth();
    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || data['isVip'] != true) return false;

      var weakRights = ((data['vipWeakTopicRights'] ?? 4) as num).toInt();
      final updates = <String, dynamic>{};
      if (data['vipRightsMonth'] != monthKey) {
        weakRights = 4;
        updates.addAll({
          'vipWeakTopicRights': 4,
          'vipPdfRights': 1,
          'vipTestRights': 1,
          'vipRightsMonth': monthKey,
        });
      }
      if (weakRights <= 0) {
        if (updates.isNotEmpty) tx.set(ref, updates, SetOptions(merge: true));
        return false;
      }
      updates['vipWeakTopicRights'] = weakRights - 1;
      tx.set(ref, updates, SetOptions(merge: true));
      return true;
    });
  }

  Future<bool> _consumePdfTopicRight() async {
    if (_uid == null) return false;
    final ref = FirebaseFirestore.instance.collection('users').doc(_uid);
    final monthKey = _currentVipRightsMonth();

    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();

      if (data == null || data['isVip'] != true) return false;

      var rights = ((data['vipPdfRights'] ?? 1) as num).toInt();
      final updates = <String, dynamic>{};

      if (data['vipRightsMonth'] != monthKey) {
        updates.addAll({
          'vipWeakTopicRights': 4,
          'vipPdfRights': 1,
          'vipTestRights': 1,
          'vipRightsMonth': monthKey,
        });
        rights = 1;
      }

      if (rights <= 0) {
        if (updates.isNotEmpty) {
          tx.set(ref, updates, SetOptions(merge: true));
        }
        return false;
      }

      updates['vipPdfRights'] = rights - 1;
      tx.set(ref, updates, SetOptions(merge: true));
      return true;
    });
  }

  Future<void> _submitPdfTopicRequest() async {
    if (_uid == null || _sendingPdfTopic) return;

    final topic = _pdfTopicController.text.trim();

    if (topic.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lütfen istediğiniz PDF adını veya konusunu yazın.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _sendingPdfTopic = true);

    try {
      final consumed = await _consumePdfTopicRight();

      if (!consumed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bu ayki konu anlatım PDF hakkınız tükenmiş.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      final userData = userDoc.data() ?? {};
      final userName = (userData['name'] ??
              FirebaseAuth.instance.currentUser?.displayName ??
              'İsimsiz')
          .toString();
      final userEmail = (userData['email'] ??
              FirebaseAuth.instance.currentUser?.email ??
              '')
          .toString();

      await FirebaseFirestore.instance.collection('vip_pdf_requests').add({
        'uid': _uid,
        'name': userName,
        'email': userEmail,
        'pdfTitle': topic,
        'topic': topic,
        'status': 'pending',
        'source': 'vip_statistics_page',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _pdfTopicController.clear();
      await _loadAllData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF talebiniz admin paneline düştü!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF00C853),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF talebi gönderilemedi: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingPdfTopic = false);
    }
  }

  Future<bool> _consumePersonalTestRight() async {
    if (_uid == null) return false;
    final ref = FirebaseFirestore.instance.collection('users').doc(_uid);
    final monthKey = _currentVipRightsMonth();

    return FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();

      if (data == null || data['isVip'] != true) return false;

      var rights = ((data['vipTestRights'] ?? 1) as num).toInt();
      final updates = <String, dynamic>{};

      if (data['vipRightsMonth'] != monthKey) {
        updates.addAll({
          'vipWeakTopicRights': 4,
          'vipPdfRights': 1,
          'vipTestRights': 1,
          'vipRightsMonth': monthKey,
        });
        rights = 1;
      }

      if (rights <= 0) {
        if (updates.isNotEmpty) {
          tx.set(ref, updates, SetOptions(merge: true));
        }
        return false;
      }

      updates['vipTestRights'] = rights - 1;
      tx.set(ref, updates, SetOptions(merge: true));
      return true;
    });
  }

  List<String> _personalTestWeakTopics() {
    final Set<String> topics = {};

    if (_weakTopics.isNotEmpty && !_weakTopics.contains('Veri yetersiz')) {
      for (final item in _weakTopics) {
        final cleaned = item.split('(').first.trim();
        if (cleaned.isNotEmpty && cleaned != 'Belirgin zayıf konu yok') {
          topics.add(cleaned);
        }
      }
    }

    for (final data in _topWrongTopics) {
      final topic = _topicNameFrom(data);
      if (topic.isNotEmpty && topic != 'Genel') {
        topics.add(topic);
      }
    }

    if (topics.isEmpty) {
      topics.add('Genel tekrar testi');
    }

    return topics.take(5).toList();
  }

  List<String> _personalTestWrongSummary() {
    final List<String> summary = [];

    for (final data in _topWrongTopics) {
      final topic = _topicNameFrom(data);
      final wrong = ((data['yanlis'] ?? data['yanlış'] ?? data['wrong'] ?? 0) as num).toInt();
      final correct = ((data['dogru'] ?? data['correct'] ?? 0) as num).toInt();
      if (wrong > 0) {
        summary.add('$topic: $wrong yanlış, $correct doğru');
      }
    }

    if (summary.isEmpty && _weeklyTotalQuestions > 0) {
      summary.add('Son 7 gün: $_weeklyTotalQuestions soru, $_weeklyWrong yanlış, $_weeklyCorrect doğru');
    }

    if (summary.isEmpty) {
      summary.add('Yeterli yanlış verisi bulunamadı. Genel tekrar testi hazırlanabilir.');
    }

    return summary.take(5).toList();
  }

  Future<void> _submitPersonalTestRequest() async {
    if (_uid == null || _sendingPersonalTest) return;

    setState(() => _sendingPersonalTest = true);

    try {
      final consumed = await _consumePersonalTestRight();

      if (!consumed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bu ayki kişisel test hakkınız tükenmiş.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final weakTopics = _personalTestWeakTopics();
      final wrongSummary = _personalTestWrongSummary();
      final primaryTopic = weakTopics.first;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      final userData = userDoc.data() ?? {};
      final userName = (userData['name'] ??
              FirebaseAuth.instance.currentUser?.displayName ??
              'İsimsiz')
          .toString();
      final userEmail = (userData['email'] ??
              FirebaseAuth.instance.currentUser?.email ??
              '')
          .toString();

      await FirebaseFirestore.instance.collection('vip_personal_test_requests').add({
        'uid': _uid,
        'name': userName,
        'email': userEmail,
        'topic': primaryTopic,
        'requestedTopics': weakTopics,
        'wrongSummary': wrongSummary,
        'strongTopics': _strongTopics,
        'weakTopics': _weakTopics,
        'weeklyTotalQuestions': _weeklyTotalQuestions,
        'weeklyCorrect': _weeklyCorrect,
        'weeklyWrong': _weeklyWrong,
        'note': 'Kullanıcının yanlış yaptığı konulara göre kişisel test hazırlanıp e-posta ile gönderilsin.',
        'mailInstruction': userEmail.isEmpty
            ? 'Kullanıcının e-posta bilgisi bulunamadı. Profil kaydını kontrol edin.'
            : 'Hazırlanan kişisel testi $userEmail adresine gönderin.',
        'source': 'vip_statistics_page',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _loadAllData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kişisel test talebiniz admin paneline iletildi!',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF00C853),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kişisel test talebi gönderilemedi: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingPersonalTest = false);
    }
  }

  Future<void> _load30DaysData() async {
    if (_uid == null) return;
    final now = DateTime.now();
    final List<int> data = List.filled(30, 0);
    try {
      // progress koleksiyonu — bölüm tamamlama tarihleri
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(_uid)
          .collection('progress').get();
      for (final doc in snap.docs) {
        final ts = doc.data()['lastUpdated'];
        if (ts == null) continue;
        final date = (ts as Timestamp).toDate();
        final diff = now.difference(date).inDays;
        if (diff >= 0 && diff < 30) data[29 - diff] = (data[29 - diff] + 1).clamp(0, 20).toInt();
      }
      // konu_istatistik son güncelleme tarihleri de grafiğe ekle
      for (final k in _konuIstatistik) {
        final ts = k['sonGuncelleme'];
        if (ts == null) continue;
        final date = (ts as Timestamp).toDate();
        final diff = now.difference(date).inDays;
        if (diff >= 0 && diff < 30) data[29 - diff] = (data[29 - diff] + 1).clamp(0, 20).toInt();
      }
    } catch (e) {
      debugPrint('30 gün veri hatası: $e');
    }
    _thirtyDaysData = data;
  }

  // ─── EN ÇOK YANLIŞ YAPILAN KONULAR ────────────────────────────────────
  // konu_istatistik koleksiyonundaki yanlis sayısına göre sırala
  List<Map<String, dynamic>> get _topWrongTopics {
    final sorted = List<Map<String, dynamic>>.from(_konuIstatistik)
      ..sort((a, b) => ((b['yanlis'] ?? 0) as num).compareTo((a['yanlis'] ?? 0) as num));
    return sorted.where((k) => (k['yanlis'] ?? 0) > 0).take(5).toList();
  }

  int get _weakTopicRights {
    if (_userData['isVip'] != true) return 0;
    final value = _userData['vipWeakTopicRights'];
    if (value is num) {
      final rights = value.toInt();
      if (rights < 0) return 0;
      if (rights > 4) return 4;
      return rights;
    }
    return 4;
  }

  String _topicNameFrom(Map<String, dynamic> data) {
    final raw = data['topic'] ?? data['konu'] ?? data['topicName'] ?? data['ders'] ?? 'Genel';
    final value = raw.toString().trim();
    return value.isEmpty ? 'Genel' : value;
  }

  DateTime? _dateFrom(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  bool? _correctFrom(Map<String, dynamic> data) {
    final candidates = [
      data['isCorrect'],
      data['correct'],
      data['dogruMu'],
      data['is_correct'],
    ];
    for (final c in candidates) {
      if (c is bool) return c;
      if (c is num) return c.toInt() == 1;
      if (c is String) {
        final s = c.toLowerCase().trim();
        if (['true', 'dogru', 'doğru', 'correct', '1'].contains(s)) return true;
        if (['false', 'yanlis', 'yanlış', 'wrong', '0'].contains(s)) return false;
      }
    }
    final status = (data['status'] ?? data['answerStatus'] ?? '').toString().toLowerCase();
    if (['correct', 'dogru', 'doğru'].contains(status)) return true;
    if (['wrong', 'yanlis', 'yanlış'].contains(status)) return false;
    return null;
  }

  Future<Map<String, _WeeklyTopicStat>> _collectQuestionHistoryStats(DateTime start) async {
    final Map<String, _WeeklyTopicStat> stats = {};
    if (_uid == null) return stats;

    final collectionNames = ['question_history', 'solved_questions', 'quiz_history'];
    final timeFields = ['timestamp', 'createdAt', 'completedAt', 'date'];
    final seen = <String>{};

    for (final col in collectionNames) {
      for (final timeField in timeFields) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .doc(_uid)
              .collection(col)
              .where(timeField, isGreaterThanOrEqualTo: Timestamp.fromDate(start))
              .get();
          for (final doc in snap.docs) {
            final key = '$col/${doc.id}';
            if (seen.contains(key)) continue;
            seen.add(key);
            final data = doc.data();
            final correct = _correctFrom(data);
            if (correct == null) continue;
            final topic = _topicNameFrom(data);
            stats.putIfAbsent(topic, () => _WeeklyTopicStat(topic));
            if (correct) {
              stats[topic]!.correct++;
            } else {
              stats[topic]!.wrong++;
            }
          }
        } catch (e) {
          debugPrint('Haftalık analiz $col/$timeField okunamadı: $e');
        }
      }
    }
    return stats;
  }

  Map<String, _WeeklyTopicStat> _collectKonuIstatistikFallback(DateTime start) {
    final Map<String, _WeeklyTopicStat> stats = {};
    for (final data in _konuIstatistik) {
      final updatedAt = _dateFrom(data['sonGuncelleme'] ?? data['lastUpdated'] ?? data['updatedAt']);
      // Kayıtta tarih yoksa tamamen dışlamıyoruz; eski projelerde tarih alanı olmayabilir.
      if (updatedAt != null && updatedAt.isBefore(start)) continue;
      final topic = _topicNameFrom(data);
      final correct = ((data['dogru'] ?? data['correct'] ?? 0) as num).toInt();
      final wrong = ((data['yanlis'] ?? data['yanlış'] ?? data['wrong'] ?? 0) as num).toInt();
      if (correct + wrong <= 0) continue;
      stats.putIfAbsent(topic, () => _WeeklyTopicStat(topic));
      stats[topic]!.correct += correct;
      stats[topic]!.wrong += wrong;
    }
    return stats;
  }

  List<_WeeklyTopicStat> _sortedTopicStats(Map<String, _WeeklyTopicStat> source) {
    final list = source.values.where((s) => s.total > 0).toList();
    list.sort((a, b) {
      final byTotal = b.total.compareTo(a.total);
      if (byTotal != 0) return byTotal;
      return b.wrong.compareTo(a.wrong);
    });
    return list;
  }

  List<String> _bestTopicsFrom(List<_WeeklyTopicStat> stats) {
    final list = stats.where((s) => s.total >= 3).toList()
      ..sort((a, b) {
        final byRate = b.successRate.compareTo(a.successRate);
        if (byRate != 0) return byRate;
        return b.total.compareTo(a.total);
      });
    return list.take(3).map((s) => '${s.topic} (${(s.successRate * 100).round()}%)').toList();
  }

  List<String> _weakTopicsFrom(List<_WeeklyTopicStat> stats) {
    final list = stats.where((s) => s.wrong > 0).toList()
      ..sort((a, b) {
        final byRate = a.successRate.compareTo(b.successRate);
        if (byRate != 0) return byRate;
        return b.wrong.compareTo(a.wrong);
      });
    return list.take(3).map((s) => '${s.topic} (${s.wrong} yanlış)').toList();
  }

  String _buildWeeklyAdvice({
    required int total,
    required int correct,
    required int wrong,
    required List<String> weakTopics,
    required List<String> strongTopics,
  }) {
    if (total == 0) {
      return 'Son 7 gün için yeterli çözüm verisi bulunamadı. Birkaç bölüm veya deneme çözdükten sonra analizi tekrar oluştur.';
    }
    final rate = total == 0 ? 0 : (correct / total * 100).round();
    final weakest = weakTopics.isNotEmpty ? weakTopics.first.split('(').first.trim() : 'belirgin bir zayıf konu';
    final strongest = strongTopics.isNotEmpty ? strongTopics.first.split('(').first.trim() : 'güçlü konuların';
    if (rate >= 75) {
      return 'Bu hafta $total soru çözdün ve başarı oranın %$rate. $strongest tarafında iyi ilerliyorsun. $weakest konusunu kısa tekrar + 20 soruluk mini test ile desteklersen performansın daha dengeli olur.';
    }
    if (rate >= 50) {
      return 'Bu hafta $total soru çözdün; $correct doğru, $wrong yanlışın var. Genel seviyen orta. Önceliği $weakest konusuna verip ardından karışık tekrar çözmeni öneririz.';
    }
    return 'Bu hafta $total soru çözdün ve hata oranın yüksek görünüyor. Önce $weakest konusunu konu anlatımıyla tekrar et, sonra düşük tempolu 10-15 soruluk testlerle pekiştir.';
  }

  Future<void> _saveWeeklyAnalysisRequest({
    required DateTime start,
    required DateTime end,
    required int total,
    required int correct,
    required int wrong,
    required List<String> strongTopics,
    required List<String> weakTopics,
    required String advice,
  }) async {
    if (_uid == null) return;
    final weakestTopic = weakTopics.isNotEmpty ? weakTopics.first.split('(').first.trim() : 'Veri yetersiz';
    await FirebaseFirestore.instance.collection('vip_analysis_requests').add({
      'uid': _uid,
      'name': _userData['name'] ?? _userData['displayName'] ?? 'İsimsiz',
      'email': FirebaseAuth.instance.currentUser?.email ?? _userData['email'] ?? '',
      'analysisType': 'weekly_api_free',
      'periodStart': Timestamp.fromDate(start),
      'periodEnd': Timestamp.fromDate(end),
      'totalQuestions': total,
      'correct': correct,
      'wrong': wrong,
      'strongTopics': strongTopics,
      'weakTopics': weakTopics,
      'weakestTopic': weakestTopic,
      'advice': advice,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

  }

  // ─── API OLMADAN HAFTALIK VIP ANALİZİ ────────────────────────────────
  Future<void> _createWeeklyAnalysis() async {
    if (_weakTopicRights <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bu ayki haftalık analiz hakkınız tükenmiş.',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isLoadingAi = true);
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 7));
      
      var statMap = await _collectQuestionHistoryStats(start);
      if (statMap.isEmpty) {
        statMap = _collectKonuIstatistikFallback(start);
      }
      final stats = _sortedTopicStats(statMap);
      final total = stats.fold<int>(0, (sum, s) => sum + s.total);
      final correct = stats.fold<int>(0, (sum, s) => sum + s.correct);
      final wrong = stats.fold<int>(0, (sum, s) => sum + s.wrong);

      final strong = total == 0 ? <String>[] : _bestTopicsFrom(stats);
      final weak = total == 0 ? <String>['Veri yetersiz'] : _weakTopicsFrom(stats);
      final advice = _buildWeeklyAdvice(
        total: total,
        correct: correct,
        wrong: wrong,
        weakTopics: weak,
        strongTopics: strong,
      );
      final successRate = total == 0 ? 0 : (correct / total * 100).round();

      final consumed = await _consumeWeakTopicRight();
      if (!consumed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Bu ayki zayıf konu analizi hakkınız tükenmiş.',
                style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }
      _userData['vipWeakTopicRights'] = _weakTopicRights > 0 ? _weakTopicRights - 1 : 0;

      // Admin paneline talebi gönderiyoruz
      await _saveWeeklyAnalysisRequest(
        start: start,
        end: end,
        total: total,
        correct: correct,
        wrong: wrong,
        strongTopics: strong,
        weakTopics: weak,
        advice: advice,
      );

      if (mounted) {
        setState(() {
          _weeklyTotalQuestions = total;
          _weeklyCorrect = correct;
          _weeklyWrong = wrong;
          _estimatedScore = '%$successRate';
          _strongTopics = strong.isEmpty ? ['Henüz güçlü konu ayrışmadı'] : strong;
          _weakTopics = weak.isEmpty ? ['Belirgin zayıf konu yok'] : weak;
          _aiAdvice = "Talep admin paneline iletildi!\nSenin için hazırlanan geçici ön izleme:\n\n" + advice;
          _hasAiData = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Haftalık analiz talebiniz başarıyla admin paneline iletildi.',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: const Color(0xFF00C853),
        ));
      }
    } catch (e) {
      debugPrint('Haftalık analiz hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Talep gönderilemedi. Lütfen tekrar dene.',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E43),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              ),
            ),
          ),
          ..._buildStaticStars(size),
          _buildMovingCloud(top: size.height * 0.1, scale: 1.2, speed: 0.6, moveRight: true),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _isLoadingData
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFFFFD700)))
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildQuickStats(),
                              const SizedBox(height: 24),
                              _buildPdfTopicRequestCard(),
                              const SizedBox(height: 24),
                              _buildPersonalTestRequestCard(),
                              const SizedBox(height: 24),
                              _build30DaysChart(),
                              const SizedBox(height: 24),
                              _buildTopWrongWidget(),
                              const SizedBox(height: 24),
                              _buildAiSection(),
                              const SizedBox(height: 24),
                              const SizedBox(height: 30),
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

  // ─── APPBAR ────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text('VIP Analiz Merkezi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    color: const Color(0xFFFFD700), fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _loadAllData,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HIZLI İSTATİSTİKLER ───────────────────────────────────────────────
  Widget _buildQuickStats() {
    final totalCorrect = (_userData['totalCorrect'] ?? 0).toInt();
    final totalSections = (_userData['totalSections'] ?? 0).toInt();
    final weeklyXp = (_userData['weeklyXp'] ?? 0).toInt();
    final loginStreak = (_userData['loginStreak'] ?? 0).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('📊 Genel Durumun', const Color(0xFF00E5FF)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _statBox('Toplam Doğru', '$totalCorrect', Icons.check_circle_rounded, const Color(0xFF00E676))),
          const SizedBox(width: 10),
          Expanded(child: _statBox('Bölümler', '$totalSections', Icons.layers_rounded, const Color(0xFF00E5FF))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _statBox('Haftalık XP', '$weeklyXp', Icons.bolt_rounded, const Color(0xFFFFD700))),
          const SizedBox(width: 10),
          Expanded(child: _statBox('Gün Serisi', '$loginStreak 🔥', Icons.local_fire_department_rounded, Colors.orangeAccent)),
        ]),
      ],
    );
  }

  Widget _statBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
          ],
        )),
      ]),
    );
  }

  Widget _buildPdfTopicRequestCard() {
    final rights = _pdfTopicRights;
    final canSend = rights > 0 && !_sendingPdfTopic;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.08),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFFFD700),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Konu Anlatım PDF Talebi',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFFD700),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aylık kalan hak: $rights',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'İstediğin PDF konusunu yaz. Talebin admin panelindeki VIP İçerik > PDF Talepleri kısmına düşer.',
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pdfTopicController,
            enabled: canSend,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
            minLines: 1,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Örn: Paragrafta Anlam, Türev, KPSS Tarih...',
              hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFFFD700)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: const Color(0xFF0A0E43),
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white54,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: canSend ? _submitPdfTopicRequest : null,
              icon: _sendingPdfTopic
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0A0E43),
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _sendingPdfTopic
                    ? 'Gönderiliyor...'
                    : rights <= 0
                        ? 'Bu Ayki PDF Hakkı Kullanıldı'
                        : 'PDF Talebi Gönder',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalTestRequestCard() {
    final rights = _personalTestRights;
    final canSend = rights > 0 && !_sendingPersonalTest;
    final weakPreview = _personalTestWeakTopics();
    final wrongPreview = _personalTestWrongSummary();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF8A52FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8A52FF).withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A52FF).withValues(alpha: 0.08),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8A52FF).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.fact_check_rounded,
                  color: Color(0xFFB388FF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yanlışlarıma Göre Test İste',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFB388FF),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aylık kalan hak: $rights',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Yanlış yaptığın konular admin paneline düşer. Admin, bu konulara göre kişisel test hazırlayıp e-posta ile gönderebilir.',
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          if (weakPreview.isNotEmpty) ...[
            Text(
              'Test istenecek konu önceliği:',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: weakPreview
                  .map((topic) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8A52FF).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF8A52FF).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          topic,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFB388FF),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
          ],
          if (wrongPreview.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin notu',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...wrongPreview.take(3).map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $item',
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 10,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8A52FF),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white54,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: canSend ? _submitPersonalTestRequest : null,
              icon: _sendingPersonalTest
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.mark_email_read_rounded),
              label: Text(
                _sendingPersonalTest
                    ? 'Talep gönderiliyor...'
                    : rights <= 0
                        ? 'Bu Ayki Kişisel Test Hakkı Kullanıldı'
                        : 'Kişisel Test Talebi Gönder',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 30 GÜN GRAFİĞİ (GERÇEK VERİ) ────────────────────────────────────
  Widget _build30DaysChart() {
    final maxVal = _thirtyDaysData.reduce(max).clamp(1, 999);
    final now = DateTime.now();
    final bool hasData = _thirtyDaysData.any((v) => v > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('📈 Son 30 Günlük Gelişim', const Color(0xFF00E5FF)),
        const SizedBox(height: 12),
        Container(
          height: 185,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(children: [
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: 30,
                itemBuilder: (context, index) {
                  final value = _thirtyDaysData[index];
                  final heightRatio = value / maxVal;
                  final isToday = index == 29;
                  final dayDate = now.subtract(Duration(days: 29 - index));
                  return Tooltip(
                    message: '${dayDate.day}/${dayDate.month}: $value aktivite',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: Duration(milliseconds: 300 + index * 15),
                            curve: Curves.easeOut,
                            width: 12,
                            height: value > 0 ? (115 * heightRatio).clamp(8.0, 115.0) : 4.0,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isToday
                                    ? [const Color(0xFFFFD700), const Color(0xFFFF8C00)]
                                    : value > 0
                                        ? [const Color(0xFF00E5FF), const Color(0xFF007BFF)]
                                        : [Colors.white10, Colors.white10],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: isToday && value > 0
                                  ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.6), blurRadius: 10)]
                                  : [],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('30 gün önce', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
              Row(children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFD700), shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('Bugün', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
              ]),
            ]),
          ]),
        ),
        if (!hasData)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Soru çözdükçe grafik burada beliriecek!',
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
          ),
      ],
    );
  }

  // ─── EN ÇOK YANLIŞ YAPILAN KONULAR ────────────────────────────────────
  Widget _buildTopWrongWidget() {
    final topics = _topWrongTopics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('🎯 En Çok Yanlış Yapılan Konular', Colors.redAccent),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
          ),
          child: topics.isEmpty
              ? Row(children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00E676)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'Henüz yanlış soru verisi yok.\nSoru çözdükçe zayıf konuların burada belirir.',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                  )),
                ])
              : Column(
                  children: topics.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final k = entry.value;
                    final yanlis = (k['yanlis'] ?? 0) as num;
                    final dogru = (k['dogru'] ?? 0) as num;
                    final maxYanlis = (topics.first['yanlis'] ?? 1) as num;
                    final progress = yanlis / maxYanlis;
                    final konuAdi = k['konu']?.toString() ?? k['ders']?.toString() ?? '?';
                    final dersAdi = k['ders']?.toString() ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(children: [
                        Row(children: [
                          Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: idx == 0
                                  ? Colors.redAccent.withValues(alpha: 0.3)
                                  : Colors.orangeAccent.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text('${idx + 1}',
                                style: GoogleFonts.poppins(
                                    color: idx == 0 ? Colors.redAccent : Colors.orangeAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(konuAdi, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              if (dersAdi.isNotEmpty)
                                Text(dersAdi, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
                            ],
                          )),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('$yanlis yanlış',
                                  style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            Text('$dogru doğru',
                                style: GoogleFonts.poppins(color: const Color(0xFF00E676), fontSize: 10)),
                          ]),
                        ]),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.toDouble(),
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation(
                                idx == 0 ? Colors.redAccent : Colors.orangeAccent),
                            minHeight: 5,
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  // ─── API OLMADAN HAFTALIK ANALİZ BÖLÜMÜ ─────────────────────────────
  Widget _buildAiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('📅 Haftalık VIP Analiz', const Color(0xFFD500F9)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            const Icon(Icons.confirmation_num_rounded, color: Color(0xFFFFD700), size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('Aylık zayıf konu analizi hakkı: $_weakTopicRights / 4',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 12),
        // Analiz butonu
        GestureDetector(
          onTap: _isLoadingAi ? null : _createWeeklyAnalysis,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _isLoadingAi
                  ? [const Color(0xFF7B2FF7).withValues(alpha: 0.6), const Color(0xFFD500F9).withValues(alpha: 0.6)]
                  : [const Color(0xFFD500F9), const Color(0xFF7B2FF7)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(
                  color: const Color(0xFFD500F9).withValues(alpha: 0.35),
                  blurRadius: 15,
                  offset: const Offset(0, 5))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_isLoadingAi) ...[
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                const SizedBox(width: 12),
                Text('Haftalık analiz oluşturuluyor...', style: GoogleFonts.poppins(color: Colors.white, fontSize: 15)),
              ] else ...[
                const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(_hasAiData ? '🔄 Haftalık Analizi Güncelle' : '✨ Haftalık Analiz Oluştur',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ]
            ]),
          ),
        ),

        if (_hasAiData) ...[
          const SizedBox(height: 16),
          // Haftalık Özet
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFFFFD700).withValues(alpha: 0.15),
                const Color(0xFFFF8C00).withValues(alpha: 0.06),
              ]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.insights_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Son 7 Gün Başarı Oranı',
                    style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                Text(_estimatedScore,
                    style: GoogleFonts.poppins(
                        color: const Color(0xFFFFD700), fontSize: 28, fontWeight: FontWeight.w900)),
                Text('$_weeklyTotalQuestions soru • $_weeklyCorrect doğru • $_weeklyWrong yanlış',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
              ])),
            ]),
          ),
          const SizedBox(height: 12),
          // Güçlü Konular
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 20),
                const SizedBox(width: 8),
                Text('En İyi Olduğun Konular',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _strongTopics.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                  ),
                  child: Text(t, style: GoogleFonts.poppins(
                      color: const Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.w600)),
                )).toList(),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          // Zayıf Konular
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Text('En Zayıf Olduğun Konular',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _weakTopics.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Text(t, style: GoogleFonts.poppins(
                      color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                )).toList(),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          // Koç Tavsiyesi
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.psychology_rounded, color: Color(0xFF00E5FF), size: 22),
                const SizedBox(width: 8),
                Text('Haftalık Koç Tavsiyesi',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              Text(_aiAdvice,
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, height: 1.6)),
            ]),
          ),
        ],
      ],
    );
  }

  // ─── KPSS PDF SETİ (SADECE VIP) ───────────────────────────────────────
  Widget _buildPdfSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('📚 KPSS PDF Seti', const Color(0xFFFFD700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.lock_open_rounded, color: Color(0xFFFFD700), size: 16),
            const SizedBox(width: 8),
            Text('PDF indirme bölümü VIP ayrıcalıklarından çıkarıldı.',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),
        ..._pdfSets.map((pdf) => _buildPdfCard(pdf)),
      ],
    );
  }

  Widget _buildPdfCard(Map<String, dynamic> pdf) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.download_done_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('${pdf['title']} — indirme başlatıldı!',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12))),
          ]),
          backgroundColor: const Color(0xFF00C853),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (pdf['color'] as Color).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(pdf['icon'] as IconData, color: pdf['color'] as Color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pdf['title'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(pdf['pages'], style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.download_rounded, color: Color(0xFF00E5FF), size: 18),
          ),
        ]),
      ),
    );
  }

  // ─── YARDIMCI ──────────────────────────────────────────────────────────
  Widget _sectionTitle(String title, Color color) {
    return Row(children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Flexible(child: Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
    ]);
  }

  List<Widget> _buildStaticStars(Size size) {
    final rand = Random(42);
    return List.generate(30, (_) => Positioned(
      left: rand.nextDouble() * size.width,
      top: rand.nextDouble() * size.height,
      child: Icon(Icons.star, size: rand.nextDouble() * 4 + 2, color: Colors.white.withValues(alpha: 0.2)),
    ));
  }

  Widget _buildMovingCloud({required double top, required double scale, required double speed, required bool moveRight}) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final sw = MediaQuery.of(context).size.width;
        final cw = 150.0 * scale;
        double offset = (_bgController.value * speed * (sw + cw)) % (sw + cw);
        if (!moveRight) offset = sw - offset;
        return Positioned(
          top: top, left: offset - cw,
          child: Transform.scale(scale: scale,
              child: Icon(Icons.cloud_rounded, color: Colors.white.withValues(alpha: 0.05), size: 100)),
        );
      },
    );
  }
}

class _WeeklyTopicStat {
  final String topic;
  int correct = 0;
  int wrong = 0;

  _WeeklyTopicStat(this.topic);

  int get total => correct + wrong;
  double get successRate => total == 0 ? 0.0 : correct / total;
}
