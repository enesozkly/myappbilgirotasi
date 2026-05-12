import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InternetGuard extends StatefulWidget {
  final Widget child;

  const InternetGuard({
    super.key,
    required this.child,
  });

  @override
  State<InternetGuard> createState() => _InternetGuardState();
}

class _InternetGuardState extends State<InternetGuard> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      _updateConnection(results);
    });
  }

  Future<void> _checkInitialConnection() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnection(results);
  }

  void _updateConnection(List<ConnectivityResult> results) {
    final bool offline =
        results.isEmpty || results.every((e) => e == ConnectivityResult.none);

    if (!mounted) return;

    if (_isOffline != offline) {
      setState(() {
        _isOffline = offline;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        if (_isOffline)
          Positioned.fill(
            child: Material(
              color: const Color(0xFF06092B),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10164F),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFFFF5252).withValues(alpha: 0.55),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5252).withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Icon(
                              Icons.wifi_off_rounded,
                              color: Color(0xFFFF5252),
                              size: 42,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'İnternet bağlantısı yok',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Bilgi Rotası internetsiz kullanılamaz. Devam etmek için lütfen internet bağlantınızı açın.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00E5FF),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Bağlantı bekleniyor...',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF00E5FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
