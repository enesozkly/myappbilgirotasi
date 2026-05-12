import pandas as pd
import json
import os

folder_path = './assets/' 

def convert_excel_to_json():
    if not os.path.exists(folder_path):
        print(f"❌ Hata: {folder_path} klasörü bulunamadı!")
        return

    for file in os.listdir(folder_path):
        if file.endswith('.xlsx'):
            try:
                df = pd.read_excel(os.path.join(folder_path, file))
                df.columns = [str(c).strip() for c in df.columns]
                
                questions = []
                for index, row in df.iterrows():
                    q_text = str(row.get('Soru', row.get('soru', '')))
                    if q_text == 'nan' or not q_text: continue

                    questions.append({
                        "question": q_text,
                        "options": [str(row.get('A','')), str(row.get('B','')), str(row.get('C','')), str(row.get('D','')), str(row.get('E',''))],
                        "correctIndex": int(row.get('Cevap', 0)),
                        "explanation": str(row.get('Aciklama', ''))
                    })

                json_file_name = file.replace('.xlsx', '.json')
                with open(os.path.join(folder_path, json_file_name), 'w', encoding='utf-8') as f:
                    # DÜZELTİLDİ: ensure_ascii=False
                    json.dump({"questions": questions}, f, ensure_ascii=False, indent=4)
                print(f"✅ {json_file_name} hazır.")
            except Exception as e:
                print(f"❌ {file} hatası: {e}")

if __name__ == "__main__":
    convert_excel_to_json()