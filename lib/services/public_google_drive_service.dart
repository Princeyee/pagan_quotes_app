import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'progressive_download_service.dart';
import 'local_audio_server.dart';

class PublicGoogleDriveService {
  String _lastError = '';
  bool _isInitialized = false;
  
  // ID публичной папки с аудиокнигами
  static const String _folderId = '1b7PFjESsnY6bsn9rDmdAe10AU0pQNwiM';
  
  // API ключ для Google Drive
  static const String _apiKey = 'AIzaSyD1sGI81Bep1Nm_zWNtQctmGbjO1eKQ24M';
  
  // Кеш
  static const String _filesCacheKey = 'public_drive_files_cache';
  static const String _filesCacheTimestampKey = 'public_drive_files_cache_timestamp';
  static const Duration _cacheValidity = Duration(days: 1);
  
  final Dio _dio = Dio();
  List<Map<String, dynamic>>? _cachedFiles;
  List<Map<String, dynamic>>? _cachedFolders;
  DateTime? _cacheTimestamp;
  
  // Сервисы для прогрессив��ой загрузки
  final ProgressiveDownloadService _progressiveDownloadService = ProgressiveDownloadService();
  final LocalAudioServer _localServer = LocalAudioServer.instance;

  Future<bool> initialize() async {
    try {
      _lastError = '';
      _isInitialized = false;
      
      print('🔧 Инициализация Google Drive сервиса...');
      
      // Загружаем кеш
      await _loadFilesCache();
      
      // Запускаем локальный сервер
      final serverStarted = await _localServer.start();
      if (!serverStarted) {
        print('❌ Не удалось запустить локальный сервер');
        _lastError = 'Не удалось запустить локальный сервер';
      } else {
        print('✅ Локальный сервер запущен на порту ${_localServer.port}');
      }
      
      // Проверяем доступ к API
      if (await isOnline()) {
        print('🌐 Проверяем доступ к Google Drive API...');
        final testUrl = 'https://www.googleapis.com/drive/v3/files/$_folderId?key=$_apiKey';
        
        try {
          final response = await _dio.get(testUrl);
          if (response.statusCode == 200) {
            print('✅ Google Drive API доступен');
            _isInitialized = true;
            return true;
          } else {
            print('❌ Google Drive API недоступен: ${response.statusCode}');
            _lastError = 'Google Drive API недоступен: ${response.statusCode}';
          }
        } catch (e) {
          print('❌ Ошибка доступа к Google Drive API: $e');
          _lastError = 'Ошибка доступа к Google Drive API: $e';
        }
      } else {
        print('❌ Нет интернет соединения');
        _lastError = 'Нет интернет соединения';
      }
      
      // Если есть кеш, считаем что инициализация успешна
      if (_cachedFiles != null && _cachedFiles!.isNotEmpty) {
        print('✅ Используем кешированные данные');
        _isInitialized = true;
        return true;
      }
      
      print('❌ Инициализация не удалась');
      return false;
    } catch (e) {
      print('❌ Критическая ошибка инициализации: $e');
      _lastError = 'Ошибка инициализации: $e';
      return false;
    }
  }

  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Получаем структуру папок и файлов
  Future<Map<String, List<Map<String, dynamic>>>> getAudiobooksByFolders() async {
    if (!await isOnline()) {
      return {};
    }

    try {
      // Сначала получаем все папки
      final foldersUrl = 'https://www.googleapis.com/drive/v3/files'
          '?q=${Uri.encodeComponent("'$_folderId' in parents and mimeType='application/vnd.google-apps.folder'")}'
          '&key=$_apiKey'
          '&fields=files(id,name)';
      
      final foldersResponse = await _dio.get(foldersUrl);
      
      if (foldersResponse.statusCode != 200) {
        _lastError = 'Ошибка получения папок: ${foldersResponse.statusCode}';
        return {};
      }
      
      final foldersData = foldersResponse.data;
      final folders = List<Map<String, dynamic>>.from(foldersData['files'] ?? []);
      
      final Map<String, List<Map<String, dynamic>>> result = {};
      
      // Для каждой папки получаем аудиофайлы
      for (final folder in folders) {
        final folderId = folder['id'] as String;
        final folderName = folder['name'] as String;
        
        final filesUrl = 'https://www.googleapis.com/drive/v3/files'
            '?q=${Uri.encodeComponent("'$folderId' in parents")}'
            '&key=$_apiKey'
            '&fields=files(id,name,mimeType,size,webContentLink)';
        
        final filesResponse = await _dio.get(filesUrl);
        
        if (filesResponse.statusCode == 200) {
          final filesData = filesResponse.data;
          final files = List<Map<String, dynamic>>.from(filesData['files'] ?? []);
          
          // Фильтруем только аудиофайлы
          final audioFiles = files.where((file) {
            final mimeType = file['mimeType'] as String? ?? '';
            final fileName = file['name'] as String? ?? '';
            return mimeType.startsWith('audio/') || 
                   fileName.toLowerCase().endsWith('.mp3') ||
                   fileName.toLowerCase().endsWith('.m4a') ||
                   fileName.toLowerCase().endsWith('.wav');
          }).toList();
          
          if (audioFiles.isNotEmpty) {
            // Сортируем файлы по имени
            audioFiles.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
            result[folderName] = audioFiles;
          }
        }
      }
      
      return result;
    } catch (e) {
      _lastError = 'Ошибка получения структуры папок: $e';
      return {};
    }
  }

  String getFileDownloadUrl(String fileId) {
    return 'https://drive.google.com/uc?id=$fileId&export=download';
  }

  Future<String?> getCachedFilePath(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/audiobook_cache/$fileName';
      
      if (await File(filePath).exists()) {
        return filePath;
      }
    } catch (e) {
      // Игнорируем ошибки кеша
    }
    
    return null;
  }

  // Предзагрузка файла в кеш (старый метод для совместимости)
  Future<String?> preloadFile(String fileId, String fileName, {Function(double)? onProgress}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audiobook_cache');
      
      // Создаем папку кеша если её нет
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      
      final filePath = '${cacheDir.path}/$fileName';
      final file = File(filePath);
      
      // Если файл уже есть в кеше, во��вращаем путь
      if (await file.exists()) {
        return filePath;
      }
      
      // Скачиваем файл
      final downloadUrl = getFileDownloadUrl(fileId);
      
      final response = await _dio.get(
        downloadUrl,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );
      
      if (response.statusCode == 200) {
        final contentLength = response.headers.value('content-length');
        final total = contentLength != null ? int.parse(contentLength) : 0;
        
        int downloaded = 0;
        final sink = file.openWrite();
        
        await for (final chunk in response.data.stream) {
          sink.add(chunk);
          downloaded += (chunk as List<int>).length;
          
          if (total > 0 && onProgress != null) {
            onProgress(downloaded / total);
          }
        }
        
        await sink.close();
        return filePath;
      }
    } catch (e) {
      print('Ошибка предзагрузки файла: $e');
    }
    
    return null;
  }

  /// НОВЫЕ МЕТОДЫ ДЛЯ ПРОГРЕССИВНОЙ ЗАГРУЗКИ
  
  /// Начать прогрессивную загрузку файла
  Future<String?> startProgressiveDownload(String fileId, String fileName, {Function(DownloadProgress)? onProgress}) async {
    try {
      // Сначала проверяем, не загружается ли уже этот файл
      final existingPath = await _progressiveDownloadService.getPartialFilePath(fileId);
      if (existingPath != null && await File(existingPath).exists()) {
        final isPlayable = await _progressiveDownloadService.isPlayable(fileId);
        if (isPlayable) {
          // Файл уже частично загружен и готов к воспроизведению
          final serverUrl = _localServer.registerFile(fileId, existingPath);
          print('🎵 Используем частично загруженный файл: $serverUrl');
          return serverUrl;
        }
      }
      
      final downloadUrl = getFileDownloadUrl(fileId);
      
      // Подписываемся на прогресс загрузки
      if (onProgress != null) {
        _progressiveDownloadService.getProgressStream(fileId).listen(onProgress);
      }
      
      // Начинаем загрузку (или продолжае�� существующую)
      final filePath = await _progressiveDownloadService.startProgressiveDownload(
        fileId: fileId,
        downloadUrl: downloadUrl,
        fileName: fileName,
        resumeIfExists: true, // Важно: продолжаем загрузку если файл существует
      );
      
      if (filePath != null) {
        // Регистрируем файл в локальном сервере
        final serverUrl = _localServer.registerFile(fileId, filePath);
        print('🎵 Файл зарегистрирован в локальном сервере: $serverUrl');
        return serverUrl;
      }
      
      return null;
    } catch (e) {
      print('❌ Ошибка прогрессивной загрузки: $e');
      return null;
    }
  }
  
  /// Получить поток прогресса загрузки
  Stream<DownloadProgress> getDownloadProgressStream(String fileId) {
    return _progressiveDownloadService.getProgressStream(fileId);
  }
  
  /// Проверить, можно ли на��ать воспроизведение
  Future<bool> isFilePlayable(String fileId) async {
    return await _progressiveDownloadService.isPlayable(fileId);
  }

  /// Получить путь к частично загруженному файлу
  Future<String?> getPartialFilePath(String fileId) async {
    return await _progressiveDownloadService.getPartialFilePath(fileId);
  }
  
  /// Получить URL для воспроизведения (локальный сервер или прямая ссылка)
  Future<String?> getPlayableUrl(String fileId, String fileName) async {
    // Сначала проверяем полностью загруженный файл в старом кеше
    final cachedPath = await getCachedFilePath(fileName);
    if (cachedPath != null) {
      print('✅ Используем полностью кешированный файл: $cachedPath');
      return cachedPath;
    }
    
    // Проверяем частично загруженный файл
    final partialPath = await _progressiveDownloadService.getPartialFilePath(fileId);
    if (partialPath != null) {
      final isPlayable = await _progressiveDownloadService.isPlayable(fileId);
      if (isPlayable) {
        // Регистрируем в локальном сервере и возвращаем URL
        final serverUrl = _localServer.registerFile(fileId, partialPath);
        print('🎵 Используем частично загруженный файл через локальный сервер: $serverUrl');
        return serverUrl;
      }
    }
    
    // Если онлайн, начинаем прогрессивную загрузку
    if (await isOnline()) {
      print('🔄 Начинаем прогрессивную загрузку: $fileName');
      return await startProgressiveDownload(fileId, fileName);
    }
    
    return null;
  }
  
  /// Приостановить загрузку
  void pauseDownload(String fileId) {
    _progressiveDownloadService.pauseDownload(fileId);
  }
  
  /// Отменить загрузку
  Future<void> cancelDownload(String fileId) async {
    await _progressiveDownloadService.cancelDownload(fileId);
    _localServer.unregisterFile(fileId);
  }
  
  /// Получить информацию о частично загруженных файлах
  List<PartialFileInfo> getPartialDownloads() {
    return _progressiveDownloadService.getPartialFiles();
  }

  // Проверка валидности кеша
  bool _isCacheValid() {
    if (_cachedFiles == null || _cachedFiles!.isEmpty || _cacheTimestamp == null) {
      return false;
    }

    final now = DateTime.now();
    final difference = now.difference(_cacheTimestamp!);
    return difference < _cacheValidity;
  }

  // Сохранение кеша
  Future<void> _saveFilesCache(List<Map<String, dynamic>> files) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final String jsonFiles = jsonEncode(files);
      await prefs.setString(_filesCacheKey, jsonFiles);
      await prefs.setString(_filesCacheTimestampKey, DateTime.now().toIso8601String());
    } catch (e) {
      // Игнорируем ошибки кеша
    }
  }

  // Загрузка кеша
  Future<void> _loadFilesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final timestampString = prefs.getString(_filesCacheTimestampKey);
      if (timestampString != null) {
        _cacheTimestamp = DateTime.parse(timestampString);
      }
      
      final jsonFiles = prefs.getString(_filesCacheKey);
      if (jsonFiles != null) {
        final List<dynamic> filesList = jsonDecode(jsonFiles);
        _cachedFiles = List<Map<String, dynamic>>.from(filesList);
      }
    } catch (e) {
      _cachedFiles = null;
      _cacheTimestamp = null;
    }
  }

  // Очистка кеша (обновленная версия)
  Future<void> clearCache() async {
    try {
      _cachedFiles = null;
      _cacheTimestamp = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_filesCacheKey);
      await prefs.remove(_filesCacheTimestampKey);

      // Очищаем старый кеш
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audiobook_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      
      // Очищаем прогрессивный кеш
      await _progressiveDownloadService.clearCache();
      
    } catch (e) {
      // Игнорируем ошибки очистки кеша
    }
  }
  
  /// Освобождение ресурсов
  Future<void> dispose() async {
    _progressiveDownloadService.dispose();
    await _localServer.stop();
  }

  // Геттеры для диагностики
  String getLastError() => _lastError;
  bool isServiceInitialized() => _isInitialized;
  bool get isLocalServerRunning => _localServer.isRunning;
  int get localServerPort => _localServer.port;
}