// tools/reading_formatter.dart
import 'dart:io';
import 'dart:convert';

/// Утилита для создания читабельной версии текста, синхронизированной с очищенной версией
/// Сохраняет оригинальное форматирование, но добавляет позиционные маркеры [pos:N]
/// для синхронизации с результатами поиска
class ReadingTextFormatter {
  /// Основной метод обработки файла
  static Future<void> formatFile(String inputPath, String cleanedPath, String outputPath) async {
    print('📖 Начинаем создание читабельной версии: $inputPath');
    print('🔗 Синхронизация с очищенной версией: $cleanedPath');
    
    try {
      // Читаем исходный файл
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        throw Exception('Исходный файл не найден: $inputPath');
      }
      
      // Читаем очищенную версию для получения позиций
      final cleanedFile = File(cleanedPath);
      if (!await cleanedFile.exists()) {
        throw Exception('Очищенный файл не найден: $cleanedPath');
      }
      
      final originalContent = await inputFile.readAsString(encoding: utf8);
      final cleanedContent = await cleanedFile.readAsString(encoding: utf8);
      
      print('📊 Исходный текст: ${originalContent.length} символов');
      print('📊 Очищенный текст: ${cleanedContent.length} символов');
      
      // Обрабатываем текст
      final readableText = _processText(originalContent, cleanedContent);
      
      // Сохраняем результат
      final outputFile = File(outputPath);
      await outputFile.create(recursive: true);
      await outputFile.writeAsString(readableText, encoding: utf8);
      
      print('✅ Сохранена читабельная версия: $outputPath');
      print('📊 Финальный размер: ${readableText.length} символов');
      
      // Статистика
      final positionCount = _countPositionMarkers(readableText);
      print('🏷️ Добавлено позиционных маркеров: $positionCount');
      
    } catch (e) {
      print('❌ Ошибка обработки файла: $e');
      rethrow;
    }
  }
  
  /// Основная логика обработки текста
  static String _processText(String originalText, String cleanedText) {
    print('🔄 Начинаем обработку для чтения...');
    
    // Извлекаем позиции из очищенного текста
    final cleanedParagraphs = _extractCleanedParagraphs(cleanedText);
    print('📝 Найдено очищенных абзацев: ${cleanedParagraphs.length}');
    
    // Обрабатываем оригинальный текст
    String text = originalText;
    
    // 1. Минимальная очистка (только критический мусор)
    text = _minimalCleanup(text);
    
    // 2. Нормализуем переносы строк
    text = _normalizeLineBreaks(text);
    
    // 3. Находим соответствия с очищенными абзацами
    text = _mapToCleanedParagraphs(text, cleanedParagraphs);
    
    print('✨ Обработка для чтения завершена');
    return text;
  }
  
  /// Извлекает абзацы из очищенного текста с их позициями
  static List<CleanedParagraph> _extractCleanedParagraphs(String cleanedText) {
    final paragraphs = <CleanedParagraph>[];
    final lines = cleanedText.split('\n\n');
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && trimmed.startsWith('[pos:')) {
        final match = RegExp(r'\[pos:(\d+)\]\s*(.*)').firstMatch(trimmed);
        if (match != null) {
          final position = int.parse(match.group(1)!);
          final content = match.group(2)!.trim();
          paragraphs.add(CleanedParagraph(position, content));
        }
      }
    }
    
    return paragraphs;
  }
  
  /// Минимальная очистка только критического мусора
  static String _minimalCleanup(String text) {
    print('🧹 Минимальная очистка...');
    
    // Убираем только явно вредные символы, но сохраняем форматирование
    final patterns = [
      // Служебные не-текстовые символы
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      
      // Множественные пробелы в одной строке (но сохраняем переносы)
      RegExp(r'[ \t]{2,}'),
    ];
    
    text = text.replaceAll(patterns[0], ''); // Служебные символы
    text = text.replaceAll(patterns[1], ' '); // Множественные пробелы
    
    return text;
  }
  
  /// Нормализует переносы строк
  static String _normalizeLineBreaks(String text) {
    print('↩️ Нормализуем переносы строк...');
    
    // Заменяем различные типы переносов на единообразные
    text = text.replaceAll(RegExp(r'\r\n|\r'), '\n');
    
    return text;
  }
  
  /// Сопоставляет оригинальный текст с очищенными абзацами
  static String _mapToCleanedParagraphs(String originalText, List<CleanedParagraph> cleanedParagraphs) {
    print('🗺️ Сопоставляем с очищенными абзацами...');
    
    if (cleanedParagraphs.isEmpty) {
      print('⚠️ Нет очищенных абзацев для сопоставления');
      return originalText;
    }
    
    // УПРОЩЕННЫЙ ПОДХОД: разбиваем оригинальный текст на части примерно равные количеству очищенных абзацев
    final originalLines = originalText.split('\n');
    final result = <String>[];
    
    // Вычисляем примерный размер куска для каждого очищенного абзаца
    final linesPerParagraph = (originalLines.length / cleanedParagraphs.length).ceil();
    
    int lineIndex = 0;
    int paragraphIndex = 0;
    
    while (lineIndex < originalLines.length && paragraphIndex < cleanedParagraphs.length) {
      final cleanedPar = cleanedParagraphs[paragraphIndex];
      
      // Берем кусок оригинального текста
      final endIndex = (lineIndex + linesPerParagraph).clamp(0, originalLines.length);
      final chunk = originalLines.sublist(lineIndex, endIndex);
      
      // Объединяем строки в один абзац
      final chunkText = chunk.join('\n').trim();
      
      if (chunkText.isNotEmpty) {
        result.add('[pos:${cleanedPar.position}]');
        result.add(chunkText);
        result.add(''); // Пустая строка для разделения
      }
      
      lineIndex = endIndex;
      paragraphIndex++;
    }
    
    // Добавляем оставшийся текст, если есть
    if (lineIndex < originalLines.length) {
      final remainingText = originalLines.sublist(lineIndex).join('\n').trim();
      if (remainingText.isNotEmpty) {
        if (paragraphIndex < cleanedParagraphs.length) {
          result.add('[pos:${cleanedParagraphs[paragraphIndex].position}]');
        } else {
          result.add('[pos:${cleanedParagraphs.last.position + 1}]');
        }
        result.add(remainingText);
      }
    }
    
    print('🎯 Сопоставлено позиций: $paragraphIndex из ${cleanedParagraphs.length}');
    return result.join('\n');
  }
  
  /// Подсчитывает количество позиционных маркеров
  static int _countPositionMarkers(String text) {
    return RegExp(r'\[pos:\d+\]').allMatches(text).length;
  }
  
  /// Пакетная обработка файлов в директории
  static Future<void> formatDirectory(String inputDir, String cleanedDir, String outputDir) async {
    print('📁 Пакетная обработка директории: $inputDir');
    print('🔗 Очищенные файлы из: $cleanedDir');
    
    final inputDirectory = Directory(inputDir);
    if (!await inputDirectory.exists()) {
      throw Exception('Исходная директория не найдена: $inputDir');
    }
    
    final cleanedDirectory = Directory(cleanedDir);
    if (!await cleanedDirectory.exists()) {
      throw Exception('Директория с очищенными файлами не найдена: $cleanedDir');
    }
    
    final outputDirectory = Directory(outputDir);
    await outputDirectory.create(recursive: true);
    
    await for (final entity in inputDirectory.list()) {
      if (entity is File && entity.path.endsWith('.txt')) {
        final fileName = entity.path.split('/').last;
        final baseName = fileName.replaceAll('.txt', '');
        
        // Ищем соответствующий очищенный файл
        final cleanedPath = '$cleanedDir/${baseName}_raw.txt';
        final cleanedFile = File(cleanedPath);
        
        if (await cleanedFile.exists()) {
          final outputPath = '$outputDir/${baseName}_reading.txt';
          
          print('\n📖 Обрабатываем: $fileName');
          await formatFile(entity.path, cleanedPath, outputPath);
        } else {
          print('⚠️ Пропускаем $fileName - не найден очищенный файл: $cleanedPath');
        }
      }
    }
    
    print('\n✅ Пакетная обработка завершена!');
  }
}

/// Класс для хранения информации об очищенном абзаце
class CleanedParagraph {
  final int position;
  final String content;
  
  CleanedParagraph(this.position, this.content);
  
  @override
  String toString() => 'CleanedParagraph(pos: $position, content: ${content.length} chars)';
}

/// Точка входа для консольного использования
void main(List<String> args) async {
  if (args.length < 3) {
    print('''
📖 Reading Text Formatter для Sacral App

Создает читабельную версию текста, синхронизированную с очищенной версией

Использование:
  dart reading_formatter.dart <input_file> <cleaned_file> <output_file>
  dart reading_formatter.dart <input_dir> <cleaned_dir> <output_dir> --batch

Примеры:
  dart reading_formatter.dart republic_source.txt republic_raw.txt republic_reading.txt
  dart reading_formatter.dart ./sources/ ./assets/raw_texts/ ./assets/reading_texts/ --batch

Функции:
  ✅ Сохранение оригинального форматирования
  ✅ Минимальная очистка только критического мусора
  ✅ Синхронизация позиционных маркеров с очищенной версией
  ✅ Создание удобной для чтения версии
    ''');
    exit(1);
  }
  
  try {
    if (args.length > 3 && args[3] == '--batch') {
      await ReadingTextFormatter.formatDirectory(args[0], args[1], args[2]);
    } else {
      await ReadingTextFormatter.formatFile(args[0], args[1], args[2]);
    }
    
    print('\n🎉 Создание читабельной версии завершено успешно!');
  } catch (e) {
    print('\n❌ Ошибка: $e');
    exit(1);
  }
}