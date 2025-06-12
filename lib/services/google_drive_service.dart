
import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  static const String _folderId = '1b7PFjESsnY6bsn9rDmdAe10AU0pQNwiM'; // ID папки с аудиокнигами
  static const List<String> _scopes = [drive.DriveApi.driveReadonlyScope];
  // Client ID из JSON-файла
  static const String _clientId = '358123091745-dk8931trk267ed1qbn8q00giqcldab58.apps.googleusercontent.com';
  
  drive.DriveApi? _driveApi;
  final Dio _dio = Dio();

  Future<void> initialize() async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: _scopes,
        clientId: _clientId,
      );
      
      final account = await googleSignIn.signIn();
      if (account == null) {
        print('Пользователь отменил вход');
        return;
      }
      
      final authHeaders = await account.authHeaders;
      final client = GoogleAuthClient(authHeaders);
      _driveApi = drive.DriveApi(client);
      
      print('Google Drive API инициализирован успешно');
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
