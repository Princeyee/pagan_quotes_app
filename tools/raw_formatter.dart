// tools/raw_formatter.dart
import 'dart:io';
import 'dart:convert';

/// Утилита для очистки и форматирования сырых текстов книг в читабельный формат
/// Генерирует raw.txt файлы с позиционными маркерами [pos:N]
class RawTextFormatter {
  /// Основной метод обработки файла
  static Future<void> formatFile(String inputPath, String outputPath) async {
    print('🔧 Начинаем обработку: $inputPath');
    
    try {
      // Читаем исходный файл
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        throw Exception('Файл не найден: $inputPath');
      }
      
      final content = await inputFile.readAsString(encoding: utf8);
      print('📖 Прочитан файл размером: ${content.length} символов');
      
      // Обрабатываем текст
      final formattedText = _processText(content);
      
      // Сохраняем результат
      final outputFile = File(outputPath);
      await outputFile.create(recursive: true);
      await outputFile.writeAsString(formattedText, encoding: utf8);
      
      print('✅ Сохранен отформатированный файл: $outputPath');
      print('📊 Обработано символов: ${formattedText.length}');
      
      // Статистика
      final paragraphCount = _countParagraphs(formattedText);
      print('📝 Создано абзацев: $paragraphCount');
      
    } catch (e) {
      print('❌ Ошибка обработки файла: $e');
      rethrow;
    }
  }
  
  /// Основная логика обработки текста
  static String _processText(String rawText) {
    print('🔄 Начинаем очистку текста...');
    
    String text = rawText;
    
    // 1. Убираем номера страниц
    text = _removePageNumbers(text);
    
    // 2. Убираем колонтитулы и хэдеры
    text = _removeHeaders(text);
    
    // 3. Убираем технический мусор
    text = _removeTechnicalJunk(text);
    
    // 4. Нормализуем переносы строк
    text = _normalizeLineBreaks(text);
    
    // 5. Склеиваем оборванные строки
    text = _joinBrokenLines(text);
    
    // 6. Формируем абзацы
    text = _createParagraphs(text);
    
    // 7. Добавляем позиционные маркеры
    text = _addPositionMarkers(text);
    
    print('✨ Очистка завершена');
    return text;
  }
  
  /// Удаляет номера страниц
  static String _removePageNumbers(String text) {
    print('📄 Удаляем номера страниц...');
    
    // Паттерны для номеров страниц
    final patterns = [
      RegExp(r'\n\s*\d+\s*\n', multiLine: true), // Номер на отдельной строке
      RegExp(r'\n\s*-\s*\d+\s*-\s*\n', multiLine: true), // -123-
      RegExp(r'\n\s*\[\s*\d+\s*\]\s*\n', multiLine: true), // [123]
      RegExp(r'\n\s*Page\s+\d+\s*\n', multiLine: true, caseSensitive: false), // Page 123
      RegExp(r'\n\s*\d+\s*/\s*\d+\s*\n', multiLine: true), // 123/456
    ];
    
    for (final pattern in patterns) {
      text = text.replaceAll(pattern, '\n\n');
    }
    
    return text;
  }
  
  /// Удаляет колонтитулы и хэдеры
  static String _removeHeaders(String text) {
    print('📋 Удаляем колонтитулы и хэдеры...');
    
    final patterns = [
      // Повторяющиеся заголовки книг/глав
      RegExp(r'\n\s*[A-ZА-Я\s]{10,50}\s*\n(?=\s*[A-ZА-Я\s]{10,50}\s*\n)', multiLine: true),
      
      // Строки с только заглавными буквами
      RegExp(r'\n\s*[A-ZА-Я\s\-]{5,}\s*\n', multiLine: true),
      
      // Строки типа "CHAPTER 1", "ГЛАВА 1"
      RegExp(r'\n\s*(CHAPTER|ГЛАВА|ЧАСТЬ|PART)\s+[IVXLCDM\d]+\s*\n', multiLine: true, caseSensitive: false),
      
      // Повторяющиеся имена авторов
      RegExp(r'\n\s*[A-ZА-Я][a-zа-я]+\s+[A-ZА-Я][a-zа-я]+\s*\n(?=.*\n\s*[A-ZА-Я][a-zа-я]+\s+[A-ZА-Я][a-zа-я]+\s*\n)', multiLine: true),
    ];
    
    for (final pattern in patterns) {
      text = text.replaceAll(pattern, '\n\n');
    }
    
    return text;
  }
  
  /// Удаляет различный технический мусор
  static String _removeTechnicalJunk(String text) {
    print('🗑️ Удаляем технический мусор...');
    
    // ИСПРАВЛЕНО: Менее агрессивная очистка
    
    // 1. Убираем только действительно проблемные служебные символы
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    
    // 2. Множественные пробелы в одну строку
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    
    // 3. Строки только из символов разделителей
    text = text.replaceAll(RegExp(r'\n\s*[-=_*]{3,}\s*\n', multiLine: true), '\n\n');
    
    // 4. Строки с служебной информацией
    text = text.replaceAll(RegExp(r'\n\s*(ISBN|Copyright|©|\(c\)).*\n', multiLine: true, caseSensitive: false), '\n\n');
    
    // 5. Пустые скобки и кавычки
    text = text.replaceAll(RegExp(r'\(\s*\)|\[\s*\]'), '');
    
    // 6. Множественные точки в многоточие
    text = text.replaceAll(RegExp(r'[.]{4,}'), '...');
    
    print('🔍 После очистки осталось символов: ${text.length}');
    return text;
  }
  
  /// Нормализует переносы строк
  static String _normalizeLineBreaks(String text) {
    print('↩️ Нормализуем переносы строк...');
    
    // Заменяем различные типы переносов на единообразные
    text = text.replaceAll(RegExp(r'\r\n|\r'), '\n');
    
    // Убираем множественные переносы (больше 3)
    text = text.replaceAll(RegExp(r'\n{4,}'), '\n\n\n');
    
    return text;
  }
  
  /// Склеивает оборванные строки в предложения
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
      
      // ИСПРАВЛЕНО: проверяем окончание строки правильным способом
      if (i < lines.length - 1 && 
          !RegExp(r'[.!?;:,]$').hasMatch(currentLine) &&
          lines[i + 1].trim().isNotEmpty &&
          !RegExp(r'^[A-ZА-Я]').hasMatch(lines[i + 1].trim()) &&
          currentLine.length > 10) {
        
        // Склеиваем с следующей строкой
        final nextLine = lines[i + 1].trim();
        result.add('$currentLine $nextLine');
        i++; // Пропускаем следующую строку
      } else {
        result.add(currentLine);
      }
    }
    
    return result.join('\n');
  }
  
  /// Формирует правильные абзацы
  static String _createParagraphs(String text) {
    print('📝 Формируем абзацы...');
    
    final lines = text.split('\n');
    final paragraphs = <String>[];
    final currentParagraph = <String>[];
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      
      if (trimmedLine.isEmpty) {
        // Пустая строка - конец абзаца
        if (currentParagraph.isNotEmpty) {
          paragraphs.add(currentParagraph.join(' ').trim());
          currentParagraph.clear();
        }
      } else {
        currentParagraph.add(trimmedLine);
      }
    }
    
    // Добавляем последний абзац, если есть
    if (currentParagraph.isNotEmpty) {
      paragraphs.add(currentParagraph.join(' ').trim());
    }
    
    print('📊 Всего абзацев до фильтрации: ${paragraphs.length}');
    
    // Фильтруем слишком короткие абзацы (ИСПРАВЛЕНО: менее строгий фильтр)
    final filteredParagraphs = paragraphs.where((p) => p.length > 10).toList(); // Было > 20
    
    print('📊 Абзацев после фильтрации: ${filteredParagraphs.length}');
    
    return filteredParagraphs.join('\n\n');
  }
  
  /// Добавляет позиционные маркеры [pos:N]
  static String _addPositionMarkers(String text) {
    print('🏷️ Добавляем позиционные маркеры...');
    
    final paragraphs = text.split('\n\n');
    final result = <String>[];
    
    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();
      if (paragraph.isNotEmpty) {
        result.add('[pos:${i + 1}] $paragraph');
      }
    }
    
    return result.join('\n\n');
  }
  
  /// Подсчитывает количество абзацев
  static int _countParagraphs(String text) {
    return RegExp(r'\[pos:\d+\]').allMatches(text).length;
  }
  
  /// Пакетная обработка файлов в директории
  static Future<void> formatDirectory(String inputDir, String outputDir) async {
    print('📁 Пакетная обработка директории: $inputDir');
    
    final inputDirectory = Directory(inputDir);
    if (!await inputDirectory.exists()) {
      throw Exception('Директория не найдена: $inputDir');
    }
    
    final outputDirectory = Directory(outputDir);
    await outputDirectory.create(recursive: true);
    
    await for (final entity in inputDirectory.list()) {
      if (entity is File && entity.path.endsWith('.txt')) {
        final fileName = entity.path.split('/').last;
        final outputPath = '$outputDir/${fileName.replaceAll('.txt', '_raw.txt')}';
        
        print('\n🔄 Обрабатываем: $fileName');
        await formatFile(entity.path, outputPath);
      }
    }
    
    print('\n✅ Пакетная обработка завершена!');
  }
}

/// Точка входа для консольного использования
void main(List<String> args) async {
  if (args.length < 2) {
    print('''
📚 Raw Text Formatter для Sacral App

Использование:
  dart raw_formatter.dart <input_file> <output_file>
  dart raw_formatter.dart <input_dir> <output_dir> --batch

Примеры:
  dart raw_formatter.dart republic_source.txt republic_raw.txt
  dart raw_formatter.dart ./sources/ ./assets/full_texts/ --batch

Функции:
  ✅ Удаление номеров страниц и колонтитулов
  ✅ Очистка технического мусора
  ✅ Склеивание оборванных строк
  ✅ Формирование читабельных абзацев
  ✅ Добавление позиционных маркеров [pos:N]
    ''');
    exit(1);
  }
  
  try {
    if (args.length > 2 && args[2] == '--batch') {
      await RawTextFormatter.formatDirectory(args[0], args[1]);
    } else {
      await RawTextFormatter.formatFile(args[0], args[1]);
    }
    
    print('\n🎉 Обработка завершена успешно!');
  } catch (e) {
    print('\n❌ Ошибка: $e');
    exit(1);
  }
}