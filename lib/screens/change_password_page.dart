import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_oldPasswordController.text.isEmpty || 
        _newPasswordController.text.isEmpty || 
        _confirmPasswordController.text.isEmpty) {
      _showSnackbar("Lütfen tüm alanları doldur.", Colors.orange);
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackbar("Yeni şifreler uyuşmuyor!", Colors.redAccent);
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showSnackbar("Yeni şifre en az 6 karakter olmalı.", Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user = _auth.currentUser;
      if (user != null && user.email != null) {
        // 1. Eski şifre ile yeniden kimlik doğrulama yap (Güvenlik için şart)
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _oldPasswordController.text.trim(),
        );

        await user.reauthenticateWithCredential(credential);

        // 2. Yeni şifreyi güncelle
        await user.updatePassword(_newPasswordController.text.trim());

        if (!mounted) return;
        _showSnackbar("Şifren başarıyla güncellendi! 🎉", const Color(0xFF00E676));
        
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          Navigator.pop(context);
        });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = "Bir hata oluştu.";
      if (e.code == 'wrong-password') {
        msg = "Eski şifren hatalı.";
      } else if (e.code == 'weak-password') {
        msg = "Şifre çok zayıf.";
      } else if (e.code == 'requires-recent-login') {
        msg = "Güvenlik için tekrar giriş yapmalısın.";
      }
      
      _showSnackbar(msg, Colors.redAccent);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar("Hata: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Klavye açılınca ekranı sıkıştır
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E43), Color(0xFF1B1F6A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Geri Butonu
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_reset_rounded, size: 60, color: Color(0xFF00E5FF)),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Center(
                  child: Text(
                    "Şifreni Yenile",
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                
                const SizedBox(height: 40),

                _buildLabel("Mevcut Şifren"),
                _buildPasswordField(_oldPasswordController, "Eski şifreni gir"),
                
                const SizedBox(height: 20),
                
                _buildLabel("Yeni Şifren"),
                _buildPasswordField(_newPasswordController, "Yeni güçlü şifreni gir"),
                
                const SizedBox(height: 20),
                
                _buildLabel("Yeni Şifre Tekrar"),
                _buildPasswordField(_confirmPasswordController, "Yeni şifreni onayla"),

                const SizedBox(height: 40),

                // Kaydet Butonu
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 10,
                      shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                    ),
                    onPressed: _isLoading ? null : _changePassword,
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(
                          "GÜNCELLE", 
                          style: GoogleFonts.poppins(color: const Color(0xFF0A0E43), fontSize: 18, fontWeight: FontWeight.bold)
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 5),
      child: Text(text, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: controller,
        obscureText: true,
        style: GoogleFonts.poppins(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.white30),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          suffixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 20),
        ),
      ),
    );
  }
}