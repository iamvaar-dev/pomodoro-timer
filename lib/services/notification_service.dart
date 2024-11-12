import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:windows_notification/windows_notification.dart';
import 'package:windows_notification/notification_message.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static final WindowsNotification winNotifyPlugin = WindowsNotification(
    applicationId: "FocusForge.App"
  );
  static bool _initialized = false;
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Pre-load both sounds
      await _player.setReleaseMode(ReleaseMode.release);
      
      if (Platform.isWindows) {
        winNotifyPlugin.initNotificationCallBack((message) {});
      } else {
        const initializationSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
        );

        await _notifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (details) async {},
        );
      }
      
      _initialized = true;
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  static Future<void> playSound(bool isBreakTime) async {
    try {
      // 1. Release any previous audio resources
      await _player.stop();
      await _player.release();
      
      // 2. Set the correct release mode for one-shot playback
      await _player.setReleaseMode(ReleaseMode.stop);
      
      // 3. Specify the complete asset path as it appears in pubspec.yaml
      final source = !isBreakTime ? 'sounds/break_complete.mp3' : 'sounds/focus_complete.mp3';
      print('Attempting to play sound: $source');
      
      // 4. Create a new source and play
      await _player.play(AssetSource(source));
      
      // 5. Add a small delay to ensure sound completes
      await Future.delayed(const Duration(seconds: 3));
    } catch (e) {
      print('Error playing completion sound: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  static Future<void> showNotification(String title, String body, {bool isBreakTime = false}) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      if (Platform.isWindows) {
        try {
          final message = NotificationMessage.fromPluginTemplate(
            "focus_forge_${DateTime.now().millisecondsSinceEpoch}",
            title,
            body,
          );
          
          await winNotifyPlugin.showNotificationPluginTemplate(message);
        } catch (e) {
          print('Error showing Windows notification: $e');
        }
      } else {
        const notificationDetails = NotificationDetails(
          android: AndroidNotificationDetails(
            'focus_forge',
            'Focus Forge',
            importance: Importance.max,
            priority: Priority.high,
          ),
        );
        
        await _notifications.show(
          0,
          title,
          body,
          notificationDetails,
        );
      }
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  static Future<void> dispose() async {
    // Dispose of any resources used by the notification service
  }
} 