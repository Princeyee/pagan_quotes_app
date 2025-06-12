// lib/services/theme_service.dart - ОБНОВЛЕННАЯ ВЕРСИЯ
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/custom_cache.dart'; // ДОБАВЛЯЕМ ИМПОРТ

class ThemeService {
  static const _key = 'enabled_themes';

  static Future<List<String>> getEnabledThemes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? ['greece', 'nordic', 'pagan', 'philosophy'];
  }

  static Future<void> setEnabledThemes(List<String> themes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, themes);
    
    // СБРАСЫВАЕМ КЭШ ЕЖЕДНЕВНЫХ ЦИТАТ при изменении тем
    await CustomCache.prefs.clearDailyQuotes();
    print('🔄 Кэш ежедневных цитат очищен после смены тем');
  }

  static Future<void> toggleTheme(String themeId) async {
    final current = await getEnabledThemes();
    if (current.contains(themeId)) {
      if (current.length == 1) return; // запрещаем отключать последнюю тему
      current.remove(themeId);
    } else {
      current.add(themeId);
    }
    await setEnabledThemes(current); // Используем setEnabledThemes для сброса кэша
  }

  static Future<bool> isEnabled(String themeId) async {
    final current = await getEnabledThemes();
    return current.contains(themeId);
  }
<<<<<<< HEAD
=======

  // Метод для получения случайной активной темы
>>>>>>> 8252fec (Assistant checkpoint: Добавлен метод получения случайной активной темы)
  static Future<String> getRandomActiveTheme() async {
    final enabledThemes = await getEnabledThemes();
    if (enabledThemes.isEmpty) {
      return 'greece'; // fallback
    }
    enabledThemes.shuffle();
    return enabledThemes.first;
  }
}