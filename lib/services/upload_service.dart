import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';

class QuestionUploader {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<Map<String, String>> _dosyaListesi = [
    // ──────────────────────────────────────────────────────────────────────────
    // TYT BÖLÜMÜ
    // ──────────────────────────────────────────────────────────────────────────
    // TYT TÜRKÇE
    {'file': 'assets/tyt_turkce/anlatim_bozukluklari.json', 'ders': 'Türkçe', 'konu': 'Anlatım Bozuklukları', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_turkce/cumlede_anlam.json', 'ders': 'Türkçe', 'konu': 'Cümlede Anlam', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_turkce/cumlenin_ogeleri.json', 'ders': 'Türkçe', 'konu': 'Cümlenin Ögeleri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_turkce/cumle_turleri.json', 'ders': 'Türkçe', 'konu': 'Cümle Türleri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_turkce/dil_bilgisi_ses_olaylari.json', 'ders': 'Türkçe', 'konu': 'Dil Bilgisi Ses Olayları', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_turkce/mantik.json', 'ders': 'Türkçe', 'konu': 'Mantık', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_turkce/noktalama_isaretleri.json', 'ders': 'Türkçe', 'konu': 'Noktalama İşaretleri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_turkce/paragrafta_anlam.json', 'ders': 'Türkçe', 'konu': 'Paragrafta Anlam', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_turkce/paragrafta_anlatim_bicimi.json', 'ders': 'Türkçe', 'konu': 'Paragrafta Anlatım Biçimi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_turkce/sozcukte_anlam.json', 'ders': 'Türkçe', 'konu': 'Sözcükte Anlam', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_turkce/sozcukte_yapi.json', 'ders': 'Türkçe', 'konu': 'Sözcükte Yapı', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_turkce/sozcuk_turleri.json', 'ders': 'Türkçe', 'konu': 'Sözcük Türleri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_turkce/yazim_kurallari.json', 'ders': 'Türkçe', 'konu': 'Yazım Kuralları', 'exam': 'TYT', 'tip': 'json'},

    // TYT MATEMATİK
    {'file': 'assets/tyt_matematik/basit_esitsizlikler.json', 'ders': 'Matematik', 'konu': 'Basit Eşitsizlikler', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/carpanlara_ayirma.json', 'ders': 'Matematik', 'konu': 'Çarpanlara Ayırma', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/denklem_cozme.json', 'ders': 'Matematik', 'konu': 'Denklem Çözme', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/fonksiyonlar.json', 'ders': 'Matematik', 'konu': 'Fonksiyonlar', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/islem.json', 'ders': 'Matematik', 'konu': 'İşlem', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/koklu_sayilar.json', 'ders': 'Matematik', 'konu': 'Köklü Sayılar', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/kumeler.json', 'ders': 'Matematik', 'konu': 'Kümeler', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/mantik.json', 'ders': 'Matematik', 'konu': 'Mantık', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/mutlak_deger.json', 'ders': 'Matematik', 'konu': 'Mutlak Değer', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/olasilik.json', 'ders': 'Matematik', 'konu': 'Olasılık', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/oran_oranti.json', 'ders': 'Matematik', 'konu': 'Oran Orantı', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/permutasyon_kombinasyon.json', 'ders': 'Matematik', 'konu': 'Permütasyon Kombinasyon', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/problemler.json', 'ders': 'Matematik', 'konu': 'Problemler', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/rasyonel_sayilar_ondalikli_sayilar.json', 'ders': 'Matematik', 'konu': 'Rasyonel Sayılar Ondalıklı Sayılar', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/temel_kavramlar.json', 'ders': 'Matematik', 'konu': 'Temel Kavramlar', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_matematik/uslu_sayilar.json', 'ders': 'Matematik', 'konu': 'Üslü Sayılar', 'exam': 'TYT', 'tip': 'json'},

    // TYT TARİH
    {'file': 'assets/tyt_tarih/17_yuzyil_osmanli_devleti_duraklama_donemi.json', 'ders': 'Tarih', 'konu': '17. Yüzyıl Osmanlı Devleti Duraklama Dönemi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_tarih/18_yuzyil_osmanli_devleti_gerileme_donemi.json', 'ders': 'Tarih', 'konu': '18. Yüzyıl Osmanlı Devleti Gerileme Dönemi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_tarih/19_yuzyil_osmanli_devleti_dagilma_donemi.json', 'ders': 'Tarih', 'konu': '19. Yüzyıl Osmanlı Devleti Dağılma Dönemi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_tarih/20_yuzyil_osmanli_devleti.json', 'ders': 'Tarih', 'konu': '20. Yüzyıl Osmanlı Devleti', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_tarih/ataturk_donemi_ic_ve_dis_politikalar.json', 'ders': 'Tarih', 'konu': 'Atatürk Dönemi İç ve Dış Politikalar', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_tarih/cagdas_turk_ve_dunya_tarihi.json', 'ders': 'Tarih', 'konu': 'Çağdaş Türk ve Dünya Tarihi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_tarih/ilk_turk_islam_devletleri.json', 'ders': 'Tarih', 'konu': 'İlk Türk İslam Devletleri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_tarih/ilk_turk_islam_devletlerinde_kultur_ve_medeniyet.json', 'ders': 'Tarih', 'konu': 'İlk Türk İslam Devletlerinde Kültür ve Medeniyet', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_tarih/inkilap_tarihi.json', 'ders': 'Tarih', 'konu': 'İnkılap Tarihi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_tarih/islamiyet_oncesi_turk_tarihi_soru_bankasi.json', 'ders': 'Tarih', 'konu': 'İslamiyet Öncesi Türk Tarihi Soru Bankası', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_tarih/islam_oncesi_turk_tarihi.json', 'ders': 'Tarih', 'konu': 'İslam Öncesi Türk Tarihi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_tarih/milli_mucadele_donemi.json', 'ders': 'Tarih', 'konu': 'Milli Mücadele Dönemi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_tarih/osmanli_devleti_kultur_ve_medeniyet.json', 'ders': 'Tarih', 'konu': 'Osmanlı Devleti Kültür ve Medeniyet', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_tarih/osmanli_devleti_kurulus_ve_yukselme_donemi.json', 'ders': 'Tarih', 'konu': 'Osmanlı Devleti Kuruluş ve Yükselme Dönemi', 'exam': 'TYT', 'tip': 'json'},

    // TYT COĞRAFYA
    {'file': 'assets/tyt_cografya/bolgeler_cografyasi.json', 'ders': 'Coğrafya', 'konu': 'Bölgeler Coğrafyası', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_cografya/hayvancilik.json', 'ders': 'Coğrafya', 'konu': 'Hayvancılık', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_cografya/madenler_ve_enerji.json', 'ders': 'Coğrafya', 'konu': 'Madenler ve Enerji', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_cografya/sanayi_ve_endustri.json', 'ders': 'Coğrafya', 'konu': 'Sanayi ve Endüstri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_cografya/tarim.json', 'ders': 'Coğrafya', 'konu': 'Tarım', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_cografya/ticaret.json', 'ders': 'Coğrafya', 'konu': 'Ticaret', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_cografya/turizm.json', 'ders': 'Coğrafya', 'konu': 'Turizm', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_cografya/turkiye_de_nufus_ve_yerlesme.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'de Nüfus ve Yerleşme', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_cografya/turkiye_nin_cografi_konumu.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'nin Coğrafi Konumu', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_cografya/turkiye_nin_fiziki_ozellikleri.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'nin Fiziki Özellikleri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_cografya/turkiye_nin_iklimi_ve_bitki_ortusu.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'nin İklimi ve Bitki Örtüsü', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_cografya/ulasim.json', 'ders': 'Coğrafya', 'konu': 'Ulaşım', 'exam': 'TYT', 'tip': 'json'},

    // TYT DİN
    {'file': 'assets/tyt_din/allah_insan_iliskisi.json', 'ders': 'Din Kültürü', 'konu': 'Allah İnsan İlişkisi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_din/anadoluda_islam.json', 'ders': 'Din Kültürü', 'konu': 'Anadolu\'da İslam', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_din/dunya_ve_ahiret.json', 'ders': 'Din Kültürü', 'konu': 'Dünya ve Ahiret', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_din/guncel_dini_meseleler.json', 'ders': 'Din Kültürü', 'konu': 'Güncel Dini Meseleler', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_din/hint_ve_cin_dinleri.json', 'ders': 'Din Kültürü', 'konu': 'Hint ve Çin Dinleri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_din/inancla_ilgili_meseleler.json', 'ders': 'Din Kültürü', 'konu': 'İnançla İlgili Meseleler', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_din/islam_dusuncesinde_tasavvufi_yorumlar_ve_mezhepler.json', 'ders': 'Din Kültürü', 'konu': 'İslam Düşüncesinde Tasavvufi Yorumlar ve Mezhepler', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_din/islam_ve_bilim.json', 'ders': 'Din Kültürü', 'konu': 'İslam ve Bilim', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_din/kurana_gore_hz_muhammed.json', 'ders': 'Din Kültürü', 'konu': 'Kur\'an\'a Göre Hz Muhammed', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_din/kurandan_mesajlar.json', 'ders': 'Din Kültürü', 'konu': 'Kur\'an\'dan Mesajlar', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_din/kuranda_bazi_kavramlar.json', 'ders': 'Din Kültürü', 'konu': 'Kur\'an\'da Bazı Kavramlar', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_din/yahudilik_ve_hristiyanlik.json', 'ders': 'Din Kültürü', 'konu': 'Yahudilik ve Hristiyanlık', 'exam': 'TYT', 'tip': 'json'},

    // TYT FELSEFE
    {'file': 'assets/tyt_felsefe/20._yuzyil_felsefesi.json', 'ders': 'Felsefe', 'konu': '20. Yüzyıl Felsefesi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/ahlak_felsefesi.json', 'ders': 'Felsefe', 'konu': 'Ahlak Felsefesi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/bilgi_felsefesi.json', 'ders': 'Felsefe', 'konu': 'Bilgi Felsefesi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/birey_ve_toplum.json', 'ders': 'Felsefe', 'konu': 'Birey ve Toplum', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/felsefesi.json', 'ders': 'Felsefe', 'konu': 'Felsefesi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/klasik_mantik.json', 'ders': 'Felsefe', 'konu': 'Klasik Mantık', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/mantiga_giris.json', 'ders': 'Felsefe', 'konu': 'Mantığa Giriş', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/mantik_ve_dil.json', 'ders': 'Felsefe', 'konu': 'Mantık ve Dil', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/ogrenme_bellek_dusunme.json', 'ders': 'Felsefe', 'konu': 'Öğrenme Bellek Düşünme', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/psikolojinin_temel_surecleri.json', 'ders': 'Felsefe', 'konu': 'Psikolojinin Temel Süreçleri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/psikoloji_bilimini_taniyalim.json', 'ders': 'Felsefe', 'konu': 'Psikoloji Bilimini Tanıyalım', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/ruh_sagliginin_temelleri.json', 'ders': 'Felsefe', 'konu': 'Ruh Sağlığının Temelleri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/sosyolojiye_giris.json', 'ders': 'Felsefe', 'konu': 'Sosyolojiye Giriş', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/toplumsal_degisme_ve_gelisme.json', 'ders': 'Felsefe', 'konu': 'Toplumsal Değişme ve Gelişme', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/toplumsal_kurumlar.json', 'ders': 'Felsefe', 'konu': 'Toplumsal Kurumlar', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/toplumsal_yapi.json', 'ders': 'Felsefe', 'konu': 'Toplumsal Yapı', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/toplum_ve_kultur.json', 'ders': 'Felsefe', 'konu': 'Toplum ve Kültür', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/varlik_felsefesi.json', 'ders': 'Felsefe', 'konu': 'Varlık Felsefesi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_felsefe/ve_bilim.json', 'ders': 'Felsefe', 'konu': 'Bilim', 'exam': 'TYT', 'tip': 'json'},

    // TYT BİYOLOJİ
    {'file': 'assets/tyt_biyoloji/bitkiler_biyolojisi.json', 'ders': 'Biyoloji', 'konu': 'Bitkiler Biyolojisi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_biyoloji/canlilarin_ortak_ozellikleri.json', 'ders': 'Biyoloji', 'konu': 'Canlıların Ortak Özellikleri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_biyoloji/canlilarin_siniflandirilmasi.json', 'ders': 'Biyoloji', 'konu': 'Canlıların Sınıflandırılması', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_biyoloji/canlilarin_temel_bilesenleri.json', 'ders': 'Biyoloji', 'konu': 'Canlıların Temel Bileşenleri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_biyoloji/ekosistem_ekolojisi.json', 'ders': 'Biyoloji', 'konu': 'Ekosistem Ekolojisi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_biyoloji/hucre_bolunmeleri_ve_ureme.json', 'ders': 'Biyoloji', 'konu': 'Hücre Bölünmeleri ve Üreme', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_biyoloji/hucre_ve_organelleri.json', 'ders': 'Biyoloji', 'konu': 'Hücre ve Organelleri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_biyoloji/kalitim.json', 'ders': 'Biyoloji', 'konu': 'Kalıtım', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_biyoloji/madde_gecisleri.json', 'ders': 'Biyoloji', 'konu': 'Madde Geçişleri', 'exam': 'TYT', 'tip': 'json'},

    // TYT FİZİK
    {'file': 'assets/tyt_fizik/Basınç.json', 'ders': 'Fizik', 'konu': 'Basınç', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_fizik/Dalgalar.json', 'ders': 'Fizik', 'konu': 'Dalgalar', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_fizik/Dinamik.json', 'ders': 'Fizik', 'konu': 'Dinamik', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_fizik/Elektrik Akımı ve Devreler.json', 'ders': 'Fizik', 'konu': 'Elektrik Akımı ve Devreler', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_fizik/Elektriksel Enerji ve Güç.json', 'ders': 'Fizik', 'konu': 'Elektriksel Enerji ve Güç', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_fizik/Elektrostatik.json', 'ders': 'Fizik', 'konu': 'Elektrostatik', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_fizik/Fizik Bilimine Giriş.json', 'ders': 'Fizik', 'konu': 'Fizik Bilimine Giriş', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_fizik/Hareket ve Kuvvet.json', 'ders': 'Fizik', 'konu': 'Hareket ve Kuvvet', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_fizik/Isı, Sıcaklık ve Genleşme.json', 'ders': 'Fizik', 'konu': 'Isı Sıcaklık ve Genleşme', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_fizik/Madde ve Özellikleri.json', 'ders': 'Fizik', 'konu': 'Madde ve Özellikleri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_fizik/Manyetizma.json', 'ders': 'Fizik', 'konu': 'Manyetizma', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_fizik/Optik.json', 'ders': 'Fizik', 'konu': 'Optik', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_fizik/Sıvıların Kaldırma Kuvveti.json', 'ders': 'Fizik', 'konu': 'Sıvıların Kaldırma Kuvveti', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_fizik/İş, Güç ve Enerji.json', 'ders': 'Fizik', 'konu': 'İş Güç ve Enerji', 'exam': 'TYT', 'tip': 'json'},

    // TYT KİMYA
    {'file': 'assets/tyt_kimya/asit_baz_dengesi.json', 'ders': 'Kimya', 'konu': 'Asit Baz Dengesi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_kimya/atomun_yapisi.json', 'ders': 'Kimya', 'konu': 'Atomun Yapısı', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_kimya/karisimlar.json', 'ders': 'Kimya', 'konu': 'Karışımlar', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_kimya/kimyanin_temel_kanunlari.json', 'ders': 'Kimya', 'konu': 'Kimyanın Temel Kanunları', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_kimya/kimyasal_hesaplamalar.json', 'ders': 'Kimya', 'konu': 'Kimyasal Hesaplamalar', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_kimya/kimyasal_turler_arasi_etkilesim.json', 'ders': 'Kimya', 'konu': 'Kimyasal Türler Arası Etkileşim', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_kimya/kimya_bilimi.json', 'ders': 'Kimya', 'konu': 'Kimya Bilimi', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_kimya/kimya_her_yerde.json', 'ders': 'Kimya', 'konu': 'Kimya Her Yerde', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_kimya/maddenin_halleri.json', 'ders': 'Kimya', 'konu': 'Maddenin Halleri', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_kimya/periyodik_sistem.json', 'ders': 'Kimya', 'konu': 'Periyodik Sistem', 'exam': 'TYT', 'tip': 'json'},
    {'file': 'assets/tyt_kimya/sivi_cozeltiler.json', 'ders': 'Kimya', 'konu': 'Sıvı Çözeltiler', 'exam': 'TYT', 'tip': 'json'},

    // ──────────────────────────────────────────────────────────────────────────
    // AYT SAYISAL BÖLÜMÜ
    // ──────────────────────────────────────────────────────────────────────────
    // AYT SAYISAL BİYOLOJİ
    {'file': 'assets/ayt_sayisal_biyoloji/bitki_biyolojisi.json', 'ders': 'Biyoloji', 'konu': 'Bitki Biyolojisi', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/canlilar_ve_cevre.json', 'ders': 'Biyoloji', 'konu': 'Canlılar ve Çevre', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/canlilik_ve_enerji.json', 'ders': 'Biyoloji', 'konu': 'Canlılık ve Enerji', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/destek_ve_hareket_sistemi.json', 'ders': 'Biyoloji', 'konu': 'Destek ve Hareket Sistemi', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/dolasim_ve_bagisiklilik_sistemi.json', 'ders': 'Biyoloji', 'konu': 'Dolaşım ve Bağışıklık Sistemi', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/duyu_organlari.json', 'ders': 'Biyoloji', 'konu': 'Duyu Organları', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/endokrin_sistem.json', 'ders': 'Biyoloji', 'konu': 'Endokrin Sistem', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/fotosentez_ve_kemosentez.json', 'ders': 'Biyoloji', 'konu': 'Fotosentez ve Kemosentez', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/genetik_sifre_ve_protein_sentezi.json', 'ders': 'Biyoloji', 'konu': 'Genetik Şifre ve Protein Sentezi', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/hucresel_solunum.json', 'ders': 'Biyoloji', 'konu': 'Hücresel Solunum', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/komunite_ve_populasyon_ekolojisi.json', 'ders': 'Biyoloji', 'konu': 'Komünite ve Popülasyon Ekolojisi', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/nukleik_asitler.json', 'ders': 'Biyoloji', 'konu': 'Nükleik Asitler', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/sindirim_sistemi.json', 'ders': 'Biyoloji', 'konu': 'Sindirim Sistemi', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/sinir_sistemi.json', 'ders': 'Biyoloji', 'konu': 'Sinir Sistemi', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/solunum_sistemi.json', 'ders': 'Biyoloji', 'konu': 'Solunum Sistemi', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/ureme_sistemi_ve_embriyonik_gelisim.json', 'ders': 'Biyoloji', 'konu': 'Üreme Sistemi ve Embriyonik Gelişim', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_biyoloji/uriner_sistem.json', 'ders': 'Biyoloji', 'konu': 'Üriner Sistem', 'exam': 'AYT Sayısal', 'tip': 'json'},

    // AYT SAYISAL FİZİK
    {'file': 'assets/ayt_sayisal_fizik/atislar.json', 'ders': 'Fizik', 'konu': 'Atışlar', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/atom_modelleri.json', 'ders': 'Fizik', 'konu': 'Atom Modelleri', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/basit_harmonik_hareket.json', 'ders': 'Fizik', 'konu': 'Basit Harmonik Hareket', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/basit_makineler.json', 'ders': 'Fizik', 'konu': 'Basit Makineler', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/buyuk_patlama_ve_parcacik_fizigi.json', 'ders': 'Fizik', 'konu': 'Büyük Patlama ve Parçacık Fiziği', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/dalga_mekanigi_ve_elektromanyetik_dalgalar.json', 'ders': 'Fizik', 'konu': 'Dalga Mekaniği ve Elektromanyetik Dalgalar', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/donme_yuvarlanma_ve_acisal_momentum.json', 'ders': 'Fizik', 'konu': 'Dönme Yuvarlanma ve Açısal Momentum', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/duzgun_cembersel_hareket.json', 'ders': 'Fizik', 'konu': 'Düzgün Çembersel Hareket', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/elektrik_alan_ve_potansiyel.json', 'ders': 'Fizik', 'konu': 'Elektrik Alan ve Potansiyel', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/fotoelektrik_olay_ve_compton_olayi.json', 'ders': 'Fizik', 'konu': 'Fotoelektrik Olay ve Compton Olayı', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/hareket.json', 'ders': 'Fizik', 'konu': 'Hareket', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/induksiyon_alternatif_akim_ve_transformatorler.json', 'ders': 'Fizik', 'konu': 'İndüksiyon Alternatif Akım ve Transformatörler', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/is_guc_ve_enerji.json', 'ders': 'Fizik', 'konu': 'İş Güç ve Enerji', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/itme_ve_cizgisel_momentum.json', 'ders': 'Fizik', 'konu': 'İtme ve Çizgisel Momentum', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/kara_cisim_isimasi.json', 'ders': 'Fizik', 'konu': 'Kara Cisim Işıması', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/kutle_cekim_merkezi_ve_acisal_momentum.json', 'ders': 'Fizik', 'konu': 'Kütle Çekim Merkezi ve Açısal Momentum', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/kutle_cekim_ve_kepler_yasalari.json', 'ders': 'Fizik', 'konu': 'Kütle Çekim ve Kepler Yasaları', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/kuvvet_tork_ve_denge.json', 'ders': 'Fizik', 'konu': 'Kuvvet Tork ve Denge', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/manyetik_alan_ve_manyetik_kuvvet.json', 'ders': 'Fizik', 'konu': 'Manyetik Alan ve Manyetik Kuvvet', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/modern_fizigin_teknolojideki_uygulamalari.json', 'ders': 'Fizik', 'konu': 'Modern Fiziğin Teknolojideki Uygulamaları', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/newton_un_hareket_yasalari.json', 'ders': 'Fizik', 'konu': 'Newton\'un Hareket Yasaları', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/ozel_gorelilik.json', 'ders': 'Fizik', 'konu': 'Özel Görelilik', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/paralel_levhalar_ve_siga.json', 'ders': 'Fizik', 'konu': 'Paralel Levhalar ve Sığa', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_fizik/vektorler.json', 'ders': 'Fizik', 'konu': 'Vektörler', 'exam': 'AYT Sayısal', 'tip': 'json'},

    // AYT SAYISAL KİMYA
    {'file': 'assets/ayt_sayisal_kimya/asit_baz_dengesi.json', 'ders': 'Kimya', 'konu': 'Asit Baz Dengesi', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_kimya/atomun_yapisi.json', 'ders': 'Kimya', 'konu': 'Atomun Yapısı', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_kimya/cozunurluk_dengesi.json', 'ders': 'Kimya', 'konu': 'Çözünürlük Dengesi', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_kimya/gazlar.json', 'ders': 'Kimya', 'konu': 'Gazlar', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_kimya/kimyasal_hesaplamalar.json', 'ders': 'Kimya', 'konu': 'Kimyasal Hesaplamalar', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_kimya/kimyasal_tepkimelerde_denge.json', 'ders': 'Kimya', 'konu': 'Kimyasal Tepkimelerde Denge', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_kimya/kimyasal_tepkimelerde_enerji.json', 'ders': 'Kimya', 'konu': 'Kimyasal Tepkimelerde Enerji', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_kimya/kimyasal_tepkimelerde_hiz.json', 'ders': 'Kimya', 'konu': 'Kimyasal Tepkimelerde Hız', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_kimya/kimyasal_turler_arasi_etkilesim.json', 'ders': 'Kimya', 'konu': 'Kimyasal Türler Arası Etkileşim', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_kimya/kimya_bilimi.json', 'ders': 'Kimya', 'konu': 'Kimya Bilimi', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_kimya/kimya_ve_elektrik.json', 'ders': 'Kimya', 'konu': 'Kimya ve Elektrik', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_kimya/modern_atom_teorisi.json', 'ders': 'Kimya', 'konu': 'Modern Atom Teorisi', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_kimya/organik_kimya.json', 'ders': 'Kimya', 'konu': 'Organik Kimya', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_kimya/periyodik_sistem.json', 'ders': 'Kimya', 'konu': 'Periyodik Sistem', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_kimya/sivi_cozeltiler.json', 'ders': 'Kimya', 'konu': 'Sıvı Çözeltiler', 'exam': 'AYT Sayısal', 'tip': 'json'},

    // AYT SAYISAL MATEMATİK
    {'file': 'assets/ayt_sayisal_matematik/bolme_ve_bolunebilme_kurallari.json', 'ders': 'Matematik', 'konu': 'Bölme ve Bölünebilme Kuralları', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_matematik/diziler.json', 'ders': 'Matematik', 'konu': 'Diziler', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_matematik/ebob_ekok.json', 'ders': 'Matematik', 'konu': 'Ebob Ekok', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_matematik/ikinci_dereceden_denklemler_parabol_ve_esitsizlikler.json', 'ders': 'Matematik', 'konu': 'İkinci Dereceden Denklemler Parabol ve Eşitsizlikler', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_matematik/integral.json', 'ders': 'Matematik', 'konu': 'İntegral', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_matematik/karmasik_sayilar.json', 'ders': 'Matematik', 'konu': 'Karmaşık Sayılar', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_matematik/logaritma.json', 'ders': 'Matematik', 'konu': 'Logaritma', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_matematik/parabol.json', 'ders': 'Matematik', 'konu': 'Parabol', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_matematik/permutasyon_kombinasyon_olasilik_binom.json', 'ders': 'Matematik', 'konu': 'Permütasyon Kombinasyon Olasılık Binom', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_matematik/polinom.json', 'ders': 'Matematik', 'konu': 'Polinom', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_matematik/sayi_basamaklari.json', 'ders': 'Matematik', 'konu': 'Sayı Basamakları', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_matematik/trigonometri.json', 'ders': 'Matematik', 'konu': 'Trigonometri', 'exam': 'AYT Sayısal', 'tip': 'json'},
    {'file': 'assets/ayt_sayisal_matematik/turev.json', 'ders': 'Matematik', 'konu': 'Türev', 'exam': 'AYT Sayısal', 'tip': 'json'},

    // ──────────────────────────────────────────────────────────────────────────
    // AYT EŞİT AĞIRLIK BÖLÜMÜ
    // ──────────────────────────────────────────────────────────────────────────
    // AYT EA MATEMATİK
    {'file': 'assets/ayt_esitagirlik_matematik/bolme_ve_bolunebilme_kurallari.json', 'ders': 'Matematik', 'konu': 'Bölme ve Bölünebilme Kuralları', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_matematik/diziler.json', 'ders': 'Matematik', 'konu': 'Diziler', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_matematik/ebob_ekok.json', 'ders': 'Matematik', 'konu': 'Ebob Ekok', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_matematik/ikinci_dereceden_denklemler_parabol_ve_esitsizlikler.json', 'ders': 'Matematik', 'konu': 'İkinci Dereceden Denklemler Parabol ve Eşitsizlikler', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_matematik/integral.json', 'ders': 'Matematik', 'konu': 'İntegral', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_matematik/karmasik_sayilar.json', 'ders': 'Matematik', 'konu': 'Karmaşık Sayılar', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_matematik/logaritma.json', 'ders': 'Matematik', 'konu': 'Logaritma', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_matematik/parabol.json', 'ders': 'Matematik', 'konu': 'Parabol', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_matematik/permutasyon_kombinasyon_olasilik_binom.json', 'ders': 'Matematik', 'konu': 'Permütasyon Kombinasyon Olasılık Binom', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_matematik/polinom.json', 'ders': 'Matematik', 'konu': 'Polinom', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_matematik/sayi_basamaklari.json', 'ders': 'Matematik', 'konu': 'Sayı Basamakları', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_matematik/trigonometri.json', 'ders': 'Matematik', 'konu': 'Trigonometri', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_matematik/turev.json', 'ders': 'Matematik', 'konu': 'Türev', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},

    // AYT EA EDEBİYAT
    {'file': 'assets/ayt_esitagirlik_edebiyat/anlam_bilgisi.json', 'ders': 'Edebiyat', 'konu': 'Anlam Bilgisi', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/cumhuriyet_donemi_edebiyati.json', 'ders': 'Edebiyat', 'konu': 'Cumhuriyet Dönemi Edebiyatı', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/dil_bilgisi.json', 'ders': 'Edebiyat', 'konu': 'Dil Bilgisi', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/divan_edebiyati.json', 'ders': 'Edebiyat', 'konu': 'Divan Edebiyatı', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/edebiyat_akimlari.json', 'ders': 'Edebiyat', 'konu': 'Edebiyat Akımları', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/edebi_sanatlar.json', 'ders': 'Edebiyat', 'konu': 'Edebi Sanatlar', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/halk_edebiyati.json', 'ders': 'Edebiyat', 'konu': 'Halk Edebiyatı', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/islamiyet_oncesi_turk_edebiyati_ve_gecis_donemi.json', 'ders': 'Edebiyat', 'konu': 'İslamiyet Öncesi Türk Edebiyatı ve Geçiş Dönemi', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/metinlerin_turleri.json', 'ders': 'Edebiyat', 'konu': 'Metinlerin Türleri', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/milli_edebiyat.json', 'ders': 'Edebiyat', 'konu': 'Milli Edebiyat', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/servet_i_funun_ve_fecr_i_ati_edebiyati.json', 'ders': 'Edebiyat', 'konu': 'Servet-i Fünun ve Fecr-i Ati Edebiyatı', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/siir_bilgisi.json', 'ders': 'Edebiyat', 'konu': 'Şiir Bilgisi', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/tanzimat_edebiyati.json', 'ders': 'Edebiyat', 'konu': 'Tanzimat Edebiyatı', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/İklim_ve_Yer_Şekilleri.json', 'ders': 'Edebiyat', 'konu': 'İklim ve Yer Şekilleri', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/İç_ve_Dış_Kuvvetler.json', 'ders': 'Edebiyat', 'konu': 'İç ve Dış Kuvvetler', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},

    // AYT EA TARİH
    {'file': 'assets/ayt_esitagirlik_tarih/ataturkculuk_ve_turk_inkilabi.json', 'ders': 'Tarih', 'konu': 'Atatürkçülük ve Türk İnkılabı', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/beylikten_devlete_osmanli_medeniyeti.json', 'ders': 'Tarih', 'konu': 'Beylikten Devlete Osmanlı Medeniyeti', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/beylikten_devlete_osmanli_siyaseti.json', 'ders': 'Tarih', 'konu': 'Beylikten Devlete Osmanlı Siyaseti', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/degisen_dunya_dengeleri_karsisinda_osmanli_siyaseti.json', 'ders': 'Tarih', 'konu': 'Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/degisim_caginda_avrupa_ve_osmanli.json', 'ders': 'Tarih', 'konu': 'Değişim Çağında Avrupa ve Osmanlı', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/devletlesme_surecinde_savascilar_ve_askerler.json', 'ders': 'Tarih', 'konu': 'Devletleşme Sürecinde Savaşçılar ve Askerler', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/devrimler_caginda_degisen_devlet_toplum_iliskileri.json', 'ders': 'Tarih', 'konu': 'Devrimler Çağında Değişen Devlet Toplum İlişkileri', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/dunya_gucu_osmanli_ve_turk_islam_tarihi.json', 'ders': 'Tarih', 'konu': 'Dünya Gücü Osmanlı ve Türk İslam Tarihi', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/ii_dunya_savasi_sonrasinda_turkiye_ve_dunya.json', 'ders': 'Tarih', 'konu': 'II. Dünya Savaşı Sonrasında Türkiye ve Dünya', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/ii_dunya_savasi_surecinde_turkiye_ve_dunya.json', 'ders': 'Tarih', 'konu': 'II. Dünya Savaşı Sürecinde Türkiye ve Dünya', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/iki_savas_arasindaki_donemde_turkiye_ve_dunya.json', 'ders': 'Tarih', 'konu': 'İki Savaş Arasındaki Dönemde Türkiye ve Dünya', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/ilk_ve_orta_caglarda_turk_dunyasi.json', 'ders': 'Tarih', 'konu': 'İlk ve Orta Çağlarda Türk Dünyası', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/insanligin_ilk_donemleri.json', 'ders': 'Tarih', 'konu': 'İnsanlığın İlk Dönemleri', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/islam_medeniyetinin_dogusu_ve_ilk_islam_devletleri.json', 'ders': 'Tarih', 'konu': 'İslam Medeniyetinin Doğuşu ve İlk İslam Devletleri', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/klasik_cagda_osmanli_toplum_duzeni.json', 'ders': 'Tarih', 'konu': 'Klasik Çağda Osmanlı Toplum Düzeni', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/milli_mucadele.json', 'ders': 'Tarih', 'konu': 'Milli Mücadele', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/orta_cag_da_dunya.json', 'ders': 'Tarih', 'konu': 'Orta Çağ\'da Dünya', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/sermaye_ve_emek.json', 'ders': 'Tarih', 'konu': 'Sermaye ve Emek', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/sultan_ve_osmanli_merkez_teskilati.json', 'ders': 'Tarih', 'konu': 'Sultan ve Osmanlı Merkez Teşkilatı', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/tarih_ve_zaman.json', 'ders': 'Tarih', 'konu': 'Tarih ve Zaman', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/Toplumsal Devrim Çağında Dünya ve Türkiye.json', 'ders': 'Tarih', 'konu': 'Toplumsal Devrim Çağında Dünya ve Türkiye', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/Türklerin İslamiyet’i Kabulü ve İlk Türk İslam Devletleri.json', 'ders': 'Tarih', 'konu': 'Türklerin İslamiyet\'i Kabulü ve İlk Türk İslam Devletleri', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/Uluslararası İlişkilerde Denge Stratejisi (1774-1914).json', 'ders': 'Tarih', 'konu': 'Uluslararası İlişkilerde Denge Stratejisi (1774-1914)', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/XIX. ve XX. Yüzyılda Değişen Gündelik Hayat.json', 'ders': 'Tarih', 'konu': 'XIX. ve XX. Yüzyılda Değişen Gündelik Hayat', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya.json', 'ders': 'Tarih', 'konu': 'XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/XXI. Yüzyılın Eşiğinde Türkiye ve Dünya.json', 'ders': 'Tarih', 'konu': 'XXI. Yüzyılın Eşiğinde Türkiye ve Dünya', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi.json', 'ders': 'Tarih', 'konu': 'Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},

    // AYT EA COĞRAFYA
    {'file': 'assets/ayt_esitagirlik_cografya/Bölgeler_ve_Ülkeler.json', 'ders': 'Coğrafya', 'konu': 'Bölgeler ve Ülkeler', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Dünya_nın_Şekli_ve_Hareketleri.json', 'ders': 'Coğrafya', 'konu': 'Dünyanın Şekli ve Hareketleri', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Ekonomik_Faaliyetler_ve_Doğal_Kaynaklar.json', 'ders': 'Coğrafya', 'konu': 'Ekonomik Faaliyetler ve Doğal Kaynaklar', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Ekosistem.json', 'ders': 'Coğrafya', 'konu': 'Ekosistem', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Göç_ve_Şehirleşme.json', 'ders': 'Coğrafya', 'konu': 'Göç ve Şehirleşme', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Harita_Bilgisi.json', 'ders': 'Coğrafya', 'konu': 'Harita Bilgisi', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Kültür_Bölgeleri.json', 'ders': 'Coğrafya', 'konu': 'Kültür Bölgeleri', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Küresel_Ticaret.json', 'ders': 'Coğrafya', 'konu': 'Küresel Ticaret', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Nüfus_Politikaları.json', 'ders': 'Coğrafya', 'konu': 'Nüfus Politikaları', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Türkiye_de_Ekonomi.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'de Ekonomi', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Türkiye_de_Nüfus_ve_Yerleşme.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'de Nüfus ve Yerleşme', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Türkiye_nin_Coğrafi_Konumu.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'nin Coğrafi Konumu', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Türkiye_nin_İşlevsel_Bölgeleri_ve_Kalkınma_Projeleri.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'nin İşlevsel Bölgeleri ve Kalkınma Projeleri', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Uluslararası_Örgütler.json', 'ders': 'Coğrafya', 'konu': 'Uluslararası Örgütler', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Çevre_ve_Toplum.json', 'ders': 'Coğrafya', 'konu': 'Çevre ve Toplum', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Ülkeler_Arası_Etkileşimler.json', 'ders': 'Coğrafya', 'konu': 'Ülkeler Arası Etkileşimler', 'exam': 'AYT Eşit Ağırlık', 'tip': 'json'},

    // ──────────────────────────────────────────────────────────────────────────
    // AYT SÖZEL BÖLÜMÜ
    // ──────────────────────────────────────────────────────────────────────────
    // AYT SÖZEL EDEBİYAT, TARİH, COĞRAFYA (EA'dan çekiliyor)
    {'file': 'assets/ayt_esitagirlik_edebiyat/anlam_bilgisi.json', 'ders': 'Edebiyat', 'konu': 'Anlam Bilgisi', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/cumhuriyet_donemi_edebiyati.json', 'ders': 'Edebiyat', 'konu': 'Cumhuriyet Dönemi Edebiyatı', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/dil_bilgisi.json', 'ders': 'Edebiyat', 'konu': 'Dil Bilgisi', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/divan_edebiyati.json', 'ders': 'Edebiyat', 'konu': 'Divan Edebiyatı', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/edebiyat_akimlari.json', 'ders': 'Edebiyat', 'konu': 'Edebiyat Akımları', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/edebi_sanatlar.json', 'ders': 'Edebiyat', 'konu': 'Edebi Sanatlar', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/halk_edebiyati.json', 'ders': 'Edebiyat', 'konu': 'Halk Edebiyatı', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/islamiyet_oncesi_turk_edebiyati_ve_gecis_donemi.json', 'ders': 'Edebiyat', 'konu': 'İslamiyet Öncesi Türk Edebiyatı ve Geçiş Dönemi', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/metinlerin_turleri.json', 'ders': 'Edebiyat', 'konu': 'Metinlerin Türleri', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/milli_edebiyat.json', 'ders': 'Edebiyat', 'konu': 'Milli Edebiyat', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/servet_i_funun_ve_fecr_i_ati_edebiyati.json', 'ders': 'Edebiyat', 'konu': 'Servet-i Fünun ve Fecr-i Ati Edebiyatı', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/siir_bilgisi.json', 'ders': 'Edebiyat', 'konu': 'Şiir Bilgisi', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/tanzimat_edebiyati.json', 'ders': 'Edebiyat', 'konu': 'Tanzimat Edebiyatı', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/İklim_ve_Yer_Şekilleri.json', 'ders': 'Edebiyat', 'konu': 'İklim ve Yer Şekilleri', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_edebiyat/İç_ve_Dış_Kuvvetler.json', 'ders': 'Edebiyat', 'konu': 'İç ve Dış Kuvvetler', 'exam': 'AYT Sözel', 'tip': 'json'},
    
    // SÖZEL TARİH
    {'file': 'assets/ayt_esitagirlik_tarih/ataturkculuk_ve_turk_inkilabi.json', 'ders': 'Tarih', 'konu': 'Atatürkçülük ve Türk İnkılabı', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/beylikten_devlete_osmanli_medeniyeti.json', 'ders': 'Tarih', 'konu': 'Beylikten Devlete Osmanlı Medeniyeti', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/beylikten_devlete_osmanli_siyaseti.json', 'ders': 'Tarih', 'konu': 'Beylikten Devlete Osmanlı Siyaseti', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/degisen_dunya_dengeleri_karsisinda_osmanli_siyaseti.json', 'ders': 'Tarih', 'konu': 'Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/degisim_caginda_avrupa_ve_osmanli.json', 'ders': 'Tarih', 'konu': 'Değişim Çağında Avrupa ve Osmanlı', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/devletlesme_surecinde_savascilar_ve_askerler.json', 'ders': 'Tarih', 'konu': 'Devletleşme Sürecinde Savaşçılar ve Askerler', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/devrimler_caginda_degisen_devlet_toplum_iliskileri.json', 'ders': 'Tarih', 'konu': 'Devrimler Çağında Değişen Devlet Toplum İlişkileri', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/dunya_gucu_osmanli_ve_turk_islam_tarihi.json', 'ders': 'Tarih', 'konu': 'Dünya Gücü Osmanlı ve Türk İslam Tarihi', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/ii_dunya_savasi_sonrasinda_turkiye_ve_dunya.json', 'ders': 'Tarih', 'konu': 'II. Dünya Savaşı Sonrasında Türkiye ve Dünya', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/ii_dunya_savasi_surecinde_turkiye_ve_dunya.json', 'ders': 'Tarih', 'konu': 'II. Dünya Savaşı Sürecinde Türkiye ve Dünya', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/iki_savas_arasindaki_donemde_turkiye_ve_dunya.json', 'ders': 'Tarih', 'konu': 'İki Savaş Arasındaki Dönemde Türkiye ve Dünya', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/ilk_ve_orta_caglarda_turk_dunyasi.json', 'ders': 'Tarih', 'konu': 'İlk ve Orta Çağlarda Türk Dünyası', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/insanligin_ilk_donemleri.json', 'ders': 'Tarih', 'konu': 'İnsanlığın İlk Dönemleri', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/islam_medeniyetinin_dogusu_ve_ilk_islam_devletleri.json', 'ders': 'Tarih', 'konu': 'İslam Medeniyetinin Doğuşu ve İlk İslam Devletleri', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/klasik_cagda_osmanli_toplum_duzeni.json', 'ders': 'Tarih', 'konu': 'Klasik Çağda Osmanlı Toplum Düzeni', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/milli_mucadele.json', 'ders': 'Tarih', 'konu': 'Milli Mücadele', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/orta_cag_da_dunya.json', 'ders': 'Tarih', 'konu': 'Orta Çağ\'da Dünya', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/sermaye_ve_emek.json', 'ders': 'Tarih', 'konu': 'Sermaye ve Emek', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/sultan_ve_osmanli_merkez_teskilati.json', 'ders': 'Tarih', 'konu': 'Sultan ve Osmanlı Merkez Teşkilatı', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/tarih_ve_zaman.json', 'ders': 'Tarih', 'konu': 'Tarih ve Zaman', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/Toplumsal Devrim Çağında Dünya ve Türkiye.json', 'ders': 'Tarih', 'konu': 'Toplumsal Devrim Çağında Dünya ve Türkiye', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/Türklerin İslamiyet’i Kabulü ve İlk Türk İslam Devletleri.json', 'ders': 'Tarih', 'konu': 'Türklerin İslamiyet\'i Kabulü ve İlk Türk İslam Devletleri', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/Uluslararası İlişkilerde Denge Stratejisi (1774-1914).json', 'ders': 'Tarih', 'konu': 'Uluslararası İlişkilerde Denge Stratejisi (1774-1914)', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/XIX. ve XX. Yüzyılda Değişen Gündelik Hayat.json', 'ders': 'Tarih', 'konu': 'XIX. ve XX. Yüzyılda Değişen Gündelik Hayat', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya.json', 'ders': 'Tarih', 'konu': 'XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/XXI. Yüzyılın Eşiğinde Türkiye ve Dünya.json', 'ders': 'Tarih', 'konu': 'XXI. Yüzyılın Eşiğinde Türkiye ve Dünya', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_tarih/Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi.json', 'ders': 'Tarih', 'konu': 'Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi', 'exam': 'AYT Sözel', 'tip': 'json'},

    // SÖZEL COĞRAFYA
    {'file': 'assets/ayt_esitagirlik_cografya/Bölgeler_ve_Ülkeler.json', 'ders': 'Coğrafya', 'konu': 'Bölgeler ve Ülkeler', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Dünya_nın_Şekli_ve_Hareketleri.json', 'ders': 'Coğrafya', 'konu': 'Dünyanın Şekli ve Hareketleri', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Ekonomik_Faaliyetler_ve_Doğal_Kaynaklar.json', 'ders': 'Coğrafya', 'konu': 'Ekonomik Faaliyetler ve Doğal Kaynaklar', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Ekosistem.json', 'ders': 'Coğrafya', 'konu': 'Ekosistem', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Göç_ve_Şehirleşme.json', 'ders': 'Coğrafya', 'konu': 'Göç ve Şehirleşme', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Harita_Bilgisi.json', 'ders': 'Coğrafya', 'konu': 'Harita Bilgisi', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Kültür_Bölgeleri.json', 'ders': 'Coğrafya', 'konu': 'Kültür Bölgeleri', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Küresel_Ticaret.json', 'ders': 'Coğrafya', 'konu': 'Küresel Ticaret', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Nüfus_Politikaları.json', 'ders': 'Coğrafya', 'konu': 'Nüfus Politikaları', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Türkiye_de_Ekonomi.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'de Ekonomi', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Türkiye_de_Nüfus_ve_Yerleşme.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'de Nüfus ve Yerleşme', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Türkiye_nin_Coğrafi_Konumu.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'nin Coğrafi Konumu', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Türkiye_nin_İşlevsel_Bölgeleri_ve_Kalkınma_Projeleri.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'nin İşlevsel Bölgeleri ve Kalkınma Projeleri', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Uluslararası_Örgütler.json', 'ders': 'Coğrafya', 'konu': 'Uluslararası Örgütler', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Çevre_ve_Toplum.json', 'ders': 'Coğrafya', 'konu': 'Çevre ve Toplum', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_esitagirlik_cografya/Ülkeler_Arası_Etkileşimler.json', 'ders': 'Coğrafya', 'konu': 'Ülkeler Arası Etkileşimler', 'exam': 'AYT Sözel', 'tip': 'json'},

    // AYT SÖZEL DİN
    {'file': 'assets/ayt_sozel_din/allah_insan_iliskisi.json', 'ders': 'Din Kültürü', 'konu': 'Allah İnsan İlişkisi', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_din/anadoluda_islam.json', 'ders': 'Din Kültürü', 'konu': 'Anadolu\'da İslam', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_din/dunya_ve_ahiret.json', 'ders': 'Din Kültürü', 'konu': 'Dünya ve Ahiret', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_din/guncel_dini_meseleler.json', 'ders': 'Din Kültürü', 'konu': 'Güncel Dini Meseleler', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_din/hint_ve_cin_dinleri.json', 'ders': 'Din Kültürü', 'konu': 'Hint ve Çin Dinleri', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_din/inancla_ilgili_meseleler.json', 'ders': 'Din Kültürü', 'konu': 'İnançla İlgili Meseleler', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_din/islam_dusuncesinde_tasavvufi_yorumlar_ve_mezhepler.json', 'ders': 'Din Kültürü', 'konu': 'İslam Düşüncesinde Tasavvufi Yorumlar ve Mezhepler', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_din/islam_ve_bilim.json', 'ders': 'Din Kültürü', 'konu': 'İslam ve Bilim', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_din/kurana_gore_hz_muhammed.json', 'ders': 'Din Kültürü', 'konu': 'Kur\'an\'a Göre Hz. Muhammed', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_din/kurandan_mesajlar.json', 'ders': 'Din Kültürü', 'konu': 'Kur\'an\'dan Mesajlar', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_din/kuranda_bazi_kavramlar.json', 'ders': 'Din Kültürü', 'konu': 'Kur\'an\'da Bazı Kavramlar', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_din/yahudilik_ve_hristiyanlik.json', 'ders': 'Din Kültürü', 'konu': 'Yahudilik ve Hristiyanlık', 'exam': 'AYT Sözel', 'tip': 'json'},

    // AYT SÖZEL FELSEFE
    {'file': 'assets/ayt_sozel_felsefe/20. Yüzyıl Felsefesi.json', 'ders': 'Felsefe', 'konu': '20. Yüzyıl Felsefesi', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Ahlak Felsefesi.json', 'ders': 'Felsefe', 'konu': 'Ahlak Felsefesi', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Bilgi Felsefesi.json', 'ders': 'Felsefe', 'konu': 'Bilgi Felsefesi', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Birey ve Toplum.json', 'ders': 'Felsefe', 'konu': 'Birey ve Toplum', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Din Felsefesi.json', 'ders': 'Felsefe', 'konu': 'Din Felsefesi', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Felsefe ve Bilim.json', 'ders': 'Felsefe', 'konu': 'Felsefe ve Bilim', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Klasik Mantık.json', 'ders': 'Felsefe', 'konu': 'Klasik Mantık', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Mantık ve Dil.json', 'ders': 'Felsefe', 'konu': 'Mantık ve Dil', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Mantığa Giriş.json', 'ders': 'Felsefe', 'konu': 'Mantığa Giriş', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Psikoloji Bilimini Tanıyalım.json', 'ders': 'Felsefe', 'konu': 'Psikoloji Bilimini Tanıyalım', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Psikolojinin Temel Süreçleri.json', 'ders': 'Felsefe', 'konu': 'Psikolojinin Temel Süreçleri', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Ruh Sağlığının Temelleri.json', 'ders': 'Felsefe', 'konu': 'Ruh Sağlığının Temelleri', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Sosyolojiye Giriş.json', 'ders': 'Felsefe', 'konu': 'Sosyolojiye Giriş', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Toplum ve Kültür.json', 'ders': 'Felsefe', 'konu': 'Toplum ve Kültür', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Toplumsal Değişme ve Gelişme.json', 'ders': 'Felsefe', 'konu': 'Toplumsal Değişme ve Gelişme', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Toplumsal Kurumlar.json', 'ders': 'Felsefe', 'konu': 'Toplumsal Kurumlar', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Toplumsal Yapı.json', 'ders': 'Felsefe', 'konu': 'Toplumsal Yapı', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Varlık Felsefesi.json', 'ders': 'Felsefe', 'konu': 'Varlık Felsefesi', 'exam': 'AYT Sözel', 'tip': 'json'},
    {'file': 'assets/ayt_sozel_felsefe/Öğrenme Bellek Düşünme.json', 'ders': 'Felsefe', 'konu': 'Öğrenme Bellek Düşünme', 'exam': 'AYT Sözel', 'tip': 'json'},

    // ──────────────────────────────────────────────────────────────────────────
    // KPSS LİSANS BÖLÜMÜ
    // ──────────────────────────────────────────────────────────────────────────
    // KPSS LİSANS TÜRKÇE
    {'file': 'assets/kpss_lisans_turkce/Anlatım Bozuklukları.json', 'ders': 'Türkçe', 'konu': 'Anlatım Bozuklukları', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_turkce/Cümle Türleri.json', 'ders': 'Türkçe', 'konu': 'Cümle Türleri', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_turkce/Cümlede Anlam.json', 'ders': 'Türkçe', 'konu': 'Cümlede Anlam', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_turkce/Cümlenin Ögeleri.json', 'ders': 'Türkçe', 'konu': 'Cümlenin Ögeleri', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_turkce/Dil Bilgisi Ses Olayları.json', 'ders': 'Türkçe', 'konu': 'Dil Bilgisi Ses Olayları', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_turkce/Noktalama İşaretleri.json', 'ders': 'Türkçe', 'konu': 'Noktalama İşaretleri', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_turkce/Paragrafta Anlam.json', 'ders': 'Türkçe', 'konu': 'Paragrafta Anlam', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_turkce/Paragrafta Anlatım Biçimi.json', 'ders': 'Türkçe', 'konu': 'Paragrafta Anlatım Biçimi', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_turkce/Sözcük Türleri.json', 'ders': 'Türkçe', 'konu': 'Sözcük Türleri', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_turkce/Sözcükte Anlam.json', 'ders': 'Türkçe', 'konu': 'Sözcükte Anlam', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_turkce/Sözcükte Yapı.json', 'ders': 'Türkçe', 'konu': 'Sözcükte Yapı', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_turkce/Sözel Mantık.json', 'ders': 'Türkçe', 'konu': 'Sözel Mantık', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_turkce/Yazım Kuralları.json', 'ders': 'Türkçe', 'konu': 'Yazım Kuralları', 'exam': 'Lisans', 'tip': 'json'},

    // KPSS LİSANS MATEMATİK
    {'file': 'assets/kpss_lisans_matematik/basit_esitsizlikler.json', 'ders': 'Matematik', 'konu': 'Basit Eşitsizlikler', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/carpanlara_ayirma.json', 'ders': 'Matematik', 'konu': 'Çarpanlara Ayırma', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/denklem_cozme.json', 'ders': 'Matematik', 'konu': 'Denklem Çözme', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/fonksiyonlar.json', 'ders': 'Matematik', 'konu': 'Fonksiyonlar', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/islem.json', 'ders': 'Matematik', 'konu': 'İşlem', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/koklu_sayilar.json', 'ders': 'Matematik', 'konu': 'Köklü Sayılar', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/kumeler.json', 'ders': 'Matematik', 'konu': 'Kümeler', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/mutlak_deger.json', 'ders': 'Matematik', 'konu': 'Mutlak Değer', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/olasilik.json', 'ders': 'Matematik', 'konu': 'Olasılık', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/oran_oranti.json', 'ders': 'Matematik', 'konu': 'Oran Orantı', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/permutasyon_kombinasyon.json', 'ders': 'Matematik', 'konu': 'Permütasyon Kombinasyon', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/problemler.json', 'ders': 'Matematik', 'konu': 'Problemler', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/rasyonel_sayilar_ondalikli_sayilar.json', 'ders': 'Matematik', 'konu': 'Rasyonel Sayılar ve Ondalıklı Sayılar', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/sayisal_mantik.json', 'ders': 'Matematik', 'konu': 'Sayısal Mantık', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/temel_kavramlar.json', 'ders': 'Matematik', 'konu': 'Temel Kavramlar', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_matematik/uslu_sayilar.json', 'ders': 'Matematik', 'konu': 'Üslü Sayılar', 'exam': 'Lisans', 'tip': 'json'},

    // KPSS LİSANS TARİH
    {'file': 'assets/kpss_lisans_tarih/17_yuzyil_osmanli_devleti_duraklama_donemi.json', 'ders': 'Tarih', 'konu': '17. Yüzyıl Osmanlı Devleti Duraklama Dönemi', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_tarih/18_yuzyil_osmanli_devleti_gerileme_donemi.json', 'ders': 'Tarih', 'konu': '18. Yüzyıl Osmanlı Devleti Gerileme Dönemi', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_tarih/19_yuzyil_osmanli_devleti_dagilma_donemi.json', 'ders': 'Tarih', 'konu': '19. Yüzyıl Osmanlı Devleti Dağılma Dönemi', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_tarih/20_yuzyil_osmanli_devleti.json', 'ders': 'Tarih', 'konu': '20. Yüzyıl Osmanlı Devleti', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_tarih/ataturk_donemi_ic_ve_dis_politikalar.json', 'ders': 'Tarih', 'konu': 'Atatürk Dönemi İç ve Dış Politikalar', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_tarih/cagdas_turk_ve_dunya_tarihi.json', 'ders': 'Tarih', 'konu': 'Çağdaş Türk ve Dünya Tarihi', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_tarih/ilk_turk_islam_devletleri.json', 'ders': 'Tarih', 'konu': 'İlk Türk İslam Devletleri', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_tarih/ilk_turk_islam_devletlerinde_kultur_ve_medeniyet.json', 'ders': 'Tarih', 'konu': 'İlk Türk İslam Devletlerinde Kültür ve Medeniyet', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_tarih/inkilap_tarihi.json', 'ders': 'Tarih', 'konu': 'İnkılap Tarihi', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_tarih/islamiyet_oncesi_turk_tarihi_soru_bankasi.json', 'ders': 'Tarih', 'konu': 'İslamiyet Öncesi Türk Tarihi Soru Bankası', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_tarih/islamiyet_oncesi_turk_tarihi.json', 'ders': 'Tarih', 'konu': 'İslamiyet Öncesi Türk Tarihi', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_tarih/milli_mucadele_donemi.json', 'ders': 'Tarih', 'konu': 'Milli Mücadele Dönemi', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_tarih/osmanli_devleti_kultur_ve_medeniyet.json', 'ders': 'Tarih', 'konu': 'Osmanlı Devleti Kültür ve Medeniyeti', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_tarih/osmanli_devleti_kurulus_ve_yukselme_donemi.json', 'ders': 'Tarih', 'konu': 'Osmanlı Devleti Kuruluş ve Yükselme Dönemi', 'exam': 'Lisans', 'tip': 'json'},

    // KPSS LİSANS COĞRAFYA
    {'file': 'assets/kpss_lisans_cografya/Bölgeler Coğrafyası.json', 'ders': 'Coğrafya', 'konu': 'Bölgeler Coğrafyası', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_cografya/Hayvancılık.json', 'ders': 'Coğrafya', 'konu': 'Hayvancılık', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_cografya/Madenler ve Enerji.json', 'ders': 'Coğrafya', 'konu': 'Madenler ve Enerji', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_cografya/Sanayi ve Endüstri.json', 'ders': 'Coğrafya', 'konu': 'Sanayi ve Endüstri', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_cografya/Tarım.json', 'ders': 'Coğrafya', 'konu': 'Tarım', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_cografya/Ticaret.json', 'ders': 'Coğrafya', 'konu': 'Ticaret', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_cografya/Turizm.json', 'ders': 'Coğrafya', 'konu': 'Turizm', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_cografya/Türkiye’de Nüfus ve Yerleşme.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'de Nüfus ve Yerleşme', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_cografya/Türkiye’nin Coğrafi Konumu.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'nin Coğrafi Konumu', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_cografya/Türkiye’nin Fiziki Özellikleri.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'nin Fiziki Özellikleri', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_cografya/Türkiye’nin İklimi ve Bitki Örtüsü.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'nin İklimi ve Bitki Örtüsü', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_cografya/Ulaşım.json', 'ders': 'Coğrafya', 'konu': 'Ulaşım', 'exam': 'Lisans', 'tip': 'json'},

    // KPSS LİSANS VATANDAŞLIK
    {'file': 'assets/kpss_lisans_vatandaslik/Anayasal Kavramlar.json', 'ders': 'Vatandaşlık', 'konu': 'Anayasal Kavramlar', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_vatandaslik/Temel Hak Ödevler.json', 'ders': 'Vatandaşlık', 'konu': 'Temel Hak Ödevler', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_vatandaslik/Temel Hukuk Kavramları.json', 'ders': 'Vatandaşlık', 'konu': 'Temel Hukuk Kavramları', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_vatandaslik/Türk Anayasa Tarihi.json', 'ders': 'Vatandaşlık', 'konu': 'Türk Anayasa Tarihi', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_vatandaslik/Yargı.json', 'ders': 'Vatandaşlık', 'konu': 'Yargı', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_vatandaslik/Yasama.json', 'ders': 'Vatandaşlık', 'konu': 'Yasama', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_vatandaslik/Yürütme.json', 'ders': 'Vatandaşlık', 'konu': 'Yürütme', 'exam': 'Lisans', 'tip': 'json'},
    {'file': 'assets/kpss_lisans_vatandaslik/İdare Hukuku.json', 'ders': 'Vatandaşlık', 'konu': 'İdare Hukuku', 'exam': 'Lisans', 'tip': 'json'},

    // ──────────────────────────────────────────────────────────────────────────
    // KPSS ÖNLİSANS BÖLÜMÜ
    // ──────────────────────────────────────────────────────────────────────────
    // KPSS ÖNLİSANS TÜRKÇE
    {'file': 'assets/kpss_onlisans_turkce/Anlatım Bozuklukları.json', 'ders': 'Türkçe', 'konu': 'Anlatım Bozuklukları', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_turkce/Cümle Türleri.json', 'ders': 'Türkçe', 'konu': 'Cümle Türleri', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_turkce/Cümlede Anlam.json', 'ders': 'Türkçe', 'konu': 'Cümlede Anlam', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_turkce/Cümlenin Ögeleri.json', 'ders': 'Türkçe', 'konu': 'Cümlenin Ögeleri', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_turkce/Dil Bilgisi Ses Olayları.json', 'ders': 'Türkçe', 'konu': 'Dil Bilgisi Ses Olayları', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_turkce/Noktalama İşaretleri.json', 'ders': 'Türkçe', 'konu': 'Noktalama İşaretleri', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_turkce/Paragrafta Anlam.json', 'ders': 'Türkçe', 'konu': 'Paragrafta Anlam', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_turkce/Paragrafta Anlatım Biçimi.json', 'ders': 'Türkçe', 'konu': 'Paragrafta Anlatım Biçimi', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_turkce/Sözcük Türleri.json', 'ders': 'Türkçe', 'konu': 'Sözcük Türleri', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_turkce/Sözcükte Anlam.json', 'ders': 'Türkçe', 'konu': 'Sözcükte Anlam', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_turkce/Sözcükte Yapı.json', 'ders': 'Türkçe', 'konu': 'Sözcükte Yapı', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_turkce/Sözel Mantık.json', 'ders': 'Türkçe', 'konu': 'Sözel Mantık', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_turkce/Yazım Kuralları.json', 'ders': 'Türkçe', 'konu': 'Yazım Kuralları', 'exam': 'Önlisans', 'tip': 'json'},

    // KPSS ÖNLİSANS MATEMATİK
    {'file': 'assets/kpss_onlisans_matematik/Basit Eşitsizlikler.json', 'ders': 'Matematik', 'konu': 'Basit Eşitsizlikler', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_matematik/Denklem Çözme.json', 'ders': 'Matematik', 'konu': 'Denklem Çözme', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_matematik/Fonksiyonlar.json', 'ders': 'Matematik', 'konu': 'Fonksiyonlar', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_matematik/Köklü Sayılar.json', 'ders': 'Matematik', 'konu': 'Köklü Sayılar', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_matematik/Kümeler.json', 'ders': 'Matematik', 'konu': 'Kümeler', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_matematik/Mutlak Değer.json', 'ders': 'Matematik', 'konu': 'Mutlak Değer', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_matematik/Oran- Orantı.json', 'ders': 'Matematik', 'konu': 'Oran Orantı', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_matematik/Problemler.json', 'ders': 'Matematik', 'konu': 'Problemler', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_matematik/Rasyonel Sayılar- Ondalıklı Sayılar.json', 'ders': 'Matematik', 'konu': 'Rasyonel Sayılar Ondalıklı Sayılar', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_matematik/Sayısal Mantık.json', 'ders': 'Matematik', 'konu': 'Sayısal Mantık', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_matematik/Temel Kavamlar.json', 'ders': 'Matematik', 'konu': 'Temel Kavramlar', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_matematik/Çarpanlara Ayırma.json', 'ders': 'Matematik', 'konu': 'Çarpanlara Ayırma', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_matematik/Üslü Sayılar.json', 'ders': 'Matematik', 'konu': 'Üslü Sayılar', 'exam': 'Önlisans', 'tip': 'json'},

    // KPSS ÖNLİSANS TARİH
    {'file': 'assets/kpss_onlisans_tarih/17_yuzyil_osmanli_devleti_duraklama_donemi.json', 'ders': 'Tarih', 'konu': '17. Yüzyıl Osmanlı Devleti Duraklama Dönemi', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_tarih/18_yuzyil_osmanli_devleti_gerileme_donemi.json', 'ders': 'Tarih', 'konu': '18. Yüzyıl Osmanlı Devleti Gerileme Dönemi', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_tarih/19_yuzyil_osmanli_devleti_dagilma_donemi.json', 'ders': 'Tarih', 'konu': '19. Yüzyıl Osmanlı Devleti Dağılma Dönemi', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_tarih/20_yuzyil_osmanli_devleti.json', 'ders': 'Tarih', 'konu': '20. Yüzyıl Osmanlı Devleti', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_tarih/ataturk_donemi_ic_ve_dis_politikalar.json', 'ders': 'Tarih', 'konu': 'Atatürk Dönemi İç ve Dış Politikalar', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_tarih/cagdas_turk_ve_dunya_tarihi.json', 'ders': 'Tarih', 'konu': 'Çağdaş Türk ve Dünya Tarihi', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_tarih/ilk_turk_islam_devletleri.json', 'ders': 'Tarih', 'konu': 'İlk Türk İslam Devletleri', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_tarih/ilk_turk_islam_devletlerinde_kultur_ve_medeniyet.json', 'ders': 'Tarih', 'konu': 'İlk Türk İslam Devletlerinde Kültür ve Medeniyet', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_tarih/inkilap_tarihi.json', 'ders': 'Tarih', 'konu': 'İnkılap Tarihi', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_tarih/islamiyet_oncesi_turk_devletlerinde_kultur_ve_medeniyet.json', 'ders': 'Tarih', 'konu': 'İslamiyet Öncesi Türk Devletlerinde Kültür ve Medeniyet', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_tarih/islamiyet_oncesi_turk_tarihi.json', 'ders': 'Tarih', 'konu': 'İslamiyet Öncesi Türk Tarihi', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_tarih/milli_mucadele_donemi.json', 'ders': 'Tarih', 'konu': 'Milli Mücadele Dönemi', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_tarih/osmanli_devleti_kultur_ve_medeniyet.json', 'ders': 'Tarih', 'konu': 'Osmanlı Devleti Kültür ve Medeniyeti', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_tarih/osmanli_devleti_kurulus_ve_yukselme_donemi.json', 'ders': 'Tarih', 'konu': 'Osmanlı Devleti Kuruluş ve Yükselme Dönemi', 'exam': 'Önlisans', 'tip': 'json'},

    // KPSS ÖNLİSANS COĞRAFYA
    {'file': 'assets/kpss_onlisans_cografya/Bölgeler Coğrafyası.json', 'ders': 'Coğrafya', 'konu': 'Bölgeler Coğrafyası', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_cografya/Hayvancılık.json', 'ders': 'Coğrafya', 'konu': 'Hayvancılık', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_cografya/Madenler ve Enerji Kaynakları.json', 'ders': 'Coğrafya', 'konu': 'Madenler ve Enerji Kaynakları', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_cografya/Sanayi ve Endüstri.json', 'ders': 'Coğrafya', 'konu': 'Sanayi ve Endüstri', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_cografya/Tarım.json', 'ders': 'Coğrafya', 'konu': 'Tarım', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_cografya/Ticaret.json', 'ders': 'Coğrafya', 'konu': 'Ticaret', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_cografya/Turizm.json', 'ders': 'Coğrafya', 'konu': 'Turizm', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_cografya/Türkiye’de Nüfus ve Yerleşme.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'de Nüfus ve Yerleşme', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_cografya/Türkiye’nin Coğrafi Konumu.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'nin Coğrafi Konumu', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_cografya/Türkiye’nin Fiziki Özellikleri.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'nin Fiziki Özellikleri', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_cografya/Türkiye’nin İklimi ve Bitki Örtüsü.json', 'ders': 'Coğrafya', 'konu': 'Türkiye\'nin İklimi ve Bitki Örtüsü', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_cografya/Ulaşım.json', 'ders': 'Coğrafya', 'konu': 'Ulaşım', 'exam': 'Önlisans', 'tip': 'json'},

    // KPSS ÖNLİSANS VATANDAŞLIK
    {'file': 'assets/kpss_onlisans_vatandaslik/Anayasal Kavramlar.json', 'ders': 'Vatandaşlık', 'konu': 'Anayasal Kavramlar', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_vatandaslik/Temel Hak ve Ödevler.json', 'ders': 'Vatandaşlık', 'konu': 'Temel Hak ve Ödevler', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_vatandaslik/Temel Hukuk Kavramları.json', 'ders': 'Vatandaşlık', 'konu': 'Temel Hukuk Kavramları', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_vatandaslik/Türk Anayasa Tarihi.json', 'ders': 'Vatandaşlık', 'konu': 'Türk Anayasa Tarihi', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_vatandaslik/Yargı.json', 'ders': 'Vatandaşlık', 'konu': 'Yargı', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_vatandaslik/Yasama.json', 'ders': 'Vatandaşlık', 'konu': 'Yasama', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_vatandaslik/Yürütme.json', 'ders': 'Vatandaşlık', 'konu': 'Yürütme', 'exam': 'Önlisans', 'tip': 'json'},
    {'file': 'assets/kpss_onlisans_vatandaslik/İdare Hukuku.json', 'ders': 'Vatandaşlık', 'konu': 'İdare Hukuku', 'exam': 'Önlisans', 'tip': 'json'},
  ];

  // ──────────────────────────────────────────────────────────────────────────
  // UPLOAD METOTLARI
  // ──────────────────────────────────────────────────────────────────────────

  static Future<UploadResult> uploadAll({
    void Function(String message)? onProgress,
  }) async {
    int totalUploaded = 0;
    List<String> errors = [];

    for (var fileInfo in _dosyaListesi) {
      final String file = fileInfo['file']!;
      final String ders = fileInfo['ders']!;
      final String konu = fileInfo['konu']!;
      final String exam = fileInfo['exam']!;
      final String tip = fileInfo['tip']!;

      onProgress?.call('🚀 Yükleniyor: $exam - $ders - $konu');
      try {
        int uploaded = await _processFile(file, ders, konu, exam, tip);
        totalUploaded += uploaded;
        onProgress?.call('✅ $exam - $ders - $konu: $uploaded soru');
      } catch (e) {
        final err = '❌ Hata ($file): $e';
        errors.add(err);
        onProgress?.call(err);
      }
    }
    return UploadResult(totalUploaded: totalUploaded, errors: errors);
  }

  static Future<UploadResult> uploadByDers(
    String targetDers, {
    void Function(String message)? onProgress,
  }) async {
    int totalUploaded = 0;
    List<String> errors = [];

    final hedefler = _dosyaListesi.where((d) => d['ders'] == targetDers).toList();

    if (hedefler.isEmpty) {
      onProgress?.call('⚠️ $targetDers dersi için dosya bulunamadı.');
      return UploadResult(totalUploaded: 0, errors: []);
    }

    for (var fileInfo in hedefler) {
      final String file = fileInfo['file']!;
      final String ders = fileInfo['ders']!;
      final String konu = fileInfo['konu']!;
      final String exam = fileInfo['exam']!;
      final String tip = fileInfo['tip']!;

      onProgress?.call('🚀 Yükleniyor: $exam - $ders - $konu');
      try {
        int uploaded = await _processFile(file, ders, konu, exam, tip);
        totalUploaded += uploaded;
        onProgress?.call('✅ $exam - $ders - $konu: $uploaded soru');
      } catch (e) {
        final err = '❌ Hata ($file): $e';
        errors.add(err);
        onProgress?.call(err);
      }
    }
    return UploadResult(totalUploaded: totalUploaded, errors: errors);
  }

  static Future<int> _processFile(
    String file,
    String ders,
    String konu,
    String exam,
    String tip,
  ) async {
    // 1. Eski soruları sil
    await _deleteExisting(ders, konu, exam);

    // 2. Yeni soruları oku ve yükle
    int uploadedCount = 0;
    if (tip == 'json') {
      uploadedCount = await _uploadJson(file, ders, konu, exam);
    } else if (tip == 'excel') {
      uploadedCount = await _uploadExcel(file, ders, konu, exam);
    }
    return uploadedCount;
  }

  static Future<int> _uploadJson(
    String filePath,
    String ders,
    String konu,
    String exam,
  ) async {
    final String jsonString = await rootBundle.loadString(filePath);
    final dynamic decoded = json.decode(jsonString);

    List<dynamic> list = [];
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map && decoded.containsKey('questions')) {
      list = decoded['questions'] ?? [];
    }

    if (list.isEmpty) return 0;

    WriteBatch batch = _db.batch();
    int count = 0;
    int total = 0;

    for (var item in list) {
      final docRef = _db.collection('sorular').doc();
      batch.set(docRef, {
        'ders': ders,
        'konu': konu,
        'exam': exam,
        'soru_metni': item['soru'] ?? item['soru_metni'] ?? item['question'] ?? '',
        'secenekler': List<String>.from(item['siklar'] ?? item['secenekler'] ?? item['options'] ?? []),
        'dogru_cevap': item['dogru_cevap'] ?? 0,
        'aciklama': item['aciklama'] ?? item['explanation'] ?? '',
        'svg_kod': item['gorsel_url']?.toString() ?? item['svg_kod']?.toString() ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      count++;
      total++;
      if (count >= 400) {
        await batch.commit();
        batch = _db.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
    return total;
  }

  static Future<int> _uploadExcel(
    String filePath,
    String ders,
    String konu,
    String exam,
  ) async {
    final ByteData byteData = await rootBundle.load(filePath);
    final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
    final excel = Excel.decodeBytes(bytes);

    String getCellValue(Data? cell) {
      if (cell == null || cell.value == null) return '';
      String text = cell.value.toString();
      if (text.startsWith('TextCellValue(')) {
        text = text.replaceAll('TextCellValue(', '').replaceAll(')', '');
      }
      return text.trim();
    }

    WriteBatch batch = _db.batch();
    int count = 0;
    int total = 0;

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
          if (s.isNotEmpty) secenekler.add(s);
        }

        final dogruHarf = row.length > 6 ? getCellValue(row[6]).toUpperCase() : 'A';
        final int dogruIndex = (dogruHarf.isNotEmpty ? dogruHarf.codeUnitAt(0) - 65 : 0)
            .clamp(0, secenekler.isEmpty ? 0 : secenekler.length - 1);

        final aciklama = row.length > 7 ? getCellValue(row[7]) : '';

        final docRef = _db.collection('sorular').doc();
        batch.set(docRef, {
          'ders': ders,
          'konu': konu,
          'exam': exam,
          'soru_metni': soruMetni,
          'secenekler': secenekler,
          'dogru_cevap': dogruIndex,
          'aciklama': aciklama,
          'svg_kod': '',
          'createdAt': FieldValue.serverTimestamp(),
        });

        count++;
        total++;
        if (count >= 400) {
          await batch.commit();
          batch = _db.batch();
          count = 0;
        }
      }
    }
    if (count > 0) await batch.commit();
    return total;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // YARDIMCI
  // ──────────────────────────────────────────────────────────────────────────
  static Future<void> _deleteExisting(
    String ders,
    String konu,
    String exam,
  ) async {
    final snapshot = await _db
        .collection('sorular')
        .where('ders', isEqualTo: ders)
        .where('konu', isEqualTo: konu)
        .where('exam', isEqualTo: exam)
        .get();
    if (snapshot.docs.isEmpty) return;
    WriteBatch batch = _db.batch();
    int count = 0;
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      count++;
      if (count >= 400) {
        await batch.commit();
        batch = _db.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
    debugPrint(
      '🗑️ $exam / $ders / $konu: ${snapshot.docs.length} eski soru silindi',
    );
  }

  static Future<Map<String, int>> getSoruSayilari() async {
    final Map<String, int> result = {};
    final snapshot = await _db.collection('sorular').get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final key = '${data['exam']} | ${data['ders']} | ${data['konu']}';
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }
}

class UploadResult {
  final int totalUploaded;
  final List<String> errors;
  UploadResult({required this.totalUploaded, required this.errors});
  bool get hasErrors => errors.isNotEmpty;
}