import 'package:flutter/material.dart';
import '../../models/theme_info.dart';
import '../../services/theme_service.dart';
import '../../services/sound_manager.dart';
import '../widgets/glass_background.dart';
import 'dart:ui' as ui;

class ThemeSelectorPage extends StatefulWidget {
  const ThemeSelectorPage({super.key});

  @override
  State<ThemeSelectorPage> createState() => _ThemeSelectorPageState();
}

class _ThemeSelectorPageState extends State<ThemeSelectorPage> {
  late List<String> _enabledThemes;
  Set<String> _selectedAuthors = {};
  Map<String, int> _authorsWithQuotes = {};
  ThemeInfo? _expandedTheme;
  final SoundManager _soundManager = SoundManager();
  String? _currentPlayingTheme;

  @override
  void initState() {
    super.initState();
    _loadEnabledThemes();
    _loadSelectedAuthors();
    _loadAuthorsWithQuotes();
  }

  Future<void> _loadEnabledThemes() async {
    final enabled = await ThemeService.getEnabledThemes();
    setState(() => _enabledThemes = enabled);
  }

  Future<void> _loadSelectedAuthors() async {
    final selected = await ThemeService.getSelectedAuthors();
    setState(() => _selectedAuthors = selected);
  }

  Future<void> _loadAuthorsWithQuotes() async {
    final authorsWithQuotes = await ThemeService.getAuthorsWithQuotes();
    setState(() => _authorsWithQuotes = authorsWithQuotes);
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
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ... фон и блюр ...
          SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: GlassBackground(
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
                          child: _buildThemeTile(theme, isSelected, isExpanded),
                        );
                      },
                    ),
                  ),
                ),
                if (canPop)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Material(
                          color: Colors.black.withOpacity(0.25),
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                            onPressed: () => Navigator.of(context).maybePop(),
                            tooltip: 'Назад',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
              
              // Кнопка включения/отключения темы
              ElevatedButton.icon(
                icon: Icon(isSelected ? Icons.check_circle : Icons.add_circle_outline),
                label: Text(isSelected ? 'Отключить тему' : 'Включить тему'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.white.withOpacity(0.1) : Colors.green,
                  foregroundColor: Colors.white,
                  side: isSelected ? BorderSide(color: Colors.white.withOpacity(0.3), width: 1) : null,
                ),
                onPressed: () async {
                  await _toggleTheme(theme.id);
                  await _loadSelectedAuthors(); // Обновляем авторов после изменения темы
                },
              ),
              
              // НОВАЯ СЕКЦИЯ: Выбор авторов (показывается только для включенных тем)
              if (isSelected) ...[
                const SizedBox(height: 20),
                const Divider(color: Colors.white30, thickness: 1),
                const SizedBox(height: 16),
                
                // Простой заголовок
                const Text(
                  'Выберите автора:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Список авторов с чекбоксами
                _buildAuthorsList(theme),
              ],
            ],
          ),
        ),
      ],
    );
  }

  
  Widget _buildAuthorsList(ThemeInfo theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: theme.authors.map((author) {
        final isSelected = _selectedAuthors.contains(author);
        final quotesCount = _authorsWithQuotes[author] ?? 0;
        final hasQuotes = quotesCount > 0;
        
        return FilterChip(
          label: Text(
            author,
            style: TextStyle(
              color: isSelected ? Colors.white : (hasQuotes ? Colors.white70 : Colors.white38),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          onSelected: hasQuotes ? (selected) async {
            await ThemeService.toggleAuthor(author);
            await _loadSelectedAuthors();
          } : null, // Отключаем выбор для авторов без цитат
          backgroundColor: hasQuotes 
              ? Colors.white.withOpacity(0.1) 
              : Colors.grey.withOpacity(0.1),
          selectedColor: Colors.greenAccent.withOpacity(0.3),
          disabledColor: Colors.grey.withOpacity(0.1),
          checkmarkColor: Colors.white,
          side: BorderSide(
            color: isSelected 
                ? Colors.greenAccent 
                : (hasQuotes ? Colors.white30 : Colors.grey.withOpacity(0.4)),
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        );
      }).toList(),
    );
  }

  
  Widget _buildThemeTile(ThemeInfo theme, bool isSelected, bool isExpanded) {
    return InkWell(
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
    );
  }
}
