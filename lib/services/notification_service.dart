import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Bildirim türleri
enum NotifType { morning, midday, evening }

/// Bildirim zamanı modeli
class NotifTime {
  final int hour;
  final int minute;
  const NotifTime(this.hour, this.minute);

  TimeOfDay toTimeOfDay() => TimeOfDay(hour: hour, minute: minute);

  String get label {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, int> toMap() => {'hour': hour, 'minute': minute};
  factory NotifTime.fromMap(Map<String, int> map) =>
      NotifTime(map['hour'] ?? 0, map['minute'] ?? 0);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Sablon mesajlar ────────────────────────────────────────────────────
  static const List<String> _morningMessages = [
    'Günaydın! Hazır mısın? ☀️ Bugün yeni bir bölüm seni bekliyor!',
    'Günaydın! 🌅 Hedefine ulaşmak için harika bir gün!',
    'Sabah çalışması, gün boyu başarı! ☀️ Hadi başlayalım!',
    'Günaydın! 🚀 Bugün kaç soru çözeceksin?',
  ];
  static const List<String> _middayMessages = [
    'Bugün test çözdün mü? 📚 Öğlen molasında birkaç soru!',
    'Öğle arası = Beyin arası! 💪 Hızlı bir test çözmeye ne dersin?',
    '📖 Gün ortası motivasyonu: Her soru seni hedefe yaklaştırır!',
    'Bir bölüm daha tamamla, sıralamanda yüksel! 🏆',
  ];
  static const List<String> _eveningMessages = [
    'Akşam öğrenme vakti! 🌙 Bugünkü hedefini tamamladın mı?',
    '🌙 Akşam çalışması yarın sınavda fark yaratır!',
    'Günü iyi tamamla! 🌟 Son bir bölüm kaldı, hadi bitirelim!',
    '🔥 Bugün kaç doğru yaptın? Streak\'ini korumayı unutma!',
  ];

  // ── Varsayılan saatler ────────────────────────────────────────────────
  static const NotifTime defaultMorning  = NotifTime(8, 0);
  static const NotifTime defaultMidday   = NotifTime(12, 0);
  static const NotifTime defaultEvening  = NotifTime(20, 0);

  // ── SharedPreferences anahtarları ─────────────────────────────────────
  static const String _keyEnabled  = 'notif_enabled';
  static const String _keyMorningH = 'notif_morning_h';
  static const String _keyMorningM = 'notif_morning_m';
  static const String _keyMiddayH  = 'notif_midday_h';
  static const String _keyMiddayM  = 'notif_midday_m';
  static const String _keyEveningH = 'notif_evening_h';
  static const String _keyEveningM = 'notif_evening_m';
  static const String _keyMorningOn  = 'notif_morning_on';
  static const String _keyMiddayOn   = 'notif_midday_on';
  static const String _keyEveningOn  = 'notif_evening_on';

  // ── Başlatma ──────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  // ── İzin iste ─────────────────────────────────────────────────────────
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    // Android 12 ve altı sürümlerde runtime bildirim izni yoktur.
    // Bu cihazlarda requestNotificationsPermission null dönebildiği için
    // null değerini izin var kabul ediyoruz; aksi halde bildirimler hiç
    // planlanmadan iptal olabiliyordu.
    bool granted = android == null && ios == null;
    if (android != null) {
      granted = await android.requestNotificationsPermission() ?? true;
      // Android 12+ cihazlarda kayıtlı saatlerde bildirim gelebilmesi için
      // exact alarm izni gerekebilir. Eski plugin/cihazlarda yoksa sessiz geç.
      try {
        await (android as dynamic).requestExactAlarmsPermission();
      } catch (_) {}
    }
    if (ios != null) {
      granted = await ios.requestPermissions(
            alert: true, badge: true, sound: true) ??
          false;
    }
    return granted;
  }

  // ── Bildirim kanalı ───────────────────────────────────────────────────
  AndroidNotificationDetails get _androidDetails =>
      const AndroidNotificationDetails(
        'bilgi_rotasi_reminders',
        'Hatırlatma Bildirimleri',
        channelDescription: 'Günlük çalışma hatırlatmaları',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

  NotificationDetails get _notifDetails =>
      NotificationDetails(android: _androidDetails,
          iOS: const DarwinNotificationDetails());

  // ── Tüm bildirimleri planla ────────────────────────────────────────────
  Future<void> scheduleAll() async {
    await initialize();
    final granted = await requestPermission();
    await _plugin.cancelAll();
    if (!granted) return;

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? true;
    if (!enabled) return;

    final morningOn  = prefs.getBool(_keyMorningOn)  ?? true;
    final middayOn   = prefs.getBool(_keyMiddayOn)   ?? true;
    final eveningOn  = prefs.getBool(_keyEveningOn)  ?? true;

    final morningTime = NotifTime(
      prefs.getInt(_keyMorningH) ?? defaultMorning.hour,
      prefs.getInt(_keyMorningM) ?? defaultMorning.minute,
    );
    final middayTime = NotifTime(
      prefs.getInt(_keyMiddayH) ?? defaultMidday.hour,
      prefs.getInt(_keyMiddayM) ?? defaultMidday.minute,
    );
    final eveningTime = NotifTime(
      prefs.getInt(_keyEveningH) ?? defaultEvening.hour,
      prefs.getInt(_keyEveningM) ?? defaultEvening.minute,
    );

    if (morningOn)  await _scheduleDaily(10, '☀️ Bilgi Rotası', _pickMessage(_morningMessages),  morningTime);
    if (middayOn)   await _scheduleDaily(11, '📚 Bilgi Rotası', _pickMessage(_middayMessages),   middayTime);
    if (eveningOn)  await _scheduleDaily(12, '🌙 Bilgi Rotası', _pickMessage(_eveningMessages),  eveningTime);
  }

  Future<void> _scheduleDaily(
    int id,
    String title,
    String body,
    NotifTime time,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _notifDetails,
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Bazı Android cihazlarda exact alarm izni kapalı olabilir.
      // Bu durumda bildirim tamamen boşa düşmesin diye inexact plana düşer.
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _notifDetails,
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }


  // ── Test bildirimi: ayarlardan hemen kontrol etmek için ───────────────
  Future<bool> showTestNotification() async {
    await initialize();
    final granted = await requestPermission();
    if (!granted) return false;
    // Test bildirimi izin akışını tetiklediği için, başarılı testte önce
    // kayıtlı saatleri yeniden planlıyoruz, sonra anlık testi gösteriyoruz.
    await scheduleAll();
    await _plugin.show(
      99,
      '🔔 Bilgi Rotası',
      'Bildirimler çalışıyor! Günlük hatırlatmalar seçtiğin saatlerde gelecek.',
      _notifDetails,
    );
    return true;
  }

  // ── Bildirimleri iptal et ─────────────────────────────────────────────
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  // ── Ayarları oku ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled':    prefs.getBool(_keyEnabled)    ?? true,
      'morningOn':  prefs.getBool(_keyMorningOn)  ?? true,
      'middayOn':   prefs.getBool(_keyMiddayOn)   ?? true,
      'eveningOn':  prefs.getBool(_keyEveningOn)  ?? true,
      'morningH':   prefs.getInt(_keyMorningH)    ?? defaultMorning.hour,
      'morningM':   prefs.getInt(_keyMorningM)    ?? defaultMorning.minute,
      'middayH':    prefs.getInt(_keyMiddayH)     ?? defaultMidday.hour,
      'middayM':    prefs.getInt(_keyMiddayM)     ?? defaultMidday.minute,
      'eveningH':   prefs.getInt(_keyEveningH)    ?? defaultEvening.hour,
      'eveningM':   prefs.getInt(_keyEveningM)    ?? defaultEvening.minute,
    };
  }

  // ── Ayarları kaydet ve yeniden planla ─────────────────────────────────
  Future<void> saveSettings({
    required bool enabled,
    required bool morningOn,
    required bool middayOn,
    required bool eveningOn,
    required NotifTime morning,
    required NotifTime midday,
    required NotifTime evening,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled,   enabled);
    await prefs.setBool(_keyMorningOn, morningOn);
    await prefs.setBool(_keyMiddayOn,  middayOn);
    await prefs.setBool(_keyEveningOn, eveningOn);
    await prefs.setInt(_keyMorningH,   morning.hour);
    await prefs.setInt(_keyMorningM,   morning.minute);
    await prefs.setInt(_keyMiddayH,    midday.hour);
    await prefs.setInt(_keyMiddayM,    midday.minute);
    await prefs.setInt(_keyEveningH,   evening.hour);
    await prefs.setInt(_keyEveningM,   evening.minute);

    if (enabled) {
      await scheduleAll();
    } else {
      await cancelAll();
    }
  }

  String _pickMessage(List<String> messages) {
    final idx = DateTime.now().day % messages.length;
    return messages[idx];
  }
}