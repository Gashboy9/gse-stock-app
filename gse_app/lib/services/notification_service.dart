// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static const String baseUrl = 'https://gse-stock-api.YOUR-SUBDOMAIN.workers.dev';

  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Notification permission granted');
    }

    // Get FCM token and send to backend
    String? token = await _messaging.getToken();
    if (token != null) {
      print('FCM Token: $token');
      await _sendTokenToBackend(token);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _sendTokenToBackend(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notification: ${message.notification?.title}');
    });
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/users/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': 1, // TODO: use real user ID after auth
          'fcm_token': token,
        }),
      );
    } catch (e) {
      print('Failed to send FCM token: $e');
    }
  }

  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}