
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/audiobook.dart';
import 'book_image_service.dart';
import 'google_drive_service.dart';

class AudiobookService {
  static const String _progressKey = 'audiobook_progress';
  static const String _favoritesKey = 'favorite_audiobooks';
  static const String _offlineAudiobooksKey = 'offline_audiobooks';
  
  final GoogleDriveService _driveService = GoogleDriveService();

  Future<List<Audiobook>> getAudiobooks() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    try {
      if (isOnline) {
        // Онлайн режим - загружаем из Google Drive и локального конфига
        await _driveService.initialize();
        final onlineAudiobooks = await _getOnlineAudiobooks();
        final localAudiobooks = await _getLocalAudiobooks();
        
        // Объединяем и сохраняем для оффлайн режима
        final allAudiobooks = [...localAudiobooks, ...onlineAudiobooks];
        await _saveOfflineAudiobooks(allAudiobooks);
        
        return allAudiobooks;
      } else {
        // Оффлайн режим - загружаем из кэша
        return await _getOfflineAudiobooks();
      }
    } catch (e) {
      // Fallback на оффлайн данные
      return await _getOfflineAudiobooks();
    }
  }

  // В методе _getLocalAudiobooks() нужно изменить логику:

Future<List<Audiobook>> _getLocalAudiobooks() async {
  try {
    final String configString = await rootBundle.loadString('assets/config/audiobooks.json');
    final Map<String, dynamic> config = json.decode(configString);
    
    final List<dynamic> audiobooksJson = config['audiobooks'] ?? [];
    final List<Audiobook> audiobooks = [];
    
    for (final json in audiobooksJson) {
      final audiobook = Audiobook.fromJson(json);
      
      // Если coverPath пустой или это тема (не URL и не путь к файлу)
      String finalCoverPath = audiobook.coverPath;
      
      if (audiobook.coverPath.isEmpty) {
        // Если пустой, используем 'philosophy' по умолчанию
        finalCoverPath = await BookImageService.getStableBookImage(
          audiobook.id, 
          'philosophy'
        );
      } else if (!audiobook.coverPath.startsWith('http') && 
                 !audiobook.coverPath.startsWith('assets/')) {
        // Если это тема (например "pagan", "nordic"), используем её
        finalCoverPath = await BookImageService.getStableBookImage(
          audiobook.id, 
          audiobook.coverPath  // ← Используем тему из конфигурации
        );
      }
      // Если это URL или путь к файлу - оставляем как есть
      
      final updatedAudiobook = Audiobook(
        id: audiobook.id,
        title: audiobook.title,
        author: audiobook.author,
        coverPath: finalCoverPath,  // ← Обновленный путь
        chapters: audiobook.chapters,
        totalDuration: audiobook.totalDuration,
        description: audiobook.description,
      );
      audiobooks.add(updatedAudiobook);
    }
    
    return audiobooks;
  } catch (e) {
    return await _scanAudiobookDirectory();
  }
}

  Future<List<Audiobook>> _getOnlineAudiobooks() async {
    try {
      final driveFiles = await _driveService.getAudiobookFiles();
      final List<Audiobook> audiobooks = [];
      
      // Группируем файлы по папкам (аудиокнигам)
      final Map<String, List<dynamic>> bookFolders = {};
      
      for (final file in driveFiles) {
        if (file.mimeType == 'application/vnd.google-apps.folder') {
          bookFolders[file.name!] = [];
        }
      }
      
      for (final file in driveFiles) {
        if (file.mimeType?.contains('audio') == true) {
          // Ищем родительскую папку
          for (final folderName in bookFolders.keys) {
            if (file.parents?.any((parent) => parent == folderName) == true) {
              bookFolders[folderName]!.add(file);
              break;
            }
          }
        }
      }
      
      // Создаем аудиокниги из найденных папок
      for (final entry in bookFolders.entries) {
        final bookName = entry.key;
        final files = entry.value;
        
        if (files.isNotEmpty) {
          final chapters = <AudiobookChapter>[];
          files.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
          
          for (int i = 0; i < files.length; i++) {
            final file = files[i];
            final chapterTitle = _formatChapterTitle(file.name ?? '', i + 1);
            
            chapters.add(AudiobookChapter(
              title: chapterTitle,
              filePath: '', // Для стриминга не используется
              duration: const Duration(minutes: 30), // Примерная длительность
              chapterNumber: i + 1,
              driveFileId: file.id,
              isStreamable: true,
            ));
          }
          
          final totalDuration = Duration(
            milliseconds: chapters.fold(0, (sum, chapter) => sum + chapter.duration.inMilliseconds),
          );
          
          final coverPath = await BookImageService.getStableBookImage(bookName, 'pagan');
          
          audiobooks.add(Audiobook(
            id: 'drive_$bookName',
            title: _formatBookTitle(bookName),
            author: 'Google Drive',
            coverPath: coverPath,
            chapters: chapters,
            totalDuration: totalDuration,
            description: 'Аудиокнига из Google Drive',
          ));
        }
      }
      
      return audiobooks;
    } catch (e) {
      print('Ошибка загрузки аудиокниг из Google Drive: $e');
      return [];
    }
  }

  Future<void> _saveOfflineAudiobooks(List<Audiobook> audiobooks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final audiobooksJson = audiobooks.map((book) => book.toJson()).toList();
      await prefs.setString(_offlineAudiobooksKey, json.encode(audiobooksJson));
    } catch (e) {
      print('Ошибка сохранения оффлайн аудиокниг: $e');
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
      print('Ошибка загрузки оффлайн аудиокниг: $e');
    }
    
    // Fallback на локальные аудиокниги
    return await _getLocalAudiobooks();
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
        return await _driveService.getFileStreamUrl(chapter.driveFileId!);
      }
      
      return null;
    } else {
      // Локальный файл
      return chapter.filePath;
    }
  }

  Future<List<Audiobook>> _scanAudiobookDirectory() async {
    final List<Audiobook> audiobooks = [];
    
    try {
      // Получаем список аудиокниг из assets
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      
      // Фильтруем файлы аудиокниг
      final audiobookFiles = manifestMap.keys
          .where((String key) => key.startsWith('assets/audiobooks/'))
          .toList();
      
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
      
      // Создаем аудиокниги из найденных папок
      for (final entry in bookFolders.entries) {
        final bookName = entry.key;
        final files = entry.value;
        
        // Ищем обложку или используем BookImageService
        String coverPath;
        final localCoverFile = files.firstWhere(
          (file) => file.contains('cover.') && 
                   (file.endsWith('.jpg') || file.endsWith('.png')),
          orElse: () => '',
        );
        
        if (localCoverFile.isNotEmpty) {
          coverPath = localCoverFile;
        } else {
          // Используем BookImageService для генерации обложки
          coverPath = await BookImageService.getStableBookImage(bookName, 'pagan');
        }
        
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
            author: 'Неизвестный автор',
            coverPath: coverPath,
            chapters: chapters,
            totalDuration: totalDuration,
          ));
        }
      }
      
    } catch (e) {
      print('Ошибка при сканировании аудиокниг: $e');
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
      print('Ошибка при сохранении прогресса: $e');
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
      print('Ошибка при загрузке прогресса: $e');
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
      print('Ошибка при загрузке карты прогресса: $e');
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
      print('Ошибка при добавлении в избранное: $e');
    }
  }

  Future<void> removeFromFavorites(String audiobookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavorites();
      
      favorites.remove(audiobookId);
      await prefs.setStringList(_favoritesKey, favorites);
    } catch (e) {
      print('Ошибка при удалении из избранного: $e');
    }
  }

  Future<List<String>> getFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_favoritesKey) ?? [];
    } catch (e) {
      print('Ошибка при загрузке избранного: $e');
      return [];
    }
  }

  Future<bool> isFavorite(String audiobookId) async {
    final favorites = await getFavorites();
    return favorites.contains(audiobookId);
  }
}
