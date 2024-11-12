import 'package:flutter/material.dart';

class TButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color? backgroundColor;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final double? height;

  const TButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height ?? 40,
      child: MaterialButton(
        onPressed: isLoading ? null : onPressed,
        elevation: 0,
        hoverElevation: 0,
        focusElevation: 0,
        highlightElevation: 0,
        color: isOutlined ? null : (backgroundColor ?? Theme.of(context).colorScheme.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: isOutlined ? BorderSide(
            color: Theme.of(context).colorScheme.primary,
          ) : BorderSide.none,
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOutlined
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              )
            : DefaultTextStyle(
                style: TextStyle(
                  color: isOutlined
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                child: child,
              ),
      ),
    );
  }
} 