import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_page.dart';
import 'screens/splash_page.dart';
import 'screens/vip_test_screen.dart';
import 'services/notification_service.dart';
import 'services/sound_service.dart';
import 'widgets/global_tap_sound.dart';
import 'widgets/internet_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SoundService.instance.init();
  await NotificationService().initialize();
  await NotificationService().scheduleAll();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bilgi Rotası',
      theme: ThemeData(useMaterial3: true),
      builder: (context, child) {
        return GlobalTapSound(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: InternetGuard(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: const Color(0xFF0A0E43),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/logo.png', width: 180),
                      const SizedBox(height: 40),
                      const CircularProgressIndicator(
                        color: Color(0xFF00E5FF),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasData && snapshot.data != null) {
              return const HomePage();
            }

            return const SplashPage();
          },
        ),
      ),
      routes: {
        '/vip-test': (context) => const VipTestScreen(),
      },
    );
  }
}
