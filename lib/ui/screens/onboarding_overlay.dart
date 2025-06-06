
// lib/ui/screens/onboarding_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import '../../services/sound_manager.dart';

class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  final Widget child;

  const OnboardingOverlay({
    Key? key,
    required this.onComplete,
    required this.child,
  }) : super(key: key);

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with TickerProviderStateMixin {
  // Контроллеры анимации
  late AnimationController _introController;
  late AnimationController _particleController;
  late AnimationController _glowController;
  late AnimationController _contentController;
  late AnimationController _gestureHintController;
  
  // Анимации
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _contentFadeAnimation;
  late Animation<double> _blurAnimation;
  
  final SoundManager _soundManager = SoundManager();
  
  // Состояния
  int _currentStep = 0;
  bool _isAnimating = true;
  bool _showGestureHints = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startOnboarding();
  }

  void _initializeAnimations() {
    // Основной контроллер для появления
    _introController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Контроллер для частиц
    _particleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    // Контроллер для свечения
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    // Контроллер для контента
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Контроллер для подсказок жестов
    _gestureHintController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Настройка анимаций
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _introController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _introController,
      curve: Curves.elasticOut,
    ));

    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );

    _contentFadeAnimation = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeIn,
    );

    _blurAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _gestureHintController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _startOnboarding() async {
    // Начинаем с анимации дерева
    await Future.delayed(const Duration(milliseconds: 300));
    _introController.forward();
    
    // Ждем завершения анимации
    await Future.delayed(const Duration(seconds: 2));
    
    // Звук выдоха
    await _playBreathSound();
    
    // Показываем контент
    setState(() => _currentStep = 1);
    _contentController.forward();
  }

  Future<void> _playBreathSound() async {
    if (!_soundManager.isMuted) {
      try {
        await _soundManager.playSound(
          'breath_sound',
          'assets/sounds/breath.mp3',
          loop: false,
        );
      } catch (e) {
        // Если звука нет, просто продолжаем
        print('Breath sound not available');
      }
    }
  }

  void _proceedToGestures() {
    setState(() => _currentStep = 2);
    _contentController.reverse();
    _gestureHintController.forward();
    setState(() => _showGestureHints = true);
  }

  void _completeOnboarding() {
    HapticFeedback.lightImpact();
    widget.onComplete();
  }

  @override
  void dispose() {
    _introController.dispose();
    _particleController.dispose();
    _glowController.dispose();
    _contentController.dispose();
    _gestureHintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Основной контент приложения
        widget.child,
        
        // Оверлей онбординга
        if (_isAnimating)
          Positioned.fill(
            child: _buildOnboardingContent(),
          ),
      ],
    );
  }

  Widget _buildOnboardingContent() {
    return GestureDetector(
      onTap: _currentStep == 1 ? _proceedToGestures : null,
      child: AnimatedBuilder(
        animation: _blurAnimation,
        builder: (context, child) {
          return BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: _currentStep == 2 ? _blurAnimation.value : 0,
              sigmaY: _currentStep == 2 ? _blurAnimation.value : 0,
            ),
            child: Container(
              color: Colors.black.withOpacity(_currentStep == 2 ? 0.7 : 0.85),
              child: SafeArea(
                child: _buildCurrentStep(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildTreeAnimation();
      case 1:
        return _buildWelcomeContent();
      case 2:
        return _buildGestureHints();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTreeAnimation() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Свечение
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
                          color: Colors.green.withOpacity(0.3 * _glowAnimation.value),
                          blurRadius: 60,
                          spreadRadius: 30,
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              // Частицы
              CustomPaint(
                size: const Size(300, 300),
                painter: MagicalParticlesPainter(
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
                  color: Colors.black.withOpacity(0.5),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 2,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeContent() {
    return FadeTransition(
      opacity: _contentFadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Логотип
            Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  'S',
                  style: GoogleFonts.merriweather(
                    fontSize: 40,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                     decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            
            // Заголовок
Text(
  'Добро пожаловать в Sacral',
  style: GoogleFonts.merriweather(
    fontSize: 28,
    fontWeight: FontWeight.w300,
    color: Colors.white,
    height: 1.2,
    decoration: TextDecoration.none, // ← убирает подчёркивание
  ),
  textAlign: TextAlign.center,
),

const SizedBox(height: 20),

// Описание
Text(
  'Каждый день — новая мудрость.\nПрикоснитесь к вечным истинам через цитаты великих мыслителей и голос мифа.',
  style: GoogleFonts.merriweather(
    fontSize: 17,
    fontWeight: FontWeight.w300,
    color: Colors.white.withOpacity(0.8),
    height: 1.5,
    decoration: TextDecoration.none,
  ),
  textAlign: TextAlign.center,
),

const SizedBox(height: 40),
            
            // Подзаголовок
            Text(
  'Философия начинается с удивления.',
  style: GoogleFonts.merriweather(
    fontSize: 16,
    fontStyle: FontStyle.italic,
    color: Colors.white.withOpacity(0.7),
    letterSpacing: 0.5,
    decoration: TextDecoration.none,
  ),
  textAlign: TextAlign.center,
),
            
            const SizedBox(height: 60),
            
            // Индикатор "тапни чтобы продолжить"
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.0),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app,
                              color: Colors.white.withOpacity(0.7),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
Text(
  'Нажмите, чтобы продолжить',
  style: GoogleFonts.merriweather(
    color: Colors.white.withOpacity(0.7),
    fontSize: 14,
    fontWeight: FontWeight.w300,
    decoration: TextDecoration.none,
  ),
),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureHints() {
    return Stack(
      children: [
        // Подсказка свайпа
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.18,
          left: 0,
          right: 0,
          child: _AnimatedGestureHint(
            icon: Icons.swipe_up,
            text: 'Свайп вверх\nдля просмотра контекста',
            delay: const Duration(milliseconds: 200),
            textStyle: GoogleFonts.merriweather(
              fontSize: 16,
              color: Colors.white.withOpacity(0.85),
              fontStyle: FontStyle.normal,
              decoration: TextDecoration.none,
              height: 1.4,
            ),
          ),
        ),
        
        // Подсказка долгого нажатия
        Positioned(
          top: MediaQuery.of(context).size.height * 0.12,
          left: 0,
          right: 0,
          child: _AnimatedGestureHint(
            icon: Icons.touch_app,
            text: 'Долгое нажатие\nдля создания заметки',
            delay: const Duration(milliseconds: 600),
            isLongPress: true,
            textStyle: GoogleFonts.merriweather(
              fontSize: 16,
              color: Colors.white.withOpacity(0.85),
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.none,
              height: 1.4,
            ),
          ),
        ),
        
        // Кнопка "Начать"
Positioned(
  bottom: 80,
  left: 0,
  right: 0,
  child: DelayedAnimation.delayed(
    delay: const Duration(milliseconds: 1000),
    duration: const Duration(milliseconds: 800),
    tween: Tween(begin: 0.0, end: 1.0),
    builder: (context, value, child) {
      return Opacity(
        opacity: value,
        child: Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Center(
            child: ElevatedButton(
              onPressed: _completeOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: Text(
                'Начать',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                   decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      );
    },
  ),
),
      ],
    );
  }
}

// Виджет анимированной подсказки жеста
class _AnimatedGestureHint extends StatefulWidget {
  final IconData icon;
  final String text;
  final Duration delay;
  final bool isLongPress;
  final TextStyle? textStyle; // ← вот это добавлено

  const _AnimatedGestureHint({
    required this.icon,
    required this.text,
    required this.delay,
    this.isLongPress = false,
    this.textStyle, // ← вот это добавлено
  });

  @override
  State<_AnimatedGestureHint> createState() => _AnimatedGestureHintState();
}

class _AnimatedGestureHintState extends State<_AnimatedGestureHint>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Запуск с задержкой
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
        if (widget.isLongPress) {
          _controller.repeat(reverse: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Анимированная иконка
                Transform.scale(
                  scale: widget.isLongPress ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Текст
                Text(
  widget.text,
  style: widget.textStyle,
  textAlign: TextAlign.center,
),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Painter для магических частиц
class MagicalParticlesPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  MagicalParticlesPainter({
    required this.animation,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final progress = animation.value;

    // Рисуем магические частицы
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 * math.pi / 180) + (progress * 2 * math.pi);
      final baseRadius = 80.0;
      final radiusVariation = 30 * math.sin(progress * 2 * math.pi + i);
      final radius = baseRadius + radiusVariation;
      
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      // Пульсация прозрачности
      final opacity = (0.3 + 0.7 * math.sin(progress * 3 * math.pi + i * 0.5)).clamp(0.0, 1.0);
      paint.color = color.withOpacity(opacity * 0.6);
      
      // Размер частицы
      final particleSize = 3 + 2 * math.sin(progress * 2 * math.pi + i);
      
      canvas.drawCircle(Offset(x, y), particleSize, paint);
      
      // Светящийся ореол
      paint.color = color.withOpacity(opacity * 0.2);
      canvas.drawCircle(Offset(x, y), particleSize + 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Extension для добавления задержки к TweenAnimationBuilder
extension DelayedAnimation on TweenAnimationBuilder {
  static Widget delayed({
    required Duration delay,
    required Duration duration,
    required Tween<double> tween,
    required Widget Function(BuildContext, double, Widget?) builder,
    Widget? child,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: delay + duration,
      builder: (context, value, _) {
        if (value < delay.inMilliseconds / (delay + duration).inMilliseconds) {
          return builder(context, tween.begin!, child);
        }
        final progress = (value - delay.inMilliseconds / (delay + duration).inMilliseconds) /
            (duration.inMilliseconds / (delay + duration).inMilliseconds);
        return builder(
          context,
          tween.transform(progress.clamp(0.0, 1.0)),
          child,
        );
      },
      child: child,
    );
  }
}