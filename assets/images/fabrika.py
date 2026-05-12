import json
import os

# Senin klasör yolun
klasor_yolu = r'C:\Users\enesz\Desktop\YKS_Fabrikasi\ChatGPT_Eksik_Konular'

# İMHA LİSTESİ: Sadece bu iki Türkçe dosyasındaki bilimsel ve mantık hataları
imha_listesi = {
    "TYT_Turkce_Tamlamalar_İsim_ve_Sıfat_Tamlamaları.json": [1, 199],
    "TYT_Turkce_Sözcükte_Yapı_Kökler_ve_Ekler.json": [1, 197, 199]
}

def turkce_fabrikasi_v2():
    if not os.path.exists(klasor_yolu):
        print(f"HATA: Yol bulunamadı -> {klasor_yolu}")
        return

    print("🚀 Türkçe Fabrikası v2: Tamlamalar ve Yapı bilgisi temizleniyor...\n")

    for dosya_adi, hatali_idler in imha_listesi.items():
        yol = os.path.join(klasor_yolu, dosya_adi)
        
        if not os.path.exists(yol):
            continue
            
        try:
            with open(yol, 'r', encoding='utf-8') as f:
                sorular = json.load(f)

            ilk_sayi = len(sorular)
            temiz_liste = []
            kayitli_idler = set()

            for soru in sorular:
                sid = soru.get('id')
                
                # TEMİZLİK: Belirlenen bilimsel hatalar + Teknik bozukluklar
                if sid in hatali_idler or sid is None or sid == "" or sid in kayitli_idler:
                    continue
                
                kayitli_idler.add(sid)
                temiz_liste.append(soru)

            if len(temiz_liste) < ilk_sayi:
                with open(yol, 'w', encoding='utf-8') as f:
                    json.dump(temiz_liste, f, indent=4, ensure_ascii=False)
                print(f"✅ {dosya_adi}: {ilk_sayi - len(temiz_liste)} hatalı soru imha edildi.")
            else:
                print(f"✨ {dosya_adi}: Dosya tertemiz, sorun yok.")

        except Exception as e:
            print(f"❌ {dosya_adi} işlenirken hata oluştu: {e}")

    print("\n🏁 İşlem tamamlandı! Türkçe bankan artık çok daha güvenilir.")

if __name__ == "__main__":
    turkce_fabrikasi_v2()