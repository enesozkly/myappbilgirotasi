import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MultiplayerQuizPage extends StatefulWidget {
  final String roomCode;
  const MultiplayerQuizPage({super.key, required this.roomCode});

  @override
  State<MultiplayerQuizPage> createState() => _MultiplayerQuizPageState();
}

class _MultiplayerQuizPageState extends State<MultiplayerQuizPage>
    with TickerProviderStateMixin {
  final User? _me = FirebaseAuth.instance.currentUser;
  StreamSubscription<DocumentSnapshot>? _roomSub;

  int _qi = 0;
  bool _gameOver = false;
  bool _amIFinished = false;
  String? _selected; // seçilen index string olarak
  bool _answered = false;
  bool _allowExit = false;
  bool _exitDialogOpen = false;

  // Soru formatı: { soru, secenekler: List<String>, dogru_cevap: int, ders }
  List<Map<String, dynamic>> _questions = [];
  bool _loaded = false;
  bool _generating = false;

  int _timeLeft = 30;
  Timer? _timer;

  late AnimationController _slideCtrl, _pulseCtrl, _winCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim, _winScale, _winFade;

  // ── Statik asset dosya haritası (AssetManifest'e bağımlılık YOK) ─────────
static const Map<String, List<String>> _assetFiles = {
  'AYT Eşit Ağırlık|Coğrafya': [
    'assets/ayt_esitagirlik_cografya/bolgeleri.json',
    'assets/ayt_esitagirlik_cografya/bolgeler_ve_ulkeler.json',
    'assets/ayt_esitagirlik_cografya/cevre_ve_toplum.json',
    'assets/ayt_esitagirlik_cografya/dunya_nin_sekli_ve_hareketleri.json',
    'assets/ayt_esitagirlik_cografya/ekonomik_faaliyetler_ve_dogal_kaynaklar.json',
    'assets/ayt_esitagirlik_cografya/ekosistem.json',
    'assets/ayt_esitagirlik_cografya/goc_ve_sehirlesme.json',
    'assets/ayt_esitagirlik_cografya/harita_bilgisi.json',
    'assets/ayt_esitagirlik_cografya/ic_ve_dis_kuvvetler.json',
    'assets/ayt_esitagirlik_cografya/iklim_ve_yer_sekilleri.json',
    'assets/ayt_esitagirlik_cografya/kuresel_ticaret.json',
    'assets/ayt_esitagirlik_cografya/nufus_politikalari.json',
    'assets/ayt_esitagirlik_cografya/turkiye_de_ekonomi.json',
    'assets/ayt_esitagirlik_cografya/turkiye_de_nufus_ve_yerlesme.json',
    'assets/ayt_esitagirlik_cografya/turkiye_nin_cografi_konumu.json',
    'assets/ayt_esitagirlik_cografya/turkiye_nin_islevsel_bolgeleri_ve_kalkinma_projeleri.json',
    'assets/ayt_esitagirlik_cografya/ulkeler_arasi_etkilesimler.json',
    'assets/ayt_esitagirlik_cografya/uluslararasi_orgutler.json',
  ],
  'AYT Eşit Ağırlık|Edebiyat': [
    'assets/ayt_esitagirlik_edebiyat/akimlari.json',
    'assets/ayt_esitagirlik_edebiyat/anlam_bilgisi.json',
    'assets/ayt_esitagirlik_edebiyat/cumhuriyet_donemi_edebiyati.json',
    'assets/ayt_esitagirlik_edebiyat/dil_bilgisi.json',
    'assets/ayt_esitagirlik_edebiyat/divan_edebiyati.json',
    'assets/ayt_esitagirlik_edebiyat/edebi_sanatlar.json',
    'assets/ayt_esitagirlik_edebiyat/halk_edebiyati.json',
    'assets/ayt_esitagirlik_edebiyat/islamiyet_oncesi_turk_edebiyati_ve_gecis_donemi.json',
    'assets/ayt_esitagirlik_edebiyat/metinlerin_turleri.json',
    'assets/ayt_esitagirlik_edebiyat/milli_edebiyat.json',
    'assets/ayt_esitagirlik_edebiyat/servet_i_funun_ve_fecr_i_ati_edebiyati.json',
    'assets/ayt_esitagirlik_edebiyat/siir_bilgisi.json',
    'assets/ayt_esitagirlik_edebiyat/tanzimat_edebiyati.json',
  ],
  'AYT Eşit Ağırlık|Matematik': [
    'assets/ayt_esitagirlik_matematik/bolme_ve_bolunebilme_kurallari.json',
    'assets/ayt_esitagirlik_matematik/diziler.json',
    'assets/ayt_esitagirlik_matematik/ebob_ekok.json',
    'assets/ayt_esitagirlik_matematik/ikinci_dereceden_denklemler_parabol_ve_esitsizlikler.json',
    'assets/ayt_esitagirlik_matematik/integral.json',
    'assets/ayt_esitagirlik_matematik/karmasik_sayilar.json',
    'assets/ayt_esitagirlik_matematik/logaritma.json',
    'assets/ayt_esitagirlik_matematik/parabol.json',
    'assets/ayt_esitagirlik_matematik/permutasyon_kombinasyon_olasilik_binom.json',
    'assets/ayt_esitagirlik_matematik/polinom.json',
    'assets/ayt_esitagirlik_matematik/sayi_basamaklari.json',
    'assets/ayt_esitagirlik_matematik/trigonometri.json',
    'assets/ayt_esitagirlik_matematik/turev.json',
  ],
  'AYT Eşit Ağırlık|Tarih': [
    'assets/ayt_esitagirlik_tarih/ataturkculuk_ve_turk_inkilabi.json',
    'assets/ayt_esitagirlik_tarih/beylikten_devlete_osmanli_medeniyeti.json',
    'assets/ayt_esitagirlik_tarih/beylikten_devlete_osmanli_siyaseti.json',
    'assets/ayt_esitagirlik_tarih/degisen_dunya_dengeleri_karsisinda_osmanli_siyaseti.json',
    'assets/ayt_esitagirlik_tarih/degisim_caginda_avrupa_ve_osmanli.json',
    'assets/ayt_esitagirlik_tarih/devletlesme_surecinde_savascilar_ve_askerler.json',
    'assets/ayt_esitagirlik_tarih/devrimler_caginda_degisen_devlet_toplum_iliskileri.json',
    'assets/ayt_esitagirlik_tarih/dunya_gucu_osmanli_ve_turk_islam_tarihi.json',
    'assets/ayt_esitagirlik_tarih/ii_dunya_savasi_sonrasinda_turkiye_ve_dunya.json',
    'assets/ayt_esitagirlik_tarih/ii_dunya_savasi_surecinde_turkiye_ve_dunya.json',
    'assets/ayt_esitagirlik_tarih/iki_savas_arasindaki_donemde_turkiye_ve_dunya.json',
    'assets/ayt_esitagirlik_tarih/ilk_ve_orta_caglarda_turk_dunyasi.json',
    'assets/ayt_esitagirlik_tarih/insanligin_ilk_donemleri.json',
    'assets/ayt_esitagirlik_tarih/islam_medeniyetinin_dogusu_ve_ilk_islam_devletleri.json',
    'assets/ayt_esitagirlik_tarih/klasik_cagda_osmanli_toplum_duzeni.json',
    'assets/ayt_esitagirlik_tarih/milli_mucadele.json',
    'assets/ayt_esitagirlik_tarih/orta_cag_da_dunya.json',
    'assets/ayt_esitagirlik_tarih/sermaye_ve_emek.json',
    'assets/ayt_esitagirlik_tarih/sultan_ve_osmanli_merkez_teskilati.json',
    'assets/ayt_esitagirlik_tarih/toplumsal_devrim_caginda_dunya_ve_turkiye.json',
    'assets/ayt_esitagirlik_tarih/turklerin_islamiyet_i_kabulu_ve_ilk_turk_islam_devletleri.json',
    'assets/ayt_esitagirlik_tarih/uluslararasi_iliskilerde_denge_stratejisi_1774_1914_.json',
    'assets/ayt_esitagirlik_tarih/ve_zaman.json',
    'assets/ayt_esitagirlik_tarih/xix._ve_xx._yuzyilda_degisen_gundelik_hayat.json',
    'assets/ayt_esitagirlik_tarih/xx._yuzyil_baslarinda_osmanli_devleti_ve_dunya.json',
    'assets/ayt_esitagirlik_tarih/xxi._yuzyilin_esiginde_turkiye_ve_dunya.json',
    'assets/ayt_esitagirlik_tarih/yerlesme_ve_devletlesme_surecinde_selcuklu_turkiyesi.json',
  ],
  'AYT Sayısal|Biyoloji': [
    'assets/ayt_sayisal_biyoloji/bitki_biyolojisi.json',
    'assets/ayt_sayisal_biyoloji/canlilar_ve_cevre.json',
    'assets/ayt_sayisal_biyoloji/canlilik_ve_enerji.json',
    'assets/ayt_sayisal_biyoloji/destek_ve_hareket_sistemi.json',
    'assets/ayt_sayisal_biyoloji/dolasim_ve_bagisiklilik_sistemi.json',
    'assets/ayt_sayisal_biyoloji/duyu_organlari.json',
    'assets/ayt_sayisal_biyoloji/endokrin_sistem.json',
    'assets/ayt_sayisal_biyoloji/fotosentez_ve_kemosentez.json',
    'assets/ayt_sayisal_biyoloji/genetik_sifre_ve_protein_sentezi.json',
    'assets/ayt_sayisal_biyoloji/hucresel_solunum.json',
    'assets/ayt_sayisal_biyoloji/komunite_ve_populasyon_ekolojisi.json',
    'assets/ayt_sayisal_biyoloji/nukleik_asitler.json',
    'assets/ayt_sayisal_biyoloji/sindirim_sistemi.json',
    'assets/ayt_sayisal_biyoloji/sinir_sistemi.json',
    'assets/ayt_sayisal_biyoloji/solunum_sistemi.json',
    'assets/ayt_sayisal_biyoloji/ureme_sistemi_ve_embriyonik_gelisim.json',
    'assets/ayt_sayisal_biyoloji/uriner_sistem.json',
  ],
  'AYT Sayısal|Fizik': [
    'assets/ayt_sayisal_fizik/atislar.json',
    'assets/ayt_sayisal_fizik/atom_modelleri.json',
    'assets/ayt_sayisal_fizik/basit_harmonik_hareket.json',
    'assets/ayt_sayisal_fizik/basit_makineler.json',
    'assets/ayt_sayisal_fizik/buyuk_patlama_ve_parcacik_fizigi.json',
    'assets/ayt_sayisal_fizik/dalga_mekanigi_ve_elektromanyetik_dalgalar.json',
    'assets/ayt_sayisal_fizik/donme_yuvarlanma_ve_acisal_momentum.json',
    'assets/ayt_sayisal_fizik/duzgun_cembersel_hareket.json',
    'assets/ayt_sayisal_fizik/elektrik_alan_ve_potansiyel.json',
    'assets/ayt_sayisal_fizik/fotoelektrik_olay_ve_compton_olayi.json',
    'assets/ayt_sayisal_fizik/hareket.json',
    'assets/ayt_sayisal_fizik/induksiyon_alternatif_akim_ve_transformatorler.json',
    'assets/ayt_sayisal_fizik/is_guc_ve_enerji.json',
    'assets/ayt_sayisal_fizik/itme_ve_cizgisel_momentum.json',
    'assets/ayt_sayisal_fizik/kara_cisim_isimasi.json',
    'assets/ayt_sayisal_fizik/kutle_cekim_merkezi_ve_acisal_momentum.json',
    'assets/ayt_sayisal_fizik/kutle_cekim_ve_kepler_yasalari.json',
    'assets/ayt_sayisal_fizik/kuvvet_tork_ve_denge.json',
    'assets/ayt_sayisal_fizik/manyetik_alan_ve_manyetik_kuvvet.json',
    'assets/ayt_sayisal_fizik/modern_fizigin_teknolojideki_uygulamalari.json',
    'assets/ayt_sayisal_fizik/newton_un_hareket_yasalari.json',
    'assets/ayt_sayisal_fizik/ozel_gorelilik.json',
    'assets/ayt_sayisal_fizik/paralel_levhalar_ve_siga.json',
    'assets/ayt_sayisal_fizik/vektorler.json',
  ],
  'AYT Sayısal|Kimya': [
    'assets/ayt_sayisal_kimya/asit_baz_dengesi.json',
    'assets/ayt_sayisal_kimya/atomun_yapisi.json',
    'assets/ayt_sayisal_kimya/bilimi.json',
    'assets/ayt_sayisal_kimya/cozunurluk_dengesi.json',
    'assets/ayt_sayisal_kimya/gazlar.json',
    'assets/ayt_sayisal_kimya/kimyasal_hesaplamalar.json',
    'assets/ayt_sayisal_kimya/kimyasal_tepkimelerde_denge.json',
    'assets/ayt_sayisal_kimya/kimyasal_tepkimelerde_enerji.json',
    'assets/ayt_sayisal_kimya/kimyasal_tepkimelerde_hiz.json',
    'assets/ayt_sayisal_kimya/kimyasal_turler_arasi_etkilesim.json',
    'assets/ayt_sayisal_kimya/modern_atom_teorisi.json',
    'assets/ayt_sayisal_kimya/organik_kimya.json',
    'assets/ayt_sayisal_kimya/periyodik_sistem.json',
    'assets/ayt_sayisal_kimya/sivi_cozeltiler.json',
    'assets/ayt_sayisal_kimya/ve_elektrik.json',
  ],
  'AYT Sayısal|Matematik': [
    'assets/ayt_sayisal_matematik/bolme_ve_bolunebilme_kurallari.json',
    'assets/ayt_sayisal_matematik/diziler.json',
    'assets/ayt_sayisal_matematik/ebob_ekok.json',
    'assets/ayt_sayisal_matematik/ikinci_dereceden_denklemler_parabol_ve_esitsizlikler.json',
    'assets/ayt_sayisal_matematik/integral.json',
    'assets/ayt_sayisal_matematik/karmasik_sayilar.json',
    'assets/ayt_sayisal_matematik/logaritma.json',
    'assets/ayt_sayisal_matematik/parabol.json',
    'assets/ayt_sayisal_matematik/permutasyon_kombinasyon_olasilik_binom.json',
    'assets/ayt_sayisal_matematik/polinom.json',
    'assets/ayt_sayisal_matematik/sayi_basamaklari.json',
    'assets/ayt_sayisal_matematik/trigonometri.json',
    'assets/ayt_sayisal_matematik/turev.json',
  ],
  'AYT Sözel|Coğrafya': [
    'assets/ayt_esitagirlik_cografya/bolgeleri.json',
    'assets/ayt_esitagirlik_cografya/bolgeler_ve_ulkeler.json',
    'assets/ayt_esitagirlik_cografya/cevre_ve_toplum.json',
    'assets/ayt_esitagirlik_cografya/dunya_nin_sekli_ve_hareketleri.json',
    'assets/ayt_esitagirlik_cografya/ekonomik_faaliyetler_ve_dogal_kaynaklar.json',
    'assets/ayt_esitagirlik_cografya/ekosistem.json',
    'assets/ayt_esitagirlik_cografya/goc_ve_sehirlesme.json',
    'assets/ayt_esitagirlik_cografya/harita_bilgisi.json',
    'assets/ayt_esitagirlik_cografya/ic_ve_dis_kuvvetler.json',
    'assets/ayt_esitagirlik_cografya/iklim_ve_yer_sekilleri.json',
    'assets/ayt_esitagirlik_cografya/kuresel_ticaret.json',
    'assets/ayt_esitagirlik_cografya/nufus_politikalari.json',
    'assets/ayt_esitagirlik_cografya/turkiye_de_ekonomi.json',
    'assets/ayt_esitagirlik_cografya/turkiye_de_nufus_ve_yerlesme.json',
    'assets/ayt_esitagirlik_cografya/turkiye_nin_cografi_konumu.json',
    'assets/ayt_esitagirlik_cografya/turkiye_nin_islevsel_bolgeleri_ve_kalkinma_projeleri.json',
    'assets/ayt_esitagirlik_cografya/ulkeler_arasi_etkilesimler.json',
    'assets/ayt_esitagirlik_cografya/uluslararasi_orgutler.json',
  ],
  'AYT Sözel|Din Kültürü': [
    'assets/ayt_sozel_din/allah_insan_iliskisi.json',
    'assets/ayt_sozel_din/anadoluda_islam.json',
    'assets/ayt_sozel_din/dunya_ve_ahiret.json',
    'assets/ayt_sozel_din/guncel_dini_meseleler.json',
    'assets/ayt_sozel_din/hint_ve_cin_dinleri.json',
    'assets/ayt_sozel_din/inancla_ilgili_meseleler.json',
    'assets/ayt_sozel_din/islam_dusuncesinde_tasavvufi_yorumlar_ve_mezhepler.json',
    'assets/ayt_sozel_din/islam_ve_bilim.json',
    'assets/ayt_sozel_din/kurana_gore_hz_muhammed.json',
    'assets/ayt_sozel_din/kurandan_mesajlar.json',
    'assets/ayt_sozel_din/kuranda_bazi_kavramlar.json',
    'assets/ayt_sozel_din/yahudilik_ve_hristiyanlik.json',
  ],
  'AYT Sözel|Edebiyat': [
    'assets/ayt_esitagirlik_edebiyat/akimlari.json',
    'assets/ayt_esitagirlik_edebiyat/anlam_bilgisi.json',
    'assets/ayt_esitagirlik_edebiyat/cumhuriyet_donemi_edebiyati.json',
    'assets/ayt_esitagirlik_edebiyat/dil_bilgisi.json',
    'assets/ayt_esitagirlik_edebiyat/divan_edebiyati.json',
    'assets/ayt_esitagirlik_edebiyat/edebi_sanatlar.json',
    'assets/ayt_esitagirlik_edebiyat/halk_edebiyati.json',
    'assets/ayt_esitagirlik_edebiyat/islamiyet_oncesi_turk_edebiyati_ve_gecis_donemi.json',
    'assets/ayt_esitagirlik_edebiyat/metinlerin_turleri.json',
    'assets/ayt_esitagirlik_edebiyat/milli_edebiyat.json',
    'assets/ayt_esitagirlik_edebiyat/servet_i_funun_ve_fecr_i_ati_edebiyati.json',
    'assets/ayt_esitagirlik_edebiyat/siir_bilgisi.json',
    'assets/ayt_esitagirlik_edebiyat/tanzimat_edebiyati.json',
  ],
  'AYT Sözel|Felsefe': [
    'assets/ayt_sozel_felsefe/20._yuzyil_felsefesi.json',
    'assets/ayt_sozel_felsefe/ahlak_felsefesi.json',
    'assets/ayt_sozel_felsefe/bilgi_felsefesi.json',
    'assets/ayt_sozel_felsefe/birey_ve_toplum.json',
    'assets/ayt_sozel_felsefe/felsefesi.json',
    'assets/ayt_sozel_felsefe/klasik_mantik.json',
    'assets/ayt_sozel_felsefe/mantiga_giris.json',
    'assets/ayt_sozel_felsefe/mantik_ve_dil.json',
    'assets/ayt_sozel_felsefe/ogrenme_bellek_dusunme.json',
    'assets/ayt_sozel_felsefe/psikolojinin_temel_surecleri.json',
    'assets/ayt_sozel_felsefe/psikoloji_bilimini_taniyalim.json',
    'assets/ayt_sozel_felsefe/ruh_sagliginin_temelleri.json',
    'assets/ayt_sozel_felsefe/sosyolojiye_giris.json',
    'assets/ayt_sozel_felsefe/toplumsal_degisme_ve_gelisme.json',
    'assets/ayt_sozel_felsefe/toplumsal_kurumlar.json',
    'assets/ayt_sozel_felsefe/toplumsal_yapi.json',
    'assets/ayt_sozel_felsefe/toplum_ve_kultur.json',
    'assets/ayt_sozel_felsefe/varlik_felsefesi.json',
    'assets/ayt_sozel_felsefe/ve_bilim.json',
  ],
  'AYT Sözel|Tarih': [
    'assets/ayt_esitagirlik_tarih/ataturkculuk_ve_turk_inkilabi.json',
    'assets/ayt_esitagirlik_tarih/beylikten_devlete_osmanli_medeniyeti.json',
    'assets/ayt_esitagirlik_tarih/beylikten_devlete_osmanli_siyaseti.json',
    'assets/ayt_esitagirlik_tarih/degisen_dunya_dengeleri_karsisinda_osmanli_siyaseti.json',
    'assets/ayt_esitagirlik_tarih/degisim_caginda_avrupa_ve_osmanli.json',
    'assets/ayt_esitagirlik_tarih/devletlesme_surecinde_savascilar_ve_askerler.json',
    'assets/ayt_esitagirlik_tarih/devrimler_caginda_degisen_devlet_toplum_iliskileri.json',
    'assets/ayt_esitagirlik_tarih/dunya_gucu_osmanli_ve_turk_islam_tarihi.json',
    'assets/ayt_esitagirlik_tarih/ii_dunya_savasi_sonrasinda_turkiye_ve_dunya.json',
    'assets/ayt_esitagirlik_tarih/ii_dunya_savasi_surecinde_turkiye_ve_dunya.json',
    'assets/ayt_esitagirlik_tarih/iki_savas_arasindaki_donemde_turkiye_ve_dunya.json',
    'assets/ayt_esitagirlik_tarih/ilk_ve_orta_caglarda_turk_dunyasi.json',
    'assets/ayt_esitagirlik_tarih/insanligin_ilk_donemleri.json',
    'assets/ayt_esitagirlik_tarih/islam_medeniyetinin_dogusu_ve_ilk_islam_devletleri.json',
    'assets/ayt_esitagirlik_tarih/klasik_cagda_osmanli_toplum_duzeni.json',
    'assets/ayt_esitagirlik_tarih/milli_mucadele.json',
    'assets/ayt_esitagirlik_tarih/orta_cag_da_dunya.json',
    'assets/ayt_esitagirlik_tarih/sermaye_ve_emek.json',
    'assets/ayt_esitagirlik_tarih/sultan_ve_osmanli_merkez_teskilati.json',
    'assets/ayt_esitagirlik_tarih/toplumsal_devrim_caginda_dunya_ve_turkiye.json',
    'assets/ayt_esitagirlik_tarih/turklerin_islamiyet_i_kabulu_ve_ilk_turk_islam_devletleri.json',
    'assets/ayt_esitagirlik_tarih/uluslararasi_iliskilerde_denge_stratejisi_1774_1914_.json',
    'assets/ayt_esitagirlik_tarih/ve_zaman.json',
    'assets/ayt_esitagirlik_tarih/xix._ve_xx._yuzyilda_degisen_gundelik_hayat.json',
    'assets/ayt_esitagirlik_tarih/xx._yuzyil_baslarinda_osmanli_devleti_ve_dunya.json',
    'assets/ayt_esitagirlik_tarih/xxi._yuzyilin_esiginde_turkiye_ve_dunya.json',
    'assets/ayt_esitagirlik_tarih/yerlesme_ve_devletlesme_surecinde_selcuklu_turkiyesi.json',
  ],
  'Lisans|Coğrafya': [
    'assets/kpss_lisans_cografya/bolgeler_cografyasi.json',
    'assets/kpss_lisans_cografya/hayvancilik.json',
    'assets/kpss_lisans_cografya/madenler_ve_enerji.json',
    'assets/kpss_lisans_cografya/sanayi_ve_endustri.json',
    'assets/kpss_lisans_cografya/tarim.json',
    'assets/kpss_lisans_cografya/ticaret.json',
    'assets/kpss_lisans_cografya/turizm.json',
    'assets/kpss_lisans_cografya/turkiye_de_nufus_ve_yerlesme.json',
    'assets/kpss_lisans_cografya/turkiye_nin_cografi_konumu.json',
    'assets/kpss_lisans_cografya/turkiye_nin_fiziki_ozellikleri.json',
    'assets/kpss_lisans_cografya/turkiye_nin_iklimi_ve_bitki_ortusu.json',
    'assets/kpss_lisans_cografya/ulasim.json',
  ],
  'Lisans|Matematik': [
    'assets/kpss_lisans_matematik/basit_esitsizlikler.json',
    'assets/kpss_lisans_matematik/carpanlara_ayirma.json',
    'assets/kpss_lisans_matematik/denklem_cozme.json',
    'assets/kpss_lisans_matematik/fonksiyonlar.json',
    'assets/kpss_lisans_matematik/islem.json',
    'assets/kpss_lisans_matematik/koklu_sayilar.json',
    'assets/kpss_lisans_matematik/kumeler.json',
    'assets/kpss_lisans_matematik/mantik.json',
    'assets/kpss_lisans_matematik/mutlak_deger.json',
    'assets/kpss_lisans_matematik/olasilik.json',
    'assets/kpss_lisans_matematik/oran_oranti.json',
    'assets/kpss_lisans_matematik/permutasyon_kombinasyon.json',
    'assets/kpss_lisans_matematik/problemler.json',
    'assets/kpss_lisans_matematik/rasyonel_sayilar_ondalikli_sayilar.json',
    'assets/kpss_lisans_matematik/temel_kavramlar.json',
    'assets/kpss_lisans_matematik/uslu_sayilar.json',
  ],
  'Lisans|Tarih': [
    'assets/kpss_lisans_tarih/17_yuzyil_osmanli_devleti_duraklama_donemi.json',
    'assets/kpss_lisans_tarih/18_yuzyil_osmanli_devleti_gerileme_donemi.json',
    'assets/kpss_lisans_tarih/19_yuzyil_osmanli_devleti_dagilma_donemi.json',
    'assets/kpss_lisans_tarih/20_yuzyil_osmanli_devleti.json',
    'assets/kpss_lisans_tarih/ataturk_donemi_ic_ve_dis_politikalar.json',
    'assets/kpss_lisans_tarih/cagdas_turk_ve_dunya_tarihi.json',
    'assets/kpss_lisans_tarih/ilk_turk_islam_devletleri.json',
    'assets/kpss_lisans_tarih/ilk_turk_islam_devletlerinde_kultur_ve_medeniyet.json',
    'assets/kpss_lisans_tarih/inkilap_tarihi.json',
    'assets/kpss_lisans_tarih/islamiyet_oncesi_turk_tarihi_soru_bankasi.json',
    'assets/kpss_lisans_tarih/islam_oncesi_turk_tarihi.json',
    'assets/kpss_lisans_tarih/milli_mucadele_donemi.json',
    'assets/kpss_lisans_tarih/osmanli_devleti_kultur_ve_medeniyet.json',
    'assets/kpss_lisans_tarih/osmanli_devleti_kurulus_ve_yukselme_donemi.json',
  ],
  'Lisans|Türkçe': [
    'assets/kpss_lisans_turkce/anlatim_bozukluklari.json',
    'assets/kpss_lisans_turkce/cumlede_anlam.json',
    'assets/kpss_lisans_turkce/cumlenin_ogeleri.json',
    'assets/kpss_lisans_turkce/cumle_turleri.json',
    'assets/kpss_lisans_turkce/dil_bilgisi_ses_olaylari.json',
    'assets/kpss_lisans_turkce/mantik.json',
    'assets/kpss_lisans_turkce/noktalama_isaretleri.json',
    'assets/kpss_lisans_turkce/paragrafta_anlam.json',
    'assets/kpss_lisans_turkce/paragrafta_anlatim_bicimi.json',
    'assets/kpss_lisans_turkce/sozcuk_turleri.json',
    'assets/kpss_lisans_turkce/sozcukte_anlam.json',
    'assets/kpss_lisans_turkce/sozcukte_yapi.json',
    'assets/kpss_lisans_turkce/yazim_kurallari.json',
  ],
  'Lisans|Vatandaşlık': [
    'assets/kpss_lisans_vatandaslik/anayasal_kavramlar.json',
    'assets/kpss_lisans_vatandaslik/idare_hukuku.json',
    'assets/kpss_lisans_vatandaslik/temel_hak_odevler.json',
    'assets/kpss_lisans_vatandaslik/temel_hukuk_kavramlari.json',
    'assets/kpss_lisans_vatandaslik/turk_anayasa_tarihi.json',
    'assets/kpss_lisans_vatandaslik/yargi.json',
    'assets/kpss_lisans_vatandaslik/yasama.json',
    'assets/kpss_lisans_vatandaslik/yurutme.json',
  ],
  'TYT|Biyoloji': [
    'assets/tyt_biyoloji/bitkiler_biyolojisi.json',
    'assets/tyt_biyoloji/canlilarin_ortak_ozellikleri.json',
    'assets/tyt_biyoloji/canlilarin_siniflandirilmasi.json',
    'assets/tyt_biyoloji/canlilarin_temel_bilesenleri.json',
    'assets/tyt_biyoloji/ekosistem_ekolojisi.json',
    'assets/tyt_biyoloji/hucre_bolunmeleri_ve_ureme.json',
    'assets/tyt_biyoloji/hucre_ve_organelleri.json',
    'assets/tyt_biyoloji/kalitim.json',
    'assets/tyt_biyoloji/madde_gecisleri.json',
  ],
  'TYT|Coğrafya': [
    'assets/tyt_cografya/bolgeler_cografyasi.json',
    'assets/tyt_cografya/hayvancilik.json',
    'assets/tyt_cografya/madenler_ve_enerji.json',
    'assets/tyt_cografya/sanayi_ve_endustri.json',
    'assets/tyt_cografya/tarim.json',
    'assets/tyt_cografya/ticaret.json',
    'assets/tyt_cografya/turizm.json',
    'assets/tyt_cografya/turkiye_de_nufus_ve_yerlesme.json',
    'assets/tyt_cografya/turkiye_nin_cografi_konumu.json',
    'assets/tyt_cografya/turkiye_nin_fiziki_ozellikleri.json',
    'assets/tyt_cografya/turkiye_nin_iklimi_ve_bitki_ortusu.json',
    'assets/tyt_cografya/ulasim.json',
  ],
  'TYT|Din Kültürü': [
    'assets/tyt_din/allah_insan_iliskisi.json',
    'assets/tyt_din/anadoluda_islam.json',
    'assets/tyt_din/dunya_ve_ahiret.json',
    'assets/tyt_din/guncel_dini_meseleler.json',
    'assets/tyt_din/hint_ve_cin_dinleri.json',
    'assets/tyt_din/inancla_ilgili_meseleler.json',
    'assets/tyt_din/islam_dusuncesinde_tasavvufi_yorumlar_ve_mezhepler.json',
    'assets/tyt_din/islam_ve_bilim.json',
    'assets/tyt_din/kurana_gore_hz_muhammed.json',
    'assets/tyt_din/kurandan_mesajlar.json',
    'assets/tyt_din/kuranda_bazi_kavramlar.json',
    'assets/tyt_din/yahudilik_ve_hristiyanlik.json',
  ],
  'TYT|Felsefe': [
    'assets/tyt_felsefe/20._yuzyil_felsefesi.json',
    'assets/tyt_felsefe/ahlak_felsefesi.json',
    'assets/tyt_felsefe/bilgi_felsefesi.json',
    'assets/tyt_felsefe/birey_ve_toplum.json',
    'assets/tyt_felsefe/felsefesi.json',
    'assets/tyt_felsefe/klasik_mantik.json',
    'assets/tyt_felsefe/mantiga_giris.json',
    'assets/tyt_felsefe/mantik_ve_dil.json',
    'assets/tyt_felsefe/ogrenme_bellek_dusunme.json',
    'assets/tyt_felsefe/psikolojinin_temel_surecleri.json',
    'assets/tyt_felsefe/psikoloji_bilimini_taniyalim.json',
    'assets/tyt_felsefe/ruh_sagliginin_temelleri.json',
    'assets/tyt_felsefe/sosyolojiye_giris.json',
    'assets/tyt_felsefe/toplumsal_degisme_ve_gelisme.json',
    'assets/tyt_felsefe/toplumsal_kurumlar.json',
    'assets/tyt_felsefe/toplumsal_yapi.json',
    'assets/tyt_felsefe/toplum_ve_kultur.json',
    'assets/tyt_felsefe/varlik_felsefesi.json',
    'assets/tyt_felsefe/ve_bilim.json',
  ],
  'TYT|Fizik': [
    'assets/tyt_fizik/basinc.json',
    'assets/tyt_fizik/bilimine_giris.json',
    'assets/tyt_fizik/dalgalar.json',
    'assets/tyt_fizik/dinamik.json',
    'assets/tyt_fizik/elektrik_akimi_ve_devreler.json',
    'assets/tyt_fizik/elektriksel_enerji_ve_guc.json',
    'assets/tyt_fizik/elektrostatik.json',
    'assets/tyt_fizik/hareket_ve_kuvvet.json',
    'assets/tyt_fizik/isi_sicaklik_ve_genlesme.json',
    'assets/tyt_fizik/is_guc_ve_enerji.json',
    'assets/tyt_fizik/madde_ve_ozellikleri.json',
    'assets/tyt_fizik/manyetizma.json',
    'assets/tyt_fizik/optik.json',
    'assets/tyt_fizik/sivilarin_kaldirma_kuvveti.json',
  ],
  'TYT|Kimya': [
    'assets/tyt_kimya/asit_baz_dengesi.json',
    'assets/tyt_kimya/atomun_yapisi.json',
    'assets/tyt_kimya/bilimi.json',
    'assets/tyt_kimya/her_yerde.json',
    'assets/tyt_kimya/karisimlar.json',
    'assets/tyt_kimya/kimyanin_temel_kanunlari.json',
    'assets/tyt_kimya/kimyasal_hesaplamalar.json',
    'assets/tyt_kimya/kimyasal_turler_arasi_etkilesim.json',
    'assets/tyt_kimya/maddenin_halleri.json',
    'assets/tyt_kimya/periyodik_sistem.json',
    'assets/tyt_kimya/sivi_cozeltiler.json',
  ],
  'TYT|Matematik': [
    'assets/tyt_matematik/basit_esitsizlikler.json',
    'assets/tyt_matematik/carpanlara_ayirma.json',
    'assets/tyt_matematik/denklem_cozme.json',
    'assets/tyt_matematik/fonksiyonlar.json',
    'assets/tyt_matematik/islem.json',
    'assets/tyt_matematik/koklu_sayilar.json',
    'assets/tyt_matematik/kumeler.json',
    'assets/tyt_matematik/mantik.json',
    'assets/tyt_matematik/mutlak_deger.json',
    'assets/tyt_matematik/olasilik.json',
    'assets/tyt_matematik/oran_oranti.json',
    'assets/tyt_matematik/permutasyon_kombinasyon.json',
    'assets/tyt_matematik/problemler.json',
    'assets/tyt_matematik/rasyonel_sayilar_ondalikli_sayilar.json',
    'assets/tyt_matematik/temel_kavramlar.json',
    'assets/tyt_matematik/uslu_sayilar.json',
  ],
  'TYT|Tarih': [
    'assets/tyt_tarih/17_yuzyil_osmanli_devleti_duraklama_donemi.json',
    'assets/tyt_tarih/18_yuzyil_osmanli_devleti_gerileme_donemi.json',
    'assets/tyt_tarih/19_yuzyil_osmanli_devleti_dagilma_donemi.json',
    'assets/tyt_tarih/20_yuzyil_osmanli_devleti.json',
    'assets/tyt_tarih/ataturk_donemi_ic_ve_dis_politikalar.json',
    'assets/tyt_tarih/cagdas_turk_ve_dunya_tarihi.json',
    'assets/tyt_tarih/ilk_turk_islam_devletleri.json',
    'assets/tyt_tarih/ilk_turk_islam_devletlerinde_kultur_ve_medeniyet.json',
    'assets/tyt_tarih/inkilap_tarihi.json',
    'assets/tyt_tarih/islamiyet_oncesi_turk_tarihi_soru_bankasi.json',
    'assets/tyt_tarih/islam_oncesi_turk_tarihi.json',
    'assets/tyt_tarih/milli_mucadele_donemi.json',
    'assets/tyt_tarih/osmanli_devleti_kultur_ve_medeniyet.json',
    'assets/tyt_tarih/osmanli_devleti_kurulus_ve_yukselme_donemi.json',
  ],
  'TYT|Türkçe': [
    'assets/tyt_turkce/anlatim_bozukluklari.json',
    'assets/tyt_turkce/cumlede_anlam.json',
    'assets/tyt_turkce/cumlenin_ogeleri.json',
    'assets/tyt_turkce/cumle_turleri.json',
    'assets/tyt_turkce/dil_bilgisi_ses_olaylari.json',
    'assets/tyt_turkce/mantik.json',
    'assets/tyt_turkce/noktalama_isaretleri.json',
    'assets/tyt_turkce/paragrafta_anlam.json',
    'assets/tyt_turkce/paragrafta_anlatim_bicimi.json',
    'assets/tyt_turkce/sozcukte_anlam.json',
    'assets/tyt_turkce/sozcukte_yapi.json',
    'assets/tyt_turkce/sozcuk_turleri.json',
    'assets/tyt_turkce/yazim_kurallari.json',
  ],
  'Önlisans|Coğrafya': [
    'assets/kpss_onlisans_cografya/bolgeler_cografyasi.json',
    'assets/kpss_onlisans_cografya/hayvancilik.json',
    'assets/kpss_onlisans_cografya/madenler_ve_enerji_kaynaklari.json',
    'assets/kpss_onlisans_cografya/sanayi_ve_endustri.json',
    'assets/kpss_onlisans_cografya/tarim.json',
    'assets/kpss_onlisans_cografya/ticaret.json',
    'assets/kpss_onlisans_cografya/turizm.json',
    'assets/kpss_onlisans_cografya/turkiye_de_nufus_ve_yerlesme.json',
    'assets/kpss_onlisans_cografya/turkiye_nin_cografi_konumu.json',
    'assets/kpss_onlisans_cografya/turkiye_nin_fiziki_ozellikleri.json',
    'assets/kpss_onlisans_cografya/turkiye_nin_iklimi_ve_bitki_ortusu.json',
    'assets/kpss_onlisans_cografya/ulasim.json',
  ],
  'Önlisans|Matematik': [
    'assets/kpss_onlisans_matematik/basit_esitsizlikler.json',
    'assets/kpss_onlisans_matematik/carpanlara_ayirma.json',
    'assets/kpss_onlisans_matematik/denklem_cozme.json',
    'assets/kpss_onlisans_matematik/fonksiyonlar.json',
    'assets/kpss_onlisans_matematik/koklu_sayilar.json',
    'assets/kpss_onlisans_matematik/kumeler.json',
    'assets/kpss_onlisans_matematik/mantik.json',
    'assets/kpss_onlisans_matematik/mutlak_deger.json',
    'assets/kpss_onlisans_matematik/oran_oranti.json',
    'assets/kpss_onlisans_matematik/problemler.json',
    'assets/kpss_onlisans_matematik/rasyonel_sayilar_ondalikli_sayilar.json',
    'assets/kpss_onlisans_matematik/temel_kavamlar.json',
    'assets/kpss_onlisans_matematik/uslu_sayilar.json',
  ],
  'Önlisans|Tarih': [
    'assets/kpss_onlisans_tarih/17_yuzyil_osmanli_devleti_duraklama_donemi.json',
    'assets/kpss_onlisans_tarih/18_yuzyil_osmanli_devleti_gerileme_donemi.json',
    'assets/kpss_onlisans_tarih/19_yuzyil_osmanli_devleti_dagilma_donemi.json',
    'assets/kpss_onlisans_tarih/20_yuzyil_osmanli_devleti.json',
    'assets/kpss_onlisans_tarih/ataturk_donemi_ic_ve_dis_politikalar.json',
    'assets/kpss_onlisans_tarih/cagdas_turk_ve_dunya_tarihi.json',
    'assets/kpss_onlisans_tarih/ilk_turk_islam_devletleri.json',
    'assets/kpss_onlisans_tarih/ilk_turk_islam_devletlerinde_kultur_ve_medeniyet.json',
    'assets/kpss_onlisans_tarih/inkilap_tarihi.json',
    'assets/kpss_onlisans_tarih/islamiyet_oncesi_turk_devletlerinde_kultur_ve_medeniyet.json',
    'assets/kpss_onlisans_tarih/islamiyet_oncesi_turk_tarihi.json',
    'assets/kpss_onlisans_tarih/milli_mucadele_donemi.json',
    'assets/kpss_onlisans_tarih/osmanli_devleti_kultur_ve_medeniyet.json',
    'assets/kpss_onlisans_tarih/osmanli_devleti_kurulus_ve_yukselme_donemi.json',
  ],
  'Önlisans|Türkçe': [
    'assets/kpss_onlisans_turkce/anlatim_bozukluklari.json',
    'assets/kpss_onlisans_turkce/cumlede_anlam.json',
    'assets/kpss_onlisans_turkce/cumlenin_ogeleri.json',
    'assets/kpss_onlisans_turkce/cumle_turleri.json',
    'assets/kpss_onlisans_turkce/dil_bilgisi_ses_olaylari.json',
    'assets/kpss_onlisans_turkce/mantik.json',
    'assets/kpss_onlisans_turkce/noktalama_isaretleri.json',
    'assets/kpss_onlisans_turkce/paragrafta_anlam.json',
    'assets/kpss_onlisans_turkce/paragrafta_anlatim_bicimi.json',
    'assets/kpss_onlisans_turkce/sozcuk_turleri.json',
    'assets/kpss_onlisans_turkce/sozcukte_anlam.json',
    'assets/kpss_onlisans_turkce/sozcukte_yapi.json',
    'assets/kpss_onlisans_turkce/yazim_kurallari.json',
  ],
  'Önlisans|Vatandaşlık': [
    'assets/kpss_onlisans_vatandaslik/anayasal_kavramlar.json',
    'assets/kpss_onlisans_vatandaslik/idare_hukuku.json',
    'assets/kpss_onlisans_vatandaslik/temel_hak_ve_odevler.json',
    'assets/kpss_onlisans_vatandaslik/temel_hukuk_kavramlari.json',
    'assets/kpss_onlisans_vatandaslik/turk_anayasa_tarihi.json',
    'assets/kpss_onlisans_vatandaslik/yargi.json',
    'assets/kpss_onlisans_vatandaslik/yasama.json',
    'assets/kpss_onlisans_vatandaslik/yurutme.json',
  ],
};


  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _slideAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 580))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.14)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _winCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _winScale = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _winCtrl, curve: Curves.elasticOut));
    _winFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _winCtrl, curve: Curves.easeIn));
    _init();
  }

  void _init() {
    final ref = FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode);
    _roomSub = ref.snapshots().listen((snap) async {
      if (!snap.exists) return;
      final d = snap.data()!;

      final bool isPlayer1 = _me?.uid == d['player1_id'];
      final bool p1Finished = d['player1_finished'] ?? false;
      final bool p2Finished = d['player2_finished'] ?? false;

      if (mounted) {
        setState(() {
          _amIFinished = isPlayer1 ? p1Finished : p2Finished;
          _gameOver = p1Finished && p2Finished;
          if (_gameOver && !_winCtrl.isAnimating && !_winCtrl.isCompleted) {
            _winCtrl.forward();
          }
        });
      }

      if (d['questions'] != null && (d['questions'] as List).isNotEmpty) {
        if (!_loaded && mounted) {
          setState(() {
            _questions = List<Map<String, dynamic>>.from(d['questions']);
            _loaded = true;
          });
          _slideCtrl.forward();
          _startTimer();
        }
      } else if (_me?.uid == d['player1_id'] && !_generating) {
        _generating = true;
        await _generateQuestions(
          exam1: d['player1_exam'] as String? ?? '',
          ders1: d['player1_ders'] as String? ?? '',
          exam2: d['player2_exam'] as String? ?? '',
          ders2: d['player2_ders'] as String? ?? '',
          ref: ref,
        );
      }
    });
  }

  // ── Soru üretici: statik map'ten dosya seç, yükle, Firestore'a yaz ────────
  Future<void> _generateQuestions({
    required String exam1, required String ders1,
    required String exam2, required String ders2,
    required DocumentReference ref,
  }) async {
    debugPrint('🎮 Multiplayer soru üretiliyor: p1=$exam1/$ders1  p2=$exam2/$ders2');

    final List<Map<String, dynamic>> pool = [];
    pool.addAll(await _loadFromMap(exam1, ders1));
    pool.addAll(await _loadFromMap(exam2, ders2));
    pool.shuffle();

    List<Map<String, dynamic>> final10 = pool.take(10).toList();

    if (final10.isEmpty) {
      debugPrint('❌ Multiplayer: Hiç soru yüklenemedi! Fallback eklendi.');
      final10 = [
        {
          'soru': 'Sorular yüklenemedi. Lütfen tekrar deneyin.',
          'secenekler': ['Tamam', 'Tamam', 'Tamam', 'Tamam'],
          'dogru_cevap': 0,
          'ders': 'Hata',
        }
      ];
    } else {
      debugPrint('✅ Multiplayer: ${final10.length} soru hazırlandı.');
    }

    await ref.update({'questions': final10});
  }

  // ── Statik map'ten dosya yükle ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _loadFromMap(String exam, String ders) async {
    final key = '$exam|$ders';
    final paths = _assetFiles[key];

    if (paths == null || paths.isEmpty) {
      debugPrint('⚠️ Statik map\'te bulunamadı: "$key"');
      return [];
    }

    // Rastgele max 3 dosya seç
    final shuffled = List<String>.from(paths)..shuffle();
    final selected = shuffled.take(3).toList();

    final List<Map<String, dynamic>> result = [];

    for (final path in selected) {
      try {
        final raw = await rootBundle.loadString(path);
        final decoded = json.decode(raw);

        List<dynamic> list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map) {
          list = (decoded['questions'] ?? decoded['sorular'] ?? []) as List<dynamic>;
        }

        list.shuffle();
        for (final item in list.take(4)) {
          final q = _parseQuestion(item, ders);
          if (q != null) result.add(q);
        }
      } catch (e) {
        debugPrint('Dosya okuma hatası ($path): $e');
      }
    }

    debugPrint('📂 $key → ${result.length} soru yüklendi');
    return result;
  }

  // ── JSON → standart soru formatı ──────────────────────────────────────────
  Map<String, dynamic>? _parseQuestion(dynamic item, String dersAdi) {
    if (item is! Map) return null;

    final String soruMetni = (item['soru'] ?? item['soru_metni'] ?? item['question'] ?? '')
        .toString().trim();
    if (soruMetni.isEmpty) return null;

    List<String> secenekler = [];

    // Format 1: siklar/secenekler/options → Liste
    final rawList = item['siklar'] ?? item['secenekler'] ?? item['options'];
    if (rawList is List) {
      secenekler = rawList.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    // Format 2: A, B, C, D, E ayrı key'ler
    else {
      for (final harf in ['A', 'B', 'C', 'D', 'E']) {
        final val = item[harf]?.toString().trim() ?? '';
        if (val.isNotEmpty) secenekler.add(val);
      }
    }

    if (secenekler.isEmpty) return null;

    // dogru_cevap → int index
    int dogruIndex = 0;
    final rawCevap = item['dogru_cevap'] ?? item['cevap'] ?? item['answer'];
    if (rawCevap is int) {
      dogruIndex = rawCevap.clamp(0, secenekler.length - 1);
    } else if (rawCevap is double) {
      dogruIndex = rawCevap.toInt().clamp(0, secenekler.length - 1);
    } else if (rawCevap != null) {
      final s = rawCevap.toString().trim().toUpperCase();
      final asInt = int.tryParse(s);
      if (asInt != null) {
        dogruIndex = asInt.clamp(0, secenekler.length - 1);
      } else if (s.isNotEmpty) {
        // 'A'→0, 'B'→1, 'C'→2 ...
        final idx = s.codeUnitAt(0) - 65;
        if (idx >= 0 && idx < secenekler.length) dogruIndex = idx;
      }
    }

    return {
      'soru': soruMetni,
      'secenekler': secenekler,
      'dogru_cevap': dogruIndex,
      'ders': dersAdi,
    };
  }

  // ── Timer ─────────────────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    if (_amIFinished || _gameOver) return;
    setState(() { _timeLeft = 30; _answered = false; _selected = null; });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft <= 1) { t.cancel(); _forceNext(); }
      else if (mounted) { setState(() => _timeLeft--); }
    });
  }

  Future<void> _forceNext() async {
    if (_qi < _questions.length - 1) { _goNext(); }
    else { await _markAsFinished(); }
  }

  void _goNext() {
    _slideCtrl.reset();
    setState(() { _qi++; _answered = false; _selected = null; });
    _slideCtrl.forward();
    _startTimer();
  }

  Future<void> _markAsFinished() async {
    _timer?.cancel();
    final ref = FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode);
    final d = (await ref.get()).data()!;
    final isPlayer1 = _me?.uid == d['player1_id'];
    await ref.update({isPlayer1 ? 'player1_finished' : 'player2_finished': true});
    if (mounted) setState(() => _amIFinished = true);
  }

  Future<void> _answer(int optIndex) async {
    if (_answered || _amIFinished) return;
    _timer?.cancel();
    setState(() { _selected = optIndex.toString(); _answered = true; });

    final int correct = _questions[_qi]['dogru_cevap'] as int;
    final ref = FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode);
    final d = (await ref.get()).data()!;
    final isPlayer1 = _me?.uid == d['player1_id'];

    if (optIndex == correct) {
      final field = isPlayer1 ? 'player1_score' : 'player2_score';
      final bonus = (_timeLeft / 30 * 10).round();
      await ref.update({field: FieldValue.increment(10 + bonus)});
    }

    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    if (_qi < _questions.length - 1) { _goNext(); }
    else { await _markAsFinished(); }
  }

  Future<void> _handleExitAttempt() async {
    if (_gameOver || _allowExit || _exitDialogOpen) return;

    _exitDialogOpen = true;
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF12186B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Yarışmadan çıkılsın mı?',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Çıkarsan yarışma ekranından ayrılacaksın. Emin misin?',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Kal',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF00E5FF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Çık',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFF3D71),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
    _exitDialogOpen = false;

    if (!mounted || shouldExit != true) return;

    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _roomSub?.cancel();
    _slideCtrl.dispose(); _pulseCtrl.dispose(); _winCtrl.dispose();
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowExit || _gameOver,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_handleExitAttempt());
      },
      child: Scaffold(
        body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E43), Color(0xFF12186B), Color(0xFF1B0A4A)],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomCode).snapshots(),
            builder: (_, snap) {
              if (!snap.hasData || !snap.data!.exists) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
              }
              final d = snap.data!.data() as Map<String, dynamic>;
              final p1Name  = d['player1_name']  ?? 'Oyuncu 1';
              final p2Name  = d['player2_name']  ?? 'Oyuncu 2';
              final p1Score = d['player1_score'] ?? 0;
              final p2Score = d['player2_score'] ?? 0;
              final p1Sub   = (d['player1_ders'] ?? '').toString();
              final p2Sub   = (d['player2_ders'] ?? '').toString();
              final bool isPlayer1 = _me?.uid == d['player1_id'];
              final String opponentName = isPlayer1 ? p2Name : p1Name;

              return Column(children: [
                _scoreBar(p1Name, p1Score, p2Name, p2Score, p1Sub, p2Sub),
                Expanded(
                  child: !_loaded
                      ? _loading()
                      : _gameOver
                          ? _winScreen(p1Name, p1Score, p2Name, p2Score)
                          : _amIFinished
                              ? _waitingOpponentScreen(opponentName)
                              : _questionArea(),
                ),
              ]);
            },
          ),
          ),
        ),
      ),
    );
  }

  Widget _loading() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      ScaleTransition(scale: _pulseAnim, child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFFD500F9), Color(0xFF7C4DFF)]),
            boxShadow: [BoxShadow(color: const Color(0xFFD500F9).withValues(alpha: 0.4), blurRadius: 28, spreadRadius: 4)]),
        child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 48),
      )),
      const SizedBox(height: 24),
      Text('Düello Başlıyor! ⚔️', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Sorular hazırlanıyor...', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
      const SizedBox(height: 18),
      const CircularProgressIndicator(color: Color(0xFFD500F9), strokeWidth: 3),
    ]));
  }

  Widget _waitingOpponentScreen(String oppName) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      ScaleTransition(scale: _pulseAnim, child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)]),
            boxShadow: [BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), blurRadius: 28, spreadRadius: 4)]),
        child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 48),
      )),
      const SizedBox(height: 24),
      Text('Harikasın! Testi Bitirdin 🚀', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('$oppName bekleniyor...', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
      const SizedBox(height: 18),
      const CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 3),
    ]));
  }

  Widget _scoreBar(String p1, int s1, String p2, int s2, String sub1, String sub2) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.38),
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)))),
      child: Row(children: [
        Expanded(child: _playerScore(p1, s1, sub1, const Color(0xFF00E5FF), CrossAxisAlignment.start)),
        Column(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFFD500F9)]),
                boxShadow: [BoxShadow(color: const Color(0xFFD500F9).withValues(alpha: 0.28), blurRadius: 10)]),
            child: Center(child: Text('VS', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)))),
          if (_loaded && !_gameOver && !_amIFinished) ...[
            const SizedBox(height: 3),
            Text('${_qi + 1}/${_questions.length}', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9)),
          ],
        ]),
        Expanded(child: _playerScore(p2, s2, sub2, const Color(0xFFFF3D71), CrossAxisAlignment.end)),
      ]),
    );
  }

  Widget _playerScore(String name, int score, String sub, Color c, CrossAxisAlignment ax) {
    return Column(crossAxisAlignment: ax, children: [
      Text(name, style: GoogleFonts.poppins(color: c, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
      if (sub.isNotEmpty) Text(sub, style: GoogleFonts.poppins(color: c.withValues(alpha: 0.55), fontSize: 9), overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text('$score', style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1)),
    ]);
  }

  Widget _questionArea() {
    if (_questions.isEmpty) return const SizedBox();
    final q = _questions[_qi];
    final String soruMetni  = q['soru'].toString();
    final List<String> secs = List<String>.from(q['secenekler'] as List);
    final int correctIndex  = q['dogru_cevap'] as int;
    final double pct  = _timeLeft / 30;
    final Color tColor = _timeLeft > 15 ? const Color(0xFF00E676)
        : _timeLeft > 8 ? const Color(0xFFFFD600) : const Color(0xFFFF3D71);
    const harfler = ['A', 'B', 'C', 'D', 'E'];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      physics: const BouncingScrollPhysics(),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(18)),
                  child: Text('${_qi + 1} / ${_questions.length}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12))),
            ),
          ),
          const SizedBox(width: 8),
          ScaleTransition(scale: _timeLeft <= 8 ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
            child: SizedBox(width: 55, height: 55, child: Stack(fit: StackFit.expand, children: [
              CircularProgressIndicator(value: pct, strokeWidth: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(tColor)),
              Center(child: Text('$_timeLeft', style: GoogleFonts.poppins(color: tColor, fontSize: 17, fontWeight: FontWeight.w900))),
            ])),
          ),
        ]),
        const SizedBox(height: 16),
        SlideTransition(
          position: _slideAnim,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09))),
            child: Column(children: [
              Container(width: 34, height: 34,
                  decoration: const BoxDecoration(shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFF7B2FF7), Color(0xFF00E5FF)])),
                  child: Center(child: Text('?', style: GoogleFonts.poppins(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)))),
              const SizedBox(height: 13),
              Text(soruMetni, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, height: 1.5), textAlign: TextAlign.center),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        ...List.generate(secs.length, (i) {
          final harf = i < harfler.length ? harfler[i] : '${i + 1}';
          Color border = Colors.white.withValues(alpha: 0.11);
          Color bg     = Colors.white.withValues(alpha: 0.04);
          Color tc     = Colors.white;
          Color lc     = Colors.white.withValues(alpha: 0.52);
          IconData? icon;
          if (_answered) {
            if (i == correctIndex) {
              border = const Color(0xFF00E676); bg = const Color(0xFF00E676).withValues(alpha: 0.11);
              tc = const Color(0xFF00E676); lc = const Color(0xFF00E676); icon = Icons.check_circle_rounded;
            } else if (_selected == i.toString()) {
              border = const Color(0xFFFF3D71); bg = const Color(0xFFFF3D71).withValues(alpha: 0.11);
              tc = const Color(0xFFFF3D71).withValues(alpha: 0.7); lc = const Color(0xFFFF3D71); icon = Icons.cancel_rounded;
            } else {
              tc = Colors.white.withValues(alpha: 0.28); lc = Colors.white.withValues(alpha: 0.18);
            }
          }
          return GestureDetector(
            onTap: () => _answer(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 11),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15), border: Border.all(color: border, width: 1.4)),
              child: Row(children: [
                Container(width: 30, height: 30,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: lc.withValues(alpha: 0.14), border: Border.all(color: lc, width: 1.4)),
                    child: Center(child: Text(harf, style: GoogleFonts.poppins(color: lc, fontSize: 12, fontWeight: FontWeight.w700)))),
                const SizedBox(width: 12),
                Expanded(child: Text(secs[i], style: GoogleFonts.poppins(color: tc, fontSize: 14, fontWeight: FontWeight.w600))),
                if (icon != null) Icon(icon, color: border, size: 20),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  Widget _winScreen(String p1, int s1, String p2, int s2) {
    final draw   = s1 == s2;
    final winner = draw ? 'Berabere!' : (s1 > s2 ? p1 : p2);
    return FadeTransition(
      opacity: _winFade,
      child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        ScaleTransition(scale: _winScale, child: Container(
          width: 115, height: 115,
          decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: draw
                  ? const LinearGradient(colors: [Color(0xFF7B2FF7), Color(0xFF00E5FF)])
                  : const LinearGradient(colors: [Color(0xFFFFD600), Color(0xFFFF6D00)]),
              boxShadow: [BoxShadow(color: draw ? const Color(0xFF7B2FF7).withValues(alpha: 0.45) : const Color(0xFFFFD600).withValues(alpha: 0.45), blurRadius: 38, spreadRadius: 4)]),
          child: Center(child: Icon(draw ? Icons.handshake_rounded : Icons.emoji_events_rounded, size: 56, color: Colors.white)),
        )),
        const SizedBox(height: 22),
        Text(draw ? 'BERABERE!' : 'KAZANAN!', style: GoogleFonts.poppins(color: draw ? const Color(0xFF00E5FF) : const Color(0xFFFFD600), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 4)),
        const SizedBox(height: 6),
        Text(winner, style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        const SizedBox(height: 26),
        Row(children: [
          Expanded(child: _endCard(p1, s1, const Color(0xFF00E5FF), s1 > s2)),
          const SizedBox(width: 12),
          Expanded(child: _endCard(p2, s2, const Color(0xFFFF3D71), s2 > s1)),
        ]),
        const SizedBox(height: 26),
        GestureDetector(
          onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFD500F9), Color(0xFF7C4DFF)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: const Color(0xFFD500F9).withValues(alpha: 0.38), blurRadius: 18, offset: const Offset(0, 5))]),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.home_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Ana Sayfaya Dön', style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ]))),
    );
  }

  Widget _endCard(String name, int score, Color c, bool isWinner) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isWinner ? c.withValues(alpha: 0.55) : c.withValues(alpha: 0.14), width: isWinner ? 2 : 1),
          boxShadow: isWinner ? [BoxShadow(color: c.withValues(alpha: 0.22), blurRadius: 18)] : []),
      child: Column(children: [
        if (isWinner) Icon(Icons.star_rounded, color: c, size: 16),
        if (isWinner) const SizedBox(height: 3),
        Text(name, style: GoogleFonts.poppins(color: c, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 7),
        Text('$score', style: GoogleFonts.poppins(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1)),
        Text('puan', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
      ]),
    );
  }
}