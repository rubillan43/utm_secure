import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'notification_service.dart';

/// Global navigator key — allows NotificationService to navigate
/// from outside the widget tree when a notification is tapped.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background message handler before runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialise FCM token storage + foreground notification display
  await NotificationService.initialize();

  runApp(const UTMsecureApp());
}

class UTMsecureApp extends StatelessWidget {
  const UTMsecureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UTM Secure',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primaryColor: const Color(0xFF800000),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF800000)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}