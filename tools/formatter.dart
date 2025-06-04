// tools/formatter.dart - ОПТИМИЗИРОВАННАЯ ВЕРСИЯ
import 'dart:io';
import 'dart:convert';
import 'dart:math';

class BookFormatter {
  static Future<void> processBook(String sourcePath, String category, String author, String bookName) async {
    print('📚 Обрабатываем книгу: $bookName');
    print('📁 Исходник: $sourcePath');
    
    try {
      // Читаем исходный файл с отслеживанием прогресса
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Исходный файл не найден: $sourcePath');
      }
      
      print('📖 Чтение файла...');
      final sourceContent = await sourceFile.readAsString(encoding: utf8);
      print('📊 Прочитано символов: ${sourceContent.length}');
      
      // Создаем папку назначения в корневой директории проекта
      final targetDir = '../assets/full_texts/$category/$author';
      await Directory(targetDir).create(recursive: true);
      
      // Пути для файлов
      final rawPath = '$targetDir/${bookName}_raw.txt';
      final cleanedPath = '$targetDir/${bookName}_cleaned.txt';
      
      // Извлекаем оригинальные позиции с отслеживанием прогресса
      print('🔍 Извлечение оригинальных позиций...');
      final originalPositions = _extractOriginalPositions(sourceContent);
      print('📍 Найдено ${originalPositions.length} оригинальных позиций');
      
      // Обрабатываем для RAW версии (агрессивная очистка) с отслеживанием
      print('🔄 Создание RAW версии...');
      final rawText = await _processForRaw(sourceContent, originalPositions);
      print('💾 Сохранение RAW файла...');
      await File(rawPath).writeAsString(rawText, encoding: utf8);
      print('✅ RAW файл создан: $rawPath');
      
      // Создаем CLEANED версию с отслеживанием
      print('🔄 Создание CLEANED версии...');
      final cleanedText = await _processForCleaned(sourceContent, originalPositions);
      print('💾 Сохранение CLEANED файла...');
      await File(cleanedPath).writeAsString(cleanedText, encoding: utf8);
      print('✅ CLEANED файл создан: $cleanedPath');
      
      print('🎉 Готово! Создано 2 синхронизированных файла для $bookName');
      
    } catch (e, stackTrace) {
      print('❌ Ошибка: $e');
      print('📜 Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  // Извлечение оригинальных позиций из исходного текста
  static List<Map<String, dynamic>> _extractOriginalPositions(String text) {
    final positions = <Map<String, dynamic>>[];
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    var currentPosition = 1;
    var processedCount = 0;
    final totalParagraphs = paragraphs.length;
    
    for (final paragraph in paragraphs) {
      processedCount++;
      if (processedCount % 100 == 0) {
        print('📊 Обработано параграфов: $processedCount / $totalParagraphs');
      }
      
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) continue;
      
      // Пропускаем служебную информацию
      if (_isServiceInfo(trimmed)) continue;
      
      positions.add({
        'position': currentPosition,
        'content': trimmed,
      });
      currentPosition++;
    }
    
    return positions;
  }
  
  // Проверка на служебную информацию
  static bool _isServiceInfo(String text) {
    return RegExp(r'^(ISBN|Copyright|©|\(c\)|ГЛАВА\s+\w+)', caseSensitive: false).hasMatch(text) ||
           RegExp(r'^[-=_*]{3,}$').hasMatch(text) ||
           RegExp(r'^\d+$').hasMatch(text);
  }
  
  // Агрессивная обработка для RAW версии (для поиска)
  static Future<String> _processForRaw(String text, List<Map<String, dynamic>> originalPositions) async {
    print('🔍 Создаем RAW версию (для поиска)...');
    
    // 1. Нормализуем символы
    print('📝 Нормализация символов...');
    text = _normalizeCharacters(text);
    
    // 2. Агрессивная очистка
    print('🧹 Агрессивная очистка...');
    text = _aggressiveClean(text);
    
    // 3. Разбиваем на абзацы с сохранением оригинальных позиций
    print('📑 Создание абзацев с позициями...');
    return await _createPositionedParagraphs(text, originalPositions, aggressive: true);
  }
  
  // Деликатная обработка для CLEANED версии (для чтения)
  static Future<String> _processForCleaned(String text, List<Map<String, dynamic>> originalPositions) async {
    print('📖 Создаем CLEANED версию (для чтения)...');
    
    // 1. Нормализуем символы
    print('📝 Нормализация символов...');
    text = _normalizeCharacters(text);
    
    // 2. Деликатная очистка
    print('🧹 Деликатная очистка...');
    text = _gentleClean(text);
    
    // 3. Разбиваем на абзацы с сохранением оригинальных позиций
    print('📑 Создание абзацев с позициями...');
    return await _createPositionedParagraphs(text, originalPositions, aggressive: false);
  }
  
  // Создание абзацев с сохранением позиций (оптимизированная версия)
  static Future<String> _createPositionedParagraphs(
    String text,
    List<Map<String, dynamic>> originalPositions,
    {required bool aggressive}
  ) async {
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    final result = <String>[];
    var currentParagraphIndex = 0;
    var processedCount = 0;
    final totalPositions = originalPositions.length;
    
    for (final position in originalPositions) {
      processedCount++;
      if (processedCount % 50 == 0) {
        print('📊 Обработано позиций: $processedCount / $totalPositions');
        // Даем шанс другим операциям выполниться
        await Future.delayed(Duration.zero);
      }
      
      if (currentParagraphIndex >= paragraphs.length) break;
      
      // Ищем наиболее похожий абзац в ограниченном окне
      var bestMatch = '';
      var bestScore = 0.0;
      final windowSize = 10; // Ограничиваем окно поиска
      
      final searchEnd = min(currentParagraphIndex + windowSize, paragraphs.length);
      for (var i = currentParagraphIndex; i < searchEnd; i++) {
        final score = _calculateMatchScore(
          _normalizeText(position['content']),
          _normalizeText(paragraphs[i])
        );
        
        if (score > bestScore) {
          bestScore = score;
          bestMatch = paragraphs[i];
          currentParagraphIndex = i + 1;
        }
        
        // Если нашли очень хорошее совпадение, прекращаем поиск
        if (score > 0.8) break;
      }
      
      // Если нашли подходящий абзац
      if (bestMatch.isNotEmpty) {
        final content = aggressive ? _aggressiveCleanParagraph(bestMatch) : bestMatch.trim();
        result.add('[pos:${position['position']}] $content');
      }
    }
    
    return result.join('\n\n');
  }
  
  // Нормализация текста для сравнения (оптимизированная версия)
  static String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Удаляем все, кроме букв, цифр и пробелов
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
  
  // Подсчет схожести текстов (оптимизированная версия)
  static double _calculateMatchScore(String text1, String text2) {
    if ((text1.length - text2.length).abs() > text1.length * 0.5) {
      return 0.0; // Слишком разные по длине
    }
    
    final words1 = text1.split(' ');
    final words2 = text2.split(' ');
    
    final Set<String> commonWords = Set<String>.from(words1).intersection(Set<String>.from(words2));
    return 2 * commonWords.length / (words1.length + words2.length);
  }
  
  // Агрессивная очистка одного абзаца
  static String _aggressiveCleanParagraph(String text) {
    return text
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }
  
  // Нормализация символов
  static String _normalizeCharacters(String text) {
    return text
        .replaceAll(RegExp(r'[""„"]'), '"')
        .replaceAll(RegExp(r'[''`]'), "'")
        .replaceAll(RegExp(r'[—–−]'), '-')
        .replaceAll('…', '...');
  }
  
  // Агрессивная очистка
  static String _aggressiveClean(String text) {
    return text
        .replaceAll(RegExp(r'\n\s*\d+\s*\n'), '\n\n')
        .replaceAll(RegExp(r'\n\s*-\s*\d+\s*-\s*\n'), '\n\n')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*[-=_*]{3,}\s*\n'), '\n\n')
        .replaceAll(RegExp(r'\n\s*(ISBN|Copyright|©|\(c\)).*\n', caseSensitive: false), '\n');
  }
  
  // Деликатная очистка
  static String _gentleClean(String text) {
    return text
        .replaceAll(RegExp(r'\n\s*\d+\s*\n'), '\n\n')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*(ISBN|Copyright|©|\(c\)).*\n', caseSensitive: false), '\n');
  }
}

void main(List<String> args) async {
  if (args.length < 4) {
    print('''
📚 Book Formatter для Sacral App

Использование:
  dart formatter.dart <source_file> <category> <author> <book_name>

Пример:
  dart formatter.dart source_files/metaphysics_source.txt greece aristotle metaphysics

Результат:
  - RAW файл с агрессивной очисткой + позиции [pos:N] (для поиска)
  - CLEANED файл с деликатной обработкой + те же позиции (для чтения)
    ''');
    exit(1);
  }
  
  try {
    await BookFormatter.processBook(args[0], args[1], args[2], args[3]);
    print('\n🎉 Успешно обработано!');
  } catch (e) {
    print('\n❌ Ошибка: $e');
    exit(1);
  }
}

