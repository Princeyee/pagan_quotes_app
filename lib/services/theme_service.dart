import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const _key = 'enabled_themes';

  static Future<List<String>> getEnabledThemes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? ['greece', 'nordic', 'pagan', 'philosophy'];
  }

  static Future<void> setEnabledThemes(List<String> themes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, themes);
  }

  static Future<void> toggleTheme(String themeId) async {
    final current = await getEnabledThemes();
    if (current.contains(themeId)) {
      if (current.length == 1) return; // запрещаем отключать последнюю тему
      current.remove(themeId);
    } else {
      current.add(themeId);
    }
    await setEnabledThemes(current);
  }

  static Future<bool> isEnabled(String themeId) async {
    final current = await getEnabledThemes();
    return current.contains(themeId);
  }
}