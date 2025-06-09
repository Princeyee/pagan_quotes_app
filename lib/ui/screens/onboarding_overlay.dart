
// lib/ui/screens/onboarding_overlay.dart - ПОЛНОСТЬЮ ПЕРЕПИСАННАЯ ВЕРСИЯ
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
  late AnimationController _blurController;
  late AnimationController _finalExitController;
  
  // Анимации
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _contentFadeAnimation;
  late Animation<double> _blurAnimation;
  late Animation<double> _finalExitAnimation;

  final SoundManager _soundManager = SoundManager();
  
  // Состояния
  int _currentStep = 0;
  bool _isAnimating = true;
  final int _totalSteps = 7;
  
  // Шаги онбординга
  final List<OnboardingStep> _steps = [
    OnboardingStep(
      type: StepType.treeAnimation,
      title: '',
      description: '',
      duration: 2000,
    ),
    OnboardingStep(
      type: StepType.welcome,
      title: 'Добро пожаловать в Sacral',
      description: 'Каждый день — новая мудрость.\nПрикоснитесь к вечным истинам через цитаты великих мыслителей.',
      duration: 0,
    ),
    OnboardingStep(
      type: StepType.dailyQuote,
      title: 'Цитата дня',
      description: 'Каждый день вас ждет новая вдохновляющая цитата от великих философов, поэтов и мыслителей.',
      icon: Icons.auto_stories,
      duration: 0,
    ),
    OnboardingStep(
      type: StepType.contextDemo,
      title: 'Свайп для контекста',
      description: 'Проведите пальцем вверх по цитате, чтобы узнать больше о ее происхождении и контексте.',
      icon: Icons.swipe_up,
      duration: 0,
    ),
    OnboardingStep(
      type: StepType.fullTextDemo,
      title: 'Тап для полного текста',
      description: 'Нажмите на экран контекста, чтобы открыть полную книгу с возможностью чтения.',
      icon: Icons.auto_stories,
      duration: 0,
    ),
    OnboardingStep(
      type: StepType.menuDemo,
      title: 'Откройте меню',
      description: 'Нажмите на иконку меню, чтобы найти избранное, заметки, библиотеку и настройки.\n\nДолгое нажатие на цитату создаст заметку.',
      icon: Icons.menu,
      duration: 0,
    ),
    OnboardingStep(
      type: StepType.finalWisdom,
      title: 'Ваше путешествие начинается',
      description: 'Философия начинается с удивления.|Язык говорит.|Перевёрнутая картина погружения в текст через цитату|Несет в себе|Отголосок духа мифопоэтики.',
      duration: 0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startOnboarding();
  }

  void _initializeAnimations() {
    _introController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _particleController = AnimationController(
      duration: const Duration(seconds: 6), // Увеличено для плавности
      vsync: this,
    )..repeat();
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _blurController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _finalExitController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

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
      parent: _blurController,
      curve: Curves.easeInOut,
    ));

    _finalExitAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _finalExitController,
      curve: Curves.easeInOutCubic,
    ));

    _blurController.forward();
  }

  Future<void> _startOnboarding() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _introController.forward();
    
    await Future.delayed(Duration(milliseconds: _steps[0].duration));
    await _playBreathSound();
    
    _nextStep();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      
      _contentController.reset();
      _contentController.forward();
    } else {
      _completeOnboarding();
    }
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
        print('Breath sound not available');
      }
    }
  }

  void _handleTap() {
    if (_currentStep == 0) return;
    
    if (_currentStep == _totalSteps - 1) {
      _finalExitController.forward().then((_) {
        _completeOnboarding();
      });
      return;
    }
    
    _nextStep();
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
    _blurController.dispose();
    _finalExitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isAnimating)
          Positioned.fill(
            child: _buildOnboardingContent(),
          ),
      ],
    );
  }

  Widget _buildOnboardingContent() {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _blurAnimation,
        builder: (context, child) {
          return BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: _blurAnimation.value,
              sigmaY: _blurAnimation.value,
            ),
            child: Container(
              color: Colors.black.withOpacity(0.4),
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
    final stepData = _steps[_currentStep];
    
    switch (stepData.type) {
      case StepType.treeAnimation:
        return _buildTreeAnimation();
      case StepType.welcome:
        return _buildWelcomeStep(stepData);
      case StepType.dailyQuote:
        return _buildFeatureStep(stepData);
      case StepType.contextDemo:
        return _buildGestureStep(stepData);
      case StepType.fullTextDemo:
        return _buildFullTextStep(stepData);
      case StepType.menuDemo:
        return _buildMenuStep(stepData);
      case StepType.finalWisdom:
        return _buildFinalWisdomStep(stepData);
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
              CustomPaint(
                size: const Size(300, 300),
                painter: MagicalParticlesPainter(
                  animation: _particleController,
                  color: Colors.greenAccent,
                ),
              ),
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

  Widget _buildWelcomeStep(OnboardingStep step) {
    return FadeTransition(
      opacity: _contentFadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
            
            Text(
              step.title,
              style: GoogleFonts.merriweather(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                height: 1.2,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            Text(
              step.description,
              style: GoogleFonts.merriweather(
                fontSize: 17,
                fontWeight: FontWeight.w300,
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureStep(OnboardingStep step) {
    return FadeTransition(
      opacity: _contentFadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1500),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        step.icon,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 40),
            
            Text(
              step.title,
              style: GoogleFonts.merriweather(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 20),
            
            Text(
              step.description,
              style: GoogleFonts.merriweather(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '"Танцующий — тот, кто может ходить по воде"',
                    style: GoogleFonts.merriweather(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '— Ницше',
                    style: GoogleFonts.merriweather(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureStep(OnboardingStep step) {
    return FadeTransition(
      opacity: _contentFadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1500),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(30 * (1 - value), -20 * (1 - value)),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.swipe_up,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 40),
            
            Text(
              step.title,
              style: GoogleFonts.merriweather(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 20),
            
            Text(
              step.description,
              style: GoogleFonts.merriweather(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Нажмите для продолжения',
                    style: GoogleFonts.merriweather(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullTextStep(OnboardingStep step) {
    return FadeTransition(
      opacity: _contentFadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1500),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        step.icon,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 40),
            
            Text(
              step.title,
              style: GoogleFonts.merriweather(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 20),
            
            Text(
              step.description,
              style: GoogleFonts.merriweather(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      'Контекст цитаты...\n"Танцующий — тот, кто может ходить по воде"\n...полный текст книги',
                      style: GoogleFonts.merriweather(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  
                  TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 2),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 10 * math.sin(value * math.pi * 4)),
                        child: Icon(
                          Icons.touch_app,
                          color: Colors.white.withOpacity(0.6),
                          size: 24,
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 15),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.book,
                          color: Colors.blue.withOpacity(0.7),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Полный текст книги',
                            style: GoogleFonts.merriweather(
                              fontSize: 12,
                              color: Colors.blue.withOpacity(0.8),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Нажмите для продолжения',
                    style: GoogleFonts.merriweather(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuStep(OnboardingStep step) {
    return FadeTransition(
      opacity: _contentFadeAnimation,
      child: Stack(
        children: [
          Positioned(
            top: 20,
            left: 20,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(seconds: 2),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.yellow.withOpacity(0.8 * math.sin(value * math.pi * 4).abs()),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.yellow.withOpacity(0.3 * math.sin(value * math.pi * 4).abs()),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.menu,
                    color: Colors.white,
                    size: 30,
                  ),
                );
              },
            ),
          ),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    step.title,
                    style: GoogleFonts.merriweather(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    step.description,
                    style: GoogleFonts.merriweather(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.5,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildMenuItemDemo(Icons.bookmark, 'Избранные цитаты'),
                        _buildMenuItemDemo(Icons.edit_note, 'Ваши заметки'),
                        _buildMenuItemDemo(Icons.library_books, 'Полная библиотека'),
                        _buildMenuItemDemo(Icons.palette, 'Настройки тем'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalWisdomStep(OnboardingStep step) {
    final lines = step.description.split('|');
    
    return AnimatedBuilder(
      animation: _finalExitAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _finalExitAnimation.value,
          child: Opacity(
            opacity: _finalExitAnimation.value,
            child: FadeTransition(
              opacity: _contentFadeAnimation,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: MysticParticlesPainter(
                      animation: _particleController,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            duration: const Duration(seconds: 4), // Увеличено для плавности
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: 0.9 + (0.1 * math.sin(value * math.pi * 2)),
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3 + 0.3 * math.sin(value * math.pi * 4)),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.2 * math.sin(value * math.pi * 2).abs()),
                                        blurRadius: 30,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/rune_icon.png',
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.auto_awesome,
                                          size: 50,
                                          color: Colors.white.withOpacity(0.8),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          const SizedBox(height: 50),
                          
                          Text(
                            step.title,
                            style: GoogleFonts.merriweather(
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                              letterSpacing: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 40),
                          
                          Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Column(
                              children: lines.asMap().entries.map((entry) {
                                final index = entry.key;
                                final line = entry.value;
                                
                                return AnimatedTextLine(
                                  text: line,
                                  delay: Duration(milliseconds: 1000 * index), // Увеличено до 1 секунды
                                  style: GoogleFonts.merriweather(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w300,
                                    color: Colors.white.withOpacity(0.9),
                                    height: 1.6,
                                    decoration: TextDecoration.none,
                                    letterSpacing: 0.5,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          
                          const SizedBox(height: 60),
                          
                          TweenAnimationBuilder<double>(
                            duration: const Duration(seconds: 2),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return AnimatedOpacity(
                                opacity: 0.5 + 0.5 * math.sin(value * math.pi * 4),
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.touch_app,
                                        color: Colors.white.withOpacity(0.6),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Нажмите, чтобы войти',
                                        style: GoogleFonts.merriweather(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w300,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItemDemo(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.merriweather(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

// Классы для структуры шагов
enum StepType {
  treeAnimation,
  welcome,
  dailyQuote,
  contextDemo,
  fullTextDemo,
  menuDemo,
  finalWisdom,
}

class OnboardingStep {
  final StepType type;
  final String title;
  final String description;
  final String? buttonText;
  final IconData? icon;
  final int duration;

  OnboardingStep({
    required this.type,
    required this.title,
    required this.description,
    this.buttonText,
    this.icon,
    required this.duration,
  });
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

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 * math.pi / 180) + (progress * 2 * math.pi);
      final baseRadius = 80.0;
      final radiusVariation = 30 * math.sin(progress * 2 * math.pi + i);
      final radius = baseRadius + radiusVariation;
      
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      final opacity = (0.3 + 0.7 * math.sin(progress * 3 * math.pi + i * 0.5)).clamp(0.0, 1.0);
      paint.color = color.withOpacity(opacity * 0.6);
      
      final particleSize = 3 + 2 * math.sin(progress * 2 * math.pi + i);
      
      canvas.drawCircle(Offset(x, y), particleSize, paint);
      
      paint.color = color.withOpacity(opacity * 0.2);
      canvas.drawCircle(Offset(x, y), particleSize + 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Painter для мистических частиц на финальном экране
class MysticParticlesPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  MysticParticlesPainter({
    required this.animation,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final progress = animation.value;

    // Рисуем плавающие частицы как споры/пыльца с плавным циклом
    for (int i = 0; i < 20; i++) {
      // Используем более плавные математические функции для цикличности
      final baseX = (i * 0.618033988749895) % 1.0;
      final baseY = (i * 0.381966011250105) % 1.0;
      
      final x = (size.width * 0.1) + 
                (size.width * 0.8) * ((baseX + progress * 0.08) % 1.0);
      final y = (size.height * 0.1) + 
                (size.height * 0.8) * ((baseY + progress * 0.05) % 1.0);
      
      // Плавная пульсация без рывков
      final particlePhase = (i * 0.314159) % (2 * math.pi);
      final particleProgress = (progress * 2 * math.pi + particlePhase);
      final opacity = 0.2 + 0.3 * ((math.sin(particleProgress) + 1) / 2);
      final size_particle = 1 + 2 * ((math.cos(particleProgress * 0.7) + 1) / 2);
      
      paint.color = color.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), size_particle, paint);
      
      // Легкое свечение вокруг частицы
      paint.color = color.withOpacity(opacity * 0.3);
      canvas.drawCircle(Offset(x, y), size_particle + 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Виджет для анимированного появления строк из тумана
class AnimatedTextLine extends StatefulWidget {
  final String text;
  final Duration delay;
  final TextStyle style;

  const AnimatedTextLine({
    Key? key,
    required this.text,
    required this.delay,
    required this.style,
  }) : super(key: key);

  @override
  State<AnimatedTextLine> createState() => _AnimatedTextLineState();
}

class _AnimatedTextLineState extends State<AnimatedTextLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
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
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Text(
                widget.text,
                style: widget.style,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}