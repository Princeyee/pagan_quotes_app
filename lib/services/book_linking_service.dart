import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audiobook.dart';
import '../models/book_source.dart';

class BookLinkingService {
  static const String _linkingKey = 'book_audio_links';
  
  // Связывает текстовую книгу с аудиокнигой
  static Future<void> linkBooks(String textBookId, String audiobookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final links = await _getLinks();
      
      links[textBookId] = audiobookId;
      
      await prefs.setString(_linkingKey, json.encode(links));
    } catch (e) {
      print('Ошибка связывания книг: $e');
    }
  }
  
  // Получает ID аудиокниги для текстовой книги
  static Future<String?> getLinkedAudiobook(String textBookId) async {
    try {
      final links = await _getLinks();
      return links[textBookId];
    } catch (e) {
      print('Ошибка получения связанной аудиокниги: $e');
      return null;
    }
  }
  
  // Получает ID текстовой книги для аудиокниги
  static Future<String?> getLinkedTextBook(String audiobookId) async {
    try {
      final links = await _getLinks();
      
      // Ищем по значению
      for (final entry in links.entries) {
        if (entry.value == audiobookId) {
          return entry.key;
        }
      }
      
      return null;
    } catch (e) {
      print('Ошибка получения связанной текстовой книги: $e');
      return null;
    }
  }
  
  // Автоматически связывает книги по названию
  static Future<void> autoLinkBooks(List<BookSource> textBooks, List<Audiobook> audiobooks) async {
    try {
      final links = await _getLinks();
      bool hasChanges = false;
      
      for (final textBook in textBooks) {
        // Если уже есть связь, пропускаем
        if (links.containsKey(textBook.id)) continue;
        
        // Ищем аудиокнигу с похожим названием
        final matchingAudiobook = _findMatchingAudiobook(textBook, audiobooks);
        
        if (matchingAudiobook != null) {
          links[textBook.id] = matchingAudiobook.id;
          hasChanges = true;
          print('🔗 Автосвязь: "${textBook.title}" ↔ "${matchingAudiobook.title}"');
        }
      }
      
      if (hasChanges) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_linkingKey, json.encode(links));
      }
    } catch (e) {
      print('Ошибка автосвязывания книг: $e');
    }
  }
  
  // Находит подходящую аудиокнигу для текстовой книги
  static Audiobook? _findMatchingAudiobook(BookSource textBook, List<Audiobook> audiobooks) {
    final textTitle = _normalizeTitle(textBook.title);
    final textAuthor = _normalizeTitle(textBook.author);
    
    for (final audiobook in audiobooks) {
      final audioTitle = _normalizeTitle(audiobook.title);
      final audioAuthor = _normalizeTitle(audiobook.author);
      
      // Проверяем совпадение названия
      if (_isSimilar(textTitle, audioTitle)) {
        return audiobook;
      }
      
      // Проверяем совпадение автора + частичное совпадение названия
      if (_isSimilar(textAuthor, audioAuthor) && _hasCommonWords(textTitle, audioTitle)) {
        return audiobook;
      }
      
      // Проверяем ключевые слова в названии
      if (_hasSignificantOverlap(textTitle, audioTitle)) {
        return audiobook;
      }
    }
    
    return null;
  }
  
  // Нормализует название для сравнения
  static String _normalizeTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Убираем пунктуацию
        .replaceAll(RegExp(r'\s+'), ' ') // Нормализуем пробелы
        .trim();
  }
  
  // Проверяет похожесть строк
  static bool _isSimilar(String str1, String str2) {
    if (str1 == str2) return true;
    
    // Проверяем, содержит ли одна строка другую
    if (str1.contains(str2) || str2.contains(str1)) return true;
    
    // Проверяем схожесть по словам
    final words1 = str1.split(' ');
    final words2 = str2.split(' ');
    
    int commonWords = 0;
    for (final word1 in words1) {
      if (word1.length > 2 && words2.any((word2) => word2.contains(word1) || word1.contains(word2))) {
        commonWords++;
      }
    }
    
    // Если больше половины слов совпадают
    return commonWords >= (words1.length / 2).ceil();
  }
  
  // Проверя��т наличие общих слов
  static bool _hasCommonWords(String str1, String str2) {
    final words1 = str1.split(' ').where((w) => w.length > 2).toSet();
    final words2 = str2.split(' ').where((w) => w.length > 2).toSet();
    
    return words1.intersection(words2).isNotEmpty;
  }
  
  // Проверяет значительное пересечение в названиях
  static bool _hasSignificantOverlap(String str1, String str2) {
    final words1 = str1.split(' ').where((w) => w.length > 3).toSet();
    final words2 = str2.split(' ').where((w) => w.length > 3).toSet();
    
    final intersection = words1.intersection(words2);
    final union = words1.union(words2);
    
    // Если пересечение составляет больше 30% от объединения
    return intersection.length / union.length > 0.3;
  }
  
  // Получает все связи
  static Future<Map<String, String>> _getLinks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final linksString = prefs.getString(_linkingKey);
      
      if (linksString != null) {
        final Map<String, dynamic> linksJson = json.decode(linksString);
        return Map<String, String>.from(linksJson);
      }
    } catch (e) {
      print('Ошибка загрузки связей: $e');
    }
    
    return {};
  }
  
  // Удаляет связь
  static Future<void> unlinkBooks(String textBookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final links = await _getLinks();
      
      links.remove(textBookId);
      
      await prefs.setString(_linkingKey, json.encode(links));
    } catch (e) {
      print('Ошибка удаления связи: $e');
    }
  }
  
  // Получает все связи для отладки
  static Future<Map<String, String>> getAllLinks() async {
    return await _getLinks();
  }
}