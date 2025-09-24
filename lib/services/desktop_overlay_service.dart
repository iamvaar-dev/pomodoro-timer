import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

class DesktopOverlayService {
  static final SystemTray _systemTray = SystemTray();
  static bool _isInitialized = false;
  static OverlayEntry? _overlayEntry;
  static bool _isOverlayVisible = false;

  /// Initialize desktop overlay functionality
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (Platform.isMacOS) {
        await _initializeMacOSSystemTray();
      } else if (Platform.isWindows) {
        await _initializeWindowsOverlay();
      }
      _isInitialized = true;
    } catch (e) {
      print('Error initializing desktop overlay: $e');
    }
  }

  /// Initialize macOS system tray
  static Future<void> _initializeMacOSSystemTray() async {
    try {
      await _systemTray.initSystemTray(
        title: "FocusForge",
        iconPath: 'assets/logo.png',
      );

      // Register system tray event
      _systemTray.registerSystemTrayEventHandler((eventName) {
        debugPrint("eventName: $eventName");
        if (eventName == 'leftMouseDown') {
          _showMainWindow();
        }
      });
    } catch (e) {
      print('Error initializing macOS system tray: $e');
    }
  }

  /// Initialize Windows overlay
  static Future<void> _initializeWindowsOverlay() async {
    try {
      // For Windows, we'll create a system tray as well
      await _initializeMacOSSystemTray();
    } catch (e) {
      print('Error initializing Windows overlay: $e');
    }
  }

  /// Show floating overlay window for Windows
  static Future<void> showWindowsOverlay(BuildContext context, String timerText, bool isRunning) async {
    if (!Platform.isWindows) return;

    try {
      // Hide existing overlay if visible
      if (_isOverlayVisible) {
        hideWindowsOverlay();
      }

      final overlay = Overlay.of(context);
      _overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: 50,
          right: 50,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surface,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRunning ? Icons.timer : Icons.timer_off,
                    color: isRunning 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).colorScheme.outline,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timerText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isRunning 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => hideWindowsOverlay(),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      overlay.insert(_overlayEntry!);
      _isOverlayVisible = true;
    } catch (e) {
      print('Error showing Windows overlay: $e');
    }
  }

  /// Hide Windows overlay
  static void hideWindowsOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isOverlayVisible = false;
    }
  }

  /// Update system tray with timer status
  static Future<void> updateSystemTray(String timerText, bool isRunning) async {
    if (!_isInitialized) return;

    try {
      final status = isRunning ? "Running" : "Paused";
      await _systemTray.setTitle("FocusForge - $timerText ($status)");
    } catch (e) {
      print('Error updating system tray: $e');
    }
  }

  /// Show main window
  static void _showMainWindow() {
    try {
      appWindow.show();
    } catch (e) {
      print('Error showing main window: $e');
    }
  }

  /// Start timer (placeholder - should be connected to actual timer service)
  static void _startTimer() {
    // This should be connected to the actual timer service
    print('Start timer requested from system tray');
  }

  /// Pause timer (placeholder - should be connected to actual timer service)
  static void _pauseTimer() {
    // This should be connected to the actual timer service
    print('Pause timer requested from system tray');
  }

  /// Reset timer (placeholder - should be connected to actual timer service)
  static void _resetTimer() {
    // This should be connected to the actual timer service
    print('Reset timer requested from system tray');
  }

  /// Quit application
  static void _quitApp() {
    try {
      appWindow.close();
    } catch (e) {
      print('Error quitting app: $e');
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      hideWindowsOverlay();
      await _systemTray.destroy();
      _isInitialized = false;
    } catch (e) {
      print('Error disposing desktop overlay service: $e');
    }
  }
}