import json
import os

# 1. Define the path (1. Yolu tanımla)
folder_path = r'C:\Users\enesz\Desktop\YKS_Fabrikasi\ChatGPT_Eksik_Konular'

# 2. Check if the folder exists (2. Klasörün var olup olmadığını kontrol et)
if not os.path.exists(folder_path):
    print(f"ERROR: The folder path does not exist! Check the path again.")
    print(f"(HATA: Klasör yolu mevcut değil! Yolu tekrar kontrol et.)")
else:
    # 3. Process files (3. Dosyaları işle)
    for file_name in os.listdir(folder_path):
        if file_name.endswith('.json'):
            full_path = os.path.join(folder_path, file_name)
            
            try:
                # Read with UTF-8 (UTF-8 ile oku)
                with open(full_path, 'r', encoding='utf-8') as file:
                    data = json.load(file)

                # Check if data is a list (Verinin liste olup olmadığını kontrol et)
                if isinstance(data, list):
                    for index, item in enumerate(data, start=1):
                        item['id'] = index
                    
                    # Write back to file (Dosyaya geri yaz)
                    with open(full_path, 'w', encoding='utf-8') as outfile:
                        json.dump(data, outfile, indent=4, ensure_ascii=False)
                    print(f"DONE (TAMAM): {file_name}")
                else:
                    print(f"SKIPPED (ATLANDI): {file_name} is a dictionary, not a list.")

            except json.JSONDecodeError:
                print(f"FORMAT ERROR (FORMAT HATASI): {file_name} has broken JSON code.")
            except Exception as e:
                print(f"OTHER ERROR (DİĞER HATA): {file_name} -> {e}")

    print("\nProcess finished! (İşlem tamamlandı!)")