// lib/services/theme_service.dart - ОБНОВЛЕННАЯ ВЕРСИЯ
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/custom_cache.dart'; // ДОБАВЛЯЕМ ИМПОРТ
import '../models/theme_info.dart';
import 'quote_extraction_service.dart'; // ДОБАВЛЯЕМ ИМПОРТ

class ThemeService {
  static const _key = 'enabled_themes';
  static const _selectedAuthorsKey = 'selected_authors';

  static Future<List<String>> getEnabledThemes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? ['greece', 'nordic', 'pagan', 'philosophy'];
  }

  static Future<void> setEnabledThemes(List<String> themes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, themes);
    
    // СБРАСЫВАЕМ КЭШ ЕЖЕДНЕВНЫХ ЦИТАТ при изменении тем
    await CustomCache.prefs.clearDailyQuotes();
    print('🔄 Кэш ежедневных цитат очищен ��осле смены тем');
  }

  static Future<void> toggleTheme(String themeId) async {
    final current = await getEnabledThemes();
    if (current.contains(themeId)) {
      if (current.length == 1) return; // запрещаем отключать последнюю тему
      current.remove(themeId);
      
      // При отключении темы убираем её авторов из выбранных
      await _removeAuthorsFromDisabledTheme(themeId);
    } else {
      current.add(themeId);
    }
    await setEnabledThemes(current); // Используем setEnabledThemes для сброса кэша
  }

  static Future<bool> isEnabled(String themeId) async {
    final current = await getEnabledThemes();
    return current.contains(themeId);
  }

  // Метод для получения случайной активной темы
  static Future<String> getRandomActiveTheme() async {
    final enabledThemes = await getEnabledThemes();
    if (enabledThemes.isEmpty) {
      return 'greece'; // fallback
    }
    enabledThemes.shuffle();
    return enabledThemes.first;
  }

  // ========== НОВЫЕ МЕТОДЫ ДЛЯ РАБОТЫ С АВТОРАМИ ==========

  /// Получить всех авторов для конкретной темы
  static List<String> getAuthorsForTheme(String themeId) {
    final theme = allThemes.firstWhere(
      (t) => t.id == themeId,
      orElse: () => ThemeInfo(id: themeId, name: '', image: '', authors: [], description: ''),
    );
    return theme.authors;
  }

  /// Получить всех авторов для всех включенных тем
  static Future<List<String>> getAllAuthorsForEnabledThemes() async {
    final enabledThemes = await getEnabledThemes();
    final allAuthors = <String>{};
    
    for (final themeId in enabledThemes) {
      allAuthors.addAll(getAuthorsForTheme(themeId));
    }
    
    return allAuthors.toList()..sort();
  }

  /// Получить выбранных авторов
  static Future<Set<String>> getSelectedAuthors() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedList = prefs.getStringList(_selectedAuthorsKey) ?? [];
    return selectedList.toSet();
  }

  /// Сохранить выбранных авторов
  static Future<void> _saveSelectedAuthors(Set<String> authors) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedAuthorsKey, authors.toList());
    
    // СБРАСЫВАЕМ КЭШ ЕЖЕДНЕВНЫХ ЦИТАТ при изменении авторов
    await CustomCache.prefs.clearDailyQuotes();
    print('🔄 Кэш ежедневных цитат очищен после смены авторов');
  }

  /// Переключить автора (добавить/убрать из выбранных)
  static Future<void> toggleAuthor(String author) async {
    final selectedAuthors = await getSelectedAuthors();
    
    if (selectedAuthors.contains(author)) {
      selectedAuthors.remove(author);
    } else {
      selectedAuthors.add(author);
    }
    
    await _saveSelectedAuthors(selectedAuthors);
  }

  /// Проверить, выбран ли автор
  static Future<bool> isAuthorSelected(String author) async {
    final selectedAuthors = await getSelectedAuthors();
    return selectedAuthors.contains(author);
  }

  /// Выбрать всех авторов темы
  static Future<void> selectAllAuthorsForTheme(String themeId) async {
    final selectedAuthors = await getSelectedAuthors();
    final themeAuthors = getAuthorsForTheme(themeId);
    
    selectedAuthors.addAll(themeAuthors);
    await _saveSelectedAuthors(selectedAuthors);
  }

  /// Убрать всех авторов темы из выбранных
  static Future<void> deselectAllAuthorsForTheme(String themeId) async {
    final selectedAuthors = await getSelectedAuthors();
    final themeAuthors = getAuthorsForTheme(themeId);
    
    for (final author in themeAuthors) {
      selectedAuthors.remove(author);
    }
    
    await _saveSelectedAuthors(selectedAuthors);
  }

  /// Очистить всех выбранных авторов
  static Future<void> clearSelectedAuthors() async {
    await _saveSelectedAuthors(<String>{});
  }

  /// Убрать авторов отключенной темы из выбранных
  static Future<void> _removeAuthorsFromDisabledTheme(String themeId) async {
    final selectedAuthors = await getSelectedAuthors();
    final themeAuthors = getAuthorsForTheme(themeId);
    
    for (final author in themeAuthors) {
      selectedAuthors.remove(author);
    }
    
    await _saveSelectedAuthors(selectedAuthors);
  }

  /// Получить статистику по авторам с проверкой наличия цитат
  static Future<Map<String, int>> getAuthorStats() async {
    final enabledThemes = await getEnabledThemes();
    final selectedAuthors = await getSelectedAuthors();
    
    // Проверяем, сколько у выбранных авторов есть цитат
    final authorsWithQuotes = await getAuthorsWithQuotes();
    final selectedAuthorsWithQuotes = selectedAuthors.where((author) => 
      authorsWithQuotes.containsKey(author)
    ).toList();
    
    return {
      'total_authors': (await getAllAuthorsForEnabledThemes()).length,
      'selected_authors': selectedAuthors.length,
      'enabled_themes': enabledThemes.length,
      'authors_with_quotes': authorsWithQuotes.length,
      'selected_authors_with_quotes': selectedAuthorsWithQuotes.length,
    };
  }

  /// Получить авторов с количеством их цитат
  static Future<Map<String, int>> getAuthorsWithQuotes() async {
    try {
      // Импортируем QuoteExtractionService для проверки
      final quoteService = QuoteExtractionService();
      final curated = await quoteService.loadCuratedQuotes();
      
      final authorsWithQuotes = <String, int>{};
      
      for (final categoryQuotes in curated.values) {
        for (final quote in categoryQuotes) {
          authorsWithQuotes[quote.author] = (authorsWithQuotes[quote.author] ?? 0) + 1;
        }
      }
      
      return authorsWithQuotes;
    } catch (e) {
      print('Ошибка получения авторов с цитатами: $e');
      return {};
    }
  }

  /// Проверить, есть ли у автора цитаты
  static Future<bool> hasAuthorQuotes(String author) async {
    final authorsWithQuotes = await getAuthorsWithQuotes();
    return authorsWithQuotes.containsKey(author) && authorsWithQuotes[author]! > 0;
  }

  /// Получить авторов темы, у которых есть цитаты
  static Future<List<String>> getAuthorsWithQuotesForTheme(String themeId) async {
    final themeAuthors = getAuthorsForTheme(themeId);
    final authorsWithQuotes = await getAuthorsWithQuotes();
    
    return themeAuthors.where((author) => 
      authorsWithQuotes.containsKey(author)
    ).toList();
  }

  /// Автоматически выбрать авторов с цитатами для темы
  static Future<void> selectAuthorsWithQuotesForTheme(String themeId) async {
    final authorsWithQuotes = await getAuthorsWithQuotesForTheme(themeId);
    final selectedAuthors = await getSelectedAuthors();
    
    selectedAuthors.addAll(authorsWithQuotes);
    await _saveSelectedAuthors(selectedAuthors);
  }
}