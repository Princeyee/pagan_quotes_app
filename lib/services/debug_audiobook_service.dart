import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/audiobook.dart';
import 'book_image_service.dart';

/// Отладочный сервис аудиокниг, который работает только с локальными файлами
/// Используется когда Google Drive не настроен
class DebugAudiobookService {
  
  /// Загружает только локальные аудиокниги из assets
  Future<List<Audiobook>> getLocalAudiobooks() async {
    try {
      print('🔍 Загружаем локальные аудиокниги...');
      
      // Сначала пробуем загрузить из конфигурации
      final configAudiobooks = await _loadFromConfig();
      if (configAudiobooks.isNotEmpty) {
        print('✅ Загружено ${configAudiobooks.length} аудиокниг из конфигурации');
        return configAudiobooks;
      }
      
      // Если конфигурации нет, сканируем папки
      final scannedAudiobooks = await _scanAudiobookDirectory();
      print('✅ Найдено ${scannedAudiobooks.length} аудиокниг при сканировании');
      
      return scannedAudiobooks;
    } catch (e) {
      print('❌ Ошибка загрузки локальных аудиокниг: $e');
      return [];
    }
  }
  
  /// Загружает аудиокниги из файла конфигурации
  Future<List<Audiobook>> _loadFromConfig() async {
    try {
      final String configString = await rootBundle.loadString('assets/config/audiobooks.json');
      final Map<String, dynamic> config = json.decode(configString);
      
      final List<dynamic> audiobooksJson = config['audiobooks'] ?? [];
      final List<Audiobook> audiobooks = [];
      
      for (final json in audiobooksJson) {
        final audiobook = Audiobook.fromJson(json);
        
        // Генерируем обложку если её нет
        String finalCoverPath = audiobook.coverPath;
        
        if (audiobook.coverPath.isEmpty) {
          finalCoverPath = await BookImageService.getStableBookImage(
            audiobook.id, 
            'philosophy'
          );
        } else if (!audiobook.coverPath.startsWith('http') && 
                   !audiobook.coverPath.startsWith('assets/')) {
          // Если это тема, используем её для генерации обложки
          finalCoverPath = await BookImageService.getStableBookImage(
            audiobook.id, 
            audiobook.coverPath
          );
        }
        
        final updatedAudiobook = Audiobook(
          id: audiobook.id,
          title: audiobook.title,
          author: audiobook.author,
          coverPath: finalCoverPath,
          chapters: audiobook.chapters,
          totalDuration: audiobook.totalDuration,
          description: audiobook.description,
        );
        
        audiobooks.add(updatedAudiobook);
        print('📖 Добавлена аудиокнига: ${audiobook.title}');
      }
      
      return audiobooks;
    } catch (e) {
      print('⚠️ Не удалось загрузить из конфигурации: $e');
      return [];
    }
  }
  
  /// Сканирует папки assets/audiobooks/ для поиска аудиокниг
  Future<List<Audiobook>> _scanAudiobookDirectory() async {
    final List<Audiobook> audiobooks = [];
    
    try {
      // Получаем список всех файлов из AssetManifest
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      
      // Фильтруем файлы аудиокниг
      final audiobookFiles = manifestMap.keys
          .where((String key) => key.startsWith('assets/audiobooks/'))
          .toList();
      
      print('📁 Найдено ${audiobookFiles.length} файлов в assets/audiobooks/');
      
      // Группируем по папкам книг
      final Map<String, List<String>> bookFolders = {};
      
      for (final file in audiobookFiles) {
        final parts = file.split('/');
        if (parts.length >= 4) {
          final bookFolder = parts[2]; // assets/audiobooks/[book_name]/...
          if (!bookFolders.containsKey(bookFolder)) {
            bookFolders[bookFolder] = [];
          }
          bookFolders[bookFolder]!.add(file);
        }
      }
      
      print('📚 Найдено ${bookFolders.length} папок с аудиокнигами');
      
      // Создаем аудиокниги из найденных папок
      for (final entry in bookFolders.entries) {
        final bookName = entry.key;
        final files = entry.value;
        
        // Генерируем обложку
        final coverPath = await BookImageService.getStableBookImage(bookName, 'pagan');
        
        // Ищем аудиофайлы
        final audioFiles = files
            .where((file) => file.endsWith('.mp3') || file.endsWith('.m4a'))
            .toList()
          ..sort();
        
        if (audioFiles.isNotEmpty) {
          final chapters = <AudiobookChapter>[];
          
          for (int i = 0; i < audioFiles.length; i++) {
            final file = audioFiles[i];
            final fileName = file.split('/').last;
            final chapterTitle = _formatChapterTitle(fileName, i + 1);
            
            chapters.add(AudiobookChapter(
              title: chapterTitle,
              filePath: file,
              duration: const Duration(minutes: 30), // Примерная длительность
              chapterNumber: i + 1,
            ));
          }
          
          final totalDuration = Duration(
            milliseconds: chapters.fold(0, (sum, chapter) => sum + chapter.duration.inMilliseconds),
          );
          
          audiobooks.add(Audiobook(
            id: bookName,
            title: _formatBookTitle(bookName),
            author: 'Локальная библиотека',
            coverPath: coverPath,
            chapters: chapters,
            totalDuration: totalDuration,
            description: 'Аудиокнига из локальной библиотеки',
          ));
          
          print('📖 Создана аудиокниг��: ${_formatBookTitle(bookName)} (${chapters.length} глав)');
        }
      }
      
    } catch (e) {
      print('❌ Ошибка при сканировании аудиокниг: $e');
    }
    
    return audiobooks;
  }
  
  String _formatBookTitle(String folderName) {
    return folderName
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' ');
  }

  String _formatChapterTitle(String fileName, int chapterNumber) {
    final nameWithoutExtension = fileName.split('.').first;
    
    // Если в имени файла есть "chapter" или "глава", используем как есть
    if (nameWithoutExtension.toLowerCase().contains('chapter') ||
        nameWithoutExtension.toLowerCase().contains('глава')) {
      return _formatBookTitle(nameWithoutExtension);
    }
    
    // Иначе добавляем номер главы
    return 'Глава $chapterNumber';
  }
  
  /// Проверяет, доступен ли файл локально
  Future<bool> isFileAvailable(String filePath) async {
    try {
      await rootBundle.load(filePath);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Возвращает информацию о состоянии локальной библиотеки
  Future<Map<String, dynamic>> getLibraryInfo() async {
    try {
      final audiobooks = await getLocalAudiobooks();
      final totalChapters = audiobooks.fold(0, (sum, book) => sum + book.chapters.length);
      final totalDuration = audiobooks.fold(
        Duration.zero, 
        (sum, book) => sum + book.totalDuration
      );
      
      return {
        'totalBooks': audiobooks.length,
        'totalChapters': totalChapters,
        'totalDuration': totalDuration.inMinutes,
        'status': 'Локальная библиотека готова',
        'source': 'assets',
      };
    } catch (e) {
      return {
        'totalBooks': 0,
        'totalChapters': 0,
        'totalDuration': 0,
        'status': 'Ошибка загрузки: $e',
        'source': 'none',
      };
    }
  }
}