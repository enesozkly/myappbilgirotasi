import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../services/sound_service.dart';

class GlobalTapSound extends StatelessWidget {
  const GlobalTapSound({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent event) {
        if (_isRealTapTarget(event)) {
          SoundService.instance.click();
        }
      },
      child: child,
    );
  }

  /// Ekranın tamamını dinler ama yalnızca semantik olarak gerçek bir
  /// onTap aksiyonu olan öğelerde ses üretir. Böylece boş alan, arka plan,
  /// kaydırma başlangıcı veya yalnızca metin olan bölümler sessiz kalır.
  bool _isRealTapTarget(PointerDownEvent event) {
    final HitTestResult result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      event.position,
      event.viewId,
    );

    // Metin alanına odaklanmak bir buton tıklaması değildir. Önce tüm hedef
    // zincirini kontrol etmek, üst sarmalayıcının onTap eylemini yanlışlıkla
    // buton kabul etmemizi engeller.
    final bool isTextInput = result.path.any((HitTestEntry entry) {
      final String renderType =
          entry.target.runtimeType.toString().toLowerCase();
      return renderType.contains('editable') ||
          renderType.contains('textfield');
    });
    if (isTextInput) return false;

    for (final HitTestEntry entry in result.path) {
      final HitTestTarget target = entry.target;
      if (target is! RenderObject) continue;

      final SemanticsConfiguration configuration = SemanticsConfiguration();
      // Render ağacının dokunma semantiğini yalnızca bu anlık hit-test için
      // okuyoruz; yapılandırma saklanmaz veya değiştirilmez.
      // ignore: invalid_use_of_protected_member
      target.describeSemanticsConfiguration(configuration);
      if (configuration.onTap != null) return true;
    }

    return false;
  }
}
