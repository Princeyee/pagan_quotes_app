import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/image_picker_service.dart';
import '../../utils/custom_cache.dart';

/// Виджет, создающий эффект объемного темного стекла с размытым фоном
class GlassBackground extends StatefulWidget {
  final Widget child;
  final double blurAmount;
  final double opacity;
  final BorderRadius? borderRadius;
  final Color? tintColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;
  final String? imageUrl;
  
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
    this.imageUrl,
  });

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground> {
  String? _backgroundImageUrl;
  
  @override
  void initState() {
    super.initState();
    _loadBackgroundImage();
  }
  
  Future<void> _loadBackgroundImage() async {
    if (widget.imageUrl != null) {
      setState(() {
        _backgroundImageUrl = widget.imageUrl;
      });
      return;
    }
    
    try {
      final today = DateTime.now();
      final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final cache = CustomCache.prefs;
      String? cachedImageUrl = cache.getSetting<String>('daily_image_$dateString');
      cachedImageUrl ??= ImagePickerService.getRandomImage('philosophy');
      
      setState(() {
        _backgroundImageUrl = cachedImageUrl;
      });
    } catch (e) {
      debugPrint('Error loading background image: $e');
      setState(() {
        _backgroundImageUrl = ImagePickerService.getRandomImage('philosophy');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Фоновое изображение
        if (_backgroundImageUrl != null)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: _backgroundImageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.black,
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.black,
              ),
            ),
          ),
          
        // Размытие и затемнение
        ClipRRect(
          borderRadius: BorderRadius.zero,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: widget.blurAmount, sigmaY: widget.blurAmount),
            child: Container(
              decoration: BoxDecoration(
                color: widget.gradient == null 
                  ? (widget.tintColor ?? Colors.black).withAlpha((widget.opacity * 255).round()) 
                  : null,
                gradient: widget.gradient ?? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (widget.tintColor ?? Colors.black).withAlpha(((widget.opacity + 0.05) * 255).round()),
                    (widget.tintColor ?? Colors.black).withAlpha((widget.opacity * 255).round()),
                  ],
                ),
                borderRadius: BorderRadius.zero,
                border: widget.border ?? Border.all(
                  color: Colors.white.withAlpha((0.12 * 255).round()),
                  width: 0.5,
                ),
                boxShadow: widget.boxShadow ?? [
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
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}