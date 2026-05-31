# Manuel Ekleme Örnekleri

Otomatik script bir dosyada beklenen bloğu bulamazsa şu şekilde manuel ekle.

## Import

```dart
import 'dart:async';
import '../services/sound_service.dart';
```

## Doğru / Yanlış cevap

```dart
final bool isCorrect = index == correctIndex;
unawaited(isCorrect ? SoundService.instance.correct() : SoundService.instance.wrong());
```

## Test bitiş

```dart
unawaited(SoundService.instance.quizResultByScore(
  correct: correctAnswersCount,
  total: questions.length,
));
```

## Arkadaşınla oyna

Kazanan:

```dart
unawaited(SoundService.instance.victory());
```

Kaybeden:

```dart
unawaited(SoundService.instance.defeat());
```

## Reklam izle ödül kazan

```dart
final rewarded = await ReklamServisi.reklamIzletFuture(
  uid: FirebaseAuth.instance.currentUser?.uid,
);

if (rewarded) {
  unawaited(SoundService.instance.energyGain());
  // puan / enerji ekle
} else {
  unawaited(SoundService.instance.wrong());
}
```

## Görev ödülü

```dart
unawaited(SoundService.instance.reward());
```

## Satın alma başarılı

```dart
unawaited(SoundService.instance.purchaseSuccess());
```
