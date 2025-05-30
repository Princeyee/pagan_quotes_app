import 'package:flutter/material.dart';
import '../../models/theme_info.dart';
import '../../services/theme_service.dart';
import 'package:just_audio/just_audio.dart';

class ThemeSelectorPage extends StatefulWidget {
  const ThemeSelectorPage({super.key});

  @override
  State<ThemeSelectorPage> createState() => _ThemeSelectorPageState();
}

class _ThemeSelectorPageState extends State<ThemeSelectorPage> {
  late List<String> _enabledThemes = [];
  ThemeInfo? _expandedTheme;
  AudioPlayer? _currentPlayer;
  String? _currentPlayingThemeId;

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

  Future<void> _stopCurrentSound() async {
    if (_currentPlayer == null) return;
    
    try {
      // Плавное затухание
      final currentVolume = _currentPlayer!.volume;
      const steps = 10;
      const stepDuration = Duration(milliseconds: 50);
      
      for (int i = steps; i >= 0; i--) {
        if (_currentPlayer != null) {
          await _currentPlayer!.setVolume(currentVolume * i / steps);
          await Future.delayed(stepDuration);
        }
      }
      
      await _currentPlayer!.stop();
      await _currentPlayer!.dispose();
    } catch (e) {
      print('Error stopping sound: $e');
    } finally {
      _currentPlayer = null;
      _currentPlayingThemeId = null;
    }
  }

  Future<void> _playThemeSound(String themeId) async {
    // Если пытаемся играть тот же звук, игнорируем
    if (_currentPlayingThemeId == themeId && _currentPlayer != null) {
      return;
    }
    
    // Останавливаем текущий звук
    await _stopCurrentSound();
    
    try {
      _currentPlayer = AudioPlayer();
      _currentPlayingThemeId = themeId;
      
      await _currentPlayer!.setAsset('assets/sounds/theme_${themeId}_open.mp3');
      await _currentPlayer!.setVolume(0.0);
      await _currentPlayer!.play();
      
      // Плавное нарастание
      const steps = 10;
      const stepDuration = Duration(milliseconds: 50);
      
      for (int i = 0; i <= steps; i++) {
        if (_currentPlayer != null) {
          await _currentPlayer!.setVolume(i / steps);
          await Future.delayed(stepDuration);
        }
      }
      
    } catch (e) {
      print('Error playing theme sound: $e');
      _currentPlayer?.dispose();
      _currentPlayer = null;
      _currentPlayingThemeId = null;
    }
  }

  @override
  void dispose() {
    _currentPlayer?.stop();
    _currentPlayer?.dispose();
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
            await _stopCurrentSound();
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
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ] : [],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                if (isExpanded) {
                  // Закрываем текущий
                  setState(() => _expandedTheme = null);
                  await _stopCurrentSound();
                } else {
                  // Открываем новый
                  final previousTheme = _expandedTheme;
                  setState(() => _expandedTheme = theme);
                  
                  // Если был открыт другой - останавливаем его звук
                  if (previousTheme != null && previousTheme.id != theme.id) {
                    await _stopCurrentSound();
                  }
                  
                  // Играем новый звук
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
    );
  }

  Widget _buildCollapsedCard(ThemeInfo theme, bool isSelected) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Image.asset(
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
          child: Image.asset(
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
                  fontWeight: FontWeight.bold
                )
              ),
              const SizedBox(height: 8),
              Text(
                theme.authors.join(', '),
                textAlign: TextAlign.center, 
                style: const TextStyle(color: Colors.white70)
              ),
              const SizedBox(height: 12),
              Text(
                theme.description,
                textAlign: TextAlign.center, 
                style: const TextStyle(
                  color: Colors.white54, 
                  height: 1.4
                )
              ),
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