import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'firebase_options.dart';
import 'screens/splash_page.dart';
import 'screens/home_page.dart';
import 'screens/vip_test_screen.dart';
import 'services/notification_service.dart';
import 'widgets/internet_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await MobileAds.instance.initialize();
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