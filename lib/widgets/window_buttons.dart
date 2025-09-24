import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  bool _isDesktop() {
    return defaultTargetPlatform == TargetPlatform.windows ||
           defaultTargetPlatform == TargetPlatform.linux ||
           defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop()) {
      return const SizedBox.shrink();
    }

    final buttonColors = WindowButtonColors(
      iconNormal: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
      mouseOver: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      mouseDown: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      iconMouseOver: Theme.of(context).colorScheme.primary,
    );

    final closeButtonColors = WindowButtonColors(
      iconNormal: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
      mouseOver: Colors.red.withOpacity(0.1),
      mouseDown: Colors.red.withOpacity(0.2),
      iconMouseOver: Colors.red,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(colors: closeButtonColors),
      ],
    );
  }
}