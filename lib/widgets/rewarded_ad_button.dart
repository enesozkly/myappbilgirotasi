import 'package:flutter/material.dart';

import '../services/reklam_servisi.dart';
import '../services/sound_service.dart';

/// Reklam izle / ödül kazan işlemini tek yerde güvenli çalıştırmak için yardımcı.
/// Kullanmak zorunda değilsin; mevcut butonda ReklamServisi.reklamIzletFuture() da kullanılabilir.
class RewardedAdButton extends StatefulWidget {
  const RewardedAdButton({
    super.key,
    required this.child,
    required this.onRewarded,
    this.loadingChild,
    this.uid,
  });

  final Widget child;
  final Widget? loadingChild;
  final String? uid;
  final Future<void> Function() onRewarded;

  @override
  State<RewardedAdButton> createState() => _RewardedAdButtonState();
}

class _RewardedAdButtonState extends State<RewardedAdButton> {
  bool _loading = false;

  Future<void> _watchAd() async {
    if (_loading) return;

    setState(() => _loading = true);

    final rewarded = await ReklamServisi.reklamIzletFuture(uid: widget.uid);

    if (!mounted) return;
    setState(() => _loading = false);

    if (rewarded) {
      await widget.onRewarded();
      await SoundService.instance.energyGain();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ödül kazandın!')),
      );
    } else {
      await SoundService.instance.wrong();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reklam şu an hazır değil. Biraz sonra tekrar dene.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _watchAd,
      child: _loading
          ? (widget.loadingChild ??
              const Center(child: CircularProgressIndicator()))
          : widget.child,
    );
  }
}
