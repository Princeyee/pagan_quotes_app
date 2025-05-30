
// tools/raw_formatter.dart - ИСПРАВЛЕННЫЙ
import 'dart:io';
import 'dart:convert';

class RawTextFormatter {
  static Future<void> formatFile(String inputPath, String outputPath) async {
    print('🔧 Начинаем обработку: $inputPath');
    
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        throw Exception('Файл не найден: $inputPath');
      }
      
      final content = await inputFile.readAsString(encoding: utf8);
      print('📖 Прочитан файл размером: ${content.length} символов');
      
      final formattedText = _processText(content);
      
      final outputFile = File(outputPath);
      await outputFile.create(recursive: true);
      await outputFile.writeAsString(formattedText, encoding: utf8);
      
      print('✅ Сохранен отформатированный файл: $outputPath');
      print('📊 Обработано символов: ${formattedText.length}');
      
    } catch (e) {
      print('❌ Ошибка обработки файла: $e');
      rethrow;
    }
  }
  
  static String _processText(String rawText) {
    print('🔄 Начинаем очистку текста...');
    
    String text = rawText;
    
    // 1. ГЛАВНОЕ ИСПРАВЛЕНИЕ: убираем ВСЕ квадратные скобки из исходного текста
    text = _removeAllBrackets(text);
    
    // 2. Нормализуем символы
    text = _normalizeCharacters(text);
    
    // 3. Убираем номера страниц
    text = _removePageNumbers(text);
    
    // 4. Убираем колонтитулы
    text = _removeHeaders(text);
    
    // 5. Убираем технический мусор
    text = _removeTechnicalJunk(text);
    
    // 6. Нормализуем переносы строк
    text = _normalizeLineBreaks(text);
    
    // 7. Склеиваем оборванные строки
    text = _joinBrokenLines(text);
    
    // 8. Формируем абзацы
    text = _createParagraphs(text);
    
    // 9. Добавляем ТОЛЬКО наши позиционные маркеры [pos:N]
    text = _addPositionMarkers(text);
    
    print('✨ Очистка завершена');
    return text;
  }
  
  /// КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ: убираем ВСЕ квадратные скобки из исходного текста
  static String _removeAllBrackets(String text) {
    print('🗑️ Удаляем ВСЕ квадратные скобки из исходного текста...');
    
    // Убираем все содержимое в квадратных скобках
    // Это может быть [примечание], [комментарий], [служебная информация] и т.д.
    text = text.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    
    // Убираем остатки одиночных скобок
    text = text.replaceAll('[', '');
    text = text.replaceAll(']', '');
    
    // Убираем также полноширинные Unicode скобки
    text = text.replaceAll('［', '');
    text = text.replaceAll('］', '');
    
    print('✅ Все квадратные скобки удалены');
    return text;
  }
  
  static String _normalizeCharacters(String text) {
    print('🔤 Нормализуем символы...');
    
    // Нормализуем кавычки
    text = text.replaceAll(RegExp(r'[""„"]'), '"');
    text = text.replaceAll(RegExp(r'[''`]'), "'");
    
    // Нормализуем тире
    text = text.replaceAll(RegExp(r'[—–−]'), '-');
    
    // Нормализуем многоточие
    text = text.replaceAll('…', '...');
    
    return text;
  }
  
  static String _removePageNumbers(String text) {
    print('📄 Удаляем номера страниц...');
    
    final patterns = [
      RegExp(r'\n\s*\d+\s*\n', multiLine: true),
      RegExp(r'\n\s*-\s*\d+\s*-\s*\n', multiLine: true),
      RegExp(r'\n\s*Page\s+\d+\s*\n', multiLine: true, caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      text = text.replaceAll(pattern, '\n\n');
    }
    
    return text;
  }
  
  static String _removeHeaders(String text) {
    print('📋 Удаляем колонтитулы...');
    
    final patterns = [
      RegExp(r'\n\s*(CHAPTER|ГЛАВА|ЧАСТЬ|PART)\s+[IVXLCDM\d]+\s*\n', multiLine: true, caseSensitive: false),
      RegExp(r'\n\s*[A-ZА-Я\s\-]{5,30}\s*\n(?=\s*\n)', multiLine: true),
    ];
    
    for (final pattern in patterns) {
      text = text.replaceAll(pattern, '\n\n');
    }
    
    return text;
  }
  
  static String _removeTechnicalJunk(String text) {
    print('🗑️ Удаляем технический мусор...');
    
    // Убираем служебные символы
    text = text.


replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    
    // Множественные пробелы в один
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    
    // Строки из разделителей
    text = text.replaceAll(RegExp(r'\n\s*[-=_*]{3,}\s*\n', multiLine: true), '\n\n');
    
    // Служебная информация
    text = text.replaceAll(RegExp(r'\n\s*(ISBN|Copyright|©|\(c\)).*\n', multiLine: true, caseSensitive: false), '\n\n');
    
    // Пустые скобки (после удаления содержимого)
    text = text.replaceAll(RegExp(r'\(\s*\)'), '');
    
    // Множественные точки в многоточие
    text = text.replaceAll(RegExp(r'[.]{4,}'), '...');
    
    return text;
  }
  
  static String _normalizeLineBreaks(String text) {
    print('↩️ Нормализуем переносы строк...');
    
    text = text.replaceAll(RegExp(r'\r\n|\r'), '\n');
    text = text.replaceAll(RegExp(r'\n{4,}'), '\n\n\n');
    
    return text;
  }
  
  static String _joinBrokenLines(String text) {
    print('🔗 Склеиваем оборванные строки...');
    
    final lines = text.split('\n');
    final result = <String>[];
    
    for (int i = 0; i < lines.length; i++) {
      final currentLine = lines[i].trim();
      
      if (currentLine.isEmpty) {
        result.add('');
        continue;
      }
      
      if (i < lines.length - 1 && 
          !RegExp(r'[.!?;:,]$').hasMatch(currentLine) &&
          lines[i + 1].trim().isNotEmpty &&
          !RegExp(r'^[A-ZА-Я]').hasMatch(lines[i + 1].trim()) &&
          currentLine.length > 10) {
        
        final nextLine = lines[i + 1].trim();
        result.add('$currentLine $nextLine');
        i++;
      } else {
        result.add(currentLine);
      }
    }
    
    return result.join('\n');
  }
  
  static String _createParagraphs(String text) {
    print('📝 Формируем абзацы...');
    
    final lines = text.split('\n');
    final paragraphs = <String>[];
    final currentParagraph = <String>[];
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      
      if (trimmedLine.isEmpty) {
        if (currentParagraph.isNotEmpty) {
          paragraphs.add(currentParagraph.join(' ').trim());
          currentParagraph.clear();
        }
      } else {
        currentParagraph.add(trimmedLine);
      }
    }
    
    if (currentParagraph.isNotEmpty) {
      paragraphs.add(currentParagraph.join(' ').trim());
    }
    
    // Менее строгий фильтр - убираем только очень короткие абзацы
    final filteredParagraphs = paragraphs.where((p) => p.length > 5).toList();
    
    print('📊 Абзацев создано: ${filteredParagraphs.length}');
    
    return filteredParagraphs.join('\n\n');
  }
  
  /// Добавляем ТОЛЬКО наши позиционные маркеры
  static String _addPositionMarkers(String text) {
    print('🏷️ Добавляем позиционные маркеры...');
    
    final paragraphs = text.split('\n\n');
    final result = <String>[];
    
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();
      if (paragraph.isNotEmpty) {
        // Добавляем ТОЛЬКО ASCII скобки для маркеров позиций
        result.add('[pos:${i + 1}] $paragraph');
      }
    }
    
    return result.join('\n\n');
  }
  
  static int _countParagraphs(String text) {
    return RegExp(r'\[pos:\d+\]').allMatches(text).length;
  }
}

//================================================================
// tools/reading_formatter.dart - ИСПРАВЛЕННЫЙ
//================================================================

class ReadingTextFormatter {
  static Future<void> formatFile(String inputPath, String cleanedPath, String outputPath) async {
    print('📖 Создаем читабельную версию: $inputPath');
    print('🔗 Синхронизация с: $cleanedPath');
    
    try {
      final inputFile = File(inputPath);
      final cleanedFile = File(cleanedPath);
      
      if (!await inputFile.exists()) {
        throw Exception('Исходный файл не найден: $inputPath');
      }
      
      if (!await cleanedFile.exists()) {
        throw Exception('Очищенный файл не найден: $cleanedPath');
      }


final originalContent = await inputFile.readAsString(encoding: utf8);
      final cleanedContent = await cleanedFile.readAsString(encoding: utf8);
      
      // Создаем читабельную версию БЕЗ позиционных маркеров
      final readableText = _createReadableVersion(originalContent, cleanedContent);
      
      final outputFile = File(outputPath);
      await outputFile.create(recursive: true);
      await outputFile.writeAsString(readableText, encoding: utf8);
      
      print('✅ Сохранена читабельная версия: $outputPath');
      
    } catch (e) {
      print('❌ Ошибка: $e');
      rethrow;
    }
  }
  
  /// Создаем версию для чтения БЕЗ позиционных маркеров
  static String _createReadableVersion(String originalText, String cleanedText) {
    print('📖 Создаем версию для чтения...');
    
    // Берем очищенный текст и УБИРАЕМ из него позиционные маркеры
    String readableText = cleanedText;
    
    // Удаляем ВСЕ позиционные маркеры [pos:N]
    readableText = readableText.replaceAll(RegExp(r'\[pos:\d+\]\s*'), '');
    
    // Убираем лишние пробелы и переносы после удаления маркеров
    readableText = readableText.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');
    readableText = readableText.replaceAll(RegExp(r'^\s+|\s+$', multiLine: true), '');
    
    print('✅ Создана читабельная версия без позиционных маркеров');
    return readableText;
  }
}

/// Точки входа для консольного использования
void main(List<String> args) async {
  if (args.isEmpty) {
    print('''
📚 Text Formatters для Sacral App

Использование:
  dart tools.dart raw <input_file> <output_file>     - создать RAW версию с маркерами
  dart tools.dart clean <raw_file> <output_file>     - создать CLEANED версию без маркеров

Примеры:
  dart tools.dart raw metaphysics_source.txt metaphysics_raw.txt
  dart tools.dart clean metaphysics_raw.txt metaphysics_cleaned.txt
    ''');
    exit(1);
  }
  
  try {
    if (args[0] == 'raw' && args.length >= 3) {
      await RawTextFormatter.formatFile(args[1], args[2]);
    } else if (args[0] == 'clean' && args.length >= 3) {
      // Читаем RAW файл и создаем CLEANED версию
      final rawFile = File(args[1]);
      final rawContent = await rawFile.readAsString(encoding: utf8);
      
      // Убираем позиционные маркеры для CLEANED версии
      final cleanedContent = rawContent.replaceAll(RegExp(r'\[pos:\d+\]\s*'), '');
      final cleanedFormatted = cleanedContent.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');
      
      final outputFile = File(args[2]);
      await outputFile.create(recursive: true);
      await outputFile.writeAsString(cleanedFormatted, encoding: utf8);
      
      print('✅ Создана CLEANED версия: ${args[2]}');
    } else {
      print('❌ Неверные параметры');
      exit(1);
    }
    
    print('\n🎉 Готово!');
  } catch (e) {
    print('\n❌ Ошибка: $e');
    exit(1);
  }
}
