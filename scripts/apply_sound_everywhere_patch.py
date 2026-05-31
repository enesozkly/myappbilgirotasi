#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Bilgi Rotası ses entegrasyonu otomatik patch script'i.

Ne yapar?
- Quiz sayfalarında doğru/yanlış cevap seslerini eklemeye çalışır.
- Quiz/deneme bitişlerinde skor sesini eklemeye çalışır.
- Reklam ödülü başarılıysa enerji/ödül sesi eklemeye çalışır.
- Her işlemden önce .bak yedek alır.

Kullanım:
  python scripts/apply_sound_everywhere_patch.py

Not:
Bu script projedeki mevcut dosya içeriğine göre güvenli regex/string replacement yapar.
Eğer bir dosyada beklenen kod bloğunu bulamazsa o dosyayı pas geçer ve terminalde uyarır.
"""

from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"

def backup(path: Path):
    bak = path.with_suffix(path.suffix + ".bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")

def write(path: Path, text: str):
    path.write_text(text, encoding="utf-8")

def ensure_import(text: str, import_line: str) -> str:
    if import_line in text:
        return text

    lines = text.splitlines()
    last_import = -1
    for i, line in enumerate(lines):
        if line.strip().startswith("import "):
            last_import = i

    if last_import == -1:
        return import_line + "\n" + text

    lines.insert(last_import + 1, import_line)
    return "\n".join(lines) + ("\n" if text.endswith("\n") else "")

def patch_file(path: Path, patcher):
    if not path.exists():
        print(f"YOK: {path.relative_to(ROOT)}")
        return

    original = read(path)
    backup(path)
    updated = patcher(original)

    if updated != original:
        write(path, updated)
        print(f"OK: {path.relative_to(ROOT)}")
    else:
        print(f"DEĞİŞMEDİ / BLOK BULUNAMADI: {path.relative_to(ROOT)}")

def patch_quiz_page(text: str) -> str:
    text = ensure_import(text, "import 'dart:async';")
    text = ensure_import(text, "import '../services/sound_service.dart';")

    # checkAnswer içinde doğru/yanlış sesi
    text = text.replace(
        "final bool isCorrect = index == questions[currentQuestionIndex]['dogru_cevap'];",
        "final bool isCorrect = index == questions[currentQuestionIndex]['dogru_cevap'];\n"
        "    unawaited(isCorrect ? SoundService.instance.correct() : SoundService.instance.wrong());"
    )

    # finishQuiz içinde sonuç sesi
    text = text.replace(
        "void finishQuiz() async {",
        "void finishQuiz() async {\n"
        "    unawaited(SoundService.instance.quizResultByScore(correct: correctAnswersCount, total: questions.length));"
    )

    # Yanlış kutusu kaydı başarılıysa reward/notification hissi
    text = text.replace(
        "ScaffoldMessenger.of(context).clearSnackBars();",
        "unawaited(SoundService.instance.notification());\n"
        "      ScaffoldMessenger.of(context).clearSnackBars();"
    )

    return text

def patch_mini_or_trial(text: str) -> str:
    text = ensure_import(text, "import 'dart:async';")
    text = ensure_import(text, "import '../services/sound_service.dart';")
    text = ensure_import(text, "import '../services/reklam_servisi.dart';")

    # Yaygın cevap kontrol desenleri
    patterns = [
        "final bool isCorrect = index ==",
        "final isCorrect = index ==",
        "bool isCorrect = index ==",
        "final bool correct = index ==",
    ]

    for p in patterns:
        if p in text and "SoundService.instance.correct()" not in text:
            # satırın sonuna değil, sonraki ; sonrası eklemeye çalış
            text = re.sub(
                r"(final\s+bool\s+isCorrect\s*=\s*[^;]+;|final\s+isCorrect\s*=\s*[^;]+;|bool\s+isCorrect\s*=\s*[^;]+;)",
                r"\1\n    unawaited(isCorrect ? SoundService.instance.correct() : SoundService.instance.wrong());",
                text,
                count=1
            )
            break

    # finish / complete / showResult fonksiyonlarında bitiş sesi
    replacements = [
        ("void finishQuiz() async {", "void finishQuiz() async {\n    unawaited(SoundService.instance.quizComplete());"),
        ("void _finishQuiz() async {", "void _finishQuiz() async {\n    unawaited(SoundService.instance.quizComplete());"),
        ("Future<void> finishQuiz() async {", "Future<void> finishQuiz() async {\n    unawaited(SoundService.instance.quizComplete());"),
        ("Future<void> _finishQuiz() async {", "Future<void> _finishQuiz() async {\n    unawaited(SoundService.instance.quizComplete());"),
        ("void showResult() {", "void showResult() {\n    unawaited(SoundService.instance.quizComplete());"),
        ("void _showResult() {", "void _showResult() {\n    unawaited(SoundService.instance.quizComplete());"),
    ]

    for old, new in replacements:
        if old in text and new not in text:
            text = text.replace(old, new, 1)

    return text

def patch_multiplayer(text: str) -> str:
    text = ensure_import(text, "import 'dart:async';")
    text = ensure_import(text, "import '../services/sound_service.dart';")

    # Doğru/yanlış cevap
    if "final bool isCorrect" in text and "SoundService.instance.correct()" not in text:
        text = re.sub(
            r"(final\s+bool\s+isCorrect\s*=\s*[^;]+;)",
            r"\1\n    unawaited(isCorrect ? SoundService.instance.correct() : SoundService.instance.wrong());",
            text,
            count=1
        )

    # Kazanma/kaybetme kelimelerine göre basit ekleme önerisi
    if "SoundService.instance.victory()" not in text:
        text = text.replace(
            "winner",
            "winner"
        )
        # Otomatik kesin yer bilinmediğinde init/finish tarafına güvenli quizComplete ekler.
        for old in ["void _finish", "Future<void> _finish", "void finish", "Future<void> finish"]:
            idx = text.find(old)
            if idx != -1:
                brace = text.find("{", idx)
                if brace != -1:
                    text = text[:brace+1] + "\n    unawaited(SoundService.instance.quizComplete());" + text[brace+1:]
                    break

    return text

def patch_store_or_reward(text: str) -> str:
    text = ensure_import(text, "import 'dart:async';")
    text = ensure_import(text, "import '../services/sound_service.dart';")

    # Satın alma başarılı mesajlarından önce başarı sesi
    success_words = [
        "Satın alma başarılı",
        "satın alma başarılı",
        "Satın alma tamamlandı",
        "purchase successful",
    ]
    if "SoundService.instance.purchaseSuccess()" not in text:
        for word in success_words:
            if word in text:
                text = text.replace(word, word)
                # fonksiyon içinde güvenli olabilecek yerlere çok agresif girmiyoruz
                text = text.replace(
                    "ScaffoldMessenger.of(context).showSnackBar(",
                    "unawaited(SoundService.instance.purchaseSuccess());\n      ScaffoldMessenger.of(context).showSnackBar(",
                    1
                )
                break

    # Ödül/enerji kelimeleri olan sayfalarda reward sesi
    if "SoundService.instance.energyGain()" not in text and ("reklamIzlet" in text or "odullu" in text or "ödül" in text.lower()):
        text = text.replace(
            "if (rewarded) {",
            "if (rewarded) {\n      unawaited(SoundService.instance.energyGain());",
            1
        )

    return text

def patch_missions(text: str) -> str:
    text = ensure_import(text, "import 'dart:async';")
    text = ensure_import(text, "import '../services/sound_service.dart';")

    if "SoundService.instance.reward()" not in text:
        # görev ödülü alındı mesajı varsa önce reward sesi
        for marker in ["Ödül", "ödül", "Görev", "görev"]:
            if marker in text:
                text = text.replace(
                    "ScaffoldMessenger.of(context).showSnackBar(",
                    "unawaited(SoundService.instance.reward());\n      ScaffoldMessenger.of(context).showSnackBar(",
                    1
                )
                break

    return text

def patch_level_pages(text: str) -> str:
    text = ensure_import(text, "import 'dart:async';")
    text = ensure_import(text, "import '../services/sound_service.dart';")

    # Genel tıklama zaten global. Level/kilit açma için sadece bilinen kelimeler varsa notification/level sesi.
    if "SoundService.instance.levelUnlock()" not in text and ("unlock" in text.lower() or "kilit" in text.lower()):
        text = text.replace(
            "ScaffoldMessenger.of(context).showSnackBar(",
            "unawaited(SoundService.instance.levelUnlock());\n      ScaffoldMessenger.of(context).showSnackBar(",
            1
        )

    return text

def main():
    targets = [
        ("lib/screens/quiz_page.dart", patch_quiz_page),
        ("lib/screens/mini_exam_page.dart", patch_mini_or_trial),
        ("lib/screens/trial_quiz_page.dart", patch_mini_or_trial),
        ("lib/screens/multiplayer_quiz_page.dart", patch_multiplayer),
        ("lib/screens/store_page.dart", patch_store_or_reward),
        ("lib/screens/missions_sheet.dart", patch_missions),
        ("lib/screens/mission_service.dart", patch_missions),
        ("lib/screens/level_map_page.dart", patch_level_pages),
        ("lib/screens/subjects_page.dart", patch_level_pages),
        ("lib/screens/topics_page.dart", patch_level_pages),
    ]

    for rel, patcher in targets:
        patch_file(ROOT / rel, patcher)

    print("\nBitti. Şimdi çalıştır:")
    print("flutter clean")
    print("flutter pub get")
    print("flutter run")

if __name__ == "__main__":
    main()
