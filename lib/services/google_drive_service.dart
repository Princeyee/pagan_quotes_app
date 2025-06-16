import 'dart:io';
import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleDriveService {
  // Статус сервиса для диагностики
  String _lastError = '';
  bool _isInitialized = false;
  String _currentUserEmail = '';
  // Используем общедоступную папку с аудиокнигами
  static const String _folderId = '1b7PFjESsnY6bsn9rDmdAe10AU0pQNwiM'; // ID папки с аудиокнигами
  static const bool _debugMode = true; // Включаем режим отладки
  static const List<String> _scopes = [drive.DriveApi.driveReadonlyScope];

  // Ключи для SharedPreferences
  static const String _filesCacheKey = 'google_drive_files_cache';
  static const String _filesCacheTimestampKey = 'google_drive_files_cache_timestamp';
  static const Duration _cacheValidity = Duration(days: 1); // Кеш действителен 24 часа

  drive.DriveApi? _driveApi;
  final Dio _dio = Dio();

  // Кеш файлов
  List<drive.File>? _cachedFiles;
  DateTime? _cacheTimestamp;

  Future<bool> initialize() async {
    try {
      _lastError = '';
      _isInitialized = false;
      _currentUserEmail = '';
      
      // Загружаем кеш если он есть
      await _loadFilesCache();

      // Используем базовую конфигурацию без явного указания serverClientId
      // Это позволит использовать ID из google-services.json
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: _scopes,
        // Убираем явное указание serverClientId, чтобы использовать настройки из google-services.json
      );
      
      print('Инициализация Google Sign-In...');
      
      // Сначала отключаемся от предыдущих сессий
      try {
        await googleSignIn.disconnect();
        print('Отключение от предыдущих сессий выполнено');
      } catch (disconnectError) {
        print('Ошибка при отключении: $disconnectError');
        // Продолжаем работу, это не критическая ошибка
      }
      
      // Пробуем выполнить вход
      try {
        print('Запрашиваем вход в Google...');
        final account = await googleSignIn.signIn();
        if (account == null) {
          _lastError = 'Пользователь отменил вход';
          print(_lastError);
          return false;
        }
        
        _currentUserEmail = account.email;
        print('Вход выполнен как: ${account.email}');
        
        try {
          print('Получаем заголовки авторизации...');
          final authHeaders = await account.authHeaders;
          final client = GoogleAuthClient(authHeaders);
          _driveApi = drive.DriveApi(client);
        
          // Проверяем доступ к API
          try {
            print('Проверяем доступ к API...');
            await _driveApi!.about.get();
            print('Доступ к API подтвержден');
            _isInitialized = true;
            return true;
          } catch (apiError) {
            _lastError = 'Ошибка проверки API: $apiError';
            print(_lastError);
            return false;
          }
        } catch (authError) {
          _lastError = 'Ошибка получения токена авторизации: $authError';
          print(_lastError);
          return false;
        }
      } catch (signInError) {
        _lastError = 'Ошибка входа в Google: $signInError';
        print('Детальная ошибка входа: $signInError');
        return false;
      }
    } catch (e) {
      _lastError = 'Ошибка инициализации Google Drive: $e';
      print(_lastError);
      return false;
    }
  }

  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<List<drive.File>> getAudiobookFiles() async {
    // Проверяем наличие действительного кеша
    if (_isCacheValid()) {
      print('Используем кешированный список файлов (${_cachedFiles!.length} файлов)');
      return _cachedFiles!;
    }
    
    if (_driveApi == null) {
      print('DriveApi не инициализирован');

      // Если DriveApi не инициализирован, но у нас есть кеш, используем его даже если срок истек
      if (_cachedFiles != null && _cachedFiles!.isNotEmpty) {
        print('Используем устаревший кеш так как DriveApi не инициализирован');
        return _cachedFiles!;
      }

      return [];
    }

    if (!await isOnline()) {
      print('Устройство не подключено к интернету');

      // Используем кеш в автономном режиме, даже если срок истек
      if (_cachedFiles != null && _cachedFiles!.isNotEmpty) {
        print('Используем кеш в автономном режиме');
        return _cachedFiles!;
      }

      return [];
    }

    try {
      // Проверяем существование указанной папки
      try {
        await _driveApi!.files.get(_folderId);
        print('Папка найдена: $_folderId');
      } catch (folderError) {
        print('Ошибка доступа к папке $_folderId: $folderError');
      }
      
      // Сначала пробуем получить файлы из указанной папки
      try {
        print('Запрашиваем файлы из папки: $_folderId');
        final fileList = await _driveApi!.files.list(
          q: "'$_folderId' in parents and (mimeType contains 'audio' or mimeType='application/vnd.google-apps.folder')",
          spaces: 'drive',
        );
        
        final files = fileList.files ?? [];
        if (files.isNotEmpty) {


          print('Найдено ${files.length} файлов в указанной папке');

          // Обновляем кеш
          _cachedFiles = files;
          _cacheTimestamp = DateTime.now();
          _saveFilesCache(files);

          return files;
        } else {
          print('В указанной папке нет файлов');
        }
      } catch (folderError) {
        print('Ошибка при запросе файлов из папки: $folderError');
      }
      
      // Если не удалось получить файлы из указанной папки, запрашиваем все доступные аудиофайлы
      print('Запрашиваем все доступные аудиофайлы');
      final allFilesList = await _driveApi!.files.list(
        q: "mimeType contains 'audio' or mimeType='application/vnd.google-apps.folder'",
        spaces: 'drive',
        pageSize: 100,
      );
      
      final allFiles = allFilesList.files ?? [];
      print('Найдено всего файлов: ${allFiles.length}');
      
      if (allFiles.isNotEmpty) {





        // Обновляем кеш
        _cachedFiles = allFiles;
        _cacheTimestamp = DateTime.now();
        _saveFilesCache(allFiles);

        print('Список найденных файлов закеширован');
      }
      
      return allFiles;
    } catch (e) {
      print('Ошибка получения файлов: $e');

      // В случае ошибки используем существующий кеш, если он есть
      if (_cachedFiles != null && _cachedFiles!.isNotEmpty) {
        print('Используем кешированные данные из-за ошибки');
        return _cachedFiles!;
      }

      return [];
    }
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

  // Сохранение кеша файлов
  Future<void> _saveFilesCache(List<drive.File> files) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Преобразуем файлы в список карт, чтобы сохранить их
      final List<Map<String, dynamic>> filesList = [];

      for (final file in files) {
        final Map<String, dynamic> fileMap = {
          'id': file.id,
          'name': file.name,
          'mimeType': file.mimeType,
        };

        if (file.parents != null) {
          fileMap['parents'] = file.parents;
        }

        filesList.add(fileMap);
      }

      // Сохраняем JSON-строку
      final String jsonFiles = jsonEncode(filesList);
      await prefs.setString(_filesCacheKey, jsonFiles);

      // Сохраняем временную метку
      await prefs.setString(_filesCacheTimestampKey, DateTime.now().toIso8601String());

      print('Кеш файлов успешно сохранен (${files.length} файлов)');
    } catch (e) {
      print('Ошибка при сохранении кеша файлов: $e');
    }
  }

  // Загрузка кеша файлов
  Future<void> _loadFilesCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Загружаем временную метку
      final timestampString = prefs.getString(_filesCacheTimestampKey);
      if (timestampString != null) {
        _cacheTimestamp = DateTime.parse(timestampString);
      }

      // Загружаем файлы
      final jsonFiles = prefs.getString(_filesCacheKey);
      if (jsonFiles != null) {
        final List<dynamic> filesList = jsonDecode(jsonFiles);

        // Преобразуем обратно в объекты drive.File
        _cachedFiles = filesList.map((fileMap) {
          return drive.File()
            ..id = fileMap['id']
            ..name = fileMap['name']
            ..mimeType = fileMap['mimeType']
            ..parents = fileMap['parents'] != null
                ? List<String>.from(fileMap['parents'])
                : null;
        }).toList();

        print('Кеш файлов успешно загружен (${_cachedFiles!.length} файлов)');

        // Проверяем, не устарел ли кеш
        if (_isCacheValid()) {
          print('Кеш действителен, срок истекает: ${_cacheTimestamp!.add(_cacheValidity)}');
        } else if (_cacheTimestamp != null) {
          print('Кеш устарел, последнее обновление: $_cacheTimestamp');
        }
      }
    } catch (e) {
      print('Ошибка при загрузке кеша файлов: $e');
      _cachedFiles = null;
      _cacheTimestamp = null;
    }
  }

  // Принудительное обновление кеша
  Future<List<drive.File>> refreshFiles() async {
    // Сбрасываем кеш
    _cachedFiles = null;
    _cacheTimestamp = null;

    // Получаем свежие данные
    return await getAudiobookFiles();
  }

  Future<String?> getFileStreamUrl(String fileId) async {
    if (_driveApi == null || !await isOnline()) {
      _lastError = 'DriveApi не инициализирован или нет подключения';
      print(_lastError);
      return null;
    }

    try {
      // Проверяем доступ к файлу
      if (_debugMode) {
        try {
          await _driveApi!.files.get(fileId);
          print('Файл доступен: $fileId');
        } catch (fileError) {
          _lastError = 'Ошибка доступа к файлу $fileId: $fileError';
          print(_lastError);
        }
      }
      
      // Возвращаем стандартную ссылку для скачивания
      return 'https://drive.google.com/uc?id=$fileId&export=download';
    } catch (e) {
      _lastError = 'Ошибка получения URL: $e';
      print(_lastError);
      return null;
    }
  }

  Future<String?> downloadAndCacheFile(String fileId, String fileName) async {
    // Сначала проверяем, есть ли файл уже в кеше
    final cachedPath = await getCachedFilePath(fileName);
    if (cachedPath != null) {
      print('Файл $fileName уже в кеше');
      return cachedPath;
    }

    if (!await isOnline()) {

      print('Нет подключения к интернету, невозможно загрузить файл');
      return null;
    }

    try {
      final url = await getFileStreamUrl(fileId);
      if (url == null) return null;

      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audiobook_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final filePath = '${cacheDir.path}/$fileName';
      print('Загрузка файла $fileName из $url');
      await _dio.download(url, filePath);

      print('Файл $fileName успешно загружен в кеш');

      return filePath;
    } catch (e) {
      print('Ошибка загрузки файла: $e');

      return null;
    }
  }

  Future<String?> getCachedFilePath(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/audiobook_cache/$fileName';
      
      if (await File(filePath).exists()) {
        return filePath;
      }
    } catch (e) {
      print('Ошибка поиска кэшированного файла: $e');
    }
    
    return null;
  }

  Future<bool> isFileCached(String fileName) async {
    final cachedPath = await getCachedFilePath(fileName);
    return cachedPath != null;
  }
  
  // Метод для очистки кеша файлов
  Future<void> clearCache() async {
    try {
      // Очищаем кеш в памяти
      _cachedFiles = null;
      _cacheTimestamp = null;

      // Очищаем кеш в SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_filesCacheKey);
      await prefs.remove(_filesCacheTimestampKey);

      // Очищаем файловый кеш
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audiobook_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('Кеш файлов успешно очищен');
      }
    } catch (e) {
      print('Ошибка при очистке кеша: $e');
    }
  }

  // Методы для диагностики
  
  String getLastError() {
    return _lastError;
  }
  
  bool isServiceInitialized() {
    return _isInitialized;
  }
  
  String getCurrentUserEmail() {
    return _currentUserEmail;
  }
  
  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    final Map<String, dynamic> info = {
      'isInitialized': _isInitialized,
      'lastError': _lastError,
      'userEmail': _currentUserEmail,
      'isOnline': await isOnline(),
      'targetFolderId': _folderId,
      'cacheStatus': _isCacheValid() ? 'Действителен' : 'Устарел или отсутствует',
      'cachedFilesCount': _cachedFiles?.length ?? 0,
      'cacheLastUpdated': _cacheTimestamp?.toIso8601String(),
    };
    
    if (_driveApi != null) {
      try {
        await _driveApi!.about.get();
        info['apiStatus'] = 'OK';
      } catch (e) {
        info['apiError'] = e.toString();
      }
    }
    
    return info;
  }
}

// Вспомогательный класс для аутентификации
class GoogleAuthClient extends BaseClient {
  final Map<String, String> _headers;
  final Client _client = Client();

  GoogleAuthClient(this._headers);

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
