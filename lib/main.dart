import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/auth_wrapper.dart';
import 'onboarding.dart';
import 'LoginPages/login_page.dart';
import 'SignUpPages/signuppage.dart';
import 'main_page.dart';
import 'app_text_styles.dart';
import 'splash_screen.dart'; // Add this import
import 'package:capstone_project/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "FitCheck App",
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        fontFamily: "Sen",
      ),
      home: SplashScreen(
        nextPage: const AuthWrapper(),
      ),
      routes: {
        '/auth': (context) => const AuthWrapper(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/main': (context) => const MainPageWrapper(),
      },
    );
  }
}