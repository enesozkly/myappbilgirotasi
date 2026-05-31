# Kopyalama Sırası

1. Projede yedek al:
   - pubspec.yaml
   - lib/main.dart
   - lib/services/reklam_servisi.dart
   - android/app/src/main/AndroidManifest.xml

2. Bu paketten şu dosyaları aynı yollara kopyala:
   - pubspec.yaml
   - lib/main.dart
   - lib/services/reklam_servisi.dart
   - lib/services/sound_service.dart
   - android/app/src/main/AndroidManifest.xml
   - assets/sounds/

3. Terminalde çalıştır:
   flutter clean
   flutter pub get

4. Android test:
   flutter run --release

5. Reklam testi için:
   - 4 test/bölüm bitir. 4. bitişte geçiş reklamı çağrılır.
   - Reklam izle puan/enerji kazan butonunda `ReklamServisi.reklamIzletFuture()` kullanılmalı.

Not:
Eğer mevcut AndroidManifest içinde özel başka ayarlar eklediysen, önce yedekle.
