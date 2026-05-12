// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_page.dart';
import 'change_password_page.dart';
import '../services/notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late AnimationController _bgController;

  // ── Bildirim ayarları ─────────────────────────────────────────────────
  bool _notifEnabled   = true;
  bool _morningOn      = true;
  bool _middayOn       = true;
  bool _eveningOn      = true;
  NotifTime _morningTime  = NotificationService.defaultMorning;
  NotifTime _middayTime   = NotificationService.defaultMidday;
  NotifTime _eveningTime  = NotificationService.defaultEvening;
  bool _notifLoading   = true;

  @override
  void initState() {
    super.initState();
    _bgController =
        AnimationController(vsync: this, duration: const Duration(seconds: 25))
          ..repeat();
    _loadNotifSettings();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  // ── Bildirim ayarlarını yükle ─────────────────────────────────────────
  Future<void> _loadNotifSettings() async {
    final s = await NotificationService().loadSettings();
    if (!mounted) return;
    setState(() {
      _notifEnabled  = s['enabled']   ?? true;
      _morningOn     = s['morningOn'] ?? true;
      _middayOn      = s['middayOn']  ?? true;
      _eveningOn     = s['eveningOn'] ?? true;
      _morningTime   = NotifTime(s['morningH'] ?? 8,  s['morningM'] ?? 0);
      _middayTime    = NotifTime(s['middayH']  ?? 12, s['middayM']  ?? 0);
      _eveningTime   = NotifTime(s['eveningH'] ?? 20, s['eveningM'] ?? 0);
      _notifLoading  = false;
    });
  }

  // ── Bildirim ayarlarını kaydet ────────────────────────────────────────
  Future<void> _saveNotifSettings({bool showSnack = true}) async {
    await NotificationService().saveSettings(
      enabled:   _notifEnabled,
      morningOn: _morningOn,
      middayOn:  _middayOn,
      eveningOn: _eveningOn,
      morning:   _morningTime,
      midday:    _middayTime,
      evening:   _eveningTime,
    );
    if (!mounted || !showSnack) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Bildirim ayarları kaydedildi ✅',
          style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: const Color(0xFF00E676),
      behavior: SnackBarBehavior.floating,
    ));
  }


  void _updateNotifSetting(VoidCallback update) {
    setState(update);
    _saveNotifSettings(showSnack: false);
  }

  Future<void> _sendTestNotification() async {
    try {
      final ok = await NotificationService().showTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          ok
              ? 'Test bildirimi gönderildi ✅'
              : 'Bildirim izni alınamadı. Telefon ayarlarından izinleri kontrol et.',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: ok ? const Color(0xFF00E676) : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Test bildirimi gönderilemedi: $e',
            style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Saat seçici ───────────────────────────────────────────────────────
  Future<void> _pickTime(NotifType type) async {
    final initial = type == NotifType.morning
        ? _morningTime
        : type == NotifType.midday
            ? _middayTime
            : _eveningTime;

    final picked = await showTimePicker(
      context: context,
      initialTime: initial.toTimeOfDay(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   Color(0xFF00E5FF),
            surface:   Color(0xFF1B1F6A),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      final t = NotifTime(picked.hour, picked.minute);
      if (type == NotifType.morning) _morningTime = t;
      else if (type == NotifType.midday)  _middayTime  = t;
      else                               _eveningTime = t;
    });
    await _saveNotifSettings(showSnack: false);
  }

  void _showFeedbackDialog() {
    final formKey = GlobalKey<FormState>();
    final TextEditingController feedbackController = TextEditingController();
    bool sending = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1F6A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Geri Bildirim Gönder',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: feedbackController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Görüş ve önerilerini yaz...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Lütfen bir şeyler yaz' : null,
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('İPTAL',
                    style: TextStyle(color: Colors.redAccent))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF)),
              onPressed: sending
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => sending = true);
                      try {
                        final user = _auth.currentUser;
                        final nav = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(context);
                        await FirebaseFirestore.instance
                            .collection('feedbacks')
                            .add({
                          'uid': user?.uid ?? 'anonymous',
                          'email': user?.email ?? '',
                          'message': feedbackController.text.trim(),
                          'createdAt': FieldValue.serverTimestamp(),
                          'status': 'new',
                        });
                        if (!mounted) return;
                        nav.pop();
                        messenger.showSnackBar(SnackBar(
                          content: Text('Geri bildiriminiz alındı!',
                              style: GoogleFonts.poppins(color: Colors.white)),
                          backgroundColor: const Color(0xFF00E676),
                          behavior: SnackBarBehavior.floating,
                        ));
                      } catch (e) {
                        setDialogState(() => sending = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Gönderilemedi: $e'),
                            backgroundColor: Colors.redAccent));
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('GÖNDER',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLegalDialog({required bool isPrivacy}) {
    final String title = isPrivacy ? 'Gizlilik Politikası' : 'Kullanım Koşulları';
    final String body = isPrivacy
        ? r"""Bilgi Rotası Gizlilik Politikası

Bilgi Rotası, SONERLER BİLİŞİM tarafından sunulan bir eğitim ve sınav hazırlık uygulamasıdır.

Toplanan Veriler
Uygulamayı kullanırken ad, e-posta adresi, kullanıcı kimliği, uygulama içi ilerleme bilgileri, doğru/yanlış cevap istatistikleri, XP, enerji, rozet, VIP durumu, geri bildirimler, bildirim tercihleri ve uygulama kullanım kayıtları işlenebilir.

Verilerin Kullanım Amacı
Bu veriler; kullanıcı hesabını oluşturmak, giriş güvenliğini sağlamak, sınav ilerlemesini kaydetmek, istatistik ve sıralama özelliklerini çalıştırmak, VIP haklarını yönetmek, bildirim tercihlerini uygulamak, destek taleplerini yanıtlamak ve uygulama deneyimini iyileştirmek için kullanılır.

Üçüncü Taraf Servisler
Bilgi Rotası; Firebase Auth, Cloud Firestore, Google Mobile Ads, Google Play satın alma servisleri ve yerel bildirim servisleri gibi teknik altyapılardan yararlanabilir. Bu servisler yalnızca uygulamanın çalışması, güvenliği, reklam/satın alma ve veri saklama süreçleri için kullanılır.

Kişisel Verilerin Korunması
SONERLER BİLİŞİM, kullanıcı verilerini yetkisiz erişime karşı korumak için makul teknik ve idari önlemler alır. Veriler satılmaz, kiralanmaz ve uygulama amacı dışında üçüncü kişilerle paylaşılmaz. Yasal zorunluluklar saklıdır.

Kullanıcı Hakları
Kullanıcı; hesabının silinmesini, kayıtlı bilgileriyle ilgili destek almayı veya kişisel verileri hakkında bilgi talep etmeyi isteyebilir. Hesap silme işlemi uygulama içindeki ayarlar ekranından yapılabilir.

İletişim
Gizlilik ve kişisel veri konularındaki talepler için uygulama içindeki geri bildirim alanı üzerinden SONERLER BİLİŞİM'e ulaşabilirsiniz."""
        : r"""Bilgi Rotası Kullanım Koşulları

Bilgi Rotası, SONERLER BİLİŞİM tarafından sunulan bir eğitim ve sınav hazırlık uygulamasıdır. Uygulamayı kullanan herkes bu koşulları kabul etmiş sayılır.

Kullanım Amacı
Uygulama; sınavlara hazırlık, soru çözme, deneme çözme, ilerleme takibi, istatistik görüntüleme, görev ve rozet sistemi, VIP ayrıcalıkları ve eğitim materyali talepleri için geliştirilmiştir.

Hesap Sorumluluğu
Kullanıcı, hesabındaki bilgilerin doğruluğundan ve hesabının güvenliğinden sorumludur. Hesap bilgilerinin üçüncü kişilerle paylaşılması önerilmez.

İçerik ve Hizmetler
Bilgi Rotası içindeki sorular, istatistikler, rozetler, enerji sistemi, denemeler, PDF talepleri ve VIP özellikleri uygulama deneyimini desteklemek amacıyla sunulur. SONERLER BİLİŞİM, uygulama içeriğini, özellikleri ve kullanım kurallarını geliştirme veya güncelleme hakkını saklı tutar.

VIP ve Satın Alma
VIP üyelik veya uygulama içi satın alma işlemleri ilgili mağaza, ödeme sağlayıcısı ve uygulama kurallarına göre yürütülür. VIP hakları kullanıcı hesabına tanımlanır ve uygulamada belirtilen limitler dahilinde kullanılır.

Uygunsuz Kullanım
Uygulamanın kötüye kullanılması, sistemi manipüle etmeye çalışma, izinsiz veri çekme, hileli kullanım veya başka kullanıcıların deneyimini bozacak davranışlar yasaktır. Bu tür durumlarda hesap erişimi kısıtlanabilir.

Sorumluluk Sınırı
Bilgi Rotası eğitim desteği sunar; sınav sonucu veya başarı garantisi vermez. Kullanıcı, çalışma planı ve sınav hazırlığıyla ilgili kendi sorumluluğunu taşır.

İletişim
Kullanım koşullarıyla ilgili talepler için uygulama içindeki geri bildirim alanı üzerinden SONERLER BİLİŞİM'e ulaşabilirsiniz.""";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F6A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              body,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Kapat',
              style: GoogleFonts.poppins(color: const Color(0xFF00E5FF)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.delete();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AuthPage()),
            (route) => false);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Hata: Hesabınızı silmek için tekrar giriş yapmanız gerekebilir.')));
      }
    }
  }

  Future<void> _resetPassword() async {
    final user = _auth.currentUser;
    if (user != null && user.email != null) {
      try {
        await _auth.sendPasswordResetEmail(email: user.email!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Şifre sıfırlama e-postası gönderildi!'),
            backgroundColor: Colors.green));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('E-posta gönderilemedi.'),
            backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF080C2E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
          ),
        ),
        title: Text('Ayarlar',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0E43),
                  Color(0xFF1B1060),
                  Color(0xFF0D1240)
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -60, right: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF7C5CFC).withValues(alpha: 0.25),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.25, left: -80,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF00E5FF).withValues(alpha: 0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          ..._buildStars(size),
          _buildMovingCloud(
              top: size.height * 0.15,
              scale: 1.1,
              speed: 0.5,
              moveRight: true),
          _buildMovingCloud(
              top: size.height * 0.55,
              scale: 0.8,
              speed: 0.35,
              moveRight: false),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hesap Ayarları ──────────────────────────────────
                  _buildSectionTitle('Hesap Ayarları'),
                  _buildSettingTile(
                    'Şifreyi Değiştir',
                    Icons.lock_outline_rounded,
                    const Color(0xFF00E5FF),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ChangePasswordPage())),
                  ),
                  _buildSettingTile(
                    'Şifre Sıfırlama E-postası',
                    Icons.mail_outline_rounded,
                    Colors.orangeAccent,
                    onTap: _resetPassword,
                  ),
                  const SizedBox(height: 24),

                  // ── Bildirimler ─────────────────────────────────────
                  _buildSectionTitle('Bildirimler'),
                  _buildNotificationSection(),
                  const SizedBox(height: 24),

                  // ── Diğer ──────────────────────────────────────────
                  _buildSectionTitle('Diğer'),
                  _buildSettingTile('Geri Bildirim',
                      Icons.feedback_outlined, Colors.greenAccent,
                      onTap: _showFeedbackDialog),
                  _buildSettingTile(
                    'Kullanım Koşulları',
                    Icons.description_outlined,
                    Colors.white54,
                    onTap: () => _showLegalDialog(isPrivacy: false),
                  ),
                  _buildSettingTile(
                    'Gizlilik Politikası',
                    Icons.privacy_tip_outlined,
                    Colors.white54,
                    onTap: () => _showLegalDialog(isPrivacy: true),
                  ),
                  const SizedBox(height: 24),

                  // ── Hesap İşlemleri ─────────────────────────────────
                  _buildSectionTitle('Hesap İşlemleri'),
                  _buildActionTile('Çıkış Yap', Icons.logout_rounded,
                      const Color(0xFFFF8C00), onTap: () async {
                    final nav = Navigator.of(context);
                    await _auth.signOut();
                    if (!mounted) return;
                    nav.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthPage()),
                        (r) => false);
                  }),
                  _buildActionTile('Hesabı Sil',
                      Icons.delete_forever_rounded, Colors.redAccent,
                      onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1B1F6A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Text('Emin misin?',
                            style: TextStyle(color: Colors.white)),
                        content: const Text(
                            'Hesabın kalıcı olarak silinecek.',
                            style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('İPTAL')),
                          TextButton(
                              onPressed: _deleteAccount,
                              child: const Text('SİL',
                                  style:
                                      TextStyle(color: Colors.redAccent))),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  Center(
                      child: Text('Versiyon 1.0.2',
                          style: GoogleFonts.poppins(
                              color: Colors.white24, fontSize: 12))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bildirim Bölümü ───────────────────────────────────────────────────
  Widget _buildNotificationSection() {
    if (_notifLoading) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(
            color: Color(0xFF00E5FF), strokeWidth: 2),
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Ana açma/kapama
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          Colors.purpleAccent.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.notifications_rounded,
                    color: Colors.purpleAccent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Tüm Bildirimler',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              Switch(
                value: _notifEnabled,
                activeThumbColor: const Color(0xFF00E5FF),
                onChanged: (val) => _updateNotifSetting(() => _notifEnabled = val),
              ),
            ]),
          ),

          if (_notifEnabled) ...[
            Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),

            // Sabah
            _buildNotifTimeTile(
              icon: '☀️',
              label: 'Sabah',
              sublabel: 'Günaydın mesajı',
              time: _morningTime,
              enabled: _morningOn,
              onToggle: (v) => _updateNotifSetting(() => _morningOn = v),
              onTimeTap: () => _pickTime(NotifType.morning),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),

            // Öğlen
            _buildNotifTimeTile(
              icon: '📚',
              label: 'Öğle',
              sublabel: 'Çalışma hatırlatması',
              time: _middayTime,
              enabled: _middayOn,
              onToggle: (v) => _updateNotifSetting(() => _middayOn = v),
              onTimeTap: () => _pickTime(NotifType.midday),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),

            // Akşam
            _buildNotifTimeTile(
              icon: '🌙',
              label: 'Akşam',
              sublabel: 'Günlük özet',
              time: _eveningTime,
              enabled: _eveningOn,
              onToggle: (v) => _updateNotifSetting(() => _eveningOn = v),
              onTimeTap: () => _pickTime(NotifType.evening),
            ),

            Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF00E5FF), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Değişiklikler otomatik kaydedilir.',
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotifTimeTile({
    required String icon,
    required String label,
    required String sublabel,
    required NotifTime time,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required VoidCallback onTimeTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      color: enabled ? Colors.white : Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(sublabel,
                  style: GoogleFonts.poppins(
                      color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),
        // Saat seçici
        GestureDetector(
          onTap: enabled ? onTimeTap : null,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: enabled
                      ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(time.label,
                style: GoogleFonts.poppins(
                    color: enabled
                        ? const Color(0xFF00E5FF)
                        : Colors.white38,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: enabled,
          activeThumbColor: const Color(0xFF00E5FF),
          onChanged: onToggle,
        ),
      ]),
    );
  }

  // ── Yardımcı widget'lar ───────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 4),
      child: Row(children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF7C5CFC)]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      ]),
    );
  }

  Widget _buildSettingTile(String title, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Text(title,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500))),
          Icon(Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.25), size: 20),
        ]),
      ),
    );
  }

  Widget _buildActionTile(String title, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Text(title,
              style: GoogleFonts.poppins(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  List<Widget> _buildStars(Size size) {
    final rand = Random(77);
    return List.generate(
        22,
        (_) => Positioned(
              left: rand.nextDouble() * size.width,
              top: rand.nextDouble() * size.height,
              child: Icon(Icons.star,
                  size: rand.nextDouble() * 3 + 1.5,
                  color: Colors.white.withValues(alpha: 0.25)),
            ));
  }

  Widget _buildMovingCloud(
      {required double top,
      required double scale,
      required double speed,
      required bool moveRight}) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final sw = MediaQuery.of(context).size.width;
        final cw = 100.0 * scale;
        double offset =
            (_bgController.value * speed * (sw + cw)) % (sw + cw);
        if (!moveRight) offset = sw - offset;
        return Positioned(
          top: top,
          left: offset - cw,
          child: Opacity(
            opacity: 0.08,
            child: Icon(Icons.cloud_rounded,
                color: Colors.white, size: 100 * scale),
          ),
        );
      },
    );
  }
}