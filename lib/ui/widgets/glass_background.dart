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
  
  const GlassBackground({
    super.key,
    required this.child,
    this.blurAmount = 10.0,
    this.opacity = 0.2,
    this.borderRadius,
    this.tintColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          decoration: BoxDecoration(
            color: (tintColor ?? Colors.black).withOpacity(opacity),
            borderRadius: borderRadius,
            border: border ?? Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}