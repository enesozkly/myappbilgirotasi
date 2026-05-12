const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");

admin.initializeApp();
const db = admin.firestore();

// Gemini API anahtarını buraya ekleyeceğiz
const genAI = new GoogleGenerativeAI("AIzaSyDg_JWDAhLXUBt4sheGuLOUIfN7Y8Rvv5w");

exports.sorulariGetir = functions.https.onCall(async (data, context) => {
    // Uygulamadan gelen istekleri alıyoruz
    const konu = data.konu;   
    const bolum = data.bolum; 

    // Veritabanında doküman yolunu belirliyoruz (Boşlukları silerek)
    const dokumanYolu = `${konu}_Bolum_${bolum}`.replace(/\s+/g, ""); 
    const bolumDokumani = db.collection("SoruBankasi").doc(dokumanYolu);
    const bolumVerisi = await bolumDokumani.get();

    // 1. ADIM: İhtiyaç Anında Üretim Kontrolü (Daha önce üretilmiş mi?)
    if (bolumVerisi.exists) {
        console.log("Sorular veritabanından çekildi. Maliyet: 0");
        return bolumVerisi.data();
    }

    // 2. ADIM: Veritabanında yoksa Gemini 1.5 Flash'a bağlan ve yeni üret
    console.log("Bu bölüm ilk defa oynanıyor, yapay zeka 10 soru üretiyor...");
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

    const prompt = `Sen uzman bir YKS öğretmenisin. "${konu}" konusunun ${bolum}. bölümü zorluğunda 10 adet özgün ve çoktan seçmeli soru üret.
    Sadece ve sadece geçerli bir JSON formatında çıktı ver, kod bloğu veya başka hiçbir metin ekleme.
    Format şu şekilde olmalı:
    {
      "konu": "${konu}",
      "bolum": ${bolum},
      "sorular": [
        {
          "id": 1,
          "soruMetni": "Soru buraya...",
          "secenekler": {"A": "...", "B": "...", "C": "...", "D": "..."},
          "dogruCevap": "A"
        }
      ]
    }`;

    try {
        const sonuc = await model.generateContent(prompt);
        let metin = sonuc.response.text();
        
        // Gemini'nin ekleyebileceği ```json taglerini temizliyoruz
        metin = metin.replace(/```json/g, "").replace(/```/g, "").trim();
        const uretilenVeri = JSON.parse(metin);

        // 3. ADIM: Üretilen soruları Firestore'a kaydet (Sonraki oyuncular için)
        await bolumDokumani.set(uretilenVeri);

        // Soruları Flutter uygulamana geri gönder
        return uretilenVeri;

    } catch (hata) {
        console.error("Yapay zeka veya JSON hatası:", hata);
        throw new functions.https.HttpsError("internal", "Sorular üretilirken bir sorun oluştu.");
    }
});