import 'dart:io';

void main() {
  // assets klasörünü hedef al
  final directory = Directory('assets');

  if (!directory.existsSync()) {
    print('HATA: assets klasörü bulunamadı! Ana dizinde olduğundan emin ol.');
    return;
  }

  // Klasördeki tüm dosyaları (alt klasörler dahil) gez
  final files = directory.listSync(recursive: true).whereType<File>();

  int count = 0;

  for (var file in files) {
    if (!file.path.endsWith('.json')) continue;

    final oldName = file.uri.pathSegments.last;
    final parentPath = file.parent.path;

    // 1. Küçük harfe çevir ve Türkçe karakterleri İngilizce'ye dönüştür
    String newName = oldName.toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('i̇', 'i') // Büyük İ küçülünce bazen bozuk çıkar, onu düzeltir
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');

    // 2. Boşlukları, tireleri ve noktalama işaretlerini alt çizgiye (_) çevir
    newName = newName.replaceAll(RegExp(r'[^a-z0-9.]'), '_');

    // 3. İsimlerin başındaki gereksiz ders/sınav etiketlerini sil (Koddaki sade isimlere ulaşmak için)
    final prefixesToRemove = [
      'ayt_', 'tyt_', 'kpss_', 'lisans_', 'onlisans_',
      'sayisal_', 'esitagirlik_', 'sozel_',
      'matematik_', 'fizik_', 'kimya_', 'biyoloji_',
      'tarih_', 'cografya_', 'turkce_', 'vatandaslik_',
      'felsefe_', 'edebiyat_', 'din_', 'kultur_'
    ];

    // Önekleri 3 tur temizle ki "kpss_lisans_turkce_sozcukte_anlam" -> "sozcukte_anlam" kalsın
    for (int i = 0; i < 3; i++) {
      for (var prefix in prefixesToRemove) {
        if (newName.startsWith(prefix)) {
          newName = newName.substring(prefix.length);
        }
      }
    }

    // 4. Yan yana gelmiş birden fazla alt çizgiyi (_) teke düşür
    newName = newName.replaceAll(RegExp(r'_+'), '_');

    // Dosyayı yeniden adlandır
    final newPath = '$parentPath/$newName';
    if (file.path != newPath) {
      file.renameSync(newPath);
      print('✅ Değişti: $oldName  -->  $newName');
      count++;
    }
  }

  print('🎉 İşlem Tamamlandı! Toplam $count dosya saniyeler içinde düzeltildi.');
}