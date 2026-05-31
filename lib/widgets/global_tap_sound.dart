import 'package:flutter/material.dart';

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
      onPointerDown: (_) {
        SoundService.instance.click();
      },
      child: child,
    );
  }
}
