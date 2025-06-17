import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

/// Локальный HTTP сервер для проксирования частично загруженных аудиофайлов
class LocalAudioServer {
  HttpServer? _server;
  int _port = 8080;
  final Map<String, String> _fileRoutes = {}; // route -> filePath
  final Map<String, AudioFileHandler> _fileHandlers = {};
  
  static LocalAudioServer? _instance;
  static LocalAudioServer get instance => _instance ??= LocalAudioServer._();
  
  LocalAudioServer._();

  /// Запуск сервера
  Future<bool> start() async {
    if (_server != null) {
      return true; // Сервер уже запущен
    }

    try {
      // Пытаемся найти свободный порт
      for (int port = 8080; port <= 8090; port++) {
        try {
          _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
          _port = port;
          break;
        } catch (e) {
          continue;
        }
      }

      if (_server == null) {
        throw Exception('Не ��далось найти свободный порт');
      }

      print('🎵 Локальный аудио сервер запущен на порту $_port');

      // Обработка запросов
      _server!.listen(_handleRequest);
      
      return true;
    } catch (e) {
      print('❌ Ошибка запуска локального сервера: $e');
      return false;
    }
  }

  /// Остановка сервера
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      _fileRoutes.clear();
      _fileHandlers.clear();
      print('🛑 Локальный аудио сервер остановлен');
    }
  }

  /// Регистрация файла для проксирования
  String registerFile(String fileId, String filePath) {
    final route = '/audio/$fileId';
    _fileRoutes[route] = filePath;
    _fileHandlers[route] = AudioFileHandler(filePath);
    
    final url = 'http://127.0.0.1:$_port$route';
    print('📁 Зарегистрирован файл: $route -> $filePath');
    return url;
  }

  /// Отмена регистрации файла
  void unregisterFile(String fileId) {
    final route = '/audio/$fileId';
    _fileRoutes.remove(route);
    _fileHandlers.remove(route);
    print('🗑️ Отменена регистрация файла: $route');
  }

  /// Обработка HTTP запросов
  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      
      // CORS заголовки
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      request.response.headers.add('Access-Control-Allow-Headers', 'Range, Content-Type');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }

      if (!_fileRoutes.containsKey(path)) {
        request.response.statusCode = 404;
        request.response.write('File not found');
        await request.response.close();
        return;
      }

      final filePath = _fileRoutes[path]!;
      final handler = _fileHandlers[path]!;

      if (request.method == 'HEAD') {
        await _handleHeadRequest(request, handler);
      } else if (request.method == 'GET') {
        await _handleGetRequest(request, handler);
      } else {
        request.response.statusCode = 405;
        request.response.write('Method not allowed');
        await request.response.close();
      }
    } catch (e) {
      print('❌ Ошибка обработки запроса: $e');
      try {
        request.response.statusCode = 500;
        request.response.write('Internal server error');
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Обработка HEAD запроса
  Future<void> _handleHeadRequest(HttpRequest request, AudioFileHandler handler) async {
    try {
      final fileSize = await handler.getFileSize();
      
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.headers.add('Accept-Ranges', 'bytes');
      request.response.headers.contentLength = fileSize;
      request.response.statusCode = 200;
      
      await request.response.close();
    } catch (e) {
      request.response.statusCode = 500;
      await request.response.close();
    }
  }

  /// Обработка GET запроса
  Future<void> _handleGetRequest(HttpRequest request, AudioFileHandler handler) async {
    try {
      final fileSize = await handler.getFileSize();
      final rangeHeader = request.headers.value('range');
      
      if (rangeHeader != null) {
        await _handleRangeRequest(request, handler, rangeHeader, fileSize);
      } else {
        await _handleFullRequest(request, handler, fileSize);
      }
    } catch (e) {
      print('❌ Ошибка GET запроса: $e');
      request.response.statusCode = 500;
      await request.response.close();
    }
  }

  /// Обработка Range запроса (частичная загрузка)
  Future<void> _handleRangeRequest(
    HttpRequest request,
    AudioFileHandler handler,
    String rangeHeader,
    int fileSize,
  ) async {
    try {
      final range = _parseRangeHeader(rangeHeader, fileSize);
      if (range == null) {
        request.response.statusCode = 416; // Range Not Satisfiable
        await request.response.close();
        return;
      }

      final start = range['start']!;
      final end = range['end']!;
      final contentLength = end - start + 1;

      request.response.statusCode = 206; // Partial Content
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.headers.add('Accept-Ranges', 'bytes');
      request.response.headers.add('Content-Range', 'bytes $start-$end/$fileSize');
      request.response.headers.contentLength = contentLength;

      // Читаем и отправляем данные по частям
      await handler.streamRange(request.response, start, end);
      
    } catch (e) {
      print('❌ Ошибка Range запроса: $e');
      request.response.statusCode = 500;
      await request.response.close();
    }
  }

  /// Обработка полного запроса
  Future<void> _handleFullRequest(
    HttpRequest request,
    AudioFileHandler handler,
    int fileSize,
  ) async {
    try {
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.headers.add('Accept-Ranges', 'bytes');
      request.response.headers.contentLength = fileSize;

      await handler.streamFull(request.response);
      
    } catch (e) {
      print('❌ Ошибка полного запроса: $e');
      request.response.statusCode = 500;
      await request.response.close();
    }
  }

  /// Парсинг Range заголовка
  Map<String, int>? _parseRangeHeader(String rangeHeader, int fileSize) {
    try {
      // Формат: "bytes=start-end" или "bytes=start-"
      final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
      if (match == null) return null;

      final start = int.parse(match.group(1)!);
      final endStr = match.group(2);
      final end = endStr!.isEmpty ? fileSize - 1 : int.parse(endStr);

      if (start >= fileSize || end >= fileSize || start > end) {
        return null;
      }

      return {'start': start, 'end': end};
    } catch (e) {
      return null;
    }
  }

  /// П��лучить URL для файла
  String? getFileUrl(String fileId) {
    final route = '/audio/$fileId';
    if (_fileRoutes.containsKey(route)) {
      return 'http://127.0.0.1:$_port$route';
    }
    return null;
  }

  /// Проверить, запущен ли сервер
  bool get isRunning => _server != null;

  /// Получить порт сервера
  int get port => _port;
}

/// Обработчик аудиофайлов
class AudioFileHandler {
  final String filePath;
  final File _file;
  static const int _bufferSize = 64 * 1024; // 64KB buffer

  AudioFileHandler(this.filePath) : _file = File(filePath);

  /// Получить размер файла
  Future<int> getFileSize() async {
    try {
      if (await _file.exists()) {
        return await _file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Стриминг полного файла
  Future<void> streamFull(HttpResponse response) async {
    try {
      final stream = _file.openRead();
      await response.addStream(stream);
      await response.close();
    } catch (e) {
      print('❌ Ошибка стриминга полного файла: $e');
      rethrow;
    }
  }

  /// Стриминг диапазона файла
  Future<void> streamRange(HttpResponse response, int start, int end) async {
    try {
      final length = end - start + 1;
      final stream = _file.openRead(start, end + 1);
      
      int totalSent = 0;
      await for (final chunk in stream) {
        if (totalSent + chunk.length > length) {
          // Обрезаем последний chunk если он превышает нужный размер
          final remainingBytes = length - totalSent;
          final trimmedChunk = Uint8List.fromList(chunk.take(remainingBytes).toList());
          response.add(trimmedChunk);
          totalSent += trimmedChunk.length;
          break;
        } else {
          response.add(chunk);
          totalSent += chunk.length;
        }
        
        if (totalSent >= length) break;
      }
      
      await response.close();
    } catch (e) {
      print('❌ Ошибка стриминга диапазона файла: $e');
      rethrow;
    }
  }

  /// Проверить доступность файла
  Future<bool> isAvailable() async {
    try {
      return await _file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Получить информацию о файле
  Future<Map<String, dynamic>> getFileInfo() async {
    try {
      if (await _file.exists()) {
        final stat = await _file.stat();
        return {
          'size': stat.size,
          'modified': stat.modified.toIso8601String(),
          'path': filePath,
        };
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}

/// Утилиты для работы с аудиофайлами
class AudioFileUtils {
  /// Определить MIME тип по расширению файла
  static String getMimeType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
      case 'aac':
        return 'audio/aac';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      default:
        return 'audio/mpeg';
    }
  }

  /// Проверить, является ли файл аудиофайлом
  static bool isAudioFile(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac'].contains(extension);
  }

  /// Форматировать размер файла
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Форматировать скорость загрузки
  static String formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// Форматировать время
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}