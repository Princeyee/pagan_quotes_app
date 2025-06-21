import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../models/audiobook.dart';
import '../../utils/custom_cache.dart';
import 'progressive_download_indicator.dart';

class AudiobookCard extends StatefulWidget {
  final Audiobook audiobook;
  final VoidCallback onTap;

  const AudiobookCard({
    Key? key,
    required this.audiobook,
    required this.onTap,
  }) : super(key: key);

  @override
  State<AudiobookCard> createState() => _AudiobookCardState();
}

class _AudiobookCardState extends State<AudiobookCard> {
  void _showLoadingOverlay(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _LoadingOverlay(
        onComplete: () {
          overlayEntry.remove();
        },
      ),
    );
    overlay.insert(overlayEntry);
  }

  void _handleAudiobookTap(BuildContext context) async {
    _showLoadingOverlay(context);
    
    try {
      // Просто вызываем onTap для совместимости
      widget.onTap();
    } catch (e) {
      print('Error loading audiobook: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки аудиокниги: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleAudiobookTap(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.4 * 255).round()),
              blurRadius: 15,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Фоновое изображение обложки
              _buildCoverImage(),
              
              // Размытый оверлей
              _buildBlurredOverlay(),
              
              // Контент карточки
              _buildCardContent(context),
              
              // Индикатор воспроизведения
              _buildPlayIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    return widget.audiobook.coverPath.startsWith('http')
        ? CachedNetworkImage(
            imageUrl: widget.audiobook.coverPath,
            cacheManager: CustomCache.instance,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: Colors.grey[900],
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.amber,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => _buildDefaultCover(),
          )
        : Image.asset(
            widget.audiobook.coverPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDefaultCover(),
          );
  }

  Widget _buildDefaultCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.withAlpha((0.6 * 255).round()),
            Colors.indigo.withAlpha((0.8 * 255).round()),
            Colors.black,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.audiotrack,
          color: Colors.white54,
          size: 60,
        ),
      ),
    );
  }

  Widget _buildBlurredOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withAlpha((0.3 * 255).round()),
              Colors.black.withAlpha((0.8 * 255).round()),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Верхняя часть - иконка аудио
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.5 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withAlpha((0.2 * 255).round()),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.headphones,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              // Количество глав
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha((0.9 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.audiobook.chapters.length} ${_getChapterText(widget.audiobook.chapters.length)}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // Нижняя часть - информация о книге
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.audiobook.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 4),
              
              Text(
                widget.audiobook.author,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withAlpha((0.9 * 255).round()),
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              // Длительность
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.white.withAlpha((0.8 * 255).round()),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(widget.audiobook.totalDuration),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha((0.8 * 255).round()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayIndicator() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.amber,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withAlpha((0.4 * 255).round()),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.play_arrow,
          color: Colors.black,
          size: 28,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));

    if (duration.inHours > 0) {
      return '${hours}ч ${minutes}м';
    } else {
      return '${minutes}м';
    }
  }

  String _getChapterText(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'глава';
    } else if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 12 || count % 100 > 14)) {
      return 'главы';
    } else {
      return 'глав';
    }
  }
}

class _LoadingOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const _LoadingOverlay({required this.onComplete});

  @override
  State<_LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<_LoadingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _treeController;
  late AnimationController _particleController;
  late AnimationController _glowController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _treeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _particleController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _treeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _treeController,
      curve: Curves.elasticOut,
    ));

    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );

    _treeController.forward();
  }

  @override
  void dispose() {
    _treeController.dispose();
    _particleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha((0.8 * 255).round()),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Тонкое свечение
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withAlpha(((0.2 * _glowAnimation.value) * 255).round()),
                              blurRadius: 40,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  // Частицы
                  CustomPaint(
                    size: const Size(300, 300),
                    painter: _TreeParticlesPainter(
                      animation: _particleController,
                      color: Colors.greenAccent,
                    ),
                  ),
                  
                  // Дерево
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withAlpha((0.3 * 255).round()),
                      border: Border.all(
                        color: Colors.green.withAlpha((0.2 * 255).round()),
                        width: 1,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/rune_icon.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.park,
                            size: 60,
                            color: Colors.green[400],
                          );
                        },
                      ),
                    ),
                  ),
                  
                  // Текст загрузки
                  Positioned(
                    bottom: 100,
                    child: Text(
                      'Загрузка аудиокниги...',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.8 * 255).round()),
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TreeParticlesPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _TreeParticlesPainter({
    required this.animation,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha((0.4 * 255).round())
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final progress = animation.value;

    // Упрощенные частицы только вокруг дерева
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45 * math.pi / 180) + (progress * 2 * math.pi);
      final baseRadius = 80.0;
      final radiusVariation = 20 * math.sin(progress * 2 * math.pi + i);
      final radius = baseRadius + radiusVariation;
      
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      final opacity = (0.2 + 0.5 * math.sin(progress * 2 * math.pi + i * 0.5)).clamp(0.0, 1.0);
      paint.color = color.withAlpha(((opacity * 0.4) * 255).round());
      
      final particleSize = 2 + 1 * math.sin(progress * 2 * math.pi + i);
      
      canvas.drawCircle(Offset(x, y), particleSize, paint);
      
      // Легкое свечение
      paint.color = color.withAlpha(((opacity * 0.1) * 255).round());
      canvas.drawCircle(Offset(x, y), particleSize + 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}