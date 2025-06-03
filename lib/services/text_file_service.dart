// lib/services/text_file_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/book_source.dart';
import 'logger_service.dart';

class TextFileService {
  static final TextFileService _instance = TextFileService._internal();
  factory TextFileService() => _instance;
  TextFileService._internal();

  final Map<String, String> _cachedTexts = {};
  final Map<String, List<BookSource>> _cachedSources = {};
  final _logger = LoggerService();

  /// Загружает все доступные источники книг
  Future<List<BookSource>> loadBookSources() async {
    if (_cachedSources.isNotEmpty) {
      return _cachedSources.values.expand((list) => list).toList();
    }

    try {
      // Загружаем конфигурацию источников
      final configString = await rootBundle.loadString('assets/config/book_sources.json');
      final config = json.decode(configString) as Map<String, dynamic>;
      
      final sources = <BookSource>[];
      
      for (final category in config.keys) {
        final categoryData = config[category] as Map<String, dynamic>;
        final categorySources = <BookSource>[];
        
        for (final bookData in categoryData['books'] as List) {
          final source = BookSource.fromJson({
            ...bookData as Map<String, dynamic>,
            'category': category,
          });
          categorySources.add(source);
          sources.add(source);
        }
        
        _cachedSources[category] = categorySources;
      }
      
      return sources;
    } catch (e) {
      _logger.error('Error loading book sources', error: e);
      return [];
    }
  }

  /// Загружает текст из файла (raw или cleaned)
  Future<String> loadTextFile(String path) async {
    debugPrint('!!! SACRAL_APP: START LOADING FILE: $path');

    if (_cachedTexts.containsKey(path)) {
      debugPrint('!!! SACRAL_APP: USING CACHE, LENGTH: ${_cachedTexts[path]!.length}');
      return _cachedTexts[path]!;
    }

    try {
      debugPrint('!!! SACRAL_APP: READING FROM ASSETS: $path');
      final content = await rootBundle.loadString(path);
      debugPrint('!!! SACRAL_APP: FILE LOADED, LENGTH: ${content.length}');
      
      if (content.isEmpty) {
        debugPrint('!!! SACRAL_APP: ERROR - FILE IS EMPTY: $path');
        throw Exception('File is empty: $path');
      }

      // Проверяем наличие позиционных маркеров
      if (!content.contains('[pos:')) {
        debugPrint('!!! SACRAL_APP: WARNING - NO POSITION MARKERS IN FILE: $path');
      }

      _cachedTexts[path] = content;
      return content;
    } catch (e, stackTrace) {
      debugPrint('!!! SACRAL_APP: ERROR LOADING FILE: $path');
      debugPrint('!!! SACRAL_APP: ERROR DETAILS: $e');
      debugPrint('!!! SACRAL_APP: STACK TRACE START');
      debugPrint(stackTrace.toString());
      debugPrint('!!! SACRAL_APP: STACK TRACE END');
      throw Exception('Failed to load text file: $path');
    }
  }

  /// Извлекает все абзацы с позициями из текста
  List<Map<String, dynamic>> extractParagraphsWithPositions(String text) {
    final paragraphs = <Map<String, dynamic>>[];
    
    // Обновленный regex для точного соответствия форматтеру
    final regex = RegExp(r'\[pos:(\d+)\]\s*((?:(?!\[pos:\d+\])[\s\S])*)', multiLine: true);
    final matches = regex.allMatches(text);
    
    for (final match in matches) {
      final position = int.parse(match.group(1)!);
      final content = match.group(2)!.trim();
      
      if (content.isEmpty) continue;
      
      // Нормализуем пробелы и переносы строк, сохраняя форматирование абзацев
      final normalizedContent = content
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      if (normalizedContent.isEmpty) continue;
      
      paragraphs.add({
        'position': position,
        'content': normalizedContent,
        'rawText': content,
      });
    }
    
    // Сортируем по позиции для гарантии правильного порядка
    paragraphs.sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    
    return paragraphs;
  }

  /// Находит абзац по позиции
  Map<String, dynamic>? findParagraphByPosition(String text, int position) {
    final paragraphs = extractParagraphsWithPositions(text);
    try {
      return paragraphs.firstWhere(
        (p) => p['position'] == position,
        orElse: () => {},
      );
    } catch (e) {
      _logger.error('Error finding paragraph at position $position', error: e);
      return null;
    }
  }

  /// Получает контекст вокруг указанной позиции с оптимизированным поиском
  List<Map<String, dynamic>> getContextAroundPosition(
    String text, 
    int centerPosition, 
    {int contextSize = 5}
  ) {
    final paragraphs = extractParagraphsWithPositions(text);
    if (paragraphs.isEmpty) return [];
    
    // Бинарный поиск для быстрого нахождения центрального абзаца
    int low = 0;
    int high = paragraphs.length - 1;
    int centerIndex = -1;
    
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final pos = paragraphs[mid]['position'] as int;
      
      if (pos == centerPosition) {
        centerIndex = mid;
        break;
      } else if (pos < centerPosition) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    
    // Если точное совпадение не найдено, используем ближайший абзац
    if (centerIndex == -1) {
      centerIndex = low.clamp(0, paragraphs.length - 1);
    }
    
    // Определяем границы контекста
    final startIndex = max(0, centerIndex - contextSize);
    final endIndex = min(paragraphs.length, centerIndex + contextSize + 1);
    
    return paragraphs.sublist(startIndex, endIndex);
  }

  /// Очищает кэш текстов
  void clearCache() {
    _cachedTexts.clear();
  }

  /// Получает размер кэша в байтах (приблизительно)
  int get cacheSize {
    return _cachedTexts.values
        .map((text) => text.length * 2) // примерно 2 байта на символ
        .fold(0, (sum, size) => sum + size);
  }
}