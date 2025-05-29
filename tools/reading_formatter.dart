import 'dart:io';
import 'dart:convert';

/// Утилита для создания читабельной версии текста, синхронизированной с очищенной версией
class ReadingTextFormatter {
  static Future<void> formatFile(String inputPath, String cleanedPath, String outputPath) async {
    print('📖 Начинаем создание читабельной версии: $inputPath');
    print('🔗 Синхронизация с очищенной версией: $cleanedPath');

    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        throw Exception('Исходный файл не найден: $inputPath');
      }

      final cleanedFile = File(cleanedPath);
      if (!await cleanedFile.exists()) {
        throw Exception('Очищенный файл не найден: $cleanedPath');
      }

      final originalContent = await inputFile.readAsString(encoding: utf8);
      final cleanedContent = await cleanedFile.readAsString(encoding: utf8);

      print('📊 Исходный текст: ${originalContent.length} символов');
      print('📊 Очищенный текст: ${cleanedContent.length} символов');

      final readableText = _mapToCleanedParagraphs(originalContent, cleanedContent);

      final outputFile = File(outputPath);
      await outputFile.create(recursive: true);
      await outputFile.writeAsString(readableText, encoding: utf8);

      print('✅ Сохранена читабельная версия: $outputPath');
      print('📊 Финальный размер: ${readableText.length} символов');
    } catch (e) {
      print('❌ Ошибка: $e');
      rethrow;
    }
  }

  static String _mapToCleanedParagraphs(String originalText, String cleanedText) {
    print('🔄 Начинаем сопоставление абзацев...');

    final buffer = StringBuffer();
    final cleanedParagraphs = _extractCleanedParagraphs(cleanedText);
    final originalParagraphs = originalText.split(RegExp(r'\n\s*\n'));

    print('📝 Очищенных абзацев: ${cleanedParagraphs.length}');
    print('📄 Абзацев в оригинале: ${originalParagraphs.length}');

    final used = <int>{};
    int matched = 0;

    for (final cleanedPar in cleanedParagraphs) {
      final normCleaned = _normalizeText(cleanedPar.content);

      bool found = false;
      for (int i = 0; i < originalParagraphs.length; i++) {
        if (used.contains(i)) continue;

        final normOriginal = _normalizeText(originalParagraphs[i]);
        if (normOriginal == normCleaned) {
          buffer.writeln('[pos:${cleanedPar.position}]');
          buffer.writeln(originalParagraphs[i].trim());
          buffer.writeln();
          used.add(i);
          matched++;
          found = true;
          break;
        }
      }

      if (!found) {
        print('❌ Не найден абзац [pos:${cleanedPar.position}]');
      }
    }

    print('🎯 Совпадений: $matched из ${cleanedParagraphs.length}');
    return buffer.toString();
  }

  static List<CleanedParagraph> _extractCleanedParagraphs(String cleanedText) {
    final result = <CleanedParagraph>[];
    final blocks = cleanedText.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.startsWith('[pos:')) {
        final match = RegExp(r'\[pos:(\d+)\]\s*(.*)', dotAll: true).firstMatch(trimmed);
        if (match != null) {
          final pos = int.parse(match.group(1)!);
          final content = match.group(2)!.trim();
          result.add(CleanedParagraph(pos, content));
        }
      }
    }

    return result;
  }

  static String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Пакетная обработка директории
  static Future<void> formatDirectory(String inputDir, String cleanedDir, String outputDir) async {
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
        final name = entity.uri.pathSegments.last.replaceAll('.txt', '');
        final cleanedPath = '$cleanedDir/${name}_raw.txt';
        final outputPath = '$outputDir/${name}_cleaned.txt';

        final cleanedFile = File(cleanedPath);
        if (await cleanedFile.exists()) {
          print('\n📖 Обрабатываем: $name');
          await formatFile(entity.path, cleanedPath, outputPath);
        } else {
          print('⚠️ Пропуск: нет raw-файла для $name');
        }
      }
    }
  }
}

class CleanedParagraph {
  final int position;
  final String content;

  CleanedParagraph(this.position, this.content);
}

void main(List<String> args) async {
  if (args.length < 3) {
    print('''
📖 Reading Text Formatter

Использование:
  dart reading_formatter.dart <source.txt> <raw.txt> <output.txt>
  dart reading_formatter.dart <source_dir> <raw_dir> <output_dir> --batch
    ''');
    exit(1);
  }

  try {
    if (args.length > 3 && args[3] == '--batch') {
      await ReadingTextFormatter.formatDirectory(args[0], args[1], args[2]);
    } else {
      await ReadingTextFormatter.formatFile(args[0], args[1], args[2]);
    }

    print('\n✅ Готово!');
  } catch (e) {
    print('\n❌ Ошибка: $e');
    exit(1);
  }
}