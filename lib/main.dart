import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:capstone_project/services/notification_service.dart';
import 'firebase_options.dart';
import 'widgets/auth_wrapper.dart';
import 'onboarding.dart';
import 'LoginPages/login_page.dart';
import 'SignUpPages/signuppage.dart';
import 'main_page.dart';
import 'splash_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Notification Service
  // This must be done before runApp()  to ensure notifications work
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Schedule daily meal reminders
  // This will automatically set up notifications for Breakfast, Lunch, Snack, and Dinner
  await notificationService.scheduleDailyMealReminders();

  // Debug: Print pending notifications (optional - remove in production)
  await notificationService.debugPrintPendingNotifications();

  // Run your app
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Add observer to detect app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove observer when app is disposed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app comes back to foreground, reschedule notifications
    // This ensures notifications work after device reboot or app restart
    if (state == AppLifecycleState.resumed) {
      NotificationService().rescheduleOnReboot();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "FitCheck App",
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        fontFamily: "Sen",
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
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