import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart';

class GoogleDriveService {
  // Статус сервиса для диагностики
  String _lastError = '';
  bool _isInitialized = false;
  String _currentUserEmail = '';
  // Используем общедоступную папку с аудиокнигами
  static const String _folderId = '1b7PFjESsnY6bsn9rDmdAe10AU0pQNwiM'; // ID папки с аудиокнигами
  static const bool _debugMode = true; // Включаем режим отладки
  static const List<String> _scopes = [drive.DriveApi.driveReadonlyScope];
  // Client ID из JSON-файла
  // Убираем явное указание clientId, будем использовать значение из ресурсов Android
  // static const String _clientId = '358123091745-dk8931trk267ed1qbn8q00giqcldab58.apps.googleusercontent.com';
  
  drive.DriveApi? _driveApi;
  final Dio _dio = Dio();

  Future<bool> initialize() async {
    try {
      _lastError = '';
      _isInitialized = false;
      _currentUserEmail = '';
      
      // Используем более простую конфигурацию без serverClientId
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: _scopes,
        // Убираем serverClientId, так как он может вызывать проблемы на Android
        // serverClientId: _clientId,
      );
      
      print('Инициализация Google Sign-In...');
      
      // Сначала выходим из всех аккаунтов для чистого старта
      try {
        await googleSignIn.signOut();
        print('Выполнен выход из предыдущих сессий');
      } catch (signOutError) {
        print('Ошибка при выходе из аккаунта: $signOutError');
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
    if (_driveApi == null) {
      print('DriveApi не инициализирован');
      return [];
    }
    
    if (!await isOnline()) {
      print('Устройство не подключено к интернету');
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
          print('Найдено ${files.length} файлов в указанной папке:');
          print('- Найдено ${files.length} файлов в папке');
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
        print('Список найденных файлов:');
        print('- Показаны первые 10 из ${allFiles.length} файлов');
        if (allFiles.length > 10) {
          print('... и еще ${allFiles.length - 10} файлов');
        }
      }
      
      return allFiles;
    } catch (e) {
      print('Ошибка получения файлов: $e');
      return [];
    }
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
    if (!await isOnline()) {
      return await getCachedFilePath(fileName);
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
      await _dio.download(url, filePath);
      
      return filePath;
    } catch (e) {
      print('Ошибка загрузки файла: $e');
      return await getCachedFilePath(fileName);
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
