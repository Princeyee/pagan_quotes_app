import 'package:flutter/material.dart';
import '../../models/theme_info.dart';
import '../../services/theme_service.dart';
import 'package:just_audio/just_audio.dart';

class ThemeSelectorPage extends StatefulWidget {
  const ThemeSelectorPage({super.key});

  @override
  State<ThemeSelectorPage> createState() => _ThemeSelectorPageState();
}

class _ThemeSelectorPageState extends State<ThemeSelectorPage> with TickerProviderStateMixin {
  late List<String> _enabledThemes = [];
  ThemeInfo? _expandedTheme;
  
  // Управление звуком
  AudioPlayer? _currentPlayer;
  String? _currentPlayingThemeId;
  bool _isFadingOut = false;
  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _initializeFadeAnimation();
    _loadEnabledThemes();
  }
  
  void _initializeFadeAnimation() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000), // 1 секунда затухания
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeOut,
    ));
    
    // Слушаем изменения анимации для обновления громкости
    _fadeAnimation!.addListener(() {
      if (_currentPlayer != null && _isFadingOut) {
        _currentPlayer!.setVolume(_fadeAnimation!.value);
      }
    });
    
    // Когда анимация завершена, останавливаем и очищаем плеер
    _fadeController!.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isFadingOut) {
        _cleanupCurrentPlayer();
      }
    });
  }

  Future<void> _loadEnabledThemes() async {
    final enabled = await ThemeService.getEnabledThemes();
    setState(() => _enabledThemes = enabled);
  }

  Future<void> _toggleTheme(String themeId) async {
    await ThemeService.toggleTheme(themeId);
    await _loadEnabledThemes();
  }

  // Очистка текущего плеера
  void _cleanupCurrentPlayer() {
    _currentPlayer?.stop();
    _currentPlayer?.dispose();
    _currentPlayer = null;
    _currentPlayingThemeId = null;
    _isFadingOut = false;
    _fadeController?.reset();
  }

  // Затухание и остановка текущего звука
  Future<void> _fadeOutCurrentSound() async {
    if (_currentPlayer == null || _isFadingOut) return;
    
    _isFadingOut = true;
    
    // Если контроллер уже анимируется, сначала останавливаем
    if (_fadeController!.isAnimating) {
      _fadeController!.stop();
    }
    
    // Сбрасываем и запускаем анимацию затухания
    _fadeController!.reset();
    
    // Ждем завершения анимации
    await _fadeController!.forward();
  }

  // Воспроизведение звука темы
  Future<void> _playThemeSound(String themeId) async {
    // Если это тот же звук, не делаем ничего
    if (_currentPlayingThemeId == themeId && _currentPlayer != null && !_isFadingOut) {
      return;
    }
    
    try {
      // Сначала затухаем текущий звук
      if (_currentPlayer != null) {
        await _fadeOutCurrentSound();
      }
      
      // Создаем новый плеер
      _currentPlayer = AudioPlayer();
      _currentPlayingThemeId = themeId;
      
      // Загружаем и воспроизводим новый звук
      await _currentPlayer!.setAsset('assets/sounds/theme_${themeId}_open.mp3');
      await _currentPlayer!.setVolume(0.0); // Начинаем с тишины
      await _currentPlayer!.play();
      
      // Плавно увеличиваем громкость
      for (double volume = 0.0; volume <= 1.0; volume += 0.1) {
        if (_currentPlayer != null && _currentPlayingThemeId == themeId) {
          await _currentPlayer!.setVolume(volume);
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
    } catch (e) {
      print('Error playing theme sound: $e');
      _cleanupCurrentPlayer();
    }
  }

  // Обработка нажатия на карточку темы
  Future<void> _handleThemeTap(ThemeInfo theme) async {
    if (_expandedTheme?.id == theme.id) {
      // Закрываем текущий контейнер
      setState(() {
        _expandedTheme = null;
      });
      await _fadeOutCurrentSound();
    } else {
      // Открываем новый контейнер
      setState(() {
        _expandedTheme = theme;
      });
      await _playThemeSound(theme.id);
    }
  }

  @override
  void dispose() {
    _cleanupCurrentPlayer();
    _fadeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Темы'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // Затухаем звук перед выходом
            await _fadeOutCurrentSound();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: allThemes.length,
        itemBuilder: (context, index) {
          final theme = allThemes[index];
          final isSelected = _enabledThemes.contains(theme.id);
          final isExpanded = _expandedTheme?.id == theme.id;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isSelected ? Colors.white10 : Colors.white12,
              boxShadow: isExpanded ? [
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ] : [],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _handleThemeTap(theme),
              child: AnimatedCrossFade(
                firstChild: _buildCollapsedCard(theme, isSelected),
                secondChild: _buildExpandedCard(theme, isSelected),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCollapsedCard(ThemeInfo theme, bool isSelected) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Stack(
            children: [
              Image.asset(
                theme.image, 
                height: 160, 
                width: double.infinity, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 160,
                    color: Colors.grey[900],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, color: Colors.white54),
                    ),
                  );
                },
              ),
              // Градиент для лучшей читаемости текста
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                theme.name, 
                style: const TextStyle(
                  fontSize: 20, 
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? Colors.greenAccent : Colors.grey,
                size: 24,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedCard(ThemeInfo theme, bool isSelected) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Stack(
            children: [
              Image.asset(
                theme.image, 
                height: 240, 
                width: double.infinity, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 240,
                    color: Colors.grey[900],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, color: Colors.white54),
                    ),
                  );
                },
              ),
              // Градиент для лучшей читаемости
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Индикатор воспроизведения звука
              if (_currentPlayingThemeId == theme.id && !_isFadingOut)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.volume_up,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                theme.name, 
                style: const TextStyle(
                  fontSize: 22, 
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                theme.authors.join(', '),
                textAlign: TextAlign.center, 
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                theme.description,
                textAlign: TextAlign.center, 
                style: const TextStyle(
                  color: Colors.white54, 
                  height: 1.4,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(
                  isSelected ? Icons.check_circle : Icons.add_circle_outline,
                ),
                label: Text(
                  isSelected ? 'Отключить тему' : 'Включить тему',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.redAccent : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () => _toggleTheme(theme.id),
              ),
            ],
          ),
        ),
      ],
    );
  }
}