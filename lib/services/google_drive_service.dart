
import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class GoogleDriveService {
  static const String _folderId = 'YOUR_GOOGLE_DRIVE_FOLDER_ID'; // Замените на ID папки с аудиокнигами
  static const List<String> _scopes = [drive.DriveApi.driveReadonlyScope];
  
  drive.DriveApi? _driveApi;
  final Dio _dio = Dio();

  Future<void> initialize() async {
    try {
      // Здесь нужно настроить аутентификацию с Google Drive
      // Для простоты используем service account или OAuth2
      // В продакшене нужно будет настроить правильную аутентификацию
      
      // Пример инициализации (нужно добавить credentials)
      // final credentials = ServiceAccountCredentials.fromJson(credentialsJson);
      // final client = await clientViaServiceAccount(credentials, _scopes);
      // _driveApi = drive.DriveApi(client);
    } catch (e) {
      print('Ошибка инициализации Google Drive: $e');
    }
  }

  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<List<drive.File>> getAudiobookFiles() async {
    if (_driveApi == null || !await isOnline()) {
      return [];
    }

    try {
      final fileList = await _driveApi!.files.list(
        q: "'$_folderId' in parents and (mimeType contains 'audio' or mimeType='application/vnd.google-apps.folder')",
        spaces: 'drive',
      );

      return fileList.files ?? [];
    } catch (e) {
      print('Ошибка получения файлов: $e');
      return [];
    }
  }

  Future<String?> getFileStreamUrl(String fileId) async {
    if (_driveApi == null || !await isOnline()) {
      return null;
    }

    try {
      // Получаем прямую ссылку на файл для стриминга
      return 'https://drive.google.com/uc?id=$fileId&export=download';
    } catch (e) {
      print('Ошибка получения URL: $e');
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
}
