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
  late List<String> _enabledThemes;
  ThemeInfo? _expandedTheme;
  // В класс _ThemeSelectorPageState добавить:
final Map<String, AudioPlayer> _audioPlayers = {};

Future<void> _playThemeSound(String themeId) async {
  // Останавливаем все предыдущие звуки
  for (final player in _audioPlayers.values) {
    player.stop();
    player.dispose();
  }
  _audioPlayers.clear();
  
  try {
    final player = AudioPlayer();
    await player.setAsset('assets/sounds/theme_${themeId}_open.mp3');
    await player.play();
    _audioPlayers[themeId] = player;
  } catch (e) {
    print('Theme sound not available: $e');
  }
}

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

  @override
   void dispose() {
  for (final player in _audioPlayers.values) {
    player.dispose();
  }
  super.dispose();
}
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Темы'),
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
            ),
            child: InkWell(
              onTap: () {
                _playThemeSound(theme.id);
                setState(() {
                  _expandedTheme = isExpanded ? null : theme;
                });
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