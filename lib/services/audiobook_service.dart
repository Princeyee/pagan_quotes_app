import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/audiobook.dart';
import 'book_image_service.dart';
import 'public_google_drive_service.dart';
import 'text_file_service.dart';

class AudiobookService {
  static const String _progressKey = 'audiobook_progress';
  static const String _favoritesKey = 'favorite_audiobooks';
  static const String _offlineAudiobooksKey = 'offline_audiobooks';
  
  final PublicGoogleDriveService _driveService = PublicGoogleDriveService();

  Future<List<Audiobook>> getAudiobooks() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    try {
      if (isOnline) {
        // Онлайн режим - загружаем только из Google Drive
        final onlineAudiobooks = await _getOnlineAudiobooks();
        
        if (onlineAudiobooks.isNotEmpty) {
          // Сохраняем для оффлайн режима
          await _saveOfflineAudiobooks(onlineAudiobooks);
          return onlineAudiobooks;
        } else {
          // Возвращаем кеш если есть
          return await _getOfflineAudiobooks();
        }
      } else {
        // Оффлайн режим - используем только кеш
        return await _getOfflineAudiobooks();
      }
    } catch (e) {
      // Fallback на кешированные данные
      return await _getOfflineAudiobooks();
    }
  }

  Future<List<Audiobook>> _getOnlineAudiobooks() async {
    try {
      // Инициализируем публичный Google Drive сервис
      final isInitialized = await _driveService.initialize();
      if (!isInitialized) {
        return [];
      }
      
      // Получаем структуру папок с аудиофайлами
      final folderStructure = await _driveService.getAudiobooksByFolders();
      if (folderStructure.isEmpty) {
        return [];
      }
      
      final List<Audiobook> audiobooks = [];
      
      // Создаем аудиокниги из папок
      for (final entry in folderStructure.entries) {
        final folderName = entry.key;
        final files = entry.value;
        
        if (files.isEmpty) continue;
        
        final chapters = <AudiobookChapter>[];
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          final fileName = file['name'] as String;
          final chapterTitle = _formatChapterTitle(fileName, i + 1);
          
          chapters.add(AudiobookChapter(
            title: chapterTitle,
            filePath: '', // Для стриминга не используется
            duration: const Duration(minutes: 30), // Примерная длительность
            chapterNumber: i + 1,
            driveFileId: file['id'] as String,
            isStreamable: true,
          ));
        }
        
        final totalDuration = Duration(
          milliseconds: chapters.fold(0, (sum, chapter) => sum + chapter.duration.inMilliseconds),
        );
        
        // Определяем ID и категорию для обложки
        String bookId = folderName;
        String category = 'pagan'; // по умолчанию
        
        // Пытаемся найти соответствующую текстовую книгу
        try {
          final textService = TextFileService();
          final textBooks = await textService.loadBookSources();
          
          // Ищем книгу с похожим названием
          for (final textBook in textBooks) {
            final textTitle = textBook.title.toLowerCase().trim();
            final audioTitle = folderName.toLowerCase().trim();
            
            if (textTitle == audioTitle || 
                textTitle.contains(audioTitle) || 
                audioTitle.contains(textTitle)) {
              bookId = textBook.id;
              category = textBook.category;
              print('🎨 Найдена соответствующая книга: ${textBook.title} (${textBook.category})');
              break;
            }
          }
        } catch (e) {
          print('Ошибка поиска текстовой книги для обложки: $e');
        }
        
        final coverPath = await BookImageService.getStableBookImage(bookId, category);
        
        audiobooks.add(Audiobook(
          id: 'drive_${folderName.replaceAll(' ', '_')}',
          title: _formatBookTitle(folderName),
          author: 'Аудиокнига',
          coverPath: coverPath,
          chapters: chapters,
          totalDuration: totalDuration,
          description: 'Аудиокнига из Google Drive',
        ));
      }
      
      return audiobooks;
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveOfflineAudiobooks(List<Audiobook> audiobooks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final audiobooksJson = audiobooks.map((book) => book.toJson()).toList();
      await prefs.setString(_offlineAudiobooksKey, json.encode(audiobooksJson));
    } catch (e) {
      // Игнорируем ошибки сохранения
    }
  }

  Future<List<Audiobook>> _getOfflineAudiobooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final audiobooksString = prefs.getString(_offlineAudiobooksKey);
      
      if (audiobooksString != null) {
        final List<dynamic> audiobooksJson = json.decode(audiobooksString);
        return audiobooksJson.map((json) => Audiobook.fromJson(json)).toList();
      }
    } catch (e) {
      // Игнорируем ошибки загрузки
    }
    
    return [];
  }

  Future<String?> getPlayableUrl(AudiobookChapter chapter) async {
    if (chapter.isStreamable && chapter.driveFileId != null) {
      // Сначала проверяем кэш
      final fileName = '${chapter.driveFileId}.mp3';
      final cachedPath = await _driveService.getCachedFilePath(fileName);
      
      if (cachedPath != null) {
        return cachedPath;
      }
      
      // Если онлайн, получаем стриминговый URL
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        return _driveService.getFileDownloadUrl(chapter.driveFileId!);
      }
      
      return null;
    }
    
    return null; // Убираем поддержку локальных файлов
  }

  String _formatBookTitle(String folderName) {
    // Убираем расширения файлов и лишние символы
    String cleanName = folderName
        .replaceAll(RegExp(r'\.(mp3|m4a|wav)$', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
    
    // Капитализируем каждое слово
    return cleanName
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  String _formatChapterTitle(String fileName, int chapterNumber) {
    final nameWithoutExtension = fileName.split('.').first;
    
    // Очищаем имя файла от лишних символов
    String cleanName = nameWithoutExtension
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
    
    // Если в имени файла есть "chapter" или "глава", используем как есть
    if (cleanName.toLowerCase().contains('chapter') ||
        cleanName.toLowerCase().contains('глава') ||
        cleanName.toLowerCase().contains('часть')) {
      return _formatBookTitle(cleanName);
    }
    
    // Если имя файла содержательное (больше 3 символов), используем его
    if (cleanName.length > 3 && !RegExp(r'^\d+$').hasMatch(cleanName)) {
      return _formatBookTitle(cleanName);
    }
    
    // Иначе добавляем номер главы
    return 'Глава $chapterNumber';
  }

  Future<void> saveProgress(String audiobookId, int chapterIndex, Duration position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressMap = await _getProgressMap();
      
      final progress = AudiobookProgress(
        audiobookId: audiobookId,
        chapterIndex: chapterIndex,
        position: position,
        lastPlayed: DateTime.now(),
      );
      
      progressMap[audiobookId] = progress.toJson();
      
      await prefs.setString(_progressKey, json.encode(progressMap));
    } catch (e) {
      // Игнорируем ошибки сохранения прогресса
    }
  }

  Future<AudiobookProgress?> getProgress(String audiobookId) async {
    try {
      final progressMap = await _getProgressMap();
      final progressJson = progressMap[audiobookId];
      
      if (progressJson != null) {
        return AudiobookProgress.fromJson(progressJson);
      }
    } catch (e) {
      // Игнорируем ошибки загрузки прогресса
    }
    
    return null;
  }

  Future<Map<String, dynamic>> _getProgressMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressString = prefs.getString(_progressKey);
      
      if (progressString != null) {
        return Map<String, dynamic>.from(json.decode(progressString));
      }
    } catch (e) {
      // Игнорируем ошибки загрузки карты прогресса
    }
    
    return {};
  }

  Future<void> addToFavorites(String audiobookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavorites();
      
      if (!favorites.contains(audiobookId)) {
        favorites.add(audiobookId);
        await prefs.setStringList(_favoritesKey, favorites);
      }
    } catch (e) {
      // Игнорируем ошибки добавления в избранное
    }
  }

  Future<void> removeFromFavorites(String audiobookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavorites();
      
      favorites.remove(audiobookId);
      await prefs.setStringList(_favoritesKey, favorites);
    } catch (e) {
      // Игнорируем ошибки удаления из избранного
    }
  }

  Future<List<String>> getFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_favoritesKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> isFavorite(String audiobookId) async {
    final favorites = await getFavorites();
    return favorites.contains(audiobookId);
  }
}