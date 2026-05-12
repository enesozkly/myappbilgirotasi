import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BRDialogs {
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.info_rounded,
    Color accent = const Color(0xFF00E5FF),
    String buttonText = 'Tamam',
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _BrDialogShell(
        title: title,
        message: message,
        icon: icon,
        accent: accent,
        actions: [
          _primaryButton(
            text: buttonText,
            accent: accent,
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  static Future<bool> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.help_rounded,
    Color accent = const Color(0xFF00E5FF),
    String cancelText = 'Vazgeç',
    String confirmText = 'Onayla',
    Color? confirmColor,
  }) async {
    if (!context.mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _BrDialogShell(
        title: title,
        message: message,
        icon: icon,
        accent: accent,
        actions: [
          _secondaryButton(
            text: cancelText,
            onTap: () => Navigator.pop(ctx, false),
          ),
          const SizedBox(width: 10),
          _primaryButton(
            text: confirmText,
            accent: confirmColor ?? accent,
            onTap: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    return result == true;
  }

  static Future<bool> showEnergyConfirm(
    BuildContext context, {
    required String title,
    required String message,
    required int amount,
  }) {
    return showConfirm(
      context,
      title: title,
      message: message,
      icon: Icons.flash_on_rounded,
      accent: const Color(0xFFFFD600),
      cancelText: 'Vazgeç',
      confirmText: '$amount Enerji Kullan',
      confirmColor: const Color(0xFFFF9100),
    );
  }

  static Future<bool> showExitConfirm(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showConfirm(
      context,
      title: title,
      message: message,
      icon: Icons.logout_rounded,
      accent: Colors.redAccent,
      cancelText: 'Devam Et',
      confirmText: 'Çık',
      confirmColor: Colors.redAccent,
    );
  }

  static Widget _primaryButton({
    required String text,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.75)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _secondaryButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrDialogShell extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color accent;
  final List<Widget> actions;

  const _BrDialogShell({
    required this.title,
    required this.message,
    required this.icon,
    required this.accent,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10165A), Color(0xFF0A0E43), Color(0xFF1B1F6A)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: accent.withValues(alpha: 0.42), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withValues(alpha: 0.92), accent.withValues(alpha: 0.45)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 22),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 38),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 13,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 22),
            Row(children: actions),
          ],
        ),
      ),
    );
  }
}
