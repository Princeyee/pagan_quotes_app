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
  
  // Сервисы для прогрессивной загрузки
  final ProgressiveDownloadService _progressiveDownloadService = ProgressiveDownloadService();
  final LocalAudioServer _localServer = LocalAudioServer.instance;

  Future<bool> initialize() async {
    try {
      _lastError = '';
      _isInitialized = false;
      
      // Загружаем кеш
      await _loadFilesCache();
      
      // Запускаем локальный сервер
      await _localServer.start();
      
      // Проверяем доступ к API
      if (await isOnline()) {
        final testUrl = 'https://www.googleapis.com/drive/v3/files/$_folderId?key=$_apiKey';
        
        try {
          final response = await _dio.get(testUrl);
          if (response.statusCode == 200) {
            _isInitialized = true;
            return true;
          }
        } catch (e) {
          _lastError = 'Ошибка доступа к Google Drive API: $e';
        }
      }
      
      // Если есть кеш, считаем что инициализация успешна
      if (_cachedFiles != null && _cachedFiles!.isNotEmpty) {
        _isInitialized = true;
        return true;
      }
      
      return false;
    } catch (e) {
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

  // Предзагрузка файла в кеш
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
      
      // Если файл уже есть в кеше, возвращаем путь
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

  // Очистка кеша
  Future<void> clearCache() async {
    try {
      _cachedFiles = null;
      _cacheTimestamp = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_filesCacheKey);
      await prefs.remove(_filesCacheTimestampKey);

      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audiobook_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      // Игнорируем ошибки очистки кеша
    }
  }

  // Геттеры для диагностики
  String getLastError() => _lastError;
  bool isServiceInitialized() => _isInitialized;
}