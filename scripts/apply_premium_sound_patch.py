#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]

def backup(p: Path):
    if not p.exists():
        return
    bak = p.with_suffix(p.suffix + ".bak_sound")
    if not bak.exists():
        shutil.copy2(p, bak)

def read(p): return p.read_text(encoding="utf-8")
def write(p, s): p.write_text(s, encoding="utf-8")

def ensure_import(text, line):
    if line in text:
        return text
    lines = text.splitlines()
    idx = -1
    for i, l in enumerate(lines):
        if l.strip().startswith("import "):
            idx = i
    if idx >= 0:
        lines.insert(idx + 1, line)
        return "\n".join(lines) + ("\n" if text.endswith("\n") else "")
    return line + "\n" + text

def add_sound_imports(text):
    text = ensure_import(text, "import 'dart:async';")
    text = ensure_import(text, "import '../services/sound_service.dart';")
    return text

def patch_answer_sounds(text):
    if "SoundService.instance.correct()" in text and "SoundService.instance.wrong()" in text:
        return text

    patterns = [
        r"(final\s+bool\s+isCorrect\s*=\s*[^;]+;)",
        r"(final\s+isCorrect\s*=\s*[^;]+;)",
        r"(bool\s+isCorrect\s*=\s*[^;]+;)",
        r"(var\s+isCorrect\s*=\s*[^;]+;)",
    ]

    for pat in patterns:
        m = re.search(pat, text)
        if m:
            insert = (
                m.group(1)
                + "\n    unawaited(isCorrect ? SoundService.instance.correct() : SoundService.instance.wrong());"
            )
            return text[:m.start()] + insert + text[m.end():]

    return text

def patch_finish_sounds(text):
    if "quizResultByScore" in text or "SoundService.instance.quizComplete()" in text:
        return text

    score_exprs = [
        ("correctAnswersCount", "questions.length"),
        ("correctAnswers", "questions.length"),
        ("dogruSayisi", "questions.length"),
        ("score", "questions.length"),
    ]

    finish_patterns = [
        r"(void\s+finishQuiz\s*\(\)\s*async\s*\{)",
        r"(Future<void>\s+finishQuiz\s*\(\)\s*async\s*\{)",
        r"(void\s+_finishQuiz\s*\(\)\s*async\s*\{)",
        r"(Future<void>\s+_finishQuiz\s*\(\)\s*async\s*\{)",
        r"(void\s+showResult\s*\(\)\s*\{)",
        r"(void\s+_showResult\s*\(\)\s*\{)",
        r"(void\s+_finishExam\s*\(\)\s*async\s*\{)",
        r"(Future<void>\s+_finishExam\s*\(\)\s*async\s*\{)",
    ]

    for pat in finish_patterns:
        m = re.search(pat, text)
        if m:
            correct = None
            total = None
            for c, t in score_exprs:
                if c in text:
                    correct, total = c, t
                    break

            if correct:
                sound_line = f"\n    unawaited(SoundService.instance.quizResultByScore(correct: {correct}, total: {total}));"
            else:
                sound_line = "\n    unawaited(SoundService.instance.quizComplete());"

            return text[:m.end()] + sound_line + text[m.end():]

    return text

def patch_reward_sounds(text):
    if "SoundService.instance.energyGain()" in text:
        return text

    text = re.sub(
        r"(if\s*\(\s*rewarded\s*\)\s*\{)",
        r"\1\n      unawaited(SoundService.instance.energyGain());",
        text,
        count=1,
    )
    return text

def patch_purchase_sounds(text):
    if "SoundService.instance.purchaseSuccess()" in text:
        return text

    low = text.lower()
    if any(k in low for k in ["purchase", "satın", "vip", "premium", "başarılı"]):
        text = re.sub(
            r"(ScaffoldMessenger\.of\(context\)\.showSnackBar\s*\()",
            r"unawaited(SoundService.instance.purchaseSuccess());\n      \1",
            text,
            count=1,
        )
    return text

def process(rel, funcs):
    p = ROOT / rel
    if not p.exists():
        print(f"YOK: {rel}")
        return
    original = read(p)
    text = original
    backup(p)

    text = add_sound_imports(text)
    for f in funcs:
        text = f(text)

    if text != original:
        write(p, text)
        print(f"OK: {rel}")
    else:
        print(f"DEĞİŞMEDİ: {rel}")

def main():
    for rel in [
        "lib/screens/quiz_page.dart",
        "lib/screens/mini_exam_page.dart",
        "lib/screens/trial_quiz_page.dart",
        "lib/screens/multiplayer_quiz_page.dart",
    ]:
        process(rel, [patch_answer_sounds, patch_finish_sounds, patch_reward_sounds])

    for rel in [
        "lib/screens/store_page.dart",
        "lib/screens/vip_test_screen.dart",
        "lib/screens/home_page.dart",
        "lib/screens/missions_sheet.dart",
        "lib/screens/mission_service.dart",
        "lib/screens/level_map_page.dart",
    ]:
        process(rel, [patch_reward_sounds, patch_purchase_sounds])

    print("\nBitti.")
    print("Sonra: flutter clean && flutter pub get && flutter run")

if __name__ == "__main__":
    main()
