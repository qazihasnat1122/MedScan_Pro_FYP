// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

class NeumorphicBox extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final bool isPressed;
  final Color? color;
  final double depth;
  final BoxShape shape;

  const NeumorphicBox({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 20,
    this.isPressed = false,
    this.color,
    this.depth = 6.0,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Background base color
    final baseColor =
        color ?? (isDark ? const Color(0xFF1E2638) : const Color(0xFFE8EEF5));

    // Highlights & Shadows
    final shadowDark = isDark
        ? Colors.black.withOpacity(0.55)
        : const Color(0xFFA6B8CE).withOpacity(0.65);
    final shadowLight = isDark
        ? const Color(0xFF2E384D).withOpacity(0.6)
        : Colors.white.withOpacity(0.9);

    final distance = depth;

    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(borderRadius),
        boxShadow: isPressed
            ? [
                BoxShadow(
                  color: shadowDark.withOpacity(0.3),
                  offset: Offset(distance * 0.5, distance * 0.5),
                  blurRadius: distance,
                ),
                BoxShadow(
                  color: shadowLight.withOpacity(0.4),
                  offset: Offset(-distance * 0.5, -distance * 0.5),
                  blurRadius: distance,
                ),
              ]
            : [
                BoxShadow(
                  color: shadowDark,
                  offset: Offset(distance, distance),
                  blurRadius: distance * 2.2,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: shadowLight,
                  offset: Offset(-distance, -distance),
                  blurRadius: distance * 2.2,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: child,
    );
  }
}

class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double depth;

  const NeumorphicButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.color,
    this.depth = 5.0,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) {
        setState(() => _isDown = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _isDown = false),
      child: AnimatedScale(
        scale: _isDown ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: NeumorphicBox(
          isPressed: _isDown,
          borderRadius: widget.borderRadius,
          padding: widget.padding,
          color: widget.color,
          depth: widget.depth,
          child: widget.child,
        ),
      ),
    );
  }
}
