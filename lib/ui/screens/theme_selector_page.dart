import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/theme_info.dart';
import '../../services/theme_service.dart';
import '../../services/sound_manager.dart';

class ThemeSelectorPage extends StatefulWidget {
  const ThemeSelectorPage({super.key});

  @override
  State<ThemeSelectorPage> createState() => _ThemeSelectorPageState();
}

class _ThemeSelectorPageState extends State<ThemeSelectorPage> {
  late List<String> _enabledThemes;
  ThemeInfo? _expandedTheme;
  final SoundManager _soundManager = SoundManager();
  String? _currentPlayingTheme;

  @override
  void initState() {
    super.initState();
    _loadEnabledThemes();
  }

  Future<void> _loadEnabledThemes() async {
    final enabled = await ThemeService.getEnabledThemes();
    setState(() => _enabledThemes = enabled);
  }

  Future<void> _toggleTheme(String themeId) async {
    await ThemeService.toggleTheme(themeId);
    await _loadEnabledThemes();
  }

  Future<void> _playThemeSound(String themeId) async {
    if (_soundManager.isMuted) return;
    
    // Если играет другой звук, плавно затухаем
    if (_currentPlayingTheme != null && _currentPlayingTheme != themeId) {
      await _soundManager.fadeOut('theme_preview', duration: const Duration(seconds: 1));
    }
    
    _currentPlayingTheme = themeId;
    
    // Плавно запускаем новый звук
    await _soundManager.fadeIn(
      'theme_preview',
      'assets/sounds/theme_${themeId}_open.mp3',
      duration: const Duration(seconds: 1),
    );
  }

  Future<void> _stopThemeSound() async {
    if (_currentPlayingTheme != null) {
      await _soundManager.fadeOut('theme_preview', duration: const Duration(seconds: 1));
      _currentPlayingTheme = null;
    }
  }

  @override
  void dispose() {
    _stopThemeSound();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Темы'),
      ),
      body: Stack(
        children: [
          // Размытый фон с изображением из главного экрана
          Image.asset(
            'assets/images/backgrounds/main_bg.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          
          // Стеклянный контейнер
          SafeArea(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.3 * 255).round()),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.2 * 255).round()),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.builder(
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
                        ),
                        child: InkWell(
                          onTap: () async {
                            if (isExpanded) {
                              // Закрываем контейнер и плавно затухаем звук
                              await _stopThemeSound();
                              setState(() {
                                _expandedTheme = null;
                              });
                            } else {
                              // Закрываем предыдущий контейнер если открыт
                              if (_expandedTheme != null) {
                                setState(() {
                                  _expandedTheme = null;
                                });
                              }
                              // Открываем новый контейнер и плавно играем звук
                              setState(() {
                                _expandedTheme = theme;
                              });
                              await _playThemeSound(theme.id);
                            }
                          },
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedCard(ThemeInfo theme, bool isSelected) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Image.asset(theme.image, height: 160, width: double.infinity, fit: BoxFit.cover),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(theme.name, style: const TextStyle(fontSize: 20, color: Colors.white)),
              const SizedBox(height: 6),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? Colors.greenAccent : Colors.grey,
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
          child: Image.asset(theme.image, height: 240, width: double.infinity, fit: BoxFit.cover),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(theme.name, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(theme.authors.join(', '),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              Text(theme.description,
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, height: 1.4)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(isSelected ? Icons.check_circle : Icons.add_circle_outline),
                label: Text(isSelected ? 'Отключить тему' : 'Включить тему'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.redAccent : Colors.green,
                  foregroundColor: Colors.white,
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
