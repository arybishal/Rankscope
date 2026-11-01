import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../logging/app_logger.dart';

/// Service managing device local notifications using flutter_local_notifications.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initializes the local notification plugin and default notification channel.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          // Handled via navigation if payload provided
        },
      );

      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImplementation != null) {
        try {
          await androidImplementation.requestNotificationsPermission();
        } catch (_) {}

        const channel = AndroidNotificationChannel(
          'rankscope_alerts',
          'Ranking Alerts & Intelligence',
          description:
              'Notifications for significant ranking movements, URL changes, and cannibalization',
          importance: Importance.high,
        );
        await androidImplementation.createNotificationChannel(channel);
      }

      _isInitialized = true;
    } catch (e) {
      await AppLogger.instance.warning(
        'Notifications',
        'init_failed',
        'Could not initialize local notifications: $e',
      );
    }
  }

  /// Displays an alert notification on the device.
  Future<void> showAlertNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      const androidDetails = AndroidNotificationDetails(
        'rankscope_alerts',
        'Ranking Alerts & Intelligence',
        channelDescription:
            'Notifications for significant ranking movements, URL changes, and cannibalization',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const details = NotificationDetails(android: androidDetails);

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      await AppLogger.instance.warning(
        'Notifications',
        'display_failed',
        'Failed to display local notification: $e',
      );
    }
  }

  /// Cancels all active notifications.
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
