import 'dart:io';
import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleDriveServiceFixed {
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
  GoogleSignIn? _googleSignIn;

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

      print('🔧 Начинаем инициализацию Google Drive Service...');
      
      // Создаем GoogleSignIn с правильной конфигурацией
      _googleSignIn = GoogleSignIn(
        scopes: _scopes,
        // Используем Web Client ID из google-services.json
        clientId: '112687964915-usd3dib9prsllich0e8n9nlo9arceco0.apps.googleusercontent.com',
      );
      
      print('📱 Проверяем текущий статус входа...');
      
      // Проверяем, есть ли уже авторизованный пользователь
      GoogleSignInAccount? account = _googleSignIn!.currentUser;
      
      if (account == null) {
        print('👤 Пользователь не авторизован, пробуем автоматический вход...');
        try {
          account = await _googleSignIn!.signInSilently();
          if (account != null) {
            print('✅ Автоматический вход успешен: ${account.email}');
          }
        } catch (silentError) {
          print('⚠️ Автоматический вход не удался: $silentError');
        }
      } else {
        print('👤 Найден авторизованный пользователь: ${account.email}');
      }
      
      if (account == null) {
        print('🔐 Запрашиваем интерактивный вход...');
        try {
          account = await _googleSignIn!.signIn();
        } catch (signInError) {
          _lastError = 'Ошибка входа в Google: $signInError';
          print('❌ Ошибка интерактивного входа: $signInError');
          
          // Детальный анализ ошибки
          final errorString = signInError.toString();
          if (errorString.contains('sign_in_failed')) {
            if (errorString.contains('J1.b: 10:')) {
              _lastError += '\n\n🔍 Код ошибки J1.b:10 - проблема с OAuth 2.0 конфигурацией';
              _lastError += '\n\n📋 Необходимо проверить в Google Cloud Console:';
              _lastError += '\n1. ✅ Включен ли Google Sign-In API';
              _lastError += '\n2. ✅ Настроен ли OAuth 2.0 Client ID для Android';
              _lastError += '\n3. ✅ Добавлен ли SHA-1: E8:39:D8:08:6A:81:8A:E4:ED:AB:3F:9C:25:9B:47:34:DE:37:C3:7E';
              _lastError += '\n4. ✅ Правильный ли package name: com.sacral.app';
              _lastError += '\n5. ✅ Включен ли Google Drive API';
              _lastError += '\n\n🌐 Также проверьте интернет-соединение';
            } else {
              _lastError += '\n\nВозможные причины:\n1. Неправильная настройка OAuth 2.0\n2. Неверный SHA-1 отпечаток\n3. Google Sign-In API не включен\n4. Проблемы с сетью';
            }
          }
          return false;
        }
      }
      
      if (account == null) {
        _lastError = 'Пользователь отменил вход';
        print('❌ Вход отменен пользователем');
        return false;
      }
      
      _currentUserEmail = account.email;
      print('✅ Успешный вход: ${account.email}');
      
      try {
        print('🔑 Получаем токены авторизации...');
        final authHeaders = await account.authHeaders;
        print('✅ Токены получены: ${authHeaders.keys.join(', ')}');
        
        final client = GoogleAuthClient(authHeaders);
        _driveApi = drive.DriveApi(client);
      
        // Проверяем доступ к Drive API
        try {
          print('🔍 Тестируем доступ к Drive API...');
          final about = await _driveApi!.about.get();
          print('✅ Drive API работает. Пользователь: ${about.user?.displayName}');
          _isInitialized = true;
          return true;
        } catch (apiError) {
          _lastError = 'Ошибка доступа к Drive API: $apiError';
          print('❌ Drive API ошибка: $apiError');
          
          // Детальный анализ ошибки API
          final errorStr = apiError.toString();
          if (errorStr.contains('403')) {
            _lastError += '\n\n🚫 Ошибка 403 - Доступ запрещен';
            _lastError += '\n📋 Проверьте в Google Cloud Console:';
            _lastError += '\n1. ✅ Google Drive API включен';
            _lastError += '\n2. ✅ Квоты API не превыш��ны';
            _lastError += '\n3. ✅ Проект активен';
          } else if (errorStr.contains('401')) {
            _lastError += '\n\n🔐 Ошибка 401 - Проблемы с авторизацией';
            _lastError += '\n📋 Возможные причины:';
            _lastError += '\n1. Токен недействителен';
            _lastError += '\n2. Неправильные scopes';
          } else if (errorStr.contains('400')) {
            _lastError += '\n\n⚠️ Ошибка 400 - Неверный запрос';
          }
          return false;
        }
      } catch (authError) {
        _lastError = 'Ошибка получения токенов: $authError';
        print('❌ Ошибка токенов: $authError');
        return false;
      }
    } catch (e) {
      _lastError = 'Критическая ошибка инициализации: $e';
      print('💥 Критическая ошибка: $e');
      return false;
    }
  }

  // Метод для принудительного повторного входа
  Future<bool> forceReauth() async {
    try {
      print('🔄 Принудительная повторная авторизация...');
      
      if (_googleSignIn != null) {
        await _googleSignIn!.disconnect();
        print('���� Отключение от предыдущей сессии');
      }
      
      // Очищаем состояние
      _isInitialized = false;
      _driveApi = null;
      _currentUserEmail = '';
      
      // Повторная инициализация
      return await initialize();
    } catch (e) {
      _lastError = 'Ошибка повторной авторизации: $e';
      print('❌ Ошибка повторной авторизации: $e');
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
      print('📦 Используем кешированный список файлов (${_cachedFiles!.length} файлов)');
      return _cachedFiles!;
    }
    
    if (_driveApi == null) {
      print('❌ DriveApi не инициализирован');

      // Если DriveApi не инициализирован, но у нас есть кеш, используем его даже если срок истек
      if (_cachedFiles != null && _cachedFiles!.isNotEmpty) {
        print('📦 Используем устаревший кеш (DriveApi не инициализирован)');
        return _cachedFiles!;
      }

      return [];
    }

    if (!await isOnline()) {
      print('🌐 Устройство не подключено к интернету');

      // Используем кеш в автономном режиме, даже если срок истек
      if (_cachedFiles != null && _cachedFiles!.isNotEmpty) {
        print('📦 Используем кеш в автономном режиме');
        return _cachedFiles!;
      }

      return [];
    }

   try {
  print('🔍 Запрашиваем файлы из папки: $_folderId');
  
  // Проверяем доступ к папке
  try {
    final folderResponse = await _driveApi!.files.get(_folderId);
    final folder = folderResponse as drive.File;
    print('✅ Папка найдена: ${folder.name}');
  } catch (folderError) {
    print('❌ Ошибка доступа к папке $_folderId: $folderError');
    _lastError = 'Нет доступа к папке с аудиокнигами: $folderError';
  }
      
      // Получаем файлы из указанной папки
      try {
        final fileList = await _driveApi!.files.list(
          q: "'$_folderId' in parents and (mimeType contains 'audio' or mimeType='application/vnd.google-apps.folder')",
          spaces: 'drive',
          pageSize: 100,
        );
        
        final files = fileList.files ?? [];
        print('📁 Найдено ${files.length} файлов в папке');

        if (files.isNotEmpty) {
          // Обновляем кеш
          _cachedFiles = files;
          _cacheTimestamp = DateTime.now();
          await _saveFilesCache(files);
          print('💾 Кеш обновлен');
          return files;
        } else {
          print('📭 В папке нет аудиофайлов');
        }
      } catch (folderError) {
        print('❌ Ошибка при запросе файлов из папки: $folderError');
        _lastError = 'Ошибка получения файлов из папки: $folderError';
      }
      
      // Если не удалось получить файлы из указанной папки, запрашиваем все доступные
      print('🔍 Запрашиваем все доступные аудиофайлы...');
      try {
        final allFilesList = await _driveApi!.files.list(
          q: "mimeType contains 'audio' or mimeType='application/vnd.google-apps.folder'",
          spaces: 'drive',
          pageSize: 100,
        );
        
        final allFiles = allFilesList.files ?? [];
        print('📁 Найдено всего файлов: ${allFiles.length}');
        
        if (allFiles.isNotEmpty) {
          // Обновляем кеш
          _cachedFiles = allFiles;
          _cacheTimestamp = DateTime.now();
          await _saveFilesCache(allFiles);
          print('💾 Кеш обновлен (все файлы)');
        }
        
        return allFiles;
      } catch (allFilesError) {
        print('❌ Ошибка получения всех файлов: $allFilesError');
        _lastError = 'Ошибка получения списка файлов: $allFilesError';
      }
      
      return [];
    } catch (e) {
      print('💥 Критическая ошибка получения файлов: $e');
      _lastError = 'Критическая ошибка: $e';

      // В случае ошибки используем существующий кеш, если он есть
      if (_cachedFiles != null && _cachedFiles!.isNotEmpty) {
        print('📦 Используем кешированные данные из-за ошибки');
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

      // Преобразуем файлы в список карт
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

      print('💾 Кеш файлов сохранен (${files.length} файлов)');
    } catch (e) {
      print('❌ Ошибка сохранения кеша: $e');
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

        print('📦 Кеш загружен (${_cachedFiles!.length} файлов)');

        // Проверяем валидность кеша
        if (_isCacheValid()) {
          print('✅ Кеш действителен до: ${_cacheTimestamp!.add(_cacheValidity)}');
        } else if (_cacheTimestamp != null) {
          print('⏰ Кеш устарел, последнее обновление: $_cacheTimestamp');
        }
      }
    } catch (e) {
      print('❌ Ошибка загрузки кеша: $e');
      _cachedFiles = null;
      _cacheTimestamp = null;
    }
  }

  // Принудительное обновление кеша
  Future<List<drive.File>> refreshFiles() async {
    print('🔄 Принудительное обновление кеша...');
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
    final fileResponse = await _driveApi!.files.get(fileId);
    final file = fileResponse as drive.File;
    print('✅ Файл доступен: ${file.name}');
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
    // Проверяем кеш
    final cachedPath = await getCachedFilePath(fileName);
    if (cachedPath != null) {
      print('📦 Файл $fileName уже в кеше');
      return cachedPath;
    }

    if (!await isOnline()) {
      print('🌐 Нет подключения, невозможно загрузить файл');
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
      print('⬇️ Загрузка файла $fileName...');
      await _dio.download(url, filePath);

      print('✅ Файл $fileName загружен в кеш');
      return filePath;
    } catch (e) {
      print('❌ Ошибка загрузки файла: $e');
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
      print('❌ Ошибка поиска кешированного файла: $e');
    }
    
    return null;
  }

  Future<bool> isFileCached(String fileName) async {
    final cachedPath = await getCachedFilePath(fileName);
    return cachedPath != null;
  }
  
  // Очистка кеша
  Future<void> clearCache() async {
    try {
      // Очищаем кеш в памяти
      _cachedFiles = null;
      _cacheTimestamp = null;

      // Очищаем SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_filesCacheKey);
      await prefs.remove(_filesCacheTimestampKey);

      // Очищаем файловый кеш
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audiobook_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('🗑️ Кеш файлов очищен');
      }
    } catch (e) {
      print('❌ Ошибка очистки кеша: $e');
    }
  }

  // Методы для диагностики
  String getLastError() => _lastError;
  bool isServiceInitialized() => _isInitialized;
  String getCurrentUserEmail() => _currentUserEmail;
  
  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    final Map<String, dynamic> info = {
      'timestamp': DateTime.now().toIso8601String(),
      'isInitialized': _isInitialized,
      'lastError': _lastError,
      'userEmail': _currentUserEmail,
      'isOnline': await isOnline(),
      'targetFolderId': _folderId,
      'cacheStatus': _isCacheValid() ? 'Действителен' : 'Устарел или отсутствует',
      'cachedFilesCount': _cachedFiles?.length ?? 0,
      'cacheLastUpdated': _cacheTimestamp?.toIso8601String(),
      'debugMode': _debugMode,
      'scopes': _scopes,
    };
    
    // Информация о Google Sign-In
    try {
      if (_googleSignIn != null) {
        info['googleSignInCurrentUser'] = _googleSignIn!.currentUser?.email ?? 'null';
        info['googleSignInIsSignedIn'] = await _googleSignIn!.isSignedIn();
        
        final currentUser = _googleSignIn!.currentUser;
        if (currentUser != null) {
          info['currentUserDetails'] = {
            'email': currentUser.email,
            'displayName': currentUser.displayName,
            'id': currentUser.id,
            'photoUrl': currentUser.photoUrl,
          };
          
          try {
            final authHeaders = await currentUser.authHeaders;
            info['authHeadersAvailable'] = true;
            info['authHeadersKeys'] = authHeaders.keys.toList();
          } catch (e) {
            info['authHeadersError'] = e.toString();
            info['authHeadersAvailable'] = false;
          }
        }
      }
    } catch (e) {
      info['googleSignInError'] = e.toString();
    }
    
    // Информация о Drive API
    if (_driveApi != null) {
      info['driveApiInitialized'] = true;
      try {
        final about = await _driveApi!.about.get();
        info['driveApiStatus'] = 'OK';
        info['driveApiUser'] = {
          'displayName': about.user?.displayName,
          'emailAddress': about.user?.emailAddress,
        };
      } catch (e) {
        info['driveApiError'] = e.toString();
        info['driveApiStatus'] = 'ERROR';
      }
    } else {
      info['driveApiInitialized'] = false;
    }
    
    // Информация о сети
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      info['connectivityType'] = connectivityResult.toString();
    } catch (e) {
      info['connectivityError'] = e.toString();
    }
    
    // Информация о файловой системе
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/audiobook_cache');
      info['cacheDirExists'] = await cacheDir.exists();
      if (await cacheDir.exists()) {
        final files = await cacheDir.list().toList();
        info['cachedFilesOnDisk'] = files.length;
      }
    } catch (e) {
      info['fileSystemError'] = e.toString();
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