import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/audiobook.dart';
import 'book_image_service.dart';
import 'public_google_drive_service.dart';
import 'text_file_service.dart';

class EnhancedAudiobookService {
  static const String _progressKey = 'audiobook_progress';
  static const String _favoritesKey = 'favorite_audiobooks';
  static const String _offlineAudiobooksKey = 'offline_audiobooks';
  static const String _preloadedChaptersKey = 'preloaded_chapters';
  static const String _urlCacheKey = 'audiobook_url_cache';
  
  final PublicGoogleDriveService _driveService = PublicGoogleDriveService();
  final Map<String, String> _preloadedFiles = {}; // fileId -> localPath
  final Map<String, String> _urlCache = {}; // chapterId -> cachedUrl

  Future<List<Audiobook>> getAudiobooks() async {
    print('🔍 EnhancedAudiobookService.getAudiobooks() - начало');
    
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;
    
    print('🌐 Статус подключения: ${isOnline ? "онлайн" : "оффлайн"}');

    try {
      // Загружаем кеш URL при первом обращении
      print('📦 Загружаем кеш URL...');
      await _loadUrlCache();
      print('✅ Кеш URL загружен');
      
      if (isOnline) {
        print('🌐 Онлайн режим - загружаем из Google Drive...');
        // Онлайн режим - загружаем только из Google Drive
        final onlineAudiobooks = await _getOnlineAudiobooks();
        print('📚 Получено аудиокниг из Google Drive: ${onlineAudiobooks.length}');
        
        if (onlineAudiobooks.isNotEmpty) {
          print('💾 Сохраняем для оффлайн режима...');
          // Сохраняем для оффлайн режима
          await _saveOfflineAudiobooks(onlineAudiobooks);
          print('✅ Аудиокниги сохранены в кеш');
          return onlineAudiobooks;
        } else {
          print('⚠️ Нет аудиокниг онлайн, возвращаем кеш...');
          // Возвращаем кеш если есть
          final cachedAudiobooks = await _getOfflineAudiobooks();
          print('📚 Получено аудиокниг из кеша: ${cachedAudiobooks.length}');
          return cachedAudiobooks;
        }
      } else {
        print('📱 Оффлайн режим - используем кеш...');
        // Оффлайн режим - используем только кеш
        final cachedAudiobooks = await _getOfflineAudiobooks();
        print('📚 Получено аудиокниг из кеша: ${cachedAudiobooks.length}');
        return cachedAudiobooks;
      }
    } catch (e) {
      print('❌ Ошибка в getAudiobooks: $e');
      // Fallback на кешированные данные
      final cachedAudiobooks = await _getOfflineAudiobooks();
      print('📚 Fallback: получено аудиокниг из кеша: ${cachedAudiobooks.length}');
      return cachedAudiobooks;
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
          
          // Маппинг названий папок к ID текстовых книг
          final Map<String, String> folderToBookId = {
            'аристотель метафизика': 'aristotle_metaphysics',
            'метафизика': 'aristotle_metaphysics',
            'аристотель этика': 'aristotle_ethics',
            'этика': 'aristotle_ethics',
            'аристотель политика': 'aristotle_politics',
            'политика': 'aristotle_politics',
            'аристотель риторика': 'aristotle_rhetoric',
            'риторика': 'aristotle_rhetoric',
            'платон софист': 'plato_sophist',
            'софист': 'plato_sophist',
            'платон парменид': 'plato_parmenides',
            'парменид': 'plato_parmenides',
            'гомер илиада': 'homer_iliad',
            'илиада': 'homer_iliad',
            'гомер одиссея': 'homer_odyssey',
            'одиссея': 'homer_odyssey',
            'гесиод труды': 'hesiod_labour',
            'труды и дни': 'hesiod_labour',
            'беовульф': 'beowulf',
            'старшая эдда': 'elder_edda',
            'эдда': 'elder_edda',
            'хайдеггер бытие': 'heidegger_being',
            'бытие и время': 'heidegger_being',
            'хайдеггер мыслить': 'heidegger_think',
            'что значит мыслить': 'heidegger_think',
            'ницше антихрист': 'nietzsche_antichrist',
            'антихрист': 'nietzsche_antichrist',
            'ницше веселая': 'nietzsche_gay_science',
            'веселая наука': 'nietzsche_gay_science',
            'ницше заратустра': 'nietzsche_zarathustra',
            'заратустра': 'nietzsche_zarathustra',
            'ницше трагедия': 'nietzsche_tragedy',
            'рождение трагедии': 'nietzsche_tragedy',
            'ницше добро зло': 'nietzsche_beyond',
            'по ту сторону': 'nietzsche_beyond',
            'шопенгауэр мир': 'schopenhauer_world',
            'мир как воля': 'schopenhauer_world',
            'шопенгауэр афоризмы': 'schopenhauer_aphorisms',
            'афоризмы': 'schopenhauer_aphorisms',
            'де бенуа язычник': 'on_being_a_pagan',
            'как можно быть язычником': 'on_being_a_pagan',
            'элиаде священное': 'eliade_sacred',
            'священное и мирское': 'eliade_sacred',
            'элиаде миф': 'eliade_myth',
            'миф о вечном возвращении': 'eliade_myth',
            'эвола империализм': 'evola_imperialism',
            'языческий империализм': 'evola_imperialism',
            'эвола пол': 'evola_sex',
            'метафизика пола': 'evola_sex',
            'эвола руины': 'evola_ruins',
            'люди и руины': 'evola_ruins',
            'аскр идентичность': 'askr_svarte_pagan_identity',
            'идентичность язычника': 'askr_svarte_pagan_identity',
            'аскр приближение': 'askr_svarte_priblizhenie',
            'приближение и окружение': 'askr_svarte_priblizhenie',
            'аскр полемос': 'askr_svarte_polemos',
            'polemos': 'askr_svarte_polemos',
          };
          
          // Ищем соответствующую текстовую книгу
          String? matchedBookId;
          for (final entry in folderToBookId.entries) {
            if (folderName.toLowerCase().contains(entry.key.toLowerCase()) ||
                entry.key.toLowerCase().contains(folderName.toLowerCase())) {
              matchedBookId = entry.value;
              break;
            }
          }
          
          if (matchedBookId != null) {
            // Находим текстовую книгу по ID
            for (final textBook in textBooks) {
              if (textBook.id == matchedBookId) {
                bookId = textBook.id;
                category = textBook.category;
                print('🎨 Найдена соответствующая книга: ${textBook.title} (${textBook.category})');
                break;
              }
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

  // УПРОЩЕННЫЙ И НАДЕЖНЫЙ МЕТОД ПОЛУЧЕНИЯ URL
  Future<String?> getPlayableUrl(AudiobookChapter chapter) async {
    if (chapter.isStreamable && chapter.driveFileId != null) {
      final fileName = '${chapter.driveFileId}.mp3';
      final chapterId = '${chapter.driveFileId}';
      
      print('🔍 Поиск файла: $fileName');
      
      try {
        // 1. Проверяем кеш URL
        if (_urlCache.containsKey(chapterId)) {
          final cachedUrl = _urlCache[chapterId]!;
          print('✅ Используем кешированный URL: $cachedUrl');
          return cachedUrl;
        }
        
        // 2. Проверяем полностью загруженный кеш
        final cachedPath = await _driveService.getCachedFilePath(fileName);
        if (cachedPath != null && await File(cachedPath).exists()) {
          print('✅ Файл найден в полном кеше: $cachedPath');
          _urlCache[chapterId] = cachedPath;
          return cachedPath;
        }
        
        // 3. Проверяем интернет соединение
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult == ConnectivityResult.none) {
          print('❌ Нет интернет соединения');
          return null;
        }
        
        // 4. Возвращаем прямую ссылку на Google Drive
        final directUrl = _driveService.getFileDownloadUrl(chapter.driveFileId!);
        print('🌐 Используем прямую ссылку: $directUrl');
        
        // Кешируем URL
        _urlCache[chapterId] = directUrl;
        
        // Сохраняем кеш если добавили новую запись
        if (_urlCache.length % 5 == 0) { // Сохраняем каждые 5 новых URL
          _saveUrlCache();
        }
        
        return directUrl;
        
      } catch (e) {
        print('❌ Ошибка получения URL: $e');
        return null;
      }
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
      
      // Создаем ключ для конкретной главы
      final chapterKey = '${audiobookId}_chapter_$chapterIndex';
      
      final progress = AudiobookProgress(
        audiobookId: audiobookId,
        chapterIndex: chapterIndex,
        position: position,
        lastPlayed: DateTime.now(),
      );
      
      // Сохраняем прогресс для конкретной главы
      progressMap[chapterKey] = progress.toJson();
      
      // Также сохраняем общий прогресс аудиокниги
      progressMap[audiobookId] = progress.toJson();
      
      await prefs.setString(_progressKey, json.encode(progressMap));
    } catch (e) {
      // Игнорируем ошибки сохранения прогресса
    }
  }

  Future<AudiobookProgress?> getProgress(String audiobookId, {int? chapterIndex}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressMap = await _getProgressMap();
      
      // Если указан конкретный индекс главы, ищем прогресс для неё
      if (chapterIndex != null) {
        final chapterKey = '${audiobookId}_chapter_$chapterIndex';
        final chapterProgress = progressMap[chapterKey];
        if (chapterProgress != null) {
          return AudiobookProgress.fromJson(chapterProgress);
        }
      }
      
      // Иначе возвращаем общий прогресс аудиокниги
      final progress = progressMap[audiobookId];
      if (progress != null) {
        return AudiobookProgress.fromJson(progress);
      }
      
      return null;
    } catch (e) {
      return null;
    }
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
      _urlCache.clear();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_preloadedChaptersKey);
      await prefs.remove(_urlCacheKey);
      
      print('🧹 Кеш очищен');
    } catch (e) {
      print('Ошибка очистки кеша: $e');
    }
  }

  Future<void> _loadUrlCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final urlCacheString = prefs.getString(_urlCacheKey);
      
      if (urlCacheString != null) {
        final Map<String, dynamic> urlCacheMap = json.decode(urlCacheString);
        _urlCache.clear();
        
        for (final entry in urlCacheMap.entries) {
          _urlCache[entry.key] = entry.value as String;
        }
        
        print('📦 Загружен кеш URL: ${_urlCache.length} записей');
      }
    } catch (e) {
      print('Ошибка загрузки кеша URL: $e');
    }
  }

  Future<void> _saveUrlCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_urlCacheKey, json.encode(_urlCache));
      print('💾 Сохранен кеш URL: ${_urlCache.length} записей');
    } catch (e) {
      print('Ошибка сохранения кеша URL: $e');
    }
  }
}