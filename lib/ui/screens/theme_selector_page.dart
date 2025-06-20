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
                  backgroundColor: isSelected ? Colors.redAccent : Colors.green,
                  foregroundColor: Colors.white,
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
                
                // Заголовок секции авторов
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Авторы для цитат:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Кнопки "Все" / "Никого"
                    _buildAuthorControlButtons(theme),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Список авторов с чекбоксами
                _buildAuthorsList(theme),
                
                const SizedBox(height: 8),
                
                // Статистика выбранных авторов
                _buildAuthorStats(theme),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorControlButtons(ThemeInfo theme) {
    final themeAuthors = theme.authors;
    final authorsWithQuotes = themeAuthors.where((author) => (_authorsWithQuotes[author] ?? 0) > 0).toList();
    final selectedThemeAuthors = themeAuthors.where((author) => _selectedAuthors.contains(author)).toList();
    final allWithQuotesSelected = authorsWithQuotes.every((author) => _selectedAuthors.contains(author));
    final noneSelected = selectedThemeAuthors.isEmpty;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Кнопка "С цитатами" (выбирает только авторов с цитатами)
        TextButton(
          onPressed: allWithQuotesSelected ? null : () async {
            await ThemeService.selectAuthorsWithQuotesForTheme(theme.id);
            await _loadSelectedAuthors();
          },
          style: TextButton.styleFrom(
            foregroundColor: allWithQuotesSelected ? Colors.white38 : Colors.greenAccent,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          child: Text(
            'С цитатами',
            style: TextStyle(
              fontSize: 12,
              fontWeight: allWithQuotesSelected ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ),
        
        const Text('|', style: TextStyle(color: Colors.white38)),
        
        // Кнопка "Никого"
        TextButton(
          onPressed: noneSelected ? null : () async {
            await ThemeService.deselectAllAuthorsForTheme(theme.id);
            await _loadSelectedAuthors();
          },
          style: TextButton.styleFrom(
            foregroundColor: noneSelected ? Colors.white38 : Colors.redAccent,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          child: Text(
            'Никого',
            style: TextStyle(
              fontSize: 12,
              fontWeight: noneSelected ? FontWeight.normal : FontWeight.bold,
            ),
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
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                author,
                style: TextStyle(
                  color: isSelected ? Colors.white : (hasQuotes ? Colors.white70 : Colors.white38),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (hasQuotes) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$quotesCount',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.greenAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'В разработке',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          selected: isSelected,
          onSelected: hasQuotes ? (selected) async {
            await ThemeService.toggleAuthor(author);
            await _loadSelectedAuthors();
          } : null, // Отключаем выбор для авторов без цитат
          backgroundColor: hasQuotes 
              ? Colors.white.withOpacity(0.1) 
              : Colors.red.withOpacity(0.05),
          selectedColor: Colors.greenAccent.withOpacity(0.3),
          disabledColor: Colors.red.withOpacity(0.1),
          checkmarkColor: Colors.white,
          side: BorderSide(
            color: isSelected 
                ? Colors.greenAccent 
                : (hasQuotes ? Colors.white30 : Colors.red.withOpacity(0.3)),
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        );
      }).toList(),
    );
  }

  Widget _buildAuthorStats(ThemeInfo theme) {
    final themeAuthors = theme.authors;
    final selectedThemeAuthors = themeAuthors.where((author) => _selectedAuthors.contains(author)).toList();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selectedThemeAuthors.isEmpty ? Icons.warning_amber : Icons.check_circle_outline,
            color: selectedThemeAuthors.isEmpty ? Colors.orange : Colors.greenAccent,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            selectedThemeAuthors.isEmpty 
                ? 'Авторы не выбраны - цитаты не будут показываться'
                : 'Выбрано ${selectedThemeAuthors.length} из ${themeAuthors.length} авторов',
            style: TextStyle(
              color: selectedThemeAuthors.isEmpty ? Colors.orange : Colors.white70,
              fontSize: 12,
              fontStyle: selectedThemeAuthors.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
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
