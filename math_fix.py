import os
import re
import argparse

def process_files(preview_only=True):
    folder_path = "assets"
    
    if not os.path.exists(folder_path):
        print(f"HATA: '{folder_path}' klasörü bulunamadı.")
        return

    # Güvenli Regex: x2, y3 gibi ifadeleri bulur (Safe Regex: finds expressions like x2, y3)
    pattern = re.compile(r'\b([a-zA-Z])(\d+)\b')
    found_any = False
    
    # Bütün klasörleri ve dosyaları tara (Scan all folders and files)
    for root, dirs, files in os.walk(folder_path):
        for file in files:
            # Eğer dosya bir JSON ise VE bulunduğu KLASÖRÜN adında 'matematik' geçiyorsa:
            # (If the file is a JSON AND the FOLDER name contains 'matematik':)
            if file.endswith(".json") and "matematik" in root.lower():
                file_path = os.path.join(root, file)
                
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                if pattern.search(content):
                    found_any = True
                    new_content = pattern.sub(r'\1^\2', content)
                    
                    if preview_only:
                        print(f"[ÖNİZLEME] Düzeltilecek dosya: {file_path}")
                    else:
                        with open(file_path, 'w', encoding='utf-8') as f:
                            f.write(new_content)
                        print(f"[BAŞARILI] Sadece matematik düzeltildi: {file_path}")
                        
    if not found_any:
        print("İşlem yapılacak klasör veya değiştirilecek matematik ifadesi bulunamadı.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", action="store_true", help="Sadece önizleme yapar.")
    parser.add_argument("--fix", action="store_true", help="Dosyaları gerçekten düzeltir.")
    args = parser.parse_args()

    if args.fix:
        print("Klasör hedefli düzeltme işlemi başlıyor...\n" + "-"*30)
        process_files(preview_only=False)
        print("-" * 30 + "\nİşlem tamamlandı, sorular hazır!")
    else:
        print("Önizleme modu çalışıyor. (Gerçekte hiçbir şey değişmiyor)\n" + "-"*30)
        process_files(preview_only=True)
        print("-" * 30 + "\nEğer listelenen dosyaları düzeltmek istiyorsan şu komutu gir: python math_fix.py --fix")