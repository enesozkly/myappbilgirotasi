// ignore_for_file: unused_field, unused_element

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NetCalculatorPage extends StatefulWidget {
  const NetCalculatorPage({super.key});

  @override
  State<NetCalculatorPage> createState() => _NetCalculatorPageState();
}

class _NetCalculatorPageState extends State<NetCalculatorPage> {
  int _selectedIndex = 0;
  String _selectedExam = "TYT";

  // Sınav dersleri artık geniş kategoriler yerine alt derslerle tutulur.
  final Map<String, List<String>> _examLessons = {
    "TYT": [
      "Türkçe", "Tarih", "Coğrafya", "Felsefe", "Din Kültürü",
      "Matematik", "Fizik", "Kimya", "Biyoloji",
    ],
    "AYT": [
      "Türk Dili ve Edebiyatı",
      "Tarih-1",
      "Coğrafya-1",
      "Tarih-2",
      "Coğrafya-2",
      "Felsefe Grubu",
      "Din Kültürü",
      "Matematik",
      "Fizik",
      "Kimya",
      "Biyoloji",
    ],
    "KPSS": [
      "Türkçe", "Matematik", "Tarih", "Coğrafya", "Vatandaşlık", "Güncel Bilgiler",
    ],
  };

  final Map<String, int> _questionCounts = {
    // TYT
    "Türkçe": 40,
    "Tarih": 5,
    "Coğrafya": 5,
    "Felsefe": 5,
    "Din Kültürü": 5,
    "Matematik": 40,
    "Fizik": 7,
    "Kimya": 7,
    "Biyoloji": 6,
    // AYT
    "Türk Dili ve Edebiyatı": 24,
    "Tarih-1": 10,
    "Coğrafya-1": 6,
    "Tarih-2": 11,
    "Coğrafya-2": 11,
    "Felsefe Grubu": 12,
    // AYT Din Kültürü aynı anahtarı kullanır
    "KPSS Türkçe": 30,
    "KPSS Matematik": 30,
    "KPSS Tarih": 27,
    "KPSS Coğrafya": 18,
    "Vatandaşlık": 9,
    "Güncel Bilgiler": 6,
  };

  final Map<String, int> _corrects = {};
  final Map<String, int> _incorrects = {};
  final Map<String, Stream<QuerySnapshot>> _streamCache = {};
  String? _uid;

  @override
  void initState() {
    super.initState();
    _resetValues();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (_uid != null) {
      for (final exam in ["TYT", "AYT", "KPSS"]) {
        _streamCache[exam] = _createStream(_uid!, exam);
      }
    }
  }

  Stream<QuerySnapshot> _createStream(String uid, String exam) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('trials')
        .where('type', isEqualTo: exam)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  void _resetValues() {
    Set<String> allLessons = {};
    for (var list in _examLessons.values) {
      allLessons.addAll(list);
    }
    for (var lesson in allLessons) {
      _corrects[lesson] = 0;
      _incorrects[lesson] = 0;
    }
  }

  double _calculateTotalNet() {
    double total = 0;
    for (var lesson in _examLessons[_selectedExam]!) {
      int d = _corrects[lesson] ?? 0;
      int y = _incorrects[lesson] ?? 0;
      total += d - (y / 4.0);
    }
    return total;
  }

  Future<void> _saveResult() async {
    double totalNet = _calculateTotalNet();
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('trials')
          .add({
        'net': totalNet,
        'date': FieldValue.serverTimestamp(),
        'type': _selectedExam,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'details': {
          for (final lesson in _examLessons[_selectedExam]!)
            lesson: {
              'correct': _corrects[lesson] ?? 0,
              'incorrect': _incorrects[lesson] ?? 0,
              'net': (_corrects[lesson] ?? 0) - ((_incorrects[lesson] ?? 0) / 4.0),
            },
        },
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("$_selectedExam netin ($totalNet) kaydedildi!"),
          backgroundColor: const Color(0xFF00E5FF),
          duration: const Duration(seconds: 1),
        ));
        setState(() => _selectedIndex = 1);
        _resetValues();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Kayıt hatası: $e"),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  void _openHistorySheet() {
    final uid = _uid;
    if (uid == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistorySheet(
        uid: uid,
        exam: _selectedExam,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E43),
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E43), Color(0xFF1B1F6A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildExamSelector(),
              const SizedBox(height: 15),
              _buildTabButtons(),
              const SizedBox(height: 15),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _buildCalculatorView(),
                    _PerformanceView(
                      uid: _uid,
                      selectedExam: _selectedExam,
                      streamCache: _streamCache,
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text("Deneme Asistanı",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ),
          GestureDetector(
            onTap: _openHistorySheet,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.history_rounded,
                  color: Color(0xFF00E5FF), size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamSelector() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: ["TYT", "AYT", "KPSS"].map((exam) {
          bool isSelected = _selectedExam == exam;
          return GestureDetector(
            onTap: () => setState(() {
                    _selectedExam = exam;
                    _corrects.clear();
                    _incorrects.clear();
                  }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 15),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00E5FF)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00E5FF)
                        : Colors.white24),
              ),
              child: Center(
                child: Text(exam,
                    style: GoogleFonts.poppins(
                        color: isSelected
                            ? const Color(0xFF0A0E43)
                            : Colors.white70,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: [
          _buildTabButton("Net Hesapla", 0),
          _buildTabButton("Performansım", 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00E5FF)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(25)),
          alignment: Alignment.center,
          child: Text(title,
              style: GoogleFonts.poppins(
                  color: isSelected
                      ? const Color(0xFF0A0E43)
                      : Colors.white54,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildCalculatorView() {
    double totalNet = _calculateTotalNet();
    return Column(
      children: [
        Expanded(
          child: _selectedExam == "AYT"
              ? _buildAytCalculatorView()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _examLessons[_selectedExam]!.length,
                  itemBuilder: (context, index) =>
                      _buildLessonCardWithCount(_examLessons[_selectedExam]![index]),
                ),
        ),
        _buildBottomResultBar(totalNet),
      ],
    );
  }

  Widget _buildAytCalculatorView() {
    // AYT bölüm grupları (görseldeki gibi)
    final sections = [
      {
        'title': 'TÜRK DİLİ ve EDEBİYATI / SOSYAL BİLİMLER-1',
        'total': 40,
        'lessons': ['Türk Dili ve Edebiyatı', 'Tarih-1', 'Coğrafya-1'],
      },
      {
        'title': 'SOSYAL BİLİMLER 2',
        'total': 40,
        'lessons': ['Tarih-2', 'Coğrafya-2', 'Felsefe Grubu', 'Din Kültürü'],
      },
      {
        'title': 'MATEMATİK',
        'total': 40,
        'lessons': ['Matematik'],
      },
      {
        'title': 'FEN BİLİMLERİ',
        'total': 40,
        'lessons': ['Fizik', 'Kimya', 'Biyoloji'],
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final section = sections[i];
        final lessons = section['lessons'] as List<String>;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bölüm başlığı (görseldeki kırmızı bar)
            Container(
              margin: const EdgeInsets.only(top: 16, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB71C1C), Color(0xFF8B0000)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      section['title'] as String,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${section['total']} Soru',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            ...lessons.map((lesson) => _buildLessonCardWithCount(lesson)),
          ],
        );
      },
    );
  }

  int _countForLesson(String lesson) {
    if (_selectedExam == 'TYT') {
      const counts = {
        'Türkçe': 40,
        'Tarih': 5,
        'Coğrafya': 5,
        'Felsefe': 5,
        'Din Kültürü': 5,
        'Matematik': 40,
        'Fizik': 7,
        'Kimya': 7,
        'Biyoloji': 6,
      };
      return counts[lesson] ?? 0;
    }
    if (_selectedExam == 'AYT') {
      const counts = {
        'Türk Dili ve Edebiyatı': 24,
        'Tarih-1': 10,
        'Coğrafya-1': 6,
        'Tarih-2': 11,
        'Coğrafya-2': 11,
        'Felsefe Grubu': 12,
        'Din Kültürü': 6,
        'Matematik': 40,
        'Fizik': 14,
        'Kimya': 13,
        'Biyoloji': 13,
      };
      return counts[lesson] ?? 0;
    }
    const kpssCounts = {
      'Türkçe': 30,
      'Matematik': 30,
      'Tarih': 27,
      'Coğrafya': 18,
      'Vatandaşlık': 9,
      'Güncel Bilgiler': 6,
    };
    return kpssCounts[lesson] ?? 0;
  }

  Widget _buildLessonCardWithCount(String lesson) {
    final count = _countForLesson(lesson);
    int d = _corrects[lesson] ?? 0;
    int y = _incorrects[lesson] ?? 0;
    double net = d - (y / 4.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(lesson,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
            Text('$count Soru',
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildCounterBox("D", d, Colors.greenAccent,
                      (val) => setState(() => _corrects[lesson] = val))),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildCounterBox("Y", y, Colors.redAccent,
                      (val) => setState(() => _incorrects[lesson] = val))),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.3))),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Net",
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 11)),
                      Text(net.toStringAsFixed(2),
                          style: GoogleFonts.poppins(
                              color: const Color(0xFF00E5FF),
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(String lesson) {
    int d = _corrects[lesson] ?? 0;
    int y = _incorrects[lesson] ?? 0;
    double net = d - (y / 4.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lesson,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _buildCounterBox("D", d, Colors.greenAccent,
                      (val) => setState(() => _corrects[lesson] = val))),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildCounterBox("Y", y, Colors.redAccent,
                      (val) => setState(() => _incorrects[lesson] = val))),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.3))),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Net",
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 11)),
                      Text(net.toStringAsFixed(2),
                          style: GoogleFonts.poppins(
                              color: const Color(0xFF00E5FF),
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterBox(
      String label, int value, Color color, Function(int) onChanged) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniBtn(
                  Icons.remove, () { if (value > 0) { onChanged(value - 1); } }),
              GestureDetector(
                onTap: () => _showKeyboardInput(value, onChanged),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text("$value",
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              _buildMiniBtn(Icons.add, () { onChanged(value + 1); }),
            ],
          ),
        ],
      ),
    );
  }

  void _showKeyboardInput(int current, Function(int) onChanged) {
    final ctrl = TextEditingController(text: current == 0 ? '' : current.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F6A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Değer Gir', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: GoogleFonts.poppins(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.07),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: GoogleFonts.poppins(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim()) ?? current;
              onChanged(v < 0 ? 0 : v);
              Navigator.pop(context);
            },
            child: Text('Tamam', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
  }

  Widget _buildBottomResultBar(double totalNet) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
          color: Color(0xFF152C5B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Toplam Net:",
                  style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              Text(totalNet.toStringAsFixed(2),
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF00E5FF),
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: const Color(0xFF0A0E43),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))),
            onPressed: _saveResult,
            child: Text("Kaydet ve Grafiğe Ekle",
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  final String uid;
  final String exam;

  const _HistorySheet({required this.uid, required this.exam});

  Future<void> _deleteEntry(
      BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A6B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Sil",
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Bu denemeyi silmek istediğine emin misin?",
            style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("İptal",
                style:
                    GoogleFonts.poppins(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Sil",
                style: GoogleFonts.poppins(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('trials')
          .doc(docId)
          .delete();
    }
  }

  void _editEntry(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    double currentNet = (data['net'] is int)
        ? (data['net'] as int).toDouble()
        : (data['net'] as double);

    final controller =
        TextEditingController(text: currentNet.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Color(0xFF152C5B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 20),
              Text("Denemeyi Düzenle",
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("$exam — Toplam Net değerini düzenle",
                  style: GoogleFonts.poppins(
                      color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: "Toplam Net",
                  labelStyle:
                      GoogleFonts.poppins(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.07),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                        color: Color(0xFF00E5FF), width: 2),
                  ),
                  suffixText: "net",
                  suffixStyle:
                      GoogleFonts.poppins(color: Colors.white38),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      child: Text("İptal",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: const Color(0xFF0A0E43),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: () async {
                        final newNet =
                            double.tryParse(controller.text.replaceAll(',', '.'));
                        if (newNet == null) return;
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('trials')
                            .doc(doc.id)
                            .update({'net': newNet});
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: Text("Kaydet",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold)),
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

  String _formatDate(dynamic createdAt) {
    if (createdAt == null) return "—";
    try {
      final dt =
          DateTime.fromMillisecondsSinceEpoch(createdAt as int);
      return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "—";
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0E1A4A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.history_rounded,
                              color: Color(0xFF00E5FF), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Deneme Geçmişi",
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            Text("$exam — Sil veya düzenle",
                                style: GoogleFonts.poppins(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: Colors.white.withValues(alpha: 0.08)),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('trials')
                      .where('type', isEqualTo: exam)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return FutureBuilder<void>(
                        future: Future.delayed(const Duration(seconds: 4)),
                        builder: (ctx, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
                          }
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.inbox_rounded, size: 60, color: Color(0xFF00E5FF)),
                                const SizedBox(height: 12),
                                Text('Henüz $exam denemesi yok',
                                    style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14)),
                                const SizedBox(height: 6),
                                Text('Net hesapla ve kaydet!',
                                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      );
                    }
                    if (snapshot.hasError) {
                      return _FallbackHistoryList(
                          uid: uid,
                          exam: exam,
                          onDelete: (ctx, id) => _deleteEntry(ctx, id),
                          onEdit: (ctx, doc) => _editEntry(ctx, doc),
                          formatDate: _formatDate,
                          scrollController: scrollController);
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inbox_rounded,
                                size: 60, color: Colors.white12),
                            const SizedBox(height: 12),
                            Text("Henüz $exam denemesi yok",
                                style: GoogleFonts.poppins(
                                    color: Colors.white54)),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: docs.length,
                      itemBuilder: (ctx, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        final double net = (data['net'] is int)
                            ? (data['net'] as int).toDouble()
                            : (data['net'] as double? ?? 0.0);
                        final String dateStr =
                            _formatDate(data['createdAt']);
                        final int total = docs.length;
                        final int rank = total - i;

                        return _HistoryTile(
                          rank: rank,
                          net: net,
                          dateStr: dateStr,
                          onEdit: () => _editEntry(ctx, doc),
                          onDelete: () => _deleteEntry(ctx, doc.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final int rank;
  final double net;
  final String dateStr;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.rank,
    required this.net,
    required this.dateStr,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPositive = net >= 0;
    final Color netColor =
        isPositive ? const Color(0xFF00E5FF) : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text("D.$rank",
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF00E5FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: netColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: netColor.withValues(alpha: 0.3)),
            ),
            child: Text(net.toStringAsFixed(2),
                style: GoogleFonts.poppins(
                    color: netColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.edit_rounded,
                  color: Colors.white54, size: 17),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.delete_rounded,
                  color: Colors.redAccent, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackHistoryList extends StatelessWidget {
  final String uid;
  final String exam;
  final Function(BuildContext, String) onDelete;
  final Function(BuildContext, QueryDocumentSnapshot) onEdit;
  final String Function(dynamic) formatDate;
  final ScrollController scrollController;

  const _FallbackHistoryList({
    required this.uid,
    required this.exam,
    required this.onDelete,
    required this.onEdit,
    required this.formatDate,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('trials')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
        }
        var docs = snapshot.data!.docs
            .where((d) => d['type'] == exam)
            .toList();
        docs.sort((a, b) {
          int av = (a.data() as Map).containsKey('createdAt')
              ? a['createdAt'] as int
              : 0;
          int bv = (b.data() as Map).containsKey('createdAt')
              ? b['createdAt'] as int
              : 0;
          return bv.compareTo(av);
        });

        if (docs.isEmpty) {
          return Center(
            child: Text("Henüz $exam denemesi yok",
                style:
                    GoogleFonts.poppins(color: Colors.white54)),
          );
        }
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final double net = (data['net'] is int)
                ? (data['net'] as int).toDouble()
                : (data['net'] as double? ?? 0.0);
            return _HistoryTile(
              rank: docs.length - i,
              net: net,
              dateStr: formatDate(data['createdAt']),
              onEdit: () => onEdit(ctx, doc),
              onDelete: () => onDelete(ctx, doc.id),
            );
          },
        );
      },
    );
  }
}

class _PerformanceView extends StatefulWidget {
  final String? uid;
  final String selectedExam;
  final Map<String, Stream<QuerySnapshot>> streamCache;

  const _PerformanceView({
    required this.uid,
    required this.selectedExam,
    required this.streamCache,
  });

  @override
  State<_PerformanceView> createState() => _PerformanceViewState();
}

class _PerformanceViewState extends State<_PerformanceView> {
  Stream<QuerySnapshot>? _activeStream;

  @override
  void initState() {
    super.initState();
    _activeStream = widget.streamCache[widget.selectedExam];
  }

  @override
  void didUpdateWidget(_PerformanceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedExam != widget.selectedExam) {
      _activeStream = widget.streamCache[widget.selectedExam];
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;
    if (uid == null) {
      return Center(
          child: Text("Lütfen giriş yapın.",
              style:
                  GoogleFonts.poppins(color: Colors.white70, fontSize: 16)));
    }
    final stream = _activeStream;
    if (stream == null) {
      return _buildFallback(uid);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildFallback(uid);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWithTimeout();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }
        var docs = snapshot.data!.docs;
        if (docs.length > 10) {
          docs = docs.sublist(docs.length - 10);
        }
        return _buildChartContent(docs);
      },
    );
  }

  Widget _buildFallback(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('trials')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text("Veri yüklenemedi",
                  style: GoogleFonts.poppins(color: Colors.white)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWithTimeout();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }
        var docs = snapshot.data!.docs
            .where((d) => d['type'] == widget.selectedExam)
            .toList();
        docs.sort((a, b) {
          int av = (a.data() as Map).containsKey('createdAt')
              ? a['createdAt'] as int
              : 0;
          int bv = (b.data() as Map).containsKey('createdAt')
              ? b['createdAt'] as int
              : 0;
          return av.compareTo(bv);
        });
        if (docs.isEmpty) {
          return _buildEmptyState();
        }
        if (docs.length > 10) {
          docs = docs.sublist(docs.length - 10);
        }
        return _buildChartContent(docs);
      },
    );
  }

  Widget _buildLoadingWithTimeout() {
    return FutureBuilder<void>(
      future: Future.delayed(const Duration(seconds: 4)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
          );
        }
        return _buildEmptyState();
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.show_chart_rounded, size: 80, color: Colors.white10),
          const SizedBox(height: 20),
          Text("Henüz ${widget.selectedExam} Verisi Yok",
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text("İlk netini hesapla ve kaydet!",
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildChartContent(List<QueryDocumentSnapshot> docs) {
    List<double> scores = docs.map((d) {
      var val = d['net'];
      return (val is int) ? val.toDouble() : (val as double);
    }).toList();
    List<String> labels = List.generate(docs.length, (i) => "D.${i + 1}");

    String motivationText;
    IconData motivationIcon;
    List<Color> motivationColors;

    if (scores.length >= 2 && scores.last > scores[scores.length - 2]) {
      motivationText = "Harika gidiyorsun! Netlerin yükselişte.";
      motivationIcon = Icons.trending_up_rounded;
      motivationColors = [const Color(0xFF00E676), const Color(0xFF00C853)];
    } else if (scores.length >= 2 &&
        scores.last < scores[scores.length - 2]) {
      motivationText = "Durma, çalışmaya devam! Başarı yakın.";
      motivationIcon = Icons.fitness_center_rounded;
      motivationColors = [const Color(0xFFFF6B35), const Color(0xFFFF4500)];
    } else {
      motivationText = "Tutarlısın! Devam et, yükseleceksin.";
      motivationIcon = Icons.star_rounded;
      motivationColors = [const Color(0xFF6C63FF), const Color(0xFF4834DF)];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            height: 320,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: const Color(0xFF223A70).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Gelişim Grafiği (${widget.selectedExam})",
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text("Son ${docs.length} deneme",
                    style: GoogleFonts.poppins(
                        color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 30),
                Expanded(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: ChartPainter(scores: scores, labels: labels),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: motivationColors),
                borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Icon(motivationIcon, color: Colors.white, size: 40),
                const SizedBox(width: 15),
                Expanded(
                    child: Text(motivationText,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<double> scores;
  final List<String> labels;
  ChartPainter({required this.scores, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) {
      return;
    }

    final linePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    double maxS = scores.reduce(max);
    double minS = scores.reduce(min);
    if (maxS == minS) {
      maxS += 10;
      minS = (minS - 5).clamp(0, double.infinity);
    }
    double range = maxS - minS;
    if (range == 0) {
      range = 1;
    }

    List<Offset> pts = [];
    double stepX =
        scores.length > 1 ? size.width / (scores.length - 1) : size.width / 2;

    for (int i = 0; i < scores.length; i++) {
      double x = scores.length > 1 ? i * stepX : size.width / 2;
      double y =
          size.height - 20 - ((scores[i] - minS) / range * (size.height - 40));
      pts.add(Offset(x, y));
    }

    if (scores.length > 1) {
      Path p = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        p.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(p, linePaint);
    }

    for (var i = 0; i < pts.length; i++) {
      canvas.drawCircle(pts[i], 6, borderPaint);
      canvas.drawCircle(pts[i], 4, dotPaint);

      textPainter.text = TextSpan(
        text: scores[i].toStringAsFixed(1),
        style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(pts[i].dx - textPainter.width / 2, pts[i].dy - 25));

      textPainter.text = TextSpan(
        text: labels[i],
        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(pts[i].dx - textPainter.width / 2, size.height + 5));
    }
  }

  @override
  bool shouldRepaint(CustomPainter old) => true;
}