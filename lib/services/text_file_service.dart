// lib/services/text_file_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/book_source.dart';
import '../models/quote.dart';
import '../models/quote_context.dart';

class TextFileService {
  static final TextFileService _instance = TextFileService._internal();
  factory TextFileService() => _instance;
  TextFileService._internal();

  final Map<String, String> _cachedTexts = {};
  final Map<String, List<BookSource>> _cachedSources = {};

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
      print('Error loading book sources: $e');
      return [];
    }
  }

  /// Загружает текст из файла (raw или cleaned)
  Future<String> loadTextFile(String path) async {
    if (_cachedTexts.containsKey(path)) {
      return _cachedTexts[path]!;
    }

    try {
      final content = await rootBundle.loadString(path);
      _cachedTexts[path] = content;
      return content;
    } catch (e) {
      print('Error loading text file $path: $e');
      throw Exception('Failed to load text file: $path');
    }
  }

  /// Извлекает все абзацы с позициями из текста
  List<Map<String, dynamic>> extractParagraphsWithPositions(String text) {
    final paragraphs = <Map<String, dynamic>>[];
    final parts = text.split('\n\n');
    
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      
      // Ищем позиционный маркер
      final positionMatch = RegExp(r'\[pos:(\d+)\]').firstMatch(trimmed);
      if (positionMatch != null) {
        final position = int.parse(positionMatch.group(1)!);
        final content = trimmed.replaceFirst(RegExp(r'\[pos:\d+\]\s*'), '');
        
        paragraphs.add({
          'position': position,
          'content': content,
          'rawText': trimmed,
        });
      }
    }
    
    return paragraphs;
  }

  /// Находит абзац по позиции
  Map<String, dynamic>? findParagraphByPosition(String text, int position) {
    final paragraphs = extractParagraphsWithPositions(text);
    return paragraphs.firstWhere(
      (p) => p['position'] == position,
      orElse: () => {},
    );
  }

  /// Получает контекст вокруг указанной позиции
  List<Map<String, dynamic>> getContextAroundPosition(
    String text, 
    int centerPosition, 
    {int contextSize = 5}
  ) {
    final paragraphs = extractParagraphsWithPositions(text);
    
    // Находим индекс центрального абзаца
    final centerIndex = paragraphs.indexWhere(
      (p) => p['position'] == centerPosition,
    );
    
    if (centerIndex == -1) return [];
    
    // Определяем границы контекста
    final startIndex = (centerIndex - contextSize).clamp(0, paragraphs.length);
    final endIndex = (centerIndex + contextSize + 1).clamp(0, paragraphs.length);
    
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