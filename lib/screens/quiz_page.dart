import 'dart:math';
import 'dart:convert';

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:excel/excel.dart' as excel_lib;
import '../services/user_service.dart';
import '../services/reklam_servisi.dart';
import '../widgets/br_dialogs.dart';

class QuizPage extends StatefulWidget {
  final String subjectName;
  final String topicName;
  final int sectionNumber;
  final String examName;
  final Map<String, dynamic>? singleQuestion;

  const QuizPage({
    super.key,
    required this.subjectName,
    required this.topicName,
    required this.sectionNumber,
    required this.examName,
    this.singleQuestion,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final UserService _userService = UserService();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _isVip = false;

  List<Map<String, dynamic>> questions = [];
  int currentQuestionIndex = 0;
  int? selectedOptionIndex;
  bool isAnswered = false;
  bool isLoading = true;
  int correctAnswersCount = 0;
  int _totalSections = 5;

  final List<String> optionLetters = ['A', 'B', 'C', 'D', 'E'];


  @override
  void initState() {
    super.initState();
    _fetchQuestionsFromAssets();
    _loadVipStatus();
  }

  // 🔥 YENİ EKLENEN: SESSİZ ANALİZ TAKİP SİSTEMİ (Mevcut sistemi bozmaz)
  Future<void> _logAnalytics(String eventName) async {
    if (_uid == null || widget.singleQuestion != null)
      return; // Yanlış sorusu çözerken loglama yapmayız
    try {
      await FirebaseFirestore.instance.collection('analytics_logs').add({
        'uid': _uid,
        'event':
            eventName, // 'quiz_started', 'quiz_exited_early', 'quiz_completed'
        'subject': widget.subjectName,
        'topic': widget.topicName,
        'section': widget.sectionNumber,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Analytics log hatası (Önemsiz): $e');
    }
  }

  Future<void> _loadVipStatus() async {
    if (_uid == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists && mounted) {
        setState(() => _isVip = doc.data()?['isVip'] == true);
      }
    } catch (_) {}
  }
  List<dynamic> _extractQuestionList(dynamic decoded) {
  if (decoded is List) {
    return decoded;
  }

  if (decoded is Map) {
    final dynamic questionsValue = decoded['questions'];
    final dynamic sorularValue = decoded['sorular'];
    final dynamic dataValue = decoded['data'];
    final dynamic itemsValue = decoded['items'];

    if (questionsValue is List) return questionsValue;
    if (sorularValue is List) return sorularValue;
    if (dataValue is List) return dataValue;
    if (itemsValue is List) return itemsValue;
  }

  return [];
}

List<String> _extractOptions(Map<String, dynamic> item) {
  final dynamic rawOptions =
      item['siklar'] ?? item['secenekler'] ?? item['options'];

  if (rawOptions is List) {
    return rawOptions
        .map((option) => option.toString().trim())
        .where((option) => option.isNotEmpty)
        .toList();
  }

  if (rawOptions is Map) {
    const orderedKeys = ['A', 'B', 'C', 'D', 'E'];
    final List<String> orderedOptions = [];

    for (final key in orderedKeys) {
      final dynamic value = rawOptions[key] ?? rawOptions[key.toLowerCase()];

      if (value != null && value.toString().trim().isNotEmpty) {
        orderedOptions.add(value.toString().trim());
      }
    }

    if (orderedOptions.isNotEmpty) {
      return orderedOptions;
    }

    return rawOptions.values
        .map((option) => option.toString().trim())
        .where((option) => option.isNotEmpty)
        .toList();
  }

  return [];
}

int _extractCorrectIndex(
  Map<String, dynamic> item,
  List<String> options,
) {
  if (options.isEmpty) return 0;

  final dynamic rawAnswer = item['dogru_cevap'] ??
      item['cevap'] ??
      item['correctAnswer'] ??
      item['answer'];

  if (rawAnswer is int) {
    return rawAnswer.clamp(0, options.length - 1);
  }

  if (rawAnswer is num) {
    return rawAnswer.toInt().clamp(0, options.length - 1);
  }

  final String answer = rawAnswer?.toString().trim() ?? '';

  if (answer.isEmpty) return 0;

  final String upperAnswer = answer.toUpperCase();

  const letters = ['A', 'B', 'C', 'D', 'E'];

  if (letters.contains(upperAnswer)) {
    return letters.indexOf(upperAnswer).clamp(0, options.length - 1);
  }

  final int? parsedNumber = int.tryParse(answer);

  if (parsedNumber != null) {
    if (parsedNumber >= 0 && parsedNumber < options.length) {
      return parsedNumber;
    }

    if (parsedNumber >= 1 && parsedNumber <= options.length) {
      return parsedNumber - 1;
    }
  }

  final int textIndex = options.indexWhere(
    (option) => option.trim().toLowerCase() == answer.toLowerCase(),
  );

  if (textIndex != -1) {
    return textIndex;
  }

  return 0;
}

Map<String, dynamic>? _normalizeQuestionItem(dynamic rawItem) {
  if (rawItem is! Map) return null;

  final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);

  final String questionText = (item['soru'] ??
          item['soru_metni'] ??
          item['question'] ??
          item['soruMetni'] ??
          '')
      .toString()
      .trim();

  final List<String> options = _extractOptions(item);

  if (questionText.isEmpty || options.length < 2) {
    return null;
  }

  final int correctIndex = _extractCorrectIndex(item, options);

  final String rawVisual = (item['svg_kod'] ??
          item['gorsel_url'] ??
          item['image'] ??
          item['visual'] ??
          '')
      .toString()
      .trim();

  final String svgCode = rawVisual.startsWith('<svg') ? rawVisual : '';

  return {
    'soru_metni': questionText,
    'secenekler': options,
    'dogru_cevap': correctIndex,
    'aciklama': item['aciklama'] ?? item['explanation'] ?? '',
    'svg_kod': svgCode,
  };
}

  Map<String, dynamic> _shuffleQuestionOptions(Map<String, dynamic> q) {
    final rawOptions = q['secenekler'];
    if (rawOptions is! List || rawOptions.length < 2) return q;

    final int correctIndex = (q['dogru_cevap'] is int)
        ? q['dogru_cevap'] as int
        : int.tryParse(q['dogru_cevap']?.toString() ?? '') ?? 0;
    if (correctIndex < 0 || correctIndex >= rawOptions.length) return q;

    final correctText = rawOptions[correctIndex].toString();
    final shuffled = List<String>.from(rawOptions.map((e) => e.toString()));
    shuffled.shuffle(Random(
        '${q['soru_metni'] ?? q['soru'] ?? DateTime.now().microsecondsSinceEpoch}'
            .hashCode));
    final newCorrectIndex =
        shuffled.indexOf(correctText).clamp(0, shuffled.length - 1);

    return {
      ...q,
      'secenekler': shuffled,
      'dogru_cevap': newCorrectIndex,
    };
  }

  // ── Soru Yükleme ──────────────────────────────────────────────────────────
  Future<void> _fetchQuestionsFromAssets() async {
  if (widget.singleQuestion != null) {
    if (mounted) {
      setState(() {
        questions = [widget.singleQuestion!];
        _totalSections = 1;
        isLoading = false;
      });
    }
    return;
  }

  try {
    debugPrint(
      'QUIZ PARAMS => exam: ${widget.examName} | ders: ${widget.subjectName} | konu: ${widget.topicName} | section: ${widget.sectionNumber}',
    );

    final String? filePath = await QuizLocalRegistry.findFilePath(
      widget.examName,
      widget.subjectName,
      widget.topicName,
    );

    debugPrint('QUIZ SELECTED FILE => $filePath');

    if (filePath == null) {
      debugPrint(
        '❌ DOSYA BULUNAMADI: ${widget.examName} - ${widget.subjectName} - ${widget.topicName}',
      );

      if (mounted) {
        setState(() {
          questions = [];
          isLoading = false;
        });
      }

      return;
    }

    final List<Map<String, dynamic>> allQuestions = [];

    if (filePath.endsWith('.json')) {
      final String jsonString = await rootBundle.loadString(filePath);
      final dynamic decoded = json.decode(jsonString);

      final List<dynamic> list = _extractQuestionList(decoded);

      debugPrint('QUIZ RAW QUESTION COUNT => ${list.length}');

      for (final item in list) {
        final Map<String, dynamic>? normalized = _normalizeQuestionItem(item);

        if (normalized != null) {
          allQuestions.add(_shuffleQuestionOptions(normalized));
        }
      }

      debugPrint('QUIZ NORMALIZED QUESTION COUNT => ${allQuestions.length}');
    } else if (filePath.endsWith('.xlsx')) {
      final ByteData byteData = await rootBundle.load(filePath);
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      final excel = excel_lib.Excel.decodeBytes(bytes);

      String getCellValue(excel_lib.Data? cell) {
        if (cell == null || cell.value == null) return '';

        String text = cell.value.toString();

        if (text.startsWith('TextCellValue(')) {
          text = text.replaceAll('TextCellValue(', '').replaceAll(')', '');
        }

        return text.trim();
      }

      for (final table in excel.tables.keys) {
        final rows = excel.tables[table]!.rows;

        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];

          if (row.isEmpty) continue;

          final soruMetni = getCellValue(row[0]);

          if (soruMetni.isEmpty) continue;

          final List<String> secenekler = [];

          for (int k = 1; k <= 5; k++) {
            final s = row.length > k ? getCellValue(row[k]) : '';

            if (s.isNotEmpty) {
              secenekler.add(s);
            }
          }

          if (secenekler.length < 2) continue;

          final dogruHarf =
              row.length > 6 ? getCellValue(row[6]).toUpperCase() : 'A';

          final int dogruIndex =
              (dogruHarf.isNotEmpty ? dogruHarf.codeUnitAt(0) - 65 : 0)
                  .clamp(0, secenekler.length - 1);

          allQuestions.add(
            _shuffleQuestionOptions({
              'soru_metni': soruMetni,
              'secenekler': secenekler,
              'dogru_cevap': dogruIndex,
              'aciklama': row.length > 7 ? getCellValue(row[7]) : '',
              'svg_kod': '',
            }),
          );
        }
      }

      debugPrint('QUIZ XLSX QUESTION COUNT => ${allQuestions.length}');
    }

    _totalSections = allQuestions.isEmpty ? 1 : (allQuestions.length / 10).ceil();

    final int startIndex = (widget.sectionNumber - 1) * 10;
    int endIndex = startIndex + 10;

    debugPrint(
      'QUIZ SECTION SLICE => start: $startIndex | end: $endIndex | total: ${allQuestions.length}',
    );

    if (startIndex >= allQuestions.length) {
      questions = [];
    } else {
      if (endIndex > allQuestions.length) {
        endIndex = allQuestions.length;
      }

      questions = allQuestions.sublist(startIndex, endIndex);
    }

    debugPrint('QUIZ PAGE QUESTION COUNT => ${questions.length}');

    if (questions.isNotEmpty && widget.singleQuestion == null) {
      _logAnalytics('quiz_started');
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  } catch (e, stackTrace) {
    debugPrint('❌ DOSYA OKUMA HATASI: $e');
    debugPrint('STACK TRACE: $stackTrace');

    if (mounted) {
      setState(() {
        questions = [];
        isLoading = false;
      });
    }
  }
}

  // ── Yanlış Kutusu ─────────────────────────────────────────────────────────
  Future<void> _saveWrongAnswer(Map<String, dynamic> question) async {
    if (_uid == null) return;
    try {
      final String soruMetni = question['soru_metni']?.toString() ?? '';
      final String docId =
          '${widget.subjectName}_${widget.topicName}_${soruMetni.hashCode.abs()}'
              .replaceAll(' ', '_');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('yanlislar')
          .doc(docId)
          .set({
        ...question,
        'kayit_tarihi': FieldValue.serverTimestamp(),
        'gelen_ders': widget.subjectName,
        'gelen_konu': widget.topicName,
        'exam': widget.examName,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yanlış kutusuna eklendi!',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Yanlış kaydı hatası: $e');
    }
  }

  // ── Cevap Kontrolü ────────────────────────────────────────────────────────
  void checkAnswer(int index) {
    if (isAnswered) return;
    final bool isCorrect =
        index == questions[currentQuestionIndex]['dogru_cevap'];
    setState(() {
      selectedOptionIndex = index;
      isAnswered = true;
      if (isCorrect) correctAnswersCount++;
    });
  }

  // ── Quiz Bitir ────────────────────────────────────────────────────────────
  void finishQuiz() async {
    int earnedStars = 0;
    if (questions.isNotEmpty) {
      final double pct = correctAnswersCount / questions.length;
      if (pct >= 0.8) {
        earnedStars = 3;
      } else if (pct >= 0.5) {
        earnedStars = 2;
      } else if (pct > 0) {
        earnedStars = 1;
      }
    }

    if (_uid != null) {
      // singleQuestion modunda (yanlış kutusundan) XP ve görev ilerlemesi verilmez
      if (widget.singleQuestion == null) {
        await _userService.updateStats(
          _uid,
          correctAnswersCount > 0,
          correctCount: correctAnswersCount,
          earnedStars: earnedStars,
        );
        await _userService.updateTaskProgress(
            _uid, questions.length, widget.subjectName);
      }

      final int wrongCount = questions.length - correctAnswersCount;
      await _userService.saveSubjectStats(
        _uid,
        widget.subjectName,
        widget.topicName,
        dogru: correctAnswersCount,
        yanlis: wrongCount,
      );

      if (widget.singleQuestion == null) {
        await _userService.saveSectionProgress(
          uid: _uid,
          subjectName: widget.subjectName,
          topicName: widget.topicName,
          sectionNumber: widget.sectionNumber,
          stars: earnedStars,
        );

        try {
          final progSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(_uid)
              .collection('progress')
              .where('topic', isEqualTo: widget.topicName)
              .limit(1)
              .get();

          if (progSnapshot.docs.isNotEmpty) {
            await progSnapshot.docs.first.reference.set({
              'sectionStars': {widget.sectionNumber.toString(): earnedStars}
            }, SetOptions(merge: true));
          }
        } catch (e) {
          debugPrint('Yıldız garanti kaydı hatası: $e');
        }

        ReklamServisi.bolumTamamlandi(_isVip);
      }
    }

    // 🔥 ANALİZ: Kullanıcı quizi başarıyla bitirdi
    if (widget.singleQuestion == null) {
      _logAnalytics('quiz_completed');
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultPage(
          subjectName: widget.subjectName,
          topicName: widget.topicName,
          sectionNumber: widget.sectionNumber,
          correctAnswers: correctAnswersCount,
          totalQuestions: questions.length,
          examName: widget.examName,
          isSingleQuestion: widget.singleQuestion != null,
          totalSections: _totalSections,
          earnedStars: _computeStars(correctAnswersCount, questions.length),
        ),
      ),
    );
  }

  static int _computeStars(int correct, int total) {
    if (total == 0) return 0;
    final double pct = correct / total;
    if (pct >= 0.8) return 3;
    if (pct >= 0.5) return 2;
    if (pct > 0) return 1;
    return 0;
  }

  // ── Matematik Metin Render
// Kök, üslü, alt indis, kesir ve temel matematik sembollerini ekranda düzeltir.
  String _formatMathTextString(String text) {
    const superMap = {
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
      '-': '⁻',
      '+': '⁺',
      'n': 'ⁿ',
      'x': 'ˣ',
      'a': 'ᵃ',
    };

    const subMap = {
      '0': '₀',
      '1': '₁',
      '2': '₂',
      '3': '₃',
      '4': '₄',
      '5': '₅',
      '6': '₆',
      '7': '₇',
      '8': '₈',
      '9': '₉',
    };

    String toSuper(String value) {
      return value.split('').map((c) => superMap[c] ?? c).join();
    }

    String toSub(String value) {
      return value.split('').map((c) => subMap[c] ?? c).join();
    }

    String rootText(String value, {String? degree}) {
      final inner = value.trim();

      final bool simple = RegExp(
        r'^[0-9a-zA-ZçğıöşüÇĞİÖŞÜ]+$',
      ).hasMatch(inner);

      final formattedInner = simple ? inner : '($inner)';

      final rootDegree =
          degree == null || degree.trim().isEmpty || degree == '2'
              ? ''
              : toSuper(degree.trim());

      return '$rootDegree√$formattedInner';
    }

    String processed = text;

    // HTML escape kalıntıları varsa temizle
    processed = processed
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll(r'$', '')
        .replaceAll('\$', '');

    // LaTeX kesir: \frac{1}{2} → 1/2
    processed = processed.replaceAllMapped(
      RegExp(r'\\frac\s*\{([^}]+)\}\s*\{([^}]+)\}'),
      (m) => '${m.group(1)}/${m.group(2)}',
    );

    // LaTeX kök: \sqrt{18} → √18
    processed = processed.replaceAllMapped(
      RegExp(r'\\sqrt\s*\{([^}]+)\}'),
      (m) => rootText(m.group(1)!),
    );
    // LaTeX kök parantezsiz: \sqrt27 → √27
    processed = processed.replaceAllMapped(
      RegExp(
        r'\\sqrt\s*([0-9a-zA-ZçğıöşüÇĞİÖŞÜ]+)',
        caseSensitive: false,
      ),
      (m) => rootText(m.group(1)!),
    );

    // Dereceli kök: \sqrt[3]{8} → ³√8
    processed = processed.replaceAllMapped(
      RegExp(r'\\sqrt\s*\[([^\]]+)\]\s*\{([^}]+)\}'),
      (m) => rootText(m.group(2)!, degree: m.group(1)),
    );

    // sqrt{18} → √18
    processed = processed.replaceAllMapped(
      RegExp(r'sqrt\s*\{([^}]+)\}', caseSensitive: false),
      (m) => rootText(m.group(1)!),
    );

    // sqrt(18) → √18
    processed = processed.replaceAllMapped(
      RegExp(r'sqrt\s*\(([^)]+)\)', caseSensitive: false),
      (m) => rootText(m.group(1)!),
    );

    // √{18} → √18
    processed = processed.replaceAllMapped(
      RegExp(r'√\s*\{([^}]+)\}'),
      (m) => rootText(m.group(1)!),
    );

    // √(18) → √18
    processed = processed.replaceAllMapped(
      RegExp(r'√\s*\(([^)]+)\)'),
      (m) => rootText(m.group(1)!),
    );

    // kök(18), kok(18) → √18
    processed = processed.replaceAllMapped(
      RegExp(r'k[oö]k\s*\(([^)]+)\)', caseSensitive: false),
      (m) => rootText(m.group(1)!),
    );

    // kök{18}, kok{18} → √18
    processed = processed.replaceAllMapped(
      RegExp(r'k[oö]k\s*\{([^}]+)\}', caseSensitive: false),
      (m) => rootText(m.group(1)!),
    );

    // kök18, kok18 → √18
    processed = processed.replaceAllMapped(
      RegExp(r'k[oö]k([0-9]+)', caseSensitive: false),
      (m) => rootText(m.group(1)!),
    );

    // kök 18, kok 18 → √18
    processed = processed.replaceAllMapped(
      RegExp(r'k[oö]k\s+([0-9]+)', caseSensitive: false),
      (m) => rootText(m.group(1)!),
    );

    // Temel LaTeX / matematik sembolleri
    processed = processed
        .replaceAll(r'\times', '×')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\div', '÷')
        .replaceAll(r'\leq', '≤')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\neq', '≠')
        .replaceAll(r'\pi', 'π')
        .replaceAll('<=', '≤')
        .replaceAll('>=', '≥')
        .replaceAll('!=', '≠');

    // ^2, ^{2}, ^{-1}, x^{2} gibi ifadeler
    processed = processed.replaceAllMapped(
      RegExp(r'\^\{([^}]+)\}|\^([^\s\^\{\}])'),
      (m) {
        final exp = (m.group(1) ?? m.group(2))!;
        return toSuper(exp);
      },
    );

    // <sup>2</sup> → ²
    processed = processed.replaceAllMapped(
      RegExp(r'<sup>(.*?)</sup>'),
      (m) {
        final exp = m.group(1)!;
        return toSuper(exp);
      },
    );

    // x_1, y_2, a_3 → x₁, y₂, a₃
    processed = processed.replaceAllMapped(
      RegExp(r'([a-zA-Z])_(\d+)'),
      (m) {
        final letter = m.group(1)!;
        final nums = m.group(2)!;
        return letter + toSub(nums);
      },
    );

    // x2, x3, y2, z3 → x², x³, y², z³
    processed = processed.replaceAllMapped(
      RegExp(r'\b([xyzXYZ])([1-9]\d*)\b'),
      (m) {
        final letter = m.group(1)!;
        final nums = m.group(2)!;
        return letter + toSuper(nums);
      },
    );

    // a3, b2, u5 vb. → a₃, b₂, u₅
    // x/y/z hariç harflerde dizi terimi gibi düşünür.
    processed = processed.replaceAllMapped(
      RegExp(r'\b([a-wA-W])([1-9]\d*)\b'),
      (m) {
        final letter = m.group(1)!;
        final nums = m.group(2)!;
        return letter + toSub(nums);
      },
    );

    // Görsel iyileştirme: eksi işareti
    processed = processed.replaceAll(' - ', ' − ');
    processed = processed.replaceAllMapped(
      RegExp(r'(?<![0-9])-(?=[0-9])'),
      (_) => '−',
    );

    return processed;
  }

  Widget _buildMathText(String text) {
    final processed = _formatMathTextString(text);

    return Text(
      processed,
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        height: 1.4,
      ),
    );
  }

  // ── Hatalı Soru Bildir ────────────────────────────────────────────────────
  Future<void> _reportQuestion(Map<String, dynamic> question) async {
    if (_uid == null) return;
    final confirm = await BRDialogs.showConfirm(
      context,
      title: 'Soruyu Bildir',
      message:
          'Bu soruyu hatalı olarak bildirmek istiyor musun? Bildirimin incelenmek üzere admin paneline düşecek.',
      icon: Icons.flag_rounded,
      accent: Colors.orangeAccent,
      cancelText: 'İptal',
      confirmText: 'Bildir',
      confirmColor: Colors.orangeAccent,
    );
    if (confirm != true) return;

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      final userData = userDoc.data() ?? {};
      final fullName = (userData['name'] ??
              FirebaseAuth.instance.currentUser?.displayName ??
              'İsimsiz')
          .toString();
      final email =
          (userData['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '')
              .toString();
      await FirebaseFirestore.instance.collection('reported_questions').add({
        'uid': _uid,
        'userName': fullName,
        'userEmail': email,
        'soru_metni': question['soru_metni'] ?? '',
        'subject': widget.subjectName,
        'topic': widget.topicName,
        'section': widget.sectionNumber,
        'exam': widget.examName,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sorun bildirildi, teşekkürler! 🙏',
              style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.deepPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Soru bildirme hatası: $e');
    }
  }

  // ── Açıklama Kutusu ───────────────────────────────────────────────────────
  Widget _buildExplanationBox(String aciklama) {
    if (aciklama.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 15, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lightbulb_outline, color: Color(0xFF00B8D4)),
            const SizedBox(width: 8),
            Text('Çözüm / Açıklama',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF00B8D4),
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ]),
          const SizedBox(height: 10),
          Text(
            _formatMathTextString(aciklama),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmExitQuiz() async {
    if (widget.singleQuestion != null) return true;
    return BRDialogs.showExitConfirm(
      context,
      title: 'Testten çıkılsın mı?',
      message:
          'Bu test için harcanan 5 enerji geri iade edilmeyecek. Test ilerlemen kaydedilmeden çıkarsan kaldığın yer korunmaz.',
    );
  }

  void _trackEarlyExitIfNeeded() {
    if (widget.singleQuestion == null &&
        currentQuestionIndex < questions.length - 1) {
      _logAnalytics('quiz_exited_early');
    }
  }

  // ── Ana Ekran Butonu (AppBar action) ─────────────────────────────────────
  /// Tek dokunuşla tüm quiz/konu/ders stack'ini atlayıp ana sayfaya döner.
  Widget _buildHomeButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () async {
          final canExit = await _confirmExitQuiz();
          if (!canExit || !context.mounted) return;
          _trackEarlyExitIfNeeded();
          // Stack'teki tüm sayfaları temizleyip ana sayfaya dön
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.home_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 5),
              Text('Ana Ekran',
                  style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E43),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E43),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1B1F6A),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_off_rounded,
                  size: 80, color: Colors.white54),
              const SizedBox(height: 20),
              Text('Soru Bulunamadı',
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 10),
              Text(
                'Bu seviyede henüz soru yok veya dosya eksik.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    final q = questions[currentQuestionIndex];

    // 🔥 ANALİZ: Kullanıcının fiziksel geri tuşuna (Android) veya swipe (iOS) ile kaçmasını yakalamak için WillPopScope eklendi
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        final canExit = await _confirmExitQuiz();
        if (canExit) _trackEarlyExitIfNeeded();
        return canExit;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E43),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1B1F6A),
          elevation: 10,
          shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.3),
          centerTitle: true,
          title: Text(
            widget.singleQuestion != null
                ? 'Yanlış Soruyu Çöz'
                : '${widget.subjectName} - Seviye ${widget.sectionNumber}',
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () async {
              final canExit = await _confirmExitQuiz();
              if (!canExit || !context.mounted) return;
              _trackEarlyExitIfNeeded();
              Navigator.pop(context);
            },
          ),
          actions: [
            _buildHomeButton(context),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // İlerleme çubuğu
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  children: [
                    Text(
                      '${currentQuestionIndex + 1}/${questions.length}',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (currentQuestionIndex + 1) / questions.length,
                          backgroundColor: Colors.white24,
                          valueColor:
                              const AlwaysStoppedAnimation(Color(0xFF00E5FF)),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Soru kartı
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1F6A),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    children: [
                      // Soru metni ve görseli
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (q['svg_kod'] != null &&
                                    q['svg_kod'].toString().trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: SvgPicture.string(
                                        q['svg_kod'].toString(),
                                        height: 180,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                _buildMathText(
                                    q['soru_metni']?.toString() ?? ''),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Seçenekler + açıklama
                      Expanded(
                        flex: 5,
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            ...List.generate((q['secenekler'] as List).length,
                                (index) {
                              final bool isCorrect = index == q['dogru_cevap'];
                              final bool isSelected =
                                  index == selectedOptionIndex;

                              Color cardColor = const Color(0xFF00E5FF);
                              double opacityValue = 1.0;
                              Widget? trailingIcon;

                              if (isAnswered) {
                                if (isCorrect) {
                                  cardColor = const Color(0xFF00E676);
                                  trailingIcon = const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF00E676),
                                      size: 26);
                                } else if (isSelected) {
                                  cardColor = const Color(0xFFFF5252);
                                  trailingIcon = const Icon(
                                      Icons.cancel_rounded,
                                      color: Color(0xFFFF5252),
                                      size: 26);
                                } else {
                                  opacityValue = 0.4;
                                }
                              }

                              return Opacity(
                                opacity: opacityValue,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: GestureDetector(
                                    onTap: () => checkAnswer(index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 15, vertical: 16),
                                      decoration: BoxDecoration(
                                        color:
                                            cardColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: cardColor.withValues(
                                                alpha: 0.5)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 35,
                                            height: 35,
                                            decoration: BoxDecoration(
                                              color: cardColor.withValues(
                                                  alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                optionLetters[index],
                                                style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 15),
                                          Expanded(
                                            child: Text(
                                              _formatMathTextString(
                                                q['secenekler'][index]
                                                    .toString(),
                                              ),
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (trailingIcon != null)
                                            trailingIcon,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            if (isAnswered)
                              _buildExplanationBox(
                                  q['aciklama']?.toString() ?? ''),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Alt butonlar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Column(
                  children: [
                    if (!isAnswered)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Doğru cevabı bul, yıldız kazan!',
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    if (isAnswered && selectedOptionIndex != q['dogru_cevap'])
                      TextButton.icon(
                        onPressed: () => _saveWrongAnswer(q),
                        icon: const Icon(Icons.add_box_rounded,
                            color: Colors.orangeAccent),
                        label: Text('Yanlış Kutusuna Ekle',
                            style: GoogleFonts.poppins(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold)),
                      ),
                    if (isAnswered)
                      TextButton.icon(
                        onPressed: () => _reportQuestion(q),
                        icon: const Icon(Icons.flag_outlined,
                            color: Colors.white38, size: 18),
                        label: Text('Hatalı Soruyu Bildir',
                            style: GoogleFonts.poppins(
                                color: Colors.white38, fontSize: 12)),
                      ),
                    if (isAnswered)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () {
                          if (currentQuestionIndex < questions.length - 1) {
                            setState(() {
                              currentQuestionIndex++;
                              isAnswered = false;
                              selectedOptionIndex = null;
                            });
                          } else {
                            finishQuiz();
                          }
                        },
                        child: Text(
                          currentQuestionIndex < questions.length - 1
                              ? 'DEVAM ET'
                              : 'BİTİR',
                          style: GoogleFonts.poppins(
                              color: const Color(0xFF0A0E43),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// QUIZ SONUÇ SAYFASI
// ═══════════════════════════════════════════════════════════════════════════

class QuizResultPage extends StatefulWidget {
  final String subjectName;
  final String topicName;
  final int sectionNumber;
  final int correctAnswers;
  final int totalQuestions;
  final bool isSingleQuestion;
  final String examName;
  final int totalSections;
  final int earnedStars;

  const QuizResultPage({
    super.key,
    required this.subjectName,
    required this.topicName,
    required this.sectionNumber,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.examName,
    this.isSingleQuestion = false,
    this.totalSections = 5,
    this.earnedStars = 0,
  });

  @override
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _starsController;
  late AnimationController _xpController;
  late AnimationController _bgController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _xpAnimation;

  int _earnedXp = 0;

  @override
  void initState() {
    super.initState();

    switch (widget.earnedStars) {
      case 3:
        _earnedXp = 50;
        break;
      case 2:
        _earnedXp = 30;
        break;
      case 1:
        _earnedXp = 10;
        break;
      default:
        _earnedXp = 5;
    }

    _bgController =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..repeat();

    _scaleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnimation =
        CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);

    _starsController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _xpController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _xpAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _xpController, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _scaleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _starsController.forward();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _xpController.forward();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _starsController.dispose();
    _xpController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  String _getResultTitle() {
    final double pct = widget.totalQuestions > 0
        ? widget.correctAnswers / widget.totalQuestions
        : 0;
    if (pct >= 0.8) return 'Harika! 🎉';
    if (pct >= 0.5) return 'İyi İş! 👏';
    if (pct > 0) return 'Devam Et! 💪';
    return 'Tekrar Dene!';
  }

  String _getResultSubtitle() {
    final double pct = widget.totalQuestions > 0
        ? widget.correctAnswers / widget.totalQuestions
        : 0;
    if (pct >= 0.8) return 'Mükemmel bir performans!';
    if (pct >= 0.5) return 'Gayet iyi gidiyorsun!';
    if (pct > 0) return 'Biraz daha çalışman gerekiyor.';
    return 'Pes etme, tekrar dene!';
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
                colors: [
                  Color(0xFF1565C0),
                  Color(0xFF1a237e),
                  Color(0xFF311b92)
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          ..._buildStaticStars(size),
          _buildMovingCloud(
              top: size.height * 0.05, scale: 0.9, speed: 0.3, moveRight: true),
          _buildMovingCloud(
              top: size.height * 0.75,
              scale: 1.0,
              speed: 0.25,
              moveRight: false),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 32, horizontal: 28),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF00E5FF)
                                    .withValues(alpha: 0.15),
                                blurRadius: 30,
                                spreadRadius: 2)
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(_getResultTitle(),
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold)),
                            Text(_getResultSubtitle(),
                                style: GoogleFonts.poppins(
                                    color: Colors.white60, fontSize: 14)),
                            const SizedBox(height: 28),

                            // Skor dairesi
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: widget.earnedStars == 3
                                      ? [
                                          const Color(0xFFFFD700),
                                          const Color(0xFFFF8C00)
                                        ]
                                      : widget.earnedStars == 2
                                          ? [
                                              const Color(0xFF00E5FF),
                                              const Color(0xFF0096C7)
                                            ]
                                          : [
                                              const Color(0xFF9C27B0),
                                              const Color(0xFF673AB7)
                                            ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (widget.earnedStars == 3
                                            ? const Color(0xFFFFD700)
                                            : const Color(0xFF00E5FF))
                                        .withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 3,
                                  )
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${widget.correctAnswers}',
                                        style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            height: 1)),
                                    Container(
                                        height: 1,
                                        width: 40,
                                        color: Colors.white54),
                                    Text('${widget.totalQuestions}',
                                        style: GoogleFonts.poppins(
                                            color: Colors.white70,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Yıldızlar
                            AnimatedBuilder(
                              animation: _starsController,
                              builder: (context, child) => Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (i) {
                                  final double delay = i * 0.25;
                                  final double progress =
                                      (_starsController.value - delay)
                                              .clamp(0.0, 1.0) /
                                          (1.0 - delay).clamp(0.3, 1.0);
                                  final double scale = Curves.elasticOut
                                      .transform(progress.clamp(0.0, 1.0));
                                  final bool isEarned = i < widget.earnedStars;
                                  return Transform.scale(
                                    scale: scale,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      child: Icon(
                                        isEarned
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        color: isEarned
                                            ? const Color(0xFFFFD700)
                                            : Colors.white24,
                                        size: 42,
                                        shadows: isEarned
                                            ? const [
                                                Shadow(
                                                    color: Color(0xFFFFD700),
                                                    blurRadius: 12)
                                              ]
                                            : null,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // XP animasyonu
                            AnimatedBuilder(
                              animation: _xpAnimation,
                              builder: (context, child) => Opacity(
                                opacity: _xpAnimation.value,
                                child: Transform.translate(
                                  offset:
                                      Offset(0, 20 * (1 - _xpAnimation.value)),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E676)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: const Color(0xFF00E676)
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.bolt_rounded,
                                            color: Color(0xFF00E676), size: 22),
                                        const SizedBox(width: 6),
                                        Text(
                                          '+$_earnedXp XP Kazandın!',
                                          style: GoogleFonts.poppins(
                                              color: const Color(0xFF00E676),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Alt butonlar
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                                side: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.25)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Haritaya Dön',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 0),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStaticStars(Size size) {
    final rand = Random(55);
    return List.generate(
      35,
      (_) => Positioned(
        left: rand.nextDouble() * size.width,
        top: rand.nextDouble() * size.height,
        child: Icon(Icons.star,
            size: rand.nextDouble() * 3 + 2,
            color:
                Colors.white.withValues(alpha: rand.nextDouble() * 0.4 + 0.1)),
      ),
    );
  }

  Widget _buildMovingCloud({
    required double top,
    required double scale,
    required double speed,
    required bool moveRight,
  }) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final double sw = MediaQuery.of(context).size.width;
        final double cw = 100.0 * scale;
        double offset = (_bgController.value * speed * (sw + cw)) % (sw + cw);
        if (!moveRight) offset = sw - offset;
        return Positioned(
          top: top,
          left: offset - cw,
          child: Opacity(
            opacity: 0.15,
            child: Icon(Icons.cloud_rounded,
                color: Colors.white, size: 100 * scale),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DOSYA KAYIT DEFTERİ (GÜNCEL, GEOMETRİSİZ, FULL LİSTE)
// ═══════════════════════════════════════════════════════════════════════════
class QuizLocalRegistry {
  static const List<Map<String, String>> _files = [
    // ──────────────────────────────────────────────────────────────────────────
    // TYT BÖLÜMÜ
    // ──────────────────────────────────────────────────────────────────────────
    // TYT TÜRKÇE
    {
      'exam': 'TYT',
      'ders': 'Türkçe',
      'konu': 'Anlatım Bozuklukları',
      'file': 'assets/tyt_turkce/anlatim_bozukluklari.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Türkçe',
      'konu': 'Cümlede Anlam',
      'file': 'assets/tyt_turkce/cumlede_anlam.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Türkçe',
      'konu': 'Cümlenin Ögeleri',
      'file': 'assets/tyt_turkce/cumlenin_ogeleri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Türkçe',
      'konu': 'Cümle Türleri',
      'file': 'assets/tyt_turkce/cumle_turleri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Türkçe',
      'konu': 'Dil Bilgisi Ses Olayları',
      'file': 'assets/tyt_turkce/dil_bilgisi_ses_olaylari.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Türkçe',
      'konu': 'Mantık',
      'file': 'assets/tyt_turkce/mantik.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Türkçe',
      'konu': 'Noktalama İşaretleri',
      'file': 'assets/tyt_turkce/noktalama_isaretleri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Türkçe',
      'konu': 'Paragrafta Anlam',
      'file': 'assets/tyt_turkce/paragrafta_anlam.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Türkçe',
      'konu': 'Paragrafta Anlatım Biçimi',
      'file': 'assets/tyt_turkce/paragrafta_anlatim_bicimi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Türkçe',
      'konu': 'Sözcükte Anlam',
      'file': 'assets/tyt_turkce/sozcukte_anlam.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Türkçe',
      'konu': 'Sözcükte Yapı',
      'file': 'assets/tyt_turkce/sozcukte_yapi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Türkçe',
      'konu': 'Sözcük Türleri',
      'file': 'assets/tyt_turkce/sozcuk_turleri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Türkçe',
      'konu': 'Yazım Kuralları',
      'file': 'assets/tyt_turkce/yazim_kurallari.json'
    },

    // TYT MATEMATİK
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Basit Eşitsizlikler',
      'file': 'assets/tyt_matematik/basit_esitsizlikler.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Çarpanlara Ayırma',
      'file': 'assets/tyt_matematik/carpanlara_ayirma.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Denklem Çözme',
      'file': 'assets/tyt_matematik/denklem_cozme.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Fonksiyonlar',
      'file': 'assets/tyt_matematik/fonksiyonlar.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'İşlem',
      'file': 'assets/tyt_matematik/islem.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Köklü Sayılar',
      'file': 'assets/tyt_matematik/koklu_sayilar.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Kümeler',
      'file': 'assets/tyt_matematik/kumeler.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Mantık',
      'file': 'assets/tyt_matematik/mantik.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Mutlak Değer',
      'file': 'assets/tyt_matematik/mutlak_deger.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Olasılık',
      'file': 'assets/tyt_matematik/olasilik.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Oran Orantı',
      'file': 'assets/tyt_matematik/oran_oranti.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Permütasyon Kombinasyon',
      'file': 'assets/tyt_matematik/permutasyon_kombinasyon.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Problemler',
      'file': 'assets/tyt_matematik/problemler.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Rasyonel Sayılar Ondalıklı Sayılar',
      'file': 'assets/tyt_matematik/rasyonel_sayilar_ondalikli_sayilar.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Temel Kavramlar',
      'file': 'assets/tyt_matematik/temel_kavramlar.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Matematik',
      'konu': 'Üslü Sayılar',
      'file': 'assets/tyt_matematik/uslu_sayilar.json'
    },

    // TYT TARİH
    {
      'exam': 'TYT',
      'ders': 'Tarih',
      'konu': '17. Yüzyıl Osmanlı Devleti Duraklama Dönemi',
      'file': 'assets/tyt_tarih/17_yuzyil_osmanli_devleti_duraklama_donemi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Tarih',
      'konu': '18. Yüzyıl Osmanlı Devleti Gerileme Dönemi',
      'file': 'assets/tyt_tarih/18_yuzyil_osmanli_devleti_gerileme_donemi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Tarih',
      'konu': '19. Yüzyıl Osmanlı Devleti Dağılma Dönemi',
      'file': 'assets/tyt_tarih/19_yuzyil_osmanli_devleti_dagilma_donemi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Tarih',
      'konu': '20. Yüzyıl Osmanlı Devleti',
      'file': 'assets/tyt_tarih/20_yuzyil_osmanli_devleti.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Tarih',
      'konu': 'Atatürk Dönemi İç ve Dış Politikalar',
      'file': 'assets/tyt_tarih/ataturk_donemi_ic_ve_dis_politikalar.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Tarih',
      'konu': 'Çağdaş Türk ve Dünya Tarihi',
      'file': 'assets/tyt_tarih/cagdas_turk_ve_dunya_tarihi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Tarih',
      'konu': 'İlk Türk İslam Devletleri',
      'file': 'assets/tyt_tarih/ilk_turk_islam_devletleri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Tarih',
      'konu': 'İlk Türk İslam Devletlerinde Kültür ve Medeniyet',
      'file':
          'assets/tyt_tarih/ilk_turk_islam_devletlerinde_kultur_ve_medeniyet.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Tarih',
      'konu': 'İnkılap Tarihi',
      'file': 'assets/tyt_tarih/inkilap_tarihi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Tarih',
      'konu': 'İslamiyet Öncesi Türk Tarihi Soru Bankası',
      'file': 'assets/tyt_tarih/islamiyet_oncesi_turk_tarihi_soru_bankasi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Tarih',
      'konu': 'İslam Öncesi Türk Tarihi',
      'file': 'assets/tyt_tarih/islam_oncesi_turk_tarihi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Tarih',
      'konu': 'Milli Mücadele Dönemi',
      'file': 'assets/tyt_tarih/milli_mucadele_donemi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Tarih',
      'konu': 'Osmanlı Devleti Kültür ve Medeniyet',
      'file': 'assets/tyt_tarih/osmanli_devleti_kultur_ve_medeniyet.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Tarih',
      'konu': 'Osmanlı Devleti Kuruluş ve Yükselme Dönemi',
      'file': 'assets/tyt_tarih/osmanli_devleti_kurulus_ve_yukselme_donemi.json'
    },

    // TYT COĞRAFYA
    {
      'exam': 'TYT',
      'ders': 'Coğrafya',
      'konu': 'Bölgeler Coğrafyası',
      'file': 'assets/tyt_cografya/bolgeler_cografyasi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Coğrafya',
      'konu': 'Hayvancılık',
      'file': 'assets/tyt_cografya/hayvancilik.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Coğrafya',
      'konu': 'Madenler ve Enerji',
      'file': 'assets/tyt_cografya/madenler_ve_enerji.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Coğrafya',
      'konu': 'Sanayi ve Endüstri',
      'file': 'assets/tyt_cografya/sanayi_ve_endustri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Coğrafya',
      'konu': 'Tarım',
      'file': 'assets/tyt_cografya/tarim.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Coğrafya',
      'konu': 'Ticaret',
      'file': 'assets/tyt_cografya/ticaret.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Coğrafya',
      'konu': 'Turizm',
      'file': 'assets/tyt_cografya/turizm.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Coğrafya',
      'konu': 'Türkiye\'de Nüfus ve Yerleşme',
      'file': 'assets/tyt_cografya/turkiye_de_nufus_ve_yerlesme.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Coğrafya',
      'konu': 'Türkiye\'nin Coğrafi Konumu',
      'file': 'assets/tyt_cografya/turkiye_nin_cografi_konumu.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Coğrafya',
      'konu': 'Türkiye\'nin Fiziki Özellikleri',
      'file': 'assets/tyt_cografya/turkiye_nin_fiziki_ozellikleri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Coğrafya',
      'konu': 'Türkiye\'nin İklimi ve Bitki Örtüsü',
      'file': 'assets/tyt_cografya/turkiye_nin_iklimi_ve_bitki_ortusu.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Coğrafya',
      'konu': 'Ulaşım',
      'file': 'assets/tyt_cografya/ulasim.json'
    },

    // TYT DİN
    {
      'exam': 'TYT',
      'ders': 'Din Kültürü',
      'konu': 'Allah İnsan İlişkisi',
      'file': 'assets/tyt_din/allah_insan_iliskisi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Din Kültürü',
      'konu': 'Anadolu\'da İslam',
      'file': 'assets/tyt_din/anadoluda_islam.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Din Kültürü',
      'konu': 'Dünya ve Ahiret',
      'file': 'assets/tyt_din/dunya_ve_ahiret.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Din Kültürü',
      'konu': 'Güncel Dini Meseleler',
      'file': 'assets/tyt_din/guncel_dini_meseleler.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Din Kültürü',
      'konu': 'Hint ve Çin Dinleri',
      'file': 'assets/tyt_din/hint_ve_cin_dinleri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Din Kültürü',
      'konu': 'İnançla İlgili Meseleler',
      'file': 'assets/tyt_din/inancla_ilgili_meseleler.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Din Kültürü',
      'konu': 'İslam Düşüncesinde Tasavvufi Yorumlar ve Mezhepler',
      'file':
          'assets/tyt_din/islam_dusuncesinde_tasavvufi_yorumlar_ve_mezhepler.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Din Kültürü',
      'konu': 'İslam ve Bilim',
      'file': 'assets/tyt_din/islam_ve_bilim.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Din Kültürü',
      'konu': 'Kur\'an\'a Göre Hz Muhammed',
      'file': 'assets/tyt_din/kurana_gore_hz_muhammed.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Din Kültürü',
      'konu': 'Kur\'an\'dan Mesajlar',
      'file': 'assets/tyt_din/kurandan_mesajlar.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Din Kültürü',
      'konu': 'Kur\'an\'da Bazı Kavramlar',
      'file': 'assets/tyt_din/kuranda_bazi_kavramlar.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Din Kültürü',
      'konu': 'Yahudilik ve Hristiyanlık',
      'file': 'assets/tyt_din/yahudilik_ve_hristiyanlik.json'
    },

    // TYT FELSEFE
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': '20. Yüzyıl Felsefesi',
      'file': 'assets/tyt_felsefe/20._yuzyil_felsefesi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Ahlak Felsefesi',
      'file': 'assets/tyt_felsefe/ahlak_felsefesi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Bilgi Felsefesi',
      'file': 'assets/tyt_felsefe/bilgi_felsefesi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Birey ve Toplum',
      'file': 'assets/tyt_felsefe/birey_ve_toplum.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Felsefesi',
      'file': 'assets/tyt_felsefe/felsefesi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Klasik Mantık',
      'file': 'assets/tyt_felsefe/klasik_mantik.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Mantığa Giriş',
      'file': 'assets/tyt_felsefe/mantiga_giris.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Mantık ve Dil',
      'file': 'assets/tyt_felsefe/mantik_ve_dil.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Öğrenme Bellek Düşünme',
      'file': 'assets/tyt_felsefe/ogrenme_bellek_dusunme.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Psikolojinin Temel Süreçleri',
      'file': 'assets/tyt_felsefe/psikolojinin_temel_surecleri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Psikoloji Bilimini Tanıyalım',
      'file': 'assets/tyt_felsefe/psikoloji_bilimini_taniyalim.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Ruh Sağlığının Temelleri',
      'file': 'assets/tyt_felsefe/ruh_sagliginin_temelleri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Sosyolojiye Giriş',
      'file': 'assets/tyt_felsefe/sosyolojiye_giris.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Toplumsal Değişme ve Gelişme',
      'file': 'assets/tyt_felsefe/toplumsal_degisme_ve_gelisme.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Toplumsal Kurumlar',
      'file': 'assets/tyt_felsefe/toplumsal_kurumlar.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Toplumsal Yapı',
      'file': 'assets/tyt_felsefe/toplumsal_yapi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Toplum ve Kültür',
      'file': 'assets/tyt_felsefe/toplum_ve_kultur.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Varlık Felsefesi',
      'file': 'assets/tyt_felsefe/varlik_felsefesi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Felsefe',
      'konu': 'Bilim',
      'file': 'assets/tyt_felsefe/ve_bilim.json'
    },

    // TYT BİYOLOJİ
    {
      'exam': 'TYT',
      'ders': 'Biyoloji',
      'konu': 'Bitkiler Biyolojisi',
      'file': 'assets/tyt_biyoloji/bitkiler_biyolojisi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Biyoloji',
      'konu': 'Canlıların Ortak Özellikleri',
      'file': 'assets/tyt_biyoloji/canlilarin_ortak_ozellikleri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Biyoloji',
      'konu': 'Canlıların Sınıflandırılması',
      'file': 'assets/tyt_biyoloji/canlilarin_siniflandirilmasi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Biyoloji',
      'konu': 'Canlıların Temel Bileşenleri',
      'file': 'assets/tyt_biyoloji/canlilarin_temel_bilesenleri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Biyoloji',
      'konu': 'Ekosistem Ekolojisi',
      'file': 'assets/tyt_biyoloji/ekosistem_ekolojisi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Biyoloji',
      'konu': 'Hücre Bölünmeleri ve Üreme',
      'file': 'assets/tyt_biyoloji/hucre_bolunmeleri_ve_ureme.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Biyoloji',
      'konu': 'Hücre ve Organelleri',
      'file': 'assets/tyt_biyoloji/hucre_ve_organelleri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Biyoloji',
      'konu': 'Kalıtım',
      'file': 'assets/tyt_biyoloji/kalitim.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Biyoloji',
      'konu': 'Madde Geçişleri',
      'file': 'assets/tyt_biyoloji/madde_gecisleri.json'
    },

    // TYT FİZİK
    {
      'exam': 'TYT',
      'ders': 'Fizik',
      'konu': 'Basınç',
      'file': 'assets/tyt_fizik/basinc.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Fizik',
      'konu': 'Bilimine Giriş',
      'file': 'assets/tyt_fizik/bilimine_giris.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Fizik',
      'konu': 'Dalgalar',
      'file': 'assets/tyt_fizik/dalgalar.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Fizik',
      'konu': 'Dinamik',
      'file': 'assets/tyt_fizik/dinamik.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Fizik',
      'konu': 'Elektrik Akımı ve Devreler',
      'file': 'assets/tyt_fizik/elektrik_akimi_ve_devreler.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Fizik',
      'konu': 'Elektriksel Enerji ve Güç',
      'file': 'assets/tyt_fizik/elektriksel_enerji_ve_guc.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Fizik',
      'konu': 'Elektrostatik',
      'file': 'assets/tyt_fizik/elektrostatik.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Fizik',
      'konu': 'Hareket ve Kuvvet',
      'file': 'assets/tyt_fizik/hareket_ve_kuvvet.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Fizik',
      'konu': 'Isı Sıcaklık ve Genleşme',
      'file': 'assets/tyt_fizik/isi_sicaklik_ve_genlesme.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Fizik',
      'konu': 'İş Güç ve Enerji',
      'file': 'assets/tyt_fizik/is_guc_ve_enerji.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Fizik',
      'konu': 'Madde ve Özellikleri',
      'file': 'assets/tyt_fizik/madde_ve_ozellikleri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Fizik',
      'konu': 'Manyetizma',
      'file': 'assets/tyt_fizik/manyetizma.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Fizik',
      'konu': 'Optik',
      'file': 'assets/tyt_fizik/optik.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Fizik',
      'konu': 'Sıvıların Kaldırma Kuvveti',
      'file': 'assets/tyt_fizik/sivilarin_kaldirma_kuvveti.json'
    },

    // TYT KİMYA
    {
      'exam': 'TYT',
      'ders': 'Kimya',
      'konu': 'Asit Baz Dengesi',
      'file': 'assets/tyt_kimya/asit_baz_dengesi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Kimya',
      'konu': 'Atomun Yapısı',
      'file': 'assets/tyt_kimya/atomun_yapisi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Kimya',
      'konu': 'Bilimi',
      'file': 'assets/tyt_kimya/bilimi.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Kimya',
      'konu': 'Her Yerde',
      'file': 'assets/tyt_kimya/her_yerde.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Kimya',
      'konu': 'Karışımlar',
      'file': 'assets/tyt_kimya/karisimlar.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Kimya',
      'konu': 'Kimyanın Temel Kanunları',
      'file': 'assets/tyt_kimya/kimyanin_temel_kanunlari.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Kimya',
      'konu': 'Kimyasal Hesaplamalar',
      'file': 'assets/tyt_kimya/kimyasal_hesaplamalar.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Kimya',
      'konu': 'Kimyasal Türler Arası Etkileşim',
      'file': 'assets/tyt_kimya/kimyasal_turler_arasi_etkilesim.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Kimya',
      'konu': 'Maddenin Halleri',
      'file': 'assets/tyt_kimya/maddenin_halleri.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Kimya',
      'konu': 'Periyodik Sistem',
      'file': 'assets/tyt_kimya/periyodik_sistem.json'
    },
    {
      'exam': 'TYT',
      'ders': 'Kimya',
      'konu': 'Sıvı Çözeltiler',
      'file': 'assets/tyt_kimya/sivi_cozeltiler.json'
    },

    // ──────────────────────────────────────────────────────────────────────────
    // AYT SAYISAL BÖLÜMÜ
    // ──────────────────────────────────────────────────────────────────────────
    // AYT SAYISAL BİYOLOJİ
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Bitki Biyolojisi',
      'file': 'assets/ayt_sayisal_biyoloji/bitki_biyolojisi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Canlılar ve Çevre',
      'file': 'assets/ayt_sayisal_biyoloji/canlilar_ve_cevre.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Canlılık ve Enerji',
      'file': 'assets/ayt_sayisal_biyoloji/canlilik_ve_enerji.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Destek ve Hareket Sistemi',
      'file': 'assets/ayt_sayisal_biyoloji/destek_ve_hareket_sistemi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Dolaşım ve Bağışıklık Sistemi',
      'file': 'assets/ayt_sayisal_biyoloji/dolasim_ve_bagisiklilik_sistemi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Duyu Organları',
      'file': 'assets/ayt_sayisal_biyoloji/duyu_organlari.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Endokrin Sistem',
      'file': 'assets/ayt_sayisal_biyoloji/endokrin_sistem.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Fotosentez ve Kemosentez',
      'file': 'assets/ayt_sayisal_biyoloji/fotosentez_ve_kemosentez.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Genetik Şifre ve Protein Sentezi',
      'file':
          'assets/ayt_sayisal_biyoloji/genetik_sifre_ve_protein_sentezi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Hücresel Solunum',
      'file': 'assets/ayt_sayisal_biyoloji/hucresel_solunum.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Komünite ve Popülasyon Ekolojisi',
      'file':
          'assets/ayt_sayisal_biyoloji/komunite_ve_populasyon_ekolojisi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Nükleik Asitler',
      'file': 'assets/ayt_sayisal_biyoloji/nukleik_asitler.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Sindirim Sistemi',
      'file': 'assets/ayt_sayisal_biyoloji/sindirim_sistemi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Sinir Sistemi',
      'file': 'assets/ayt_sayisal_biyoloji/sinir_sistemi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Solunum Sistemi',
      'file': 'assets/ayt_sayisal_biyoloji/solunum_sistemi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Üreme Sistemi ve Embriyonik Gelişim',
      'file':
          'assets/ayt_sayisal_biyoloji/ureme_sistemi_ve_embriyonik_gelisim.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Biyoloji',
      'konu': 'Üriner Sistem',
      'file': 'assets/ayt_sayisal_biyoloji/uriner_sistem.json'
    },

    // AYT SAYISAL FİZİK
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Atışlar',
      'file': 'assets/ayt_sayisal_fizik/atislar.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Atom Modelleri',
      'file': 'assets/ayt_sayisal_fizik/atom_modelleri.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Basit Harmonik Hareket',
      'file': 'assets/ayt_sayisal_fizik/basit_harmonik_hareket.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Basit Makineler',
      'file': 'assets/ayt_sayisal_fizik/basit_makineler.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Büyük Patlama ve Parçacık Fiziği',
      'file': 'assets/ayt_sayisal_fizik/buyuk_patlama_ve_parcacik_fizigi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Dalga Mekaniği ve Elektromanyetik Dalgalar',
      'file':
          'assets/ayt_sayisal_fizik/dalga_mekanigi_ve_elektromanyetik_dalgalar.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Dönme Yuvarlanma ve Açısal Momentum',
      'file':
          'assets/ayt_sayisal_fizik/donme_yuvarlanma_ve_acisal_momentum.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Düzgün Çembersel Hareket',
      'file': 'assets/ayt_sayisal_fizik/duzgun_cembersel_hareket.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Elektrik Alan ve Potansiyel',
      'file': 'assets/ayt_sayisal_fizik/elektrik_alan_ve_potansiyel.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Fotoelektrik Olay ve Compton Olayı',
      'file': 'assets/ayt_sayisal_fizik/fotoelektrik_olay_ve_compton_olayi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Hareket',
      'file': 'assets/ayt_sayisal_fizik/hareket.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'İndüksiyon Alternatif Akım ve Transformatörler',
      'file':
          'assets/ayt_sayisal_fizik/induksiyon_alternatif_akim_ve_transformatorler.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'İş Güç ve Enerji',
      'file': 'assets/ayt_sayisal_fizik/is_guc_ve_enerji.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'İtme ve Çizgisel Momentum',
      'file': 'assets/ayt_sayisal_fizik/itme_ve_cizgisel_momentum.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Kara Cisim Işıması',
      'file': 'assets/ayt_sayisal_fizik/kara_cisim_isimasi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Kütle Çekim Merkezi ve Açısal Momentum',
      'file':
          'assets/ayt_sayisal_fizik/kutle_cekim_merkezi_ve_acisal_momentum.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Kütle Çekim ve Kepler Yasaları',
      'file': 'assets/ayt_sayisal_fizik/kutle_cekim_ve_kepler_yasalari.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Kuvvet Tork ve Denge',
      'file': 'assets/ayt_sayisal_fizik/kuvvet_tork_ve_denge.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Manyetik Alan ve Manyetik Kuvvet',
      'file': 'assets/ayt_sayisal_fizik/manyetik_alan_ve_manyetik_kuvvet.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Modern Fiziğin Teknolojideki Uygulamaları',
      'file':
          'assets/ayt_sayisal_fizik/modern_fizigin_teknolojideki_uygulamalari.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Newton\'un Hareket Yasaları',
      'file': 'assets/ayt_sayisal_fizik/newton_un_hareket_yasalari.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Özel Görelilik',
      'file': 'assets/ayt_sayisal_fizik/ozel_gorelilik.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Paralel Levhalar ve Sığa',
      'file': 'assets/ayt_sayisal_fizik/paralel_levhalar_ve_siga.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Fizik',
      'konu': 'Vektörler',
      'file': 'assets/ayt_sayisal_fizik/vektorler.json'
    },

    // AYT SAYISAL KİMYA
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Asit Baz Dengesi',
      'file': 'assets/ayt_sayisal_kimya/asit_baz_dengesi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Atomun Yapısı',
      'file': 'assets/ayt_sayisal_kimya/atomun_yapisi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Bilimi',
      'file': 'assets/ayt_sayisal_kimya/bilimi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Çözünürlük Dengesi',
      'file': 'assets/ayt_sayisal_kimya/cozunurluk_dengesi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Gazlar',
      'file': 'assets/ayt_sayisal_kimya/gazlar.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Kimyasal Hesaplamalar',
      'file': 'assets/ayt_sayisal_kimya/kimyasal_hesaplamalar.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Kimyasal Tepkimelerde Denge',
      'file': 'assets/ayt_sayisal_kimya/kimyasal_tepkimelerde_denge.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Kimyasal Tepkimelerde Enerji',
      'file': 'assets/ayt_sayisal_kimya/kimyasal_tepkimelerde_enerji.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Kimyasal Tepkimelerde Hız',
      'file': 'assets/ayt_sayisal_kimya/kimyasal_tepkimelerde_hiz.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Kimyasal Türler Arası Etkileşim',
      'file': 'assets/ayt_sayisal_kimya/kimyasal_turler_arasi_etkilesim.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Modern Atom Teorisi',
      'file': 'assets/ayt_sayisal_kimya/modern_atom_teorisi.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Organik Kimya',
      'file': 'assets/ayt_sayisal_kimya/organik_kimya.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Periyodik Sistem',
      'file': 'assets/ayt_sayisal_kimya/periyodik_sistem.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Sıvı Çözeltiler',
      'file': 'assets/ayt_sayisal_kimya/sivi_cozeltiler.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Kimya',
      'konu': 'Ve Elektrik',
      'file': 'assets/ayt_sayisal_kimya/ve_elektrik.json'
    },

    // AYT SAYISAL MATEMATİK
    {
      'exam': 'AYT Sayısal',
      'ders': 'Matematik',
      'konu': 'Bölme ve Bölünebilme Kuralları',
      'file': 'assets/ayt_sayisal_matematik/bolme_ve_bolunebilme_kurallari.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Matematik',
      'konu': 'Diziler',
      'file': 'assets/ayt_sayisal_matematik/diziler.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Matematik',
      'konu': 'Ebob Ekok',
      'file': 'assets/ayt_sayisal_matematik/ebob_ekok.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Matematik',
      'konu': 'İkinci Dereceden Denklemler Parabol ve Eşitsizlikler',
      'file':
          'assets/ayt_sayisal_matematik/ikinci_dereceden_denklemler_parabol_ve_esitsizlikler.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Matematik',
      'konu': 'İntegral',
      'file': 'assets/ayt_sayisal_matematik/integral.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Matematik',
      'konu': 'Karmaşık Sayılar',
      'file': 'assets/ayt_sayisal_matematik/karmasik_sayilar.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Matematik',
      'konu': 'Limit',
      'file': 'assets/ayt_sayisal_matematik/limit.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Matematik',
      'konu': 'Logaritma',
      'file': 'assets/ayt_sayisal_matematik/logaritma.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Matematik',
      'konu': 'Parabol',
      'file': 'assets/ayt_sayisal_matematik/parabol.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Matematik',
      'konu': 'Permütasyon Kombinasyon Olasılık Binom',
      'file':
          'assets/ayt_sayisal_matematik/permutasyon_kombinasyon_olasilik_binom.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Matematik',
      'konu': 'Polinom',
      'file': 'assets/ayt_sayisal_matematik/polinom.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Matematik',
      'konu': 'Sayı Basamakları',
      'file': 'assets/ayt_sayisal_matematik/sayi_basamaklari.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Matematik',
      'konu': 'Trigonometri',
      'file': 'assets/ayt_sayisal_matematik/trigonometri.json'
    },
    {
      'exam': 'AYT Sayısal',
      'ders': 'Matematik',
      'konu': 'Türev',
      'file': 'assets/ayt_sayisal_matematik/turev.json'
    },

    // ──────────────────────────────────────────────────────────────────────────
    // AYT EŞİT AĞIRLIK BÖLÜMÜ
    // ──────────────────────────────────────────────────────────────────────────
    // AYT EA MATEMATİK
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Matematik',
      'konu': 'Bölme ve Bölünebilme Kuralları',
      'file':
          'assets/ayt_esitagirlik_matematik/bolme_ve_bolunebilme_kurallari.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Matematik',
      'konu': 'Diziler',
      'file': 'assets/ayt_esitagirlik_matematik/diziler.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Matematik',
      'konu': 'Ebob Ekok',
      'file': 'assets/ayt_esitagirlik_matematik/ebob_ekok.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Matematik',
      'konu': 'İkinci Dereceden Denklemler Parabol ve Eşitsizlikler',
      'file':
          'assets/ayt_esitagirlik_matematik/ikinci_dereceden_denklemler_parabol_ve_esitsizlikler.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Matematik',
      'konu': 'İntegral',
      'file': 'assets/ayt_esitagirlik_matematik/integral.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Matematik',
      'konu': 'Karmaşık Sayılar',
      'file': 'assets/ayt_esitagirlik_matematik/karmasik_sayilar.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Matematik',
      'konu': 'Limit',
      'file': 'assets/ayt_esitagirlik_matematik/limit.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Matematik',
      'konu': 'Logaritma',
      'file': 'assets/ayt_esitagirlik_matematik/logaritma.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Matematik',
      'konu': 'Parabol',
      'file': 'assets/ayt_esitagirlik_matematik/parabol.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Matematik',
      'konu': 'Permütasyon Kombinasyon Olasılık Binom',
      'file':
          'assets/ayt_esitagirlik_matematik/permutasyon_kombinasyon_olasilik_binom.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Matematik',
      'konu': 'Polinom',
      'file': 'assets/ayt_esitagirlik_matematik/polinom.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Matematik',
      'konu': 'Sayı Basamakları',
      'file': 'assets/ayt_esitagirlik_matematik/sayi_basamaklari.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Matematik',
      'konu': 'Trigonometri',
      'file': 'assets/ayt_esitagirlik_matematik/trigonometri.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Matematik',
      'konu': 'Türev',
      'file': 'assets/ayt_esitagirlik_matematik/turev.json'
    },

    // AYT EA EDEBİYAT
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Edebiyat',
      'konu': 'Akımları',
      'file': 'assets/ayt_esitagirlik_edebiyat/akimlari.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Edebiyat',
      'konu': 'Anlam Bilgisi',
      'file': 'assets/ayt_esitagirlik_edebiyat/anlam_bilgisi.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Edebiyat',
      'konu': 'Cumhuriyet Dönemi Edebiyatı',
      'file': 'assets/ayt_esitagirlik_edebiyat/cumhuriyet_donemi_edebiyati.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Edebiyat',
      'konu': 'Dil Bilgisi',
      'file': 'assets/ayt_esitagirlik_edebiyat/dil_bilgisi.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Edebiyat',
      'konu': 'Divan Edebiyatı',
      'file': 'assets/ayt_esitagirlik_edebiyat/divan_edebiyati.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Edebiyat',
      'konu': 'Edebi Sanatlar',
      'file': 'assets/ayt_esitagirlik_edebiyat/edebi_sanatlar.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Edebiyat',
      'konu': 'Halk Edebiyatı',
      'file': 'assets/ayt_esitagirlik_edebiyat/halk_edebiyati.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Edebiyat',
      'konu': 'İslamiyet Öncesi Türk Edebiyatı ve Geçiş Dönemi',
      'file':
          'assets/ayt_esitagirlik_edebiyat/islamiyet_oncesi_turk_edebiyati_ve_gecis_donemi.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Edebiyat',
      'konu': 'Metinlerin Türleri',
      'file': 'assets/ayt_esitagirlik_edebiyat/metinlerin_turleri.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Edebiyat',
      'konu': 'Milli Edebiyat',
      'file': 'assets/ayt_esitagirlik_edebiyat/milli_edebiyat.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Edebiyat',
      'konu': 'Servet-i Fünun ve Fecr-i Ati Edebiyatı',
      'file':
          'assets/ayt_esitagirlik_edebiyat/servet_i_funun_ve_fecr_i_ati_edebiyati.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Edebiyat',
      'konu': 'Şiir Bilgisi',
      'file': 'assets/ayt_esitagirlik_edebiyat/siir_bilgisi.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Edebiyat',
      'konu': 'Tanzimat Edebiyatı',
      'file': 'assets/ayt_esitagirlik_edebiyat/tanzimat_edebiyati.json'
    },

    // AYT EA TARİH
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Atatürkçülük ve Türk İnkılabı',
      'file': 'assets/ayt_esitagirlik_tarih/ataturkculuk_ve_turk_inkilabi.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Beylikten Devlete Osmanlı Medeniyeti',
      'file':
          'assets/ayt_esitagirlik_tarih/beylikten_devlete_osmanli_medeniyeti.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Beylikten Devlete Osmanlı Siyaseti',
      'file':
          'assets/ayt_esitagirlik_tarih/beylikten_devlete_osmanli_siyaseti.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti',
      'file':
          'assets/ayt_esitagirlik_tarih/degisen_dunya_dengeleri_karsisinda_osmanli_siyaseti.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Değişim Çağında Avrupa ve Osmanlı',
      'file':
          'assets/ayt_esitagirlik_tarih/degisim_caginda_avrupa_ve_osmanli.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Devletleşme Sürecinde Savaşçılar ve Askerler',
      'file':
          'assets/ayt_esitagirlik_tarih/devletlesme_surecinde_savascilar_ve_askerler.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Devrimler Çağında Değişen Devlet Toplum İlişkileri',
      'file':
          'assets/ayt_esitagirlik_tarih/devrimler_caginda_degisen_devlet_toplum_iliskileri.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Dünya Gücü Osmanlı ve Türk İslam Tarihi',
      'file':
          'assets/ayt_esitagirlik_tarih/dunya_gucu_osmanli_ve_turk_islam_tarihi.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'II. Dünya Savaşı Sonrasında Türkiye ve Dünya',
      'file':
          'assets/ayt_esitagirlik_tarih/ii_dunya_savasi_sonrasinda_turkiye_ve_dunya.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'II. Dünya Savaşı Sürecinde Türkiye ve Dünya',
      'file':
          'assets/ayt_esitagirlik_tarih/ii_dunya_savasi_surecinde_turkiye_ve_dunya.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'İki Savaş Arasındaki Dönemde Türkiye ve Dünya',
      'file':
          'assets/ayt_esitagirlik_tarih/iki_savas_arasindaki_donemde_turkiye_ve_dunya.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'İlk ve Orta Çağlarda Türk Dünyası',
      'file':
          'assets/ayt_esitagirlik_tarih/ilk_ve_orta_caglarda_turk_dunyasi.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'İnsanlığın İlk Dönemleri',
      'file': 'assets/ayt_esitagirlik_tarih/insanligin_ilk_donemleri.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'İslam Medeniyetinin Doğuşu ve İlk İslam Devletleri',
      'file':
          'assets/ayt_esitagirlik_tarih/islam_medeniyetinin_dogusu_ve_ilk_islam_devletleri.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Klasik Çağda Osmanlı Toplum Düzeni',
      'file':
          'assets/ayt_esitagirlik_tarih/klasik_cagda_osmanli_toplum_duzeni.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Milli Mücadele',
      'file': 'assets/ayt_esitagirlik_tarih/milli_mucadele.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Orta Çağ\'da Dünya',
      'file': 'assets/ayt_esitagirlik_tarih/orta_cag_da_dunya.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Sermaye ve Emek',
      'file': 'assets/ayt_esitagirlik_tarih/sermaye_ve_emek.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Sultan ve Osmanlı Merkez Teşkilatı',
      'file':
          'assets/ayt_esitagirlik_tarih/sultan_ve_osmanli_merkez_teskilati.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Toplumsal Devrim Çağında Dünya ve Türkiye',
      'file':
          'assets/ayt_esitagirlik_tarih/toplumsal_devrim_caginda_dunya_ve_turkiye.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Türklerin İslamiyet\'i Kabulü ve İlk Türk İslam Devletleri',
      'file':
          'assets/ayt_esitagirlik_tarih/turklerin_islamiyet_i_kabulu_ve_ilk_turk_islam_devletleri.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Uluslararası İlişkilerde Denge Stratejisi',
      'file':
          'assets/ayt_esitagirlik_tarih/uluslararasi_iliskilerde_denge_stratejisi_1774_1914_.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Ve Zaman',
      'file': 'assets/ayt_esitagirlik_tarih/ve_zaman.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'XIX. ve XX. Yüzyılda Değişen Gündelik Hayat',
      'file':
          'assets/ayt_esitagirlik_tarih/xix._ve_xx._yuzyilda_degisen_gundelik_hayat.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya',
      'file':
          'assets/ayt_esitagirlik_tarih/xx._yuzyil_baslarinda_osmanli_devleti_ve_dunya.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'XXI. Yüzyılın Eşiğinde Türkiye ve Dünya',
      'file':
          'assets/ayt_esitagirlik_tarih/xxi._yuzyilin_esiginde_turkiye_ve_dunya.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Tarih',
      'konu': 'Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi',
      'file':
          'assets/ayt_esitagirlik_tarih/yerlesme_ve_devletlesme_surecinde_selcuklu_turkiyesi.json'
    },

    // AYT EA COĞRAFYA
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Bölgeleri',
      'file': 'assets/ayt_esitagirlik_cografya/bolgeleri.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Bölgeler ve Ülkeler',
      'file': 'assets/ayt_esitagirlik_cografya/bolgeler_ve_ulkeler.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Çevre ve Toplum',
      'file': 'assets/ayt_esitagirlik_cografya/cevre_ve_toplum.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Dünyanın Şekli ve Hareketleri',
      'file':
          'assets/ayt_esitagirlik_cografya/dunya_nin_sekli_ve_hareketleri.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Ekonomik Faaliyetler ve Doğal Kaynaklar',
      'file':
          'assets/ayt_esitagirlik_cografya/ekonomik_faaliyetler_ve_dogal_kaynaklar.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Ekosistem',
      'file': 'assets/ayt_esitagirlik_cografya/ekosistem.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Göç ve Şehirleşme',
      'file': 'assets/ayt_esitagirlik_cografya/goc_ve_sehirlesme.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Harita Bilgisi',
      'file': 'assets/ayt_esitagirlik_cografya/harita_bilgisi.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'İç ve Dış Kuvvetler',
      'file': 'assets/ayt_esitagirlik_cografya/ic_ve_dis_kuvvetler.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'İklim ve Yer Şekilleri',
      'file': 'assets/ayt_esitagirlik_cografya/iklim_ve_yer_sekilleri.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Küresel Ticaret',
      'file': 'assets/ayt_esitagirlik_cografya/kuresel_ticaret.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Nüfus Politikaları',
      'file': 'assets/ayt_esitagirlik_cografya/nufus_politikalari.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Türkiye\'de Ekonomi',
      'file': 'assets/ayt_esitagirlik_cografya/turkiye_de_ekonomi.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Türkiye\'de Nüfus ve Yerleşme',
      'file':
          'assets/ayt_esitagirlik_cografya/turkiye_de_nufus_ve_yerlesme.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Türkiye\'nin Coğrafi Konumu',
      'file': 'assets/ayt_esitagirlik_cografya/turkiye_nin_cografi_konumu.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Türkiye\'nin İşlevsel Bölgeleri ve Kalkınma Projeleri',
      'file':
          'assets/ayt_esitagirlik_cografya/turkiye_nin_islevsel_bolgeleri_ve_kalkinma_projeleri.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Ülkeler Arası Etkileşimler',
      'file': 'assets/ayt_esitagirlik_cografya/ulkeler_arasi_etkilesimler.json'
    },
    {
      'exam': 'AYT Eşit Ağırlık',
      'ders': 'Coğrafya',
      'konu': 'Uluslararası Örgütler',
      'file': 'assets/ayt_esitagirlik_cografya/uluslararasi_orgutler.json'
    },

    // ──────────────────────────────────────────────────────────────────────────
    // AYT SÖZEL BÖLÜMÜ
    // ──────────────────────────────────────────────────────────────────────────
    // AYT SÖZEL EDEBİYAT, TARİH, COĞRAFYA (EA'dan çekiliyor)
    {
      'exam': 'AYT Sözel',
      'ders': 'Edebiyat',
      'konu': 'Akımları',
      'file': 'assets/ayt_esitagirlik_edebiyat/akimlari.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Edebiyat',
      'konu': 'Anlam Bilgisi',
      'file': 'assets/ayt_esitagirlik_edebiyat/anlam_bilgisi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Edebiyat',
      'konu': 'Cumhuriyet Dönemi Edebiyatı',
      'file': 'assets/ayt_esitagirlik_edebiyat/cumhuriyet_donemi_edebiyati.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Edebiyat',
      'konu': 'Dil Bilgisi',
      'file': 'assets/ayt_esitagirlik_edebiyat/dil_bilgisi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Edebiyat',
      'konu': 'Divan Edebiyatı',
      'file': 'assets/ayt_esitagirlik_edebiyat/divan_edebiyati.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Edebiyat',
      'konu': 'Edebi Sanatlar',
      'file': 'assets/ayt_esitagirlik_edebiyat/edebi_sanatlar.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Edebiyat',
      'konu': 'Halk Edebiyatı',
      'file': 'assets/ayt_esitagirlik_edebiyat/halk_edebiyati.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Edebiyat',
      'konu': 'İslamiyet Öncesi Türk Edebiyatı ve Geçiş Dönemi',
      'file':
          'assets/ayt_esitagirlik_edebiyat/islamiyet_oncesi_turk_edebiyati_ve_gecis_donemi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Edebiyat',
      'konu': 'Metinlerin Türleri',
      'file': 'assets/ayt_esitagirlik_edebiyat/metinlerin_turleri.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Edebiyat',
      'konu': 'Milli Edebiyat',
      'file': 'assets/ayt_esitagirlik_edebiyat/milli_edebiyat.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Edebiyat',
      'konu': 'Servet-i Fünun ve Fecr-i Ati Edebiyatı',
      'file':
          'assets/ayt_esitagirlik_edebiyat/servet_i_funun_ve_fecr_i_ati_edebiyati.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Edebiyat',
      'konu': 'Şiir Bilgisi',
      'file': 'assets/ayt_esitagirlik_edebiyat/siir_bilgisi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Edebiyat',
      'konu': 'Tanzimat Edebiyatı',
      'file': 'assets/ayt_esitagirlik_edebiyat/tanzimat_edebiyati.json'
    },

    // SÖZEL TARİH
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Atatürkçülük ve Türk İnkılabı',
      'file': 'assets/ayt_esitagirlik_tarih/ataturkculuk_ve_turk_inkilabi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Beylikten Devlete Osmanlı Medeniyeti',
      'file':
          'assets/ayt_esitagirlik_tarih/beylikten_devlete_osmanli_medeniyeti.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Beylikten Devlete Osmanlı Siyaseti',
      'file':
          'assets/ayt_esitagirlik_tarih/beylikten_devlete_osmanli_siyaseti.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti',
      'file':
          'assets/ayt_esitagirlik_tarih/degisen_dunya_dengeleri_karsisinda_osmanli_siyaseti.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Değişim Çağında Avrupa ve Osmanlı',
      'file':
          'assets/ayt_esitagirlik_tarih/degisim_caginda_avrupa_ve_osmanli.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Devletleşme Sürecinde Savaşçılar ve Askerler',
      'file':
          'assets/ayt_esitagirlik_tarih/devletlesme_surecinde_savascilar_ve_askerler.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Devrimler Çağında Değişen Devlet Toplum İlişkileri',
      'file':
          'assets/ayt_esitagirlik_tarih/devrimler_caginda_degisen_devlet_toplum_iliskileri.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Dünya Gücü Osmanlı ve Türk İslam Tarihi',
      'file':
          'assets/ayt_esitagirlik_tarih/dunya_gucu_osmanli_ve_turk_islam_tarihi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'II. Dünya Savaşı Sonrasında Türkiye ve Dünya',
      'file':
          'assets/ayt_esitagirlik_tarih/ii_dunya_savasi_sonrasinda_turkiye_ve_dunya.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'II. Dünya Savaşı Sürecinde Türkiye ve Dünya',
      'file':
          'assets/ayt_esitagirlik_tarih/ii_dunya_savasi_surecinde_turkiye_ve_dunya.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'İki Savaş Arasındaki Dönemde Türkiye ve Dünya',
      'file':
          'assets/ayt_esitagirlik_tarih/iki_savas_arasindaki_donemde_turkiye_ve_dunya.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'İlk ve Orta Çağlarda Türk Dünyası',
      'file':
          'assets/ayt_esitagirlik_tarih/ilk_ve_orta_caglarda_turk_dunyasi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'İnsanlığın İlk Dönemleri',
      'file': 'assets/ayt_esitagirlik_tarih/insanligin_ilk_donemleri.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'İslam Medeniyetinin Doğuşu ve İlk İslam Devletleri',
      'file':
          'assets/ayt_esitagirlik_tarih/islam_medeniyetinin_dogusu_ve_ilk_islam_devletleri.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Klasik Çağda Osmanlı Toplum Düzeni',
      'file':
          'assets/ayt_esitagirlik_tarih/klasik_cagda_osmanli_toplum_duzeni.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Milli Mücadele',
      'file': 'assets/ayt_esitagirlik_tarih/milli_mucadele.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Orta Çağ\'da Dünya',
      'file': 'assets/ayt_esitagirlik_tarih/orta_cag_da_dunya.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Sermaye ve Emek',
      'file': 'assets/ayt_esitagirlik_tarih/sermaye_ve_emek.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Sultan ve Osmanlı Merkez Teşkilatı',
      'file':
          'assets/ayt_esitagirlik_tarih/sultan_ve_osmanli_merkez_teskilati.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Toplumsal Devrim Çağında Dünya ve Türkiye',
      'file':
          'assets/ayt_esitagirlik_tarih/toplumsal_devrim_caginda_dunya_ve_turkiye.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Türklerin İslamiyet\'i Kabulü ve İlk Türk İslam Devletleri',
      'file':
          'assets/ayt_esitagirlik_tarih/turklerin_islamiyet_i_kabulu_ve_ilk_turk_islam_devletleri.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Uluslararası İlişkilerde Denge Stratejisi',
      'file':
          'assets/ayt_esitagirlik_tarih/uluslararasi_iliskilerde_denge_stratejisi_1774_1914_.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Ve Zaman',
      'file': 'assets/ayt_esitagirlik_tarih/ve_zaman.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'XIX. ve XX. Yüzyılda Değişen Gündelik Hayat',
      'file':
          'assets/ayt_esitagirlik_tarih/xix._ve_xx._yuzyilda_degisen_gundelik_hayat.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya',
      'file':
          'assets/ayt_esitagirlik_tarih/xx._yuzyil_baslarinda_osmanli_devleti_ve_dunya.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'XXI. Yüzyılın Eşiğinde Türkiye ve Dünya',
      'file':
          'assets/ayt_esitagirlik_tarih/xxi._yuzyilin_esiginde_turkiye_ve_dunya.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Tarih',
      'konu': 'Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi',
      'file':
          'assets/ayt_esitagirlik_tarih/yerlesme_ve_devletlesme_surecinde_selcuklu_turkiyesi.json'
    },

    // SÖZEL COĞRAFYA
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Bölgeleri',
      'file': 'assets/ayt_esitagirlik_cografya/bolgeleri.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Bölgeler ve Ülkeler',
      'file': 'assets/ayt_esitagirlik_cografya/bolgeler_ve_ulkeler.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Çevre ve Toplum',
      'file': 'assets/ayt_esitagirlik_cografya/cevre_ve_toplum.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Dünyanın Şekli ve Hareketleri',
      'file':
          'assets/ayt_esitagirlik_cografya/dunya_nin_sekli_ve_hareketleri.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Ekonomik Faaliyetler ve Doğal Kaynaklar',
      'file':
          'assets/ayt_esitagirlik_cografya/ekonomik_faaliyetler_ve_dogal_kaynaklar.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Ekosistem',
      'file': 'assets/ayt_esitagirlik_cografya/ekosistem.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Göç ve Şehirleşme',
      'file': 'assets/ayt_esitagirlik_cografya/goc_ve_sehirlesme.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Harita Bilgisi',
      'file': 'assets/ayt_esitagirlik_cografya/harita_bilgisi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'İç ve Dış Kuvvetler',
      'file': 'assets/ayt_esitagirlik_cografya/ic_ve_dis_kuvvetler.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'İklim ve Yer Şekilleri',
      'file': 'assets/ayt_esitagirlik_cografya/iklim_ve_yer_sekilleri.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Küresel Ticaret',
      'file': 'assets/ayt_esitagirlik_cografya/kuresel_ticaret.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Nüfus Politikaları',
      'file': 'assets/ayt_esitagirlik_cografya/nufus_politikalari.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Türkiye\'de Ekonomi',
      'file': 'assets/ayt_esitagirlik_cografya/turkiye_de_ekonomi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Türkiye\'de Nüfus ve Yerleşme',
      'file':
          'assets/ayt_esitagirlik_cografya/turkiye_de_nufus_ve_yerlesme.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Türkiye\'nin Coğrafi Konumu',
      'file': 'assets/ayt_esitagirlik_cografya/turkiye_nin_cografi_konumu.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Türkiye\'nin İşlevsel Bölgeleri ve Kalkınma Projeleri',
      'file':
          'assets/ayt_esitagirlik_cografya/turkiye_nin_islevsel_bolgeleri_ve_kalkinma_projeleri.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Ülkeler Arası Etkileşimler',
      'file': 'assets/ayt_esitagirlik_cografya/ulkeler_arasi_etkilesimler.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Coğrafya',
      'konu': 'Uluslararası Örgütler',
      'file': 'assets/ayt_esitagirlik_cografya/uluslararasi_orgutler.json'
    },

    // AYT SÖZEL DİN
    {
      'exam': 'AYT Sözel',
      'ders': 'Din Kültürü',
      'konu': 'Allah İnsan İlişkisi',
      'file': 'assets/ayt_sozel_din/allah_insan_iliskisi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Din Kültürü',
      'konu': 'Anadolu\'da İslam',
      'file': 'assets/ayt_sozel_din/anadoluda_islam.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Din Kültürü',
      'konu': 'Dünya ve Ahiret',
      'file': 'assets/ayt_sozel_din/dunya_ve_ahiret.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Din Kültürü',
      'konu': 'Güncel Dini Meseleler',
      'file': 'assets/ayt_sozel_din/guncel_dini_meseleler.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Din Kültürü',
      'konu': 'Hint ve Çin Dinleri',
      'file': 'assets/ayt_sozel_din/hint_ve_cin_dinleri.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Din Kültürü',
      'konu': 'İnançla İlgili Meseleler',
      'file': 'assets/ayt_sozel_din/inancla_ilgili_meseleler.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Din Kültürü',
      'konu': 'İslam Düşüncesinde Tasavvufi Yorumlar ve Mezhepler',
      'file':
          'assets/ayt_sozel_din/islam_dusuncesinde_tasavvufi_yorumlar_ve_mezhepler.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Din Kültürü',
      'konu': 'İslam ve Bilim',
      'file': 'assets/ayt_sozel_din/islam_ve_bilim.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Din Kültürü',
      'konu': 'Kur\'an\'a Göre Hz. Muhammed',
      'file': 'assets/ayt_sozel_din/kurana_gore_hz_muhammed.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Din Kültürü',
      'konu': 'Kur\'an\'dan Mesajlar',
      'file': 'assets/ayt_sozel_din/kurandan_mesajlar.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Din Kültürü',
      'konu': 'Kur\'an\'da Bazı Kavramlar',
      'file': 'assets/ayt_sozel_din/kuranda_bazi_kavramlar.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Din Kültürü',
      'konu': 'Yahudilik ve Hristiyanlık',
      'file': 'assets/ayt_sozel_din/yahudilik_ve_hristiyanlik.json'
    },

    // AYT SÖZEL FELSEFE
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': '20. Yüzyıl Felsefesi',
      'file': 'assets/ayt_sozel_felsefe/20._yuzyil_felsefesi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Ahlak Felsefesi',
      'file': 'assets/ayt_sozel_felsefe/ahlak_felsefesi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Bilgi Felsefesi',
      'file': 'assets/ayt_sozel_felsefe/bilgi_felsefesi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Birey ve Toplum',
      'file': 'assets/ayt_sozel_felsefe/birey_ve_toplum.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Felsefesi',
      'file': 'assets/ayt_sozel_felsefe/felsefesi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Klasik Mantık',
      'file': 'assets/ayt_sozel_felsefe/klasik_mantik.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Mantığa Giriş',
      'file': 'assets/ayt_sozel_felsefe/mantiga_giris.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Mantık ve Dil',
      'file': 'assets/ayt_sozel_felsefe/mantik_ve_dil.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Öğrenme Bellek Düşünme',
      'file': 'assets/ayt_sozel_felsefe/ogrenme_bellek_dusunme.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Psikolojinin Temel Süreçleri',
      'file': 'assets/ayt_sozel_felsefe/psikolojinin_temel_surecleri.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Psikoloji Bilimini Tanıyalım',
      'file': 'assets/ayt_sozel_felsefe/psikoloji_bilimini_taniyalim.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Ruh Sağlığının Temelleri',
      'file': 'assets/ayt_sozel_felsefe/ruh_sagliginin_temelleri.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Sosyolojiye Giriş',
      'file': 'assets/ayt_sozel_felsefe/sosyolojiye_giris.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Toplumsal Değişme ve Gelişme',
      'file': 'assets/ayt_sozel_felsefe/toplumsal_degisme_ve_gelisme.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Toplumsal Kurumlar',
      'file': 'assets/ayt_sozel_felsefe/toplumsal_kurumlar.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Toplumsal Yapı',
      'file': 'assets/ayt_sozel_felsefe/toplumsal_yapi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Toplum ve Kültür',
      'file': 'assets/ayt_sozel_felsefe/toplum_ve_kultur.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Varlık Felsefesi',
      'file': 'assets/ayt_sozel_felsefe/varlik_felsefesi.json'
    },
    {
      'exam': 'AYT Sözel',
      'ders': 'Felsefe',
      'konu': 'Ve Bilim',
      'file': 'assets/ayt_sozel_felsefe/ve_bilim.json'
    },

    // ──────────────────────────────────────────────────────────────────────────
    // KPSS LİSANS BÖLÜMÜ
    // ──────────────────────────────────────────────────────────────────────────
    // KPSS LİSANS TÜRKÇE
    {
      'exam': 'Lisans',
      'ders': 'Türkçe',
      'konu': 'Anlatım Bozuklukları',
      'file': 'assets/kpss_lisans_turkce/anlatim_bozukluklari.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Türkçe',
      'konu': 'Cümlede Anlam',
      'file': 'assets/kpss_lisans_turkce/cumlede_anlam.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Türkçe',
      'konu': 'Cümlenin Ögeleri',
      'file': 'assets/kpss_lisans_turkce/cumlenin_ogeleri.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Türkçe',
      'konu': 'Cümle Türleri',
      'file': 'assets/kpss_lisans_turkce/cumle_turleri.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Türkçe',
      'konu': 'Dil Bilgisi Ses Olayları',
      'file': 'assets/kpss_lisans_turkce/dil_bilgisi_ses_olaylari.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Türkçe',
      'konu': 'Mantık',
      'file': 'assets/kpss_lisans_turkce/mantik.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Türkçe',
      'konu': 'Noktalama İşaretleri',
      'file': 'assets/kpss_lisans_turkce/noktalama_isaretleri.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Türkçe',
      'konu': 'Paragrafta Anlam',
      'file': 'assets/kpss_lisans_turkce/paragrafta_anlam.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Türkçe',
      'konu': 'Paragrafta Anlatım Biçimi',
      'file': 'assets/kpss_lisans_turkce/paragrafta_anlatim_bicimi.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Türkçe',
      'konu': 'Sözcük Türleri',
      'file': 'assets/kpss_lisans_turkce/sozcuk_turleri.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Türkçe',
      'konu': 'Sözcükte Anlam',
      'file': 'assets/kpss_lisans_turkce/sozcukte_anlam.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Türkçe',
      'konu': 'Sözcükte Yapı',
      'file': 'assets/kpss_lisans_turkce/sozcukte_yapi.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Türkçe',
      'konu': 'Yazım Kuralları',
      'file': 'assets/kpss_lisans_turkce/yazim_kurallari.json'
    },

    // KPSS LİSANS MATEMATİK
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Basit Eşitsizlikler',
      'file': 'assets/kpss_lisans_matematik/basit_esitsizlikler.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Çarpanlara Ayırma',
      'file': 'assets/kpss_lisans_matematik/carpanlara_ayirma.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Denklem Çözme',
      'file': 'assets/kpss_lisans_matematik/denklem_cozme.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Fonksiyonlar',
      'file': 'assets/kpss_lisans_matematik/fonksiyonlar.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'İşlem',
      'file': 'assets/kpss_lisans_matematik/islem.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Köklü Sayılar',
      'file': 'assets/kpss_lisans_matematik/koklu_sayilar.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Kümeler',
      'file': 'assets/kpss_lisans_matematik/kumeler.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Mantık',
      'file': 'assets/kpss_lisans_matematik/mantik.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Mutlak Değer',
      'file': 'assets/kpss_lisans_matematik/mutlak_deger.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Olasılık',
      'file': 'assets/kpss_lisans_matematik/olasilik.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Oran Orantı',
      'file': 'assets/kpss_lisans_matematik/oran_oranti.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Permütasyon Kombinasyon',
      'file': 'assets/kpss_lisans_matematik/permutasyon_kombinasyon.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Problemler',
      'file': 'assets/kpss_lisans_matematik/problemler.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Rasyonel Sayılar Ondalıklı Sayılar',
      'file':
          'assets/kpss_lisans_matematik/rasyonel_sayilar_ondalikli_sayilar.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Temel Kavramlar',
      'file': 'assets/kpss_lisans_matematik/temel_kavramlar.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Matematik',
      'konu': 'Üslü Sayılar',
      'file': 'assets/kpss_lisans_matematik/uslu_sayilar.json'
    },

    // KPSS LİSANS TARİH
    {
      'exam': 'Lisans',
      'ders': 'Tarih',
      'konu': '17 Yüzyıl Osmanlı Devleti Duraklama Dönemi',
      'file':
          'assets/kpss_lisans_tarih/17_yuzyil_osmanli_devleti_duraklama_donemi.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Tarih',
      'konu': '18 Yüzyıl Osmanlı Devleti Gerileme Dönemi',
      'file':
          'assets/kpss_lisans_tarih/18_yuzyil_osmanli_devleti_gerileme_donemi.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Tarih',
      'konu': '19 Yüzyıl Osmanlı Devleti Dağılma Dönemi',
      'file':
          'assets/kpss_lisans_tarih/19_yuzyil_osmanli_devleti_dagilma_donemi.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Tarih',
      'konu': '20 Yüzyıl Osmanlı Devleti',
      'file': 'assets/kpss_lisans_tarih/20_yuzyil_osmanli_devleti.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Tarih',
      'konu': 'Atatürk Dönemi İç ve Dış Politikalar',
      'file':
          'assets/kpss_lisans_tarih/ataturk_donemi_ic_ve_dis_politikalar.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Tarih',
      'konu': 'Çağdaş Türk ve Dünya Tarihi',
      'file': 'assets/kpss_lisans_tarih/cagdas_turk_ve_dunya_tarihi.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Tarih',
      'konu': 'İlk Türk İslam Devletleri',
      'file': 'assets/kpss_lisans_tarih/ilk_turk_islam_devletleri.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Tarih',
      'konu': 'İlk Türk İslam Devletlerinde Kültür ve Medeniyet',
      'file':
          'assets/kpss_lisans_tarih/ilk_turk_islam_devletlerinde_kultur_ve_medeniyet.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Tarih',
      'konu': 'İnkılap Tarihi',
      'file': 'assets/kpss_lisans_tarih/inkilap_tarihi.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Tarih',
      'konu': 'İslamiyet Öncesi Türk Tarihi Soru Bankası',
      'file':
          'assets/kpss_lisans_tarih/islamiyet_oncesi_turk_tarihi_soru_bankasi.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Tarih',
      'konu': 'İslamiyet Öncesi Türk Tarihi',
      'file': 'assets/kpss_lisans_tarih/islam_oncesi_turk_tarihi.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Tarih',
      'konu': 'Milli Mücadele Dönemi',
      'file': 'assets/kpss_lisans_tarih/milli_mucadele_donemi.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Tarih',
      'konu': 'Osmanlı Devleti Kültür ve Medeniyet',
      'file':
          'assets/kpss_lisans_tarih/osmanli_devleti_kultur_ve_medeniyet.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Tarih',
      'konu': 'Osmanlı Devleti Kuruluş ve Yükselme Dönemi',
      'file':
          'assets/kpss_lisans_tarih/osmanli_devleti_kurulus_ve_yukselme_donemi.json'
    },

    // KPSS LİSANS COĞRAFYA
    {
      'exam': 'Lisans',
      'ders': 'Coğrafya',
      'konu': 'Bölgeler Coğrafyası',
      'file': 'assets/kpss_lisans_cografya/bolgeler_cografyasi.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Coğrafya',
      'konu': 'Hayvancılık',
      'file': 'assets/kpss_lisans_cografya/hayvancilik.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Coğrafya',
      'konu': 'Madenler ve Enerji',
      'file': 'assets/kpss_lisans_cografya/madenler_ve_enerji.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Coğrafya',
      'konu': 'Sanayi ve Endüstri',
      'file': 'assets/kpss_lisans_cografya/sanayi_ve_endustri.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Coğrafya',
      'konu': 'Tarım',
      'file': 'assets/kpss_lisans_cografya/tarim.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Coğrafya',
      'konu': 'Ticaret',
      'file': 'assets/kpss_lisans_cografya/ticaret.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Coğrafya',
      'konu': 'Turizm',
      'file': 'assets/kpss_lisans_cografya/turizm.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Coğrafya',
      'konu': 'Türkiye de Nüfus ve Yerleşme',
      'file': 'assets/kpss_lisans_cografya/turkiye_de_nufus_ve_yerlesme.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Coğrafya',
      'konu': 'Türkiye nin Coğrafi Konumu',
      'file': 'assets/kpss_lisans_cografya/turkiye_nin_cografi_konumu.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Coğrafya',
      'konu': 'Türkiye nin Fiziki Özellikleri',
      'file': 'assets/kpss_lisans_cografya/turkiye_nin_fiziki_ozellikleri.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Coğrafya',
      'konu': 'Türkiye nin İklimi ve Bitki Örtüsü',
      'file':
          'assets/kpss_lisans_cografya/turkiye_nin_iklimi_ve_bitki_ortusu.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Coğrafya',
      'konu': 'Ulaşım',
      'file': 'assets/kpss_lisans_cografya/ulasim.json'
    },

    // KPSS LİSANS VATANDAŞLIK
    {
      'exam': 'Lisans',
      'ders': 'Vatandaşlık',
      'konu': 'Anayasal Kavramlar',
      'file': 'assets/kpss_lisans_vatandaslik/anayasal_kavramlar.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Vatandaşlık',
      'konu': 'İdare Hukuku',
      'file': 'assets/kpss_lisans_vatandaslik/idare_hukuku.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Vatandaşlık',
      'konu': 'Temel Hak ve Ödevler',
      'file': 'assets/kpss_lisans_vatandaslik/temel_hak_odevler.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Vatandaşlık',
      'konu': 'Temel Hukuk Kavramları',
      'file': 'assets/kpss_lisans_vatandaslik/temel_hukuk_kavramlari.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Vatandaşlık',
      'konu': 'Türk Anayasa Tarihi',
      'file': 'assets/kpss_lisans_vatandaslik/turk_anayasa_tarihi.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Vatandaşlık',
      'konu': 'Yargı',
      'file': 'assets/kpss_lisans_vatandaslik/yargi.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Vatandaşlık',
      'konu': 'Yasama',
      'file': 'assets/kpss_lisans_vatandaslik/yasama.json'
    },
    {
      'exam': 'Lisans',
      'ders': 'Vatandaşlık',
      'konu': 'Yürütme',
      'file': 'assets/kpss_lisans_vatandaslik/yurutme.json'
    },

    // ──────────────────────────────────────────────────────────────────────────
    // KPSS ÖNLİSANS BÖLÜMÜ
    // ──────────────────────────────────────────────────────────────────────────
    // KPSS ÖNLİSANS COĞRAFYA
    {
      'exam': 'Önlisans',
      'ders': 'Coğrafya',
      'konu': 'Bölgeler Coğrafyası',
      'file': 'assets/kpss_onlisans_cografya/bolgeler_cografyasi.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Coğrafya',
      'konu': 'Hayvancılık',
      'file': 'assets/kpss_onlisans_cografya/hayvancilik.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Coğrafya',
      'konu': 'Madenler ve Enerji Kaynakları',
      'file': 'assets/kpss_onlisans_cografya/madenler_ve_enerji_kaynaklari.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Coğrafya',
      'konu': 'Sanayi ve Endüstri',
      'file': 'assets/kpss_onlisans_cografya/sanayi_ve_endustri.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Coğrafya',
      'konu': 'Tarım',
      'file': 'assets/kpss_onlisans_cografya/tarim.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Coğrafya',
      'konu': 'Ticaret',
      'file': 'assets/kpss_onlisans_cografya/ticaret.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Coğrafya',
      'konu': 'Turizm',
      'file': 'assets/kpss_onlisans_cografya/turizm.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Coğrafya',
      'konu': 'Türkiye de Nüfus ve Yerleşme',
      'file': 'assets/kpss_onlisans_cografya/turkiye_de_nufus_ve_yerlesme.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Coğrafya',
      'konu': 'Türkiye nin Coğrafi Konumu',
      'file': 'assets/kpss_onlisans_cografya/turkiye_nin_cografi_konumu.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Coğrafya',
      'konu': 'Türkiye nin Fiziki Özellikleri',
      'file':
          'assets/kpss_onlisans_cografya/turkiye_nin_fiziki_ozellikleri.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Coğrafya',
      'konu': 'Türkiye nin İklimi ve Bitki Örtüsü',
      'file':
          'assets/kpss_onlisans_cografya/turkiye_nin_iklimi_ve_bitki_ortusu.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Coğrafya',
      'konu': 'Ulaşım',
      'file': 'assets/kpss_onlisans_cografya/ulasim.json'
    },

    // KPSS ÖNLİSANS MATEMATİK
    {
      'exam': 'Önlisans',
      'ders': 'Matematik',
      'konu': 'Basit Eşitsizlikler',
      'file': 'assets/kpss_onlisans_matematik/basit_esitsizlikler.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Matematik',
      'konu': 'Çarpanlara Ayırma',
      'file': 'assets/kpss_onlisans_matematik/carpanlara_ayirma.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Matematik',
      'konu': 'Denklem Çözme',
      'file': 'assets/kpss_onlisans_matematik/denklem_cozme.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Matematik',
      'konu': 'Fonksiyonlar',
      'file': 'assets/kpss_onlisans_matematik/fonksiyonlar.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Matematik',
      'konu': 'Köklü Sayılar',
      'file': 'assets/kpss_onlisans_matematik/koklu_sayilar.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Matematik',
      'konu': 'Kümeler',
      'file': 'assets/kpss_onlisans_matematik/kumeler.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Matematik',
      'konu': 'Mantık',
      'file': 'assets/kpss_onlisans_matematik/mantik.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Matematik',
      'konu': 'Mutlak Değer',
      'file': 'assets/kpss_onlisans_matematik/mutlak_deger.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Matematik',
      'konu': 'Oran Orantı',
      'file': 'assets/kpss_onlisans_matematik/oran_oranti.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Matematik',
      'konu': 'Problemler',
      'file': 'assets/kpss_onlisans_matematik/problemler.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Matematik',
      'konu': 'Rasyonel Sayılar Ondalıklı Sayılar',
      'file':
          'assets/kpss_onlisans_matematik/rasyonel_sayilar_ondalikli_sayilar.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Matematik',
      'konu': 'Temel Kavramlar',
      'file': 'assets/kpss_onlisans_matematik/temel_kavamlar.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Matematik',
      'konu': 'Üslü Sayılar',
      'file': 'assets/kpss_onlisans_matematik/uslu_sayilar.json'
    },

    // KPSS ÖNLİSANS TARİH
    {
      'exam': 'Önlisans',
      'ders': 'Tarih',
      'konu': '17 Yüzyıl Osmanlı Devleti Duraklama Dönemi',
      'file':
          'assets/kpss_onlisans_tarih/17_yuzyil_osmanli_devleti_duraklama_donemi.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Tarih',
      'konu': '18 Yüzyıl Osmanlı Devleti Gerileme Dönemi',
      'file':
          'assets/kpss_onlisans_tarih/18_yuzyil_osmanli_devleti_gerileme_donemi.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Tarih',
      'konu': '19 Yüzyıl Osmanlı Devleti Dağılma Dönemi',
      'file':
          'assets/kpss_onlisans_tarih/19_yuzyil_osmanli_devleti_dagilma_donemi.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Tarih',
      'konu': '20 Yüzyıl Osmanlı Devleti',
      'file': 'assets/kpss_onlisans_tarih/20_yuzyil_osmanli_devleti.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Tarih',
      'konu': 'Atatürk Dönemi İç ve Dış Politikalar',
      'file':
          'assets/kpss_onlisans_tarih/ataturk_donemi_ic_ve_dis_politikalar.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Tarih',
      'konu': 'Çağdaş Türk ve Dünya Tarihi',
      'file': 'assets/kpss_onlisans_tarih/cagdas_turk_ve_dunya_tarihi.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Tarih',
      'konu': 'İlk Türk İslam Devletleri',
      'file': 'assets/kpss_onlisans_tarih/ilk_turk_islam_devletleri.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Tarih',
      'konu': 'İlk Türk İslam Devletlerinde Kültür ve Medeniyet',
      'file':
          'assets/kpss_onlisans_tarih/ilk_turk_islam_devletlerinde_kultur_ve_medeniyet.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Tarih',
      'konu': 'İnkılap Tarihi',
      'file': 'assets/kpss_onlisans_tarih/inkilap_tarihi.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Tarih',
      'konu': 'İslamiyet Öncesi Türk Devletlerinde Kültür ve Medeniyet',
      'file':
          'assets/kpss_onlisans_tarih/islamiyet_oncesi_turk_devletlerinde_kultur_ve_medeniyet.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Tarih',
      'konu': 'İslamiyet Öncesi Türk Tarihi',
      'file': 'assets/kpss_onlisans_tarih/islamiyet_oncesi_turk_tarihi.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Tarih',
      'konu': 'Milli Mücadele Dönemi',
      'file': 'assets/kpss_onlisans_tarih/milli_mucadele_donemi.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Tarih',
      'konu': 'Osmanlı Devleti Kültür ve Medeniyet',
      'file':
          'assets/kpss_onlisans_tarih/osmanli_devleti_kultur_ve_medeniyet.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Tarih',
      'konu': 'Osmanlı Devleti Kuruluş ve Yükselme Dönemi',
      'file':
          'assets/kpss_onlisans_tarih/osmanli_devleti_kurulus_ve_yukselme_donemi.json'
    },

    // KPSS ÖNLİSANS TÜRKÇE
    {
      'exam': 'Önlisans',
      'ders': 'Türkçe',
      'konu': 'Anlatım Bozuklukları',
      'file': 'assets/kpss_onlisans_turkce/anlatim_bozukluklari.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Türkçe',
      'konu': 'Cümlede Anlam',
      'file': 'assets/kpss_onlisans_turkce/cumlede_anlam.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Türkçe',
      'konu': 'Cümlenin Ögeleri',
      'file': 'assets/kpss_onlisans_turkce/cumlenin_ogeleri.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Türkçe',
      'konu': 'Cümle Türleri',
      'file': 'assets/kpss_onlisans_turkce/cumle_turleri.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Türkçe',
      'konu': 'Dil Bilgisi Ses Olayları',
      'file': 'assets/kpss_onlisans_turkce/dil_bilgisi_ses_olaylari.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Türkçe',
      'konu': 'Mantık',
      'file': 'assets/kpss_onlisans_turkce/mantik.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Türkçe',
      'konu': 'Noktalama İşaretleri',
      'file': 'assets/kpss_onlisans_turkce/noktalama_isaretleri.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Türkçe',
      'konu': 'Paragrafta Anlam',
      'file': 'assets/kpss_onlisans_turkce/paragrafta_anlam.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Türkçe',
      'konu': 'Paragrafta Anlatım Biçimi',
      'file': 'assets/kpss_onlisans_turkce/paragrafta_anlatim_bicimi.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Türkçe',
      'konu': 'Sözcük Türleri',
      'file': 'assets/kpss_onlisans_turkce/sozcuk_turleri.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Türkçe',
      'konu': 'Sözcükte Anlam',
      'file': 'assets/kpss_onlisans_turkce/sozcukte_anlam.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Türkçe',
      'konu': 'Sözcükte Yapı',
      'file': 'assets/kpss_onlisans_turkce/sozcukte_yapi.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Türkçe',
      'konu': 'Yazım Kuralları',
      'file': 'assets/kpss_onlisans_turkce/yazim_kurallari.json'
    },

    // KPSS ÖNLİSANS VATANDAŞLIK
    {
      'exam': 'Önlisans',
      'ders': 'Vatandaşlık',
      'konu': 'Anayasal Kavramlar',
      'file': 'assets/kpss_onlisans_vatandaslik/anayasal_kavramlar.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Vatandaşlık',
      'konu': 'İdare Hukuku',
      'file': 'assets/kpss_onlisans_vatandaslik/idare_hukuku.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Vatandaşlık',
      'konu': 'Temel Hak ve Ödevler',
      'file': 'assets/kpss_onlisans_vatandaslik/temel_hak_ve_odevler.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Vatandaşlık',
      'konu': 'Temel Hukuk Kavramları',
      'file': 'assets/kpss_onlisans_vatandaslik/temel_hukuk_kavramlari.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Vatandaşlık',
      'konu': 'Türk Anayasa Tarihi',
      'file': 'assets/kpss_onlisans_vatandaslik/turk_anayasa_tarihi.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Vatandaşlık',
      'konu': 'Yargı',
      'file': 'assets/kpss_onlisans_vatandaslik/yargi.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Vatandaşlık',
      'konu': 'Yasama',
      'file': 'assets/kpss_onlisans_vatandaslik/yasama.json'
    },
    {
      'exam': 'Önlisans',
      'ders': 'Vatandaşlık',
      'konu': 'Yürütme',
      'file': 'assets/kpss_onlisans_vatandaslik/yurutme.json'
    },
  ];

  static Future<String?> findFilePath(
  String exam,
  String ders,
  String konu,
) async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    final Set<String> assets = manifest
        .listAssets()
        .where((path) => path.startsWith('assets/') && path.endsWith('.json'))
        .toSet();

    final String? staticMatch = _findFromStaticList(exam, ders, konu);

    if (staticMatch != null && assets.contains(staticMatch)) {
      debugPrint('✅ Statik dosya bulundu: $staticMatch');
      return staticMatch;
    }

    final List<String> candidates = _buildCandidatePaths(exam, ders, konu);

    for (final candidate in candidates) {
      if (assets.contains(candidate)) {
        debugPrint('✅ Otomatik dosya bulundu: $candidate');
        return candidate;
      }
    }

    final String subjectFolder = _subjectFolderName(ders);
    final String topicSlug = _slug(konu);
    final List<String> prefixes = _examFolderPrefixes(exam);

    final List<String> topicWords = topicSlug
        .split('_')
        .where((word) => word.trim().length >= 3)
        .toList();

    final List<String> fuzzyMatches = assets.where((path) {
      final String normalizedPath = _slug(path);

      final bool examMatch = prefixes.any(
        (prefix) => path.startsWith('assets/${prefix}_'),
      );

      final bool subjectMatch = path.contains('_$subjectFolder/');

      final int wordMatchCount = topicWords
          .where((word) => normalizedPath.contains(word))
          .length;

      final int requiredMatchCount = topicWords.length <= 2 ? 1 : 2;

      return examMatch && subjectMatch && wordMatchCount >= requiredMatchCount;
    }).toList();

    fuzzyMatches.sort((a, b) {
      final int aScore = _scorePath(a, topicWords);
      final int bScore = _scorePath(b, topicWords);
      return bScore.compareTo(aScore);
    });

    if (fuzzyMatches.isNotEmpty) {
      debugPrint('✅ Yakın eşleşme bulundu: ${fuzzyMatches.first}');
      return fuzzyMatches.first;
    }

    debugPrint('❌ ASSET EŞLEŞMESİ YOK: $exam - $ders - $konu');
    debugPrint('Denenen adaylar: $candidates');

    return null;
  } catch (e) {
    debugPrint('❌ AssetManifest okunamadı: $e');
    return _findFromStaticList(exam, ders, konu);
  }
}

static String? getFilePath(String exam, String ders, String konu) {
  final String? staticMatch = _findFromStaticList(exam, ders, konu);

  if (staticMatch != null) {
    return staticMatch;
  }

  final candidates = _buildCandidatePaths(exam, ders, konu);

  if (candidates.isNotEmpty) {
    return candidates.first;
  }

  return null;
}

static String? _findFromStaticList(
  String exam,
  String ders,
  String konu,
) {
  final String normExam = _compact(exam);
  final String normDers = _compact(ders).replaceAll(RegExp(r'\d+$'), '');
  final String normKonu = _compact(konu);

  try {
    final map = _files.firstWhere((e) {
      final String eExam = _compact(e['exam'] ?? '');
      final String eDers =
          _compact(e['ders'] ?? '').replaceAll(RegExp(r'\d+$'), '');
      final String eKonu = _compact(e['konu'] ?? '');
      final String eFile = _compact(e['file'] ?? '');

      return eExam == normExam &&
          eDers == normDers &&
          (eKonu == normKonu || eFile.contains(normKonu));
    });

    return map['file'];
  } catch (_) {
    try {
      final fallback = _files.firstWhere((e) {
        final String eDers =
            _compact(e['ders'] ?? '').replaceAll(RegExp(r'\d+$'), '');
        final String eKonu = _compact(e['konu'] ?? '');
        final String eFile = _compact(e['file'] ?? '');

        return eDers == normDers &&
            (eKonu == normKonu || eFile.contains(normKonu));
      });

      return fallback['file'];
    } catch (_) {
      return null;
    }
  }
}

static List<String> _buildCandidatePaths(
  String exam,
  String ders,
  String konu,
) {
  final List<String> prefixes = _examFolderPrefixes(exam);
  final String subjectFolder = _subjectFolderName(ders);
  final Set<String> topicVariants = _topicVariants(konu);

  final List<String> result = [];

  for (final prefix in prefixes) {
    for (final topic in topicVariants) {
      result.add('assets/${prefix}_$subjectFolder/$topic.json');
    }
  }

  return result;
}

static List<String> _examFolderPrefixes(String exam) {
  final String e = _compact(exam);

  if (e.contains('tyt')) {
    return ['tyt'];
  }

  if (e.contains('ayt') && e.contains('sayisal')) {
    return ['ayt_sayisal'];
  }

  if (e.contains('ayt') &&
      (e.contains('esitagirlik') ||
          e.contains('esit') ||
          e.contains('agirlik'))) {
    return ['ayt_esitagirlik'];
  }

  if (e.contains('ayt') && e.contains('sozel')) {
    return ['ayt_sozel'];
  }

  if (e.contains('ayt')) {
    return [
      'ayt_sayisal',
      'ayt_esitagirlik',
      'ayt_sozel',
    ];
  }

  if (e.contains('onlisans') || e.contains('onlisans')) {
    return ['kpss_onlisans'];
  }

  if (e.contains('lisans')) {
    return ['kpss_lisans'];
  }

  if (e.contains('kpss')) {
    return [
      'kpss_lisans',
      'kpss_onlisans',
    ];
  }

  return [
    'tyt',
    'ayt_sayisal',
    'ayt_esitagirlik',
    'ayt_sozel',
    'kpss_lisans',
    'kpss_onlisans',
  ];
}

static String _subjectFolderName(String ders) {
  final String d = _compact(ders);

  if (d.contains('turkce')) return 'turkce';
  if (d.contains('matematik')) return 'matematik';
  if (d.contains('tarih')) return 'tarih';
  if (d.contains('cografya')) return 'cografya';
  if (d.contains('din')) return 'din';
  if (d.contains('felsefe')) return 'felsefe';
  if (d.contains('biyoloji')) return 'biyoloji';
  if (d.contains('fizik')) return 'fizik';
  if (d.contains('kimya')) return 'kimya';
  if (d.contains('edebiyat')) return 'edebiyat';
  if (d.contains('vatandaslik')) return 'vatandaslik';

  return _slug(ders);
}

static Set<String> _topicVariants(String konu) {
  final String topic = _slug(konu);
  final Set<String> variants = {topic};

  // Dosya adlarında var olan birkaç özel durum
  if (topic == 'temel_kavramlar') {
    variants.add('temel_kavamlar');
  }

  if (topic == 'madenler_ve_enerji') {
    variants.add('madenler_ve_enerji_kaynaklari');
  }

  if (topic == 'temel_hak_odevler') {
    variants.add('temel_hak_ve_odevler');
  }

  if (topic == 'kimya_bilimi') {
    variants.add('bilimi');
  }

  if (topic.endsWith('_ve_bilim')) {
    variants.add('ve_bilim');
  }

  return variants;
}

static int _scorePath(String path, List<String> topicWords) {
  final String normalizedPath = _slug(path);

  int score = 0;

  for (final word in topicWords) {
    if (normalizedPath.contains(word)) {
      score++;
    }
  }

  return score;
}

static String _compact(String value) {
  return _slug(value).replaceAll('_', '');
}

static String _slug(String value) {
  String text = value
      .replaceAll('İ', 'i')
      .replaceAll('I', 'i')
      .replaceAll('ı', 'i')
      .replaceAll('Ö', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('Ü', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('Ş', 's')
      .replaceAll('ş', 's')
      .replaceAll('Ğ', 'g')
      .replaceAll('ğ', 'g')
      .replaceAll('Ç', 'c')
      .replaceAll('ç', 'c')
      .replaceAll('Â', 'a')
      .replaceAll('â', 'a')
      .toLowerCase();

  text = text.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  text = text.replaceAll(RegExp(r'_+'), '_');
  text = text.replaceAll(RegExp(r'^_+|_+$'), '');

  return text;
}
}