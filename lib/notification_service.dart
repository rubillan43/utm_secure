import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_page.dart';
import 'main.dart' show navigatorKey;

// ── Must be a top-level function (not a class method) ────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by the time this runs.
  // flutter_local_notifications cannot be used here on Android;
  // FCM displays the notification automatically via the system tray.
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService
// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  NotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'match_notifications';
  static const _channelName = 'Match Notifications';
  static const _channelDesc =
      'Push notifications when a match is found for your lost or found item report.';

  // ── Call once from main() after Firebase.initializeApp() ─────────────────
  static Future<void> initialize() async {
    // 1. Request permission (iOS + Android 13+)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Initialise flutter_local_notifications (for foreground messages)
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );

    // 3. Create the Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
            playSound: true,
          ),
        );

    // 4. Foreground message handler — show a local notification
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // 4b. App in background — user tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final matchId = message.data['matchId'] as String?;
      if (matchId != null) _handleNotificationTap(matchId);
    });

    // 4c. App was terminated — check if launched via notification tap
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      final matchId = initial.data['matchId'] as String?;
      if (matchId != null) {
        // Delay to let the widget tree mount before navigating
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationTap(matchId);
        });
      }
    }

    // 5. Save/refresh FCM token whenever auth state changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _saveToken(user.uid);
    });

    // 6. Keep token fresh on rotation
    _messaging.onTokenRefresh.listen((token) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        FirebaseFirestore.instance
            .collection('Users')
            .doc(uid)
            .update({'fcmToken': token});
      }
    });
  }

  // ── Navigate to the correct ChatPage when a notification is tapped ───────
  static Future<void> _handleNotificationTap(String matchId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final matchDoc = await FirebaseFirestore.instance
        .collection('Matches')
        .doc(matchId)
        .get();
    if (!matchDoc.exists) return;

    final matchData = matchDoc.data()!;
    final chatId = matchData['chatId'] as String?;
    if (chatId == null) return;

    final chatDoc = await FirebaseFirestore.instance.collection('Chats').doc(chatId).get();
    final myRole = (chatDoc.data()?['roles'] as Map<String, dynamic>?)?[uid] as String? ?? 'finder';

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          chatId: chatId,
          matchId: matchId,
          myRole: myRole,
        ),
      ),
    );
  }

  // ── Store the device FCM token in the user's Firestore document ──────────
  static Future<void> _saveToken(String uid) async {
    final token = await _messaging.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .update({'fcmToken': token});
  }

  // ── Show a heads-up notification while the app is in the foreground ───────
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;

    await _localNotifications.show(
      n.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
