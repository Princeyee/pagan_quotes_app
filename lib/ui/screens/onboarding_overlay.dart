
// lib/ui/screens/onboarding_overlay.dart - СЕРЬЕЗНАЯ ВЕРСИЯ
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
  
  // Анимации
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _blurAnimation;

  final SoundManager _soundManager = SoundManager();
  
  // Состояния
  int _currentStep = 0;
  bool _isAnimating = true;
  bool _contentLoaded = false; // Флаг загрузки контента
  bool _isInitialized = false; // Флаг инициализации
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
      title: 'Ежедневные цитаты',
      description: '',
      duration: 0,
    ),
    OnboardingStep(
      type: StepType.contextDemo,
      title: 'Контекст цитат',
      description: 'Проведите пальцем вверх по цитате, чтобы узнать ее происхождение и исторический контекст.',
      duration: 0,
    ),
    OnboardingStep(
      type: StepType.fullTextDemo,
      title: 'Полные тексты',
      description: 'Нажмите на экран контекста, чтобы открыть полную книгу и погрузиться в чтение.',
      duration: 0,
    ),
    OnboardingStep(
      type: StepType.menuDemo,
      title: 'Меню приложения',
      description: 'В меню вы найдете избранные цитаты, свои заметки, полную библиотеку и календарь праздников.\n\nДолгое нажатие на цитату создаст заметку.',
      duration: 0,
    ),
    OnboardingStep(
      type: StepType.finalWisdom,
      title: 'Философия начинается с удивления',
      description: 'Язык говорит.|Перевёрнутая картина погружения в текст через цитату|Несет в себе|Отголосок духа мифопоэтики.',
      duration: 0,
    ),
  ];


  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    if (!_isInitialized) {
      _isInitialized = true;
      _startOnboarding();
    }
  }

  void _initializeAnimations() {
    _introController = AnimationController(
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
    
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 300), // Быстрее для предотвращения дергания
      vsync: this,
    );
    
    _blurController = AnimationController(
      duration: const Duration(milliseconds: 800), // Быстрее
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



    _blurAnimation = Tween<double>(
      begin: 0.0,
      end: 8.0, // Немного меньше
    ).animate(CurvedAnimation(
      parent: _blurController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _startOnboarding() async {
    // Ждем загрузки контента (дерева, шрифтов и т.д.)
    await Future.delayed(const Duration(milliseconds: 1200));
    
    if (!mounted) return; // Проверяем, что виджет еще активен
    
    // Показываем контент с блюром плавно
    setState(() => _contentLoaded = true);
    _blurController.forward();
    
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (!mounted) return; // Проверяем снова
    
    _introController.forward();
    _contentController.forward(); // Запускаем анимацию контента сразу
    
    await Future.delayed(Duration(milliseconds: _steps[0].duration));
    
    if (!mounted) return; // Проверяем перед звуком
    
    await _playBreathSound();
    
    if (mounted) { // Проверяем перед переходом к следующему шагу
      _nextStep();
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1 && !_contentController.isAnimating) {
      // Сначала плавно скрываем текущий контент
      _contentController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _currentStep++;
          });
          // Затем плавно показываем новый контент
          _contentController.forward();
        }
      });
    } else if (_currentStep >= _totalSteps - 1) {
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
      // Простое завершение вместо сложной анимации
      _completeOnboarding();
      return;
    }
    
    // Предотвращаем множественные нажатия во время анимации
    if (!_contentController.isAnimating) {
      _nextStep();
    }
  }

  void _completeOnboarding() {
    HapticFeedback.lightImpact();
    setState(() => _isAnimating = false);
    widget.onComplete();
  }

  @override
  void dispose() {
    _introController.dispose();
    _particleController.dispose();
    _glowController.dispose();
    _contentController.dispose();
    _blurController.dispose();
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
    // Если контент еще не загружен, показываем черный экран
    if (!_contentLoaded) {
      return Container(
        color: Colors.black,
        child: const SizedBox.expand(),
      );
    }

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
              color: Colors.black.withAlpha((0.5 * 255).round()),
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
    
    // Используем AnimatedBuilder вместо AnimatedSwitcher для более стабильной анимации
    return AnimatedBuilder(
      animation: _contentController,
      builder: (context, child) {
        return Opacity(
          opacity: _contentController.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _contentController.value) * 20),
            child: _buildStepContent(stepData),
          ),
        );
      },
    );
  }
  
  Widget _buildStepContent(OnboardingStep stepData) {
    switch (stepData.type) {
      case StepType.treeAnimation:
        return _buildTreeAnimation();
      case StepType.welcome:
        return _buildWelcomeStep(stepData);
      case StepType.dailyQuote:
        return _buildSimpleStep(stepData);
      case StepType.contextDemo:
        return _buildSimpleStep(stepData);
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
              
              // Частицы (оставляем только для дерева)
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeStep(OnboardingStep step) {
    // Используем только один слой анимации для предотвращения конфликтов
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Простой логотип без анимаций
            Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withAlpha((0.2 * 255).round()),
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
                color: Colors.white.withAlpha((0.8 * 255).round()),
                height: 1.5,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 60),
            
            // Простая подсказка
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Нажмите для продолжения',
                style: GoogleFonts.merriweather(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      );
    
  }

  Widget _buildSimpleStep(OnboardingStep step) {
    // Убираем лишний слой анимации
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              step.title,
              key: ValueKey('step_title_${step.type.name}'), // Стабильный ключ
              style: GoogleFonts.merriweather(
                fontSize: 26,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                decoration: TextDecoration.none,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 30),
            
            Text(
              step.description,
              key: ValueKey('step_desc_${step.type.name}'), // Стабильный ключ
              style: GoogleFonts.merriweather(
                fontSize: 16,
                color: Colors.white.withAlpha((0.85 * 255).round()),
                height: 1.6,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 50),
            
            // Демо цитаты только для шага с цитатами - СТАБИЛЬНАЯ ВЕРСИЯ
            if (step.type == StepType.dailyQuote)
              Container(
                key: const ValueKey('demo_quote_container'), // Стабильный ключ
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withAlpha((0.1 * 255).round()),
                    width: 1,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 120),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '"Танцующий — тот, кто может ходить по воде"',
                        key: const ValueKey('demo_quote_text'), // Стабильный ключ
                        style: GoogleFonts.merriweather(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withAlpha((0.9 * 255).round()),
                          decoration: TextDecoration.none,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '— Фридрих Ницше',
                        key: const ValueKey('demo_quote_author'), // Стабиль��ый ключ
                        style: GoogleFonts.merriweather(
                          fontSize: 14,
                          color: Colors.white.withAlpha((0.6 * 255).round()),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                'Нажмите для продолжения',
                style: GoogleFonts.merriweather(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      );
    
  }

  Widget _buildFullTextStep(OnboardingStep step) {
    // Убираем лишний слой анимации
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              step.title,
              style: GoogleFonts.merriweather(
                fontSize: 26,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                decoration: TextDecoration.none,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 30),
            
            Text(
              step.description,
              style: GoogleFonts.merriweather(
                fontSize: 16,
                color: Colors.white.withAlpha((0.85 * 255).round()),
                height: 1.6,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            // Простое демо перехода
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withAlpha((0.1 * 255).round()),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.05 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Контекст цитаты...\n"Танцующий — тот, кто может ходить по воде"\n...полный текст источника',
                      style: GoogleFonts.merriweather(
                        fontSize: 13,
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        decoration: TextDecoration.none,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withAlpha((0.2 * 255).round()),
                      ),
                    ),
                    child: Text(
                      '→ Полный текст книги',
                      style: GoogleFonts.merriweather(
                        fontSize: 13,
                        color: Colors.blue.withAlpha((0.8 * 255).round()),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withAlpha((0.2 * 255).round()),
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                'Нажмите для продолжения',
                style: GoogleFonts.merriweather(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      );
   
  }

  Widget _buildMenuStep(OnboardingStep step) {
    // Убираем лишний слой анимации
    return Stack(
      children: [
          // Простое выделение меню без желтого контура
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withAlpha((0.4 * 255).round()),
                  width: 2,
                ),
                color: Colors.white.withAlpha((0.1 * 255).round()),
              ),
              child: Icon(
                Icons.menu,
                color: Colors.white.withAlpha((0.9 * 255).round()),
                size: 30,
              ),
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
                      fontSize: 26,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 30),
                  
                  Text(
                    step.description,
                    style: GoogleFonts.merriweather(
                      fontSize: 16,
                      color: Colors.white.withAlpha((0.85 * 255).round()),
                      height: 1.6,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Простой список функций
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withAlpha((0.1 * 255).round()),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildMenuItemDemo('Избранные цитаты'),
                        _buildMenuItemDemo('Ваши заметки'),
                        _buildMenuItemDemo('Полная библиотека'),
                        _buildMenuItemDemo('Колесо года'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withAlpha((0.2 * 255).round()),
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      'Нажмите для продолжения',
                      style: GoogleFonts.merriweather(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        fontSize: 14,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
  
  }

  Widget _buildFinalWisdomStep(OnboardingStep step) {
    final lines = step.description.split('|');
    
    // Убираем лишний слой анимации
    return Center(
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Простая иконка без анимаций
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withAlpha((0.2 * 255).round()),
                    width: 1,
                  ),
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
                        color: Colors.white.withAlpha((0.6 * 255).round()),
                      );
                    },
                  ),
                ),
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
                  color: Colors.black.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withAlpha((0.1 * 255).round()),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: lines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final line = entry.value;
                    
                    return AnimatedTextLine(
                      text: line,
                      delay: Duration(milliseconds: 800 * index),
                      style: GoogleFonts.merriweather(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withAlpha((0.9 * 255).round()),
                        height: 1.6,
                        decoration: TextDecoration.none,
                        letterSpacing: 0.5,
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Простая кнопка завершения
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withAlpha((0.3 * 255).round()),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  'Нажмите, чтобы войти',
                  style: GoogleFonts.merriweather(
                    color: Colors.white.withAlpha((0.8 * 255).round()),
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
   
  }

  Widget _buildMenuItemDemo(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: GoogleFonts.merriweather(
          color: Colors.white.withAlpha((0.7 * 255).round()),
          fontSize: 15,
          decoration: TextDecoration.none,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// Классы для структуры шагов (без изменений)
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

// Painter для магических частиц (упрощенная версия только для дерева)
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

// Painter для тонких частиц на финальном экране - УДАЛЕН

// Виджет для анимированного появления строк (оставляем как есть)
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
      duration: const Duration(milliseconds: 1000),
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
      begin: const Offset(0, 0.3),
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
          padding: const EdgeInsets.symmetric(vertical: 3),
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