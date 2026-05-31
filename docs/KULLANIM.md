# Subtle Exam App Sound Pack

Bu paket sınav/mobil uygulama için daha minimal ve rahatsız etmeyen seslerden oluşur.
Mario/oyun salonu hissi veren jingle yoktur.

## Ses mantığı

- click.wav: çok kısa, düşük frekanslı yumuşak tıklama
- correct.wav: kısa pozitif onay
- wrong.wav: sakin düşük yanlış cevabı
- quiz_complete.wav: kısa tamamlandı hissi
- victory.wav: yüksek başarı ama abartısız
- defeat.wav: düşük skor/kaybetme ama moral bozucu değil
- energy_gain.wav: reklam/enerji/puan kazanma
- reward.wav: görev ödülü
- notification.wav: hafif uyarı
- level_unlock.wav: bölüm/kilit açma
- purchase_success.wav: VIP/satın alma

## Kopyalama

Projeye kopyala:

- assets/sounds/
- lib/services/sound_service.dart
- lib/widgets/global_tap_sound.dart
- scripts/apply_subtle_exam_sound_patch.py

## Çalıştır

```bash
python scripts/apply_subtle_exam_sound_patch.py
flutter clean
flutter pub get
flutter run
```

Hot reload yetmez. Uygulamayı kapatıp yeniden aç.
