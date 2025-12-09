// lib/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Initialize
  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    }

    // Get FCM token
    String? token = await _messaging.getToken();
    debugPrint('FCM Token: $token');

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
  }

  // Save FCM token to Firestore
  Future<void> saveFCMToken(String userId, String userRole) async {
    String? token = await _messaging.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmToken': token,
      });
    }
  }

  // Handle foreground message
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');
  }

  // Handle background message
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('Background message: ${message.notification?.title}');
  }

  // Send notification via Cloud Function (you'll implement this in Cloud Functions)
  // This is just the client-side setup
  Future<void> sendOrderNotification({
    required String recipientId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    // This would trigger a Cloud Function
    // For now, we'll create a notification document that a Cloud Function watches
    await FirebaseFirestore.instance.collection('notifications').add({
      'recipientId': recipientId,
      'title': title,
      'body': body,
      'data': data ?? {},
      'createdAt': FieldValue.serverTimestamp(),
      'sent': false,
    });
  }
}