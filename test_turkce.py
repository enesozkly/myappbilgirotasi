import google.generativeai as genai
import json
import time

# 1. YENİ API ANAHTARINI BURAYA YAPIŞTIR (PASTE YOUR NEW API KEY HERE)
genai.configure(api_key="AIzaSyDbloadkLnZ2_HYuE4Kyt_GM9h5wG5iXQY")

# 2. ÜCRETSİZ VE STANDART MODEL (FREE AND STANDARD MODEL)
model = genai.GenerativeModel('gemini-flash-latest')

DERS = "TYT Türkçe"
HEDEF_SORU = 200 # Tam hedef (Full target)
PARTI_BUYUKLUGU = 10 # Her istekte 10 soru (10 questions per request)
BOLUM_SAYISI = HEDEF_SORU // PARTI_BUYUKLUGU # 20 döngü (20 loops)

KONULAR = ["Sözcükte Anlam"] 

def generate_questions(konu):
    dosya_adi = f"{DERS.replace(' ', '_')}_{konu.replace(' ', '_')}_TAM_TEST.json"
    tum_sorular = []
    
    print(f"\n🚀 DEV OPERASYON BAŞLIYOR: {DERS} - {konu} ({HEDEF_SORU} Soru)")
    
    for section_no in range(1, BOLUM_SAYISI + 1):
        start_soru_no = (section_no - 1) * PARTI_BUYUKLUGU + 1
        
        prompt = f"""
        Sen uzman bir {DERS} öğretmenisin. '{konu}' konusunda tam {PARTI_BUYUKLUGU} adet soru üret.
        
        KRİTİK KURALLAR (CRITICAL RULES):
        1. ÇİZİM YOK: Sadece metin tabanlı sorular. 'svg_kod' ve 'image_url' her zaman boş ("") kalacak.
        2. %100 TYT SEVİYESİ: ÖSYM tarzında, çeldirici şıkları güçlü, anlam yoğunluğu yüksek, kaliteli uzun metinli sorular hazırla.
        3. DÜŞÜNCE SİSTEMİ (ÇOK ÖNEMLİ): Çeldiricilere düşmemek için, önce 'dusunce_sistemi' alanına kelimenin/cümlenin bağlam içindeki anlamını ve neden diğer şıkların yanlış olduğunu analiz et.
        4. SADECE JSON DÖNDÜR: Hiçbir Markdown etiketi (```json) kullanma, sadece ham köşeli parantezli listeyi döndür.
        
        Format:
        [
          {{
            "dusunce_sistemi": "Bu soruda altı çizili sözcük mecaz anlamda kullanılmış... A şıkkı çeldirici çünkü... Doğru cevap C olmalı.",
            "soru_metni": "...",
            "image_url": "",
            "svg_kod": "",
            "secenekler": ["A", "B", "C", "D", "E"],
            "dogru_cevap": 0,
            "aciklama": "Öğrencinin göreceği detaylı ve anlaşılır çözüm..."
          }}
        ]
        """
        try:
            response = model.generate_content(prompt)
            # Metni temizle (Clean the text)
            text = response.text.replace("```json", "").replace("```", "").strip()
            
            sorular_json = json.loads(text)
            
            for i, soru in enumerate(sorular_json):
                soru["ders"] = DERS
                soru["konu"] = konu
                soru["soru_no"] = start_soru_no + i
                if "image_url" not in soru: soru["image_url"] = ""
                if "svg_kod" not in soru: soru["svg_kod"] = ""
                
                # 'dusunce_sistemi'ni JSON'dan çıkarıyoruz (We remove the thinking system from JSON)
                if "dusunce_sistemi" in soru:
                    del soru["dusunce_sistemi"]
                
                tum_sorular.append(soru)
                
            print(f"  ✅ Bölüm {section_no}/{BOLUM_SAYISI} başarılı! ({len(tum_sorular)}/{HEDEF_SORU})")
            
        except Exception as e:
            print(f"  ❌ Hata: Bölüm {section_no} atlandı. Sebep: {e}")
        
        # 6 saniye güvenlik molası (6 seconds safety pause)
        time.sleep(6) 

    if tum_sorular:
        with open(dosya_adi, "w", encoding="utf-8") as f:
            json.dump(tum_sorular, f, ensure_ascii=False, indent=2)
        print(f"📦 TAM DOSYA KAYDEDİLDİ: {dosya_adi}")

for k in KONULAR:
    generate_questions(k)
    
print("🎉 200 SORULUK DEV TEST BİTTİ! (200-QUESTION GIANT TEST FINISHED!)")