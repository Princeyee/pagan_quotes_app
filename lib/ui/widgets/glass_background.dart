import 'dart:ui';
import 'package:flutter/material.dart';

/// Виджет, создающий эффект объемного темного стекла с размытым фоном
class GlassBackground extends StatelessWidget {
  final Widget child;
  final double blurAmount;
  final double opacity;
  final BorderRadius? borderRadius;
  final Color? tintColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;
  
  const GlassBackground({
    super.key,
    required this.child,
    this.blurAmount = 15.0,
    this.opacity = 0.15,
    this.borderRadius,
    this.tintColor,
    this.border,
    this.boxShadow,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          decoration: BoxDecoration(
            color: gradient == null ? (tintColor ?? Colors.black).withAlpha((opacity * 255).round()) : null,
            gradient: gradient ?? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (tintColor ?? Colors.black).withAlpha(((opacity + 0.05) * 255).round()),
                (tintColor ?? Colors.black).withAlpha((opacity * 255).round()),
              ],
            ),
            borderRadius: borderRadius,
            border: border ?? Border.all(
              color: Colors.white.withAlpha((0.12 * 255).round()),
              width: 0.5,
            ),
            boxShadow: boxShadow ?? [
              BoxShadow(
                color: Colors.black.withAlpha((0.25 * 255).round()),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.white.withAlpha((0.05 * 255).round()),
                blurRadius: 5,
                spreadRadius: -1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}