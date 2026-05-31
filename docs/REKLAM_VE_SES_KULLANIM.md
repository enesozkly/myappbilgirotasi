# Reklam ve Ses Kullanımı

## 4 bölümde 1 geçiş reklamı

Test/bölüm/deneme bitince:

```dart
ReklamServisi.bolumTamamlandi(_isVip);
```

## Ödüllü reklam / reklam izle puan kazan

```dart
final rewarded = await ReklamServisi.reklamIzletFuture(
  uid: FirebaseAuth.instance.currentUser?.uid,
);

if (rewarded) {
  // puan/enerji ekle
  await SoundService.instance.energyGain();
}
```

## Sesler

```dart
await SoundService.instance.click();
await SoundService.instance.correct();
await SoundService.instance.wrong();
await SoundService.instance.quizComplete();
await SoundService.instance.victory();
await SoundService.instance.defeat();
await SoundService.instance.energyGain();
```

## ID'ler

Android App ID:
ca-app-pub-9545517913490977~1278583376

Android geçiş:
ca-app-pub-9545517913490977/4585449163

Android ödüllü:
ca-app-pub-9545517913490977/6534779489

iOS App ID:
ca-app-pub-9545517913490977~9579742624

iOS geçiş:
ca-app-pub-9545517913490977/4766399641

iOS ödüllü:
ca-app-pub-9545517913490977/9412221662
