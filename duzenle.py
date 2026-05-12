import os
import json

# The folder where your JSON files are (JSON dosyalarının bulunduğu klasör)
klasor_yolu = './assets'

def format_json(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError:
            print(f"Hata (Error): {file_path} okunamadı.")
            return

    # Check if the file is a list or a dictionary (Dosyanın liste mi yoksa sözlük mü olduğunu kontrol et)
    is_dict_format = False
    questions = []
    
    if isinstance(data, dict):
        if 'questions' in data:
            questions = data['questions']
            is_dict_format = True
        else:
            questions = [data] 
    elif isinstance(data, list):
        questions = data

    yeni_sorular = []
    sayac = 1 # Question counter (Soru sayacı)

    for item in questions:
        yeni_soru = {}
        
        # 1. Find or create Question Number (Soru Numarasını bul veya oluştur)
        mevcut_id = item.get('soru_no') or item.get('id') or item.get('Soru_No')
        yeni_soru['soru_no'] = int(mevcut_id) if mevcut_id is not None and str(mevcut_id).isdigit() else sayac
        
        # 2. Find Question Text (Soru Metnini Bul)
        yeni_soru['soru_metni'] = item.get('soru_metni') or item.get('question') or item.get('Soru') or item.get('soru') or ""
        
        # 3. Find Options (Seçenekleri Bul)
        yeni_soru['secenekler'] = item.get('secenekler') or item.get('options') or item.get('Secenekler') or item.get('şıklar') or []
        
        # 4. Find Correct Answer (Doğru Cevabı Bul)
        cevap = item.get('dogru_cevap') if item.get('dogru_cevap') is not None else item.get('correctIndex')
        if cevap is None:
            cevap = item.get('correct_answer')
        yeni_soru['dogru_cevap'] = int(cevap) if str(cevap).isdigit() else 0
            
        # 5. Find Explanation (Açıklamayı Bul)
        yeni_soru['aciklama'] = item.get('aciklama') or item.get('explanation') or item.get('cozum') or item.get('çözüm') or ""
        
        # 6. Other necessary fields (Diğer gerekli alanlar)
        yeni_soru['svg_kod'] = item.get('svg_kod') or item.get('image_url') or ""
        yeni_soru['ders'] = item.get('ders') or ""
        yeni_soru['konu'] = item.get('konu') or ""
        
        yeni_sorular.append(yeni_soru)
        sayac += 1

    # Save in the same format (Aynı formatta kaydet)
    kaydedilecek_veri = {"questions": yeni_sorular} if is_dict_format else yeni_sorular

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(kaydedilecek_veri, f, ensure_ascii=False, indent=2)
        
    print(f"✅ Düzenlendi (Fixed): {os.path.basename(file_path)} ({len(yeni_sorular)} soru)")

# Find all JSON files and fix them (Tüm JSON dosyalarını bul ve düzenle)
for dosya in os.listdir(klasor_yolu):
    if dosya.endswith('.json'):
        format_json(os.path.join(klasor_yolu, dosya))

print("🎉 İŞLEM TAMAMLANDI! TÜM DOSYALAR TEK STANDARDA GETİRİLDİ.")