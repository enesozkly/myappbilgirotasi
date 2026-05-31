# Kopyalama ve Patch Sırası

## 1) Önce yedek al

Şunları yedekle:
- pubspec.yaml
- lib/main.dart
- lib/services/reklam_servisi.dart
- android/app/src/main/AndroidManifest.xml

## 2) Paketten dosyaları aynı yollara kopyala

- pubspec.yaml
- lib/main.dart
- lib/services/reklam_servisi.dart
- lib/services/sound_service.dart
- lib/widgets/global_tap_sound.dart
- lib/widgets/rewarded_ad_button.dart
- android/app/src/main/AndroidManifest.xml
- assets/sounds/
- scripts/apply_sound_everywhere_patch.py

## 3) Otomatik ses patch script'ini çalıştır

Proje ana klasöründe:

```bash
python scripts/apply_sound_everywhere_patch.py
```

Bu script şu dosyalara ses çağrılarını eklemeye çalışır:

- lib/screens/quiz_page.dart
- lib/screens/mini_exam_page.dart
- lib/screens/trial_quiz_page.dart
- lib/screens/multiplayer_quiz_page.dart
- lib/screens/store_page.dart
- lib/screens/missions_sheet.dart
- lib/screens/mission_service.dart
- lib/screens/level_map_page.dart
- lib/screens/subjects_page.dart
- lib/screens/topics_page.dart

Her dosyanın `.bak` yedeğini alır.

## 4) Temiz çalıştır

```bash
flutter clean
flutter pub get
flutter run
```

Hot reload yetmez. Uygulamayı komple kapatıp aç.

## 5) Seslerin nerede çalışması gerekir?

- Her tıklama: otomatik click.wav
- Doğru cevap: correct.wav
- Yanlış cevap: wrong.wav
- Test/deneme bitiş: skora göre victory / quiz_complete / defeat
- Multiplayer bitiş: quiz_complete, gerekirse victory/defeat manuel bağlanabilir
- Reklam ödülü/enerji: energy_gain.wav
- Görev ödülü: reward.wav
- Satın alma başarılı: purchase_success.wav
- Kilit/level açma: level_unlock.wav
