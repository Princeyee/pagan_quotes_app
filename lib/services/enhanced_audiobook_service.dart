import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audiobook.dart';
import 'book_image_service.dart';
import 'public_google_drive_service.dart';

class EnhancedAudiobookService {
  static const String _progressKey = 'audiobook_progress';
  static const String _favoritesKey = 'favorite_audiobooks';
  static const String _offlineAudiobooksKey = 'offline_audiobooks';
  static const String _preloadedChaptersKey = 'preloaded_chapters';
  
  final PublicGoogleDriveService _driveService = PublicGoogleDriveService();
  final Map<String, String> _preloadedFiles = {}; // fileId -> localPath

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
        
        final coverPath = await BookImageService.getStableBookImage(folderName, 'pagan');
        
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

  // УЛУЧШЕННЫЙ МЕТОД ПОЛУЧЕНИЯ URL С КЕШИРОВАНИЕМ И ПРОГРЕССИВНОЙ ЗАГРУЗКОЙ
  Future<String?> getPlayableUrl(AudiobookChapter chapter) async {
    if (chapter.isStreamable && chapter.driveFileId != null) {
      final fileName = '${chapter.driveFileId}.mp3';
      
      print('🔍 Поиск файла: $fileName');
      
      // 1. Проверяем полностью загруженный кеш
      final cachedPath = await _driveService.getCachedFilePath(fileName);
      if (cachedPath != null && await File(cachedPath).exists()) {
        print('✅ Файл найден в полном кеше: $cachedPath');
        return cachedPath;
      }
      
      // 2. Проверяем предзагруженные файлы в памяти
      if (_preloadedFiles.containsKey(chapter.driveFileId)) {
        final preloadedPath = _preloadedFiles[chapter.driveFileId]!;
        if (await File(preloadedPath).exists()) {
          print('✅ Файл найден в предзагрузке (память): $preloadedPath');
          return preloadedPath;
        } else {
          // Файл был удален, убираем из кеша
          _preloadedFiles.remove(chapter.driveFileId);
          await _savePreloadedChapters();
        }
      }
      
      // 3. Проверяем прогрессивную загрузку
      final progressivePath = await _driveService.getPartialFilePath(chapter.driveFileId!);
      if (progressivePath != null && await File(progressivePath).exists()) {
        final isPlayable = await _driveService.isFilePlayable(chapter.driveFileId!);
        if (isPlayable) {
          print('✅ Файл найден в прогрессивной загрузке: $progressivePath');
          _preloadedFiles[chapter.driveFileId!] = progressivePath;
          await _savePreloadedChapters();
          return progressivePath;
        }
      }
      
      // 4. Если онлайн, начинаем прогрессивную загрузку
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        print('🔄 Начинаем прогрессивную загрузку файла: $fileName');
        
        try {
          // Используем прогрессивную загрузку вместо обычной предзагрузки
          final progressiveUrl = await _driveService.startProgressiveDownload(
            chapter.driveFileId!,
            fileName,
          );
          
          if (progressiveUrl != null) {
            // Получаем реальный путь к файлу для кеширования
            final realPath = await _driveService.getPartialFilePath(chapter.driveFileId!);
            if (realPath != null) {
              _preloadedFiles[chapter.driveFileId!] = realPath;
              await _savePreloadedChapters();
            }
            print('✅ Файл добавлен в прогрессивную загрузку: $progressiveUrl');
            return progressiveUrl;
          }
        } catch (e) {
          print('❌ Ошибка прогрессивной загрузки: $e');
        }
        
        // Если прогрессивная загрузка не удалась, возвращаем стриминговый URL
        print('🌐 Используем стриминг: ${chapter.driveFileId}');
        return _driveService.getFileDownloadUrl(chapter.driveFileId!);
      }
      
      return null;
    }
    
    return null;
  }

  // ПРЕДЗАГРУЗКА СЛЕДУЮЩИХ ГЛАВ
  Future<void> preloadNextChapters(Audiobook audiobook, int currentChapterIndex, {int count = 2}) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    for (int i = 1; i <= count; i++) {
      final nextIndex = currentChapterIndex + i;
      if (nextIndex < audiobook.chapters.length) {
        final nextChapter = audiobook.chapters[nextIndex];
        
        if (nextChapter.driveFileId != null) {
          final fileName = '${nextChapter.driveFileId}.mp3';
          
          // Проверяем, не загружен ли уже файл
          final cachedPath = await _driveService.getCachedFilePath(fileName);
          if (cachedPath == null && !_preloadedFiles.containsKey(nextChapter.driveFileId)) {
            print('🔄 Предзагружаем следующую главу: ${nextChapter.title}');
            
            // Запускаем прогрессивную загрузку в фоне
            _driveService.startProgressiveDownload(
              nextChapter.driveFileId!,
              fileName,
            ).then((serverUrl) {
              if (serverUrl != null) {
                // Получаем реальный путь к файлу
                _driveService.getPartialFilePath(nextChapter.driveFileId!).then((realPath) {
                  if (realPath != null) {
                    _preloadedFiles[nextChapter.driveFileId!] = realPath;
                    _savePreloadedChapters();
                    print('✅ Предзагружена глава: ${nextChapter.title}');
                  }
                });
              }
            }).catchError((e) {
              print('❌ Ошибка предзагрузки главы "${nextChapter.title}": $e');
            });
          }
        }
      }
    }
  }

  // Сохранение информации о предзагруженных главах
  Future<void> _savePreloadedChapters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preloadedChaptersKey, json.encode(_preloadedFiles));
    } catch (e) {
      print('Ошибка сохранения предзагруженных глав: $e');
    }
  }

  // Загрузка информации о предзагруженных главах
  Future<void> _loadPreloadedChapters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final preloadedString = prefs.getString(_preloadedChaptersKey);
      
      if (preloadedString != null) {
        final Map<String, dynamic> preloadedMap = json.decode(preloadedString);
        _preloadedFiles.clear();
        
        // Проверяем, что файлы действительно существуют
        for (final entry in preloadedMap.entries) {
          final filePath = entry.value as String;
          if (await File(filePath).exists()) {
            _preloadedFiles[entry.key] = filePath;
          }
        }
        
        // Сохраняем обновленный список
        await _savePreloadedChapters();
      }
    } catch (e) {
      print('Ошибка загрузки предзагруженных глав: $e');
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

  // Инициализация сервиса
  Future<void> initialize() async {
    await _loadPreloadedChapters();
  }

  // Очистка кеша
  Future<void> clearCache() async {
    try {
      _preloadedFiles.clear();
      await _driveService.clearCache();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_preloadedChaptersKey);
      
      print('🗑️ Кеш очищен');
    } catch (e) {
      print('Ошибка очистки кеша: $e');
    }
  }
}