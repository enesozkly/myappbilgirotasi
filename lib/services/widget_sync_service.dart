import 'package:home_widget/home_widget.dart';
import '../models/user_model.dart';

class WidgetSyncService {
  static const String androidWidgetName = 'BilgiRotasiWidgetProvider';

  static String _dailyMotivation() {
    const list = [
      'Bugün küçük bir adım, sınavda büyük fark yaratır.',
      'Rakiplerin dinlenirken sen bir soru daha çöz.',
      'Disiplin motivasyondan daha kalıcıdır.',
      'Her doğru, hedefine biraz daha yaklaştırır.',
      'Bugünün dersi: erteleme, başla.',
    ];
    return list[DateTime.now().day % list.length];
  }

  static int _daysUntil(DateTime target) {
    final now = DateTime.now();
    return target.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  static Future<void> updateUserWidget(UserModel user) async {
    final int yksDays = _daysUntil(DateTime(2026, 6, 20));
    final int kpssDays = _daysUntil(DateTime(2026, 9, 6));

    await HomeWidget.saveWidgetData<String>('br_name', user.name);
    await HomeWidget.saveWidgetData<int>('br_energy', user.energy);
    await HomeWidget.saveWidgetData<int>('br_maxEnergy', user.maxEnergy);
    await HomeWidget.saveWidgetData<int>('br_bonusEnergy', user.bonusEnergy);
    await HomeWidget.saveWidgetData<int>('br_totalXp', user.totalXp);
    await HomeWidget.saveWidgetData<String>('br_league', user.league);
    await HomeWidget.saveWidgetData<int>('br_streak', user.loginStreak);
    await HomeWidget.saveWidgetData<String>('br_motivation', _dailyMotivation());
    await HomeWidget.saveWidgetData<String>('br_streakText', '${user.loginStreak} gündür bizimlesin 🔥');
    await HomeWidget.saveWidgetData<String>('br_todayAction', 'Bugün mini denemeni çözdün mü?');
    await HomeWidget.saveWidgetData<int>('br_yksDays', yksDays);
    await HomeWidget.saveWidgetData<int>('br_kpssDays', kpssDays);

    await HomeWidget.updateWidget(
      androidName: androidWidgetName,
      qualifiedAndroidName: androidWidgetName,
    );
  }

  static Future<void> clearWidget() async {
    await HomeWidget.saveWidgetData<String>('br_name', 'Bilgi Rotası');
    await HomeWidget.saveWidgetData<int>('br_energy', 0);
    await HomeWidget.saveWidgetData<int>('br_maxEnergy', 50);
    await HomeWidget.saveWidgetData<int>('br_bonusEnergy', 0);
    await HomeWidget.saveWidgetData<int>('br_totalXp', 0);
    await HomeWidget.saveWidgetData<String>('br_league', 'Bronz');
    await HomeWidget.saveWidgetData<int>('br_streak', 0);
    await HomeWidget.saveWidgetData<String>('br_motivation', _dailyMotivation());
    await HomeWidget.saveWidgetData<String>('br_streakText', 'Serini bugün başlat!');
    await HomeWidget.saveWidgetData<String>('br_todayAction', 'Mini deneme seni bekliyor.');
    await HomeWidget.saveWidgetData<int>('br_yksDays', 0);
    await HomeWidget.saveWidgetData<int>('br_kpssDays', 0);

    await HomeWidget.updateWidget(
      androidName: androidWidgetName,
      qualifiedAndroidName: androidWidgetName,
    );
  }
}