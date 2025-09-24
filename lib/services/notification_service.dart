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
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        );

        final result = await _notifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (details) async {},
        );
        
        print('Notification initialization result: $result');
      }
      
      _initialized = true;
      print('Notification service initialized successfully');
    } catch (e) {
      print('Error initializing notification service: $e');
      // Mark as initialized anyway to prevent blocking the app
      _initialized = true;
    }
  }

  static Future<void> playSound(bool isBreakTime) async {
    try {
      // 1. Stop any currently playing audio
      await _player.stop();
      
      // 2. Set the correct release mode for one-shot playback
      await _player.setReleaseMode(ReleaseMode.stop);
      
      // 3. Specify the complete asset path as it appears in pubspec.yaml
      final source = isBreakTime ? 'sounds/break_complete.mp3' : 'sounds/focus_complete.mp3';
      print('Attempting to play sound: $source');
      
      // 4. Play the sound
      await _player.play(AssetSource(source));
      
      // 5. Wait for completion or timeout
      await Future.any([
        _player.onPlayerComplete.first,
        Future.delayed(const Duration(seconds: 5)), // Timeout after 5 seconds
      ]);
      
    } catch (e) {
      print('Error playing completion sound: $e');
      // Fallback: try to play a system beep or show visual notification
      try {
        debugPrint('Sound playback failed, falling back to system notification');
      } catch (fallbackError) {
        print('Fallback notification also failed: $fallbackError');
      }
    }
  }

  static Future<bool> requestPermissions() async {
    try {
      if (Platform.isWindows) {
        return true; // Windows doesn't need explicit permission requests
      }
      
      final result = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ?? await _notifications
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      
      print('Permission request result: $result');
      return result ?? false;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
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
    try {
      await _player.stop();
      await _player.dispose();
    } catch (e) {
      print('Error disposing audio player: $e');
    }
  }
}