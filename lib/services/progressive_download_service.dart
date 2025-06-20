import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Статус прогрессивной загрузки
enum ProgressiveDownloadStatus {
  idle,
  downloading,
  paused,
  completed,
  error,
  cancelled
}

/// Информация о прогрессе загрузки
class DownloadProgress {
  final String fileId;
  final int downloadedBytes;
  final int totalBytes;
  final double percentage;
  final ProgressiveDownloadStatus status;
  final String? error;
  final int downloadSpeed; // bytes per second
  final Duration estimatedTimeRemaining;

  DownloadProgress({
    required this.fileId,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.percentage,
    required this.status,
    this.error,
    this.downloadSpeed = 0,
    this.estimatedTimeRemaining = Duration.zero,
  });

  bool get isPlayable => percentage >= 0.15; // 15% для начала восп��оизведения
  bool get isBuffered => percentage >= 0.25; // 25% для стабильного воспроизведения
}

/// Сервис прогрессивной загрузки аудиофайлов
class ProgressiveDownloadService {
  static const String _progressKey = 'progressive_download_progress';
  static const String _partialFilesKey = 'partial_files_info';
  static const int _chunkSize = 512 * 1024; // 512KB chunks
  static const double _playableThreshold = 0.15; // 15% для начала воспроизведения
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  final Dio _dio = Dio();
  final Map<String, StreamController<DownloadProgress>> _progressControllers = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, Timer> _speedCalculationTimers = {};
  final Map<String, int> _lastDownloadedBytes = {};
  final Map<String, DateTime> _lastSpeedUpdate = {};
  
  // Кеш информации о частично загруженных файлах
  final Map<String, PartialFileInfo> _partialFiles = {};

  ProgressiveDownloadService() {
    _loadPartialFilesInfo();
  }

  /// Получить поток прогресса загрузки для файла
  Stream<DownloadProgress> getProgressStream(String fileId) {
    if (!_progressControllers.containsKey(fileId)) {
      _progressControllers[fileId] = StreamController<DownloadProgress>.broadcast();
    }
    return _progressControllers[fileId]!.stream;
  }

  /// Начать прогрессивную загрузку файла
  Future<String?> startProgressiveDownload({
    required String fileId,
    required String downloadUrl,
    required String fileName,
    bool resumeIfExists = true,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/progressive_cache');
      
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final filePath = '${cacheDir.path}/$fileName';
      final file = File(filePath);
      
      // Проверяем, есть ли уже полностью загруженный файл
      if (await file.exists()) {
        final fileSize = await file.length();
        final expectedSize = await _getFileSize(downloadUrl);
        
        if (expectedSize > 0 && fileSize >= expectedSize) {
          _emitProgress(fileId, DownloadProgress(
            fileId: fileId,
            downloadedBytes: fileSize,
            totalBytes: fileSize,
            percentage: 1.0,
            status: ProgressiveDownloadStatus.completed,
          ));
          return filePath;
        }
      }

      // Проверяем частично загруженный файл
      int startByte = 0;
      if (resumeIfExists && await file.exists()) {
        startByte = await file.length();
      }

      // Получаем размер файла
      final totalSize = await _getFileSize(downloadUrl);
      if (totalSize <= 0) {
        throw Exception('Не удалось получить размер файла');
      }

      // Проверяем, не загружается ли уже этот файл
      if (_cancelTokens.containsKey(fileId) && !_cancelTokens[fileId]!.isCancelled) {
        print('🔄 Файл $fileId уже загружается, используем существующую загрузку');
        return filePath;
      }
      
      // Создаем токен отмены только если его еще нет
      final cancelToken = CancelToken();
      _cancelTokens[fileId] = cancelToken;

      // Начинаем загрузку
      await _downloadWithResume(
        fileId: fileId,
        downloadUrl: downloadUrl,
        filePath: filePath,
        startByte: startByte,
        totalSize: totalSize,
        cancelToken: cancelToken,
      );

      return filePath;
    } catch (e) {
      _emitProgress(fileId, DownloadProgress(
        fileId: fileId,
        downloadedBytes: 0,
        totalBytes: 0,
        percentage: 0.0,
        status: ProgressiveDownloadStatus.error,
        error: e.toString(),
      ));
      return null;
    }
  }

  /// Загрузка с поддержкой возобновления
  Future<void> _downloadWithResume({
    required String fileId,
    required String downloadUrl,
    required String filePath,
    required int startByte,
    required int totalSize,
    required CancelToken cancelToken,
    int retryCount = 0,
  }) async {
    try {
      final file = File(filePath);
      final sink = file.openWrite(mode: FileMode.append);
      
      // Настраиваем заголовки для Range request
      final headers = <String, dynamic>{};
      if (startByte > 0) {
        headers['Range'] = 'bytes=$startByte-';
      }

      _emitProgress(fileId, DownloadProgress(
        fileId: fileId,
        downloadedBytes: startByte,
        totalBytes: totalSize,
        percentage: startByte / totalSize,
        status: ProgressiveDownloadStatus.downloading,
      ));

      // Инициализируем отслеживание скорости
      _initSpeedTracking(fileId, startByte);

      final response = await _dio.get(
        downloadUrl,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
        cancelToken: cancelToken,
      );

     if (response.statusCode == 200 || response.statusCode == 206) {
  int downloadedBytes = startByte;
  
  await for (final chunk in response.data.stream) {
    if (cancelToken.isCancelled) {
      break;
    }

    sink.add(chunk);
    downloadedBytes += (chunk as List<int>).length;
    
    final percentage = downloadedBytes / totalSize;
    final progress = DownloadProgress(
      fileId: fileId,
      downloadedBytes: downloadedBytes,
      totalBytes: totalSize,
      percentage: percentage,
      status: ProgressiveDownloadStatus.downloading,
      downloadSpeed: _calculateSpeed(fileId, downloadedBytes),
      estimatedTimeRemaining: _calculateETA(fileId, downloadedBytes, totalSize),
    );

          _emitProgress(fileId, progress);
          _updatePartialFileInfo(fileId, filePath, downloadedBytes, totalSize);
        }

        await sink.close();

        if (!cancelToken.isCancelled) {
          // Проверяем, что файл загружен полностью
          final finalSize = await file.length();
          if (finalSize >= totalSize) {
            _emitProgress(fileId, DownloadProgress(
              fileId: fileId,
              downloadedBytes: finalSize,
              totalBytes: totalSize,
              percentage: 1.0,
              status: ProgressiveDownloadStatus.completed,
            ));
            _removePartialFileInfo(fileId);
          }
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.statusMessage}');
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        _emitProgress(fileId, DownloadProgress(
          fileId: fileId,
          downloadedBytes: startByte,
          totalBytes: totalSize,
          percentage: startByte / totalSize,
          status: ProgressiveDownloadStatus.cancelled,
        ));
        return;
      }

      // Повторная попытка при ошибке
      if (retryCount < _maxRetries) {
        await Future.delayed(_retryDelay);
        final currentSize = await File(filePath).length().catchError((_) => 0);
        await _downloadWithResume(
          fileId: fileId,
          downloadUrl: downloadUrl,
          filePath: filePath,
          startByte: currentSize,
          totalSize: totalSize,
          cancelToken: cancelToken,
          retryCount: retryCount + 1,
        );
      } else {
        _emitProgress(fileId, DownloadProgress(
          fileId: fileId,
          downloadedBytes: startByte,
          totalBytes: totalSize,
          percentage: startByte / totalSize,
          status: ProgressiveDownloadStatus.error,
          error: e.toString(),
        ));
      }
    } finally {
      _cleanupSpeedTracking(fileId);
    }
  }

  /// Получить размер файла по URL
  Future<int> _getFileSize(String url) async {
    try {
      final response = await _dio.head(url);
      final contentLength = response.headers.value('content-length');
      return contentLength != null ? int.parse(contentLength) : 0;
    } catch (e) {
      return 0;
    }
  }

  /// Проверить, можно ли начать воспроизведение
  Future<bool> isPlayable(String fileId) async {
    final info = _partialFiles[fileId];
    if (info == null) return false;
    
    final file = File(info.filePath);
    if (!await file.exists()) return false;
    
    final currentSize = await file.length();
    final percentage = currentSize / info.totalSize;
    
    return percentage >= _playableThreshold;
  }

  /// Получить путь к частично загруженному файлу
  Future<String?> getPartialFilePath(String fileId) async {
    final info = _partialFiles[fileId];
    if (info == null) return null;
    
    final file = File(info.filePath);
    if (!await file.exists()) return null;
    
    return info.filePath;
  }

  /// Приостановить загрузку
  void pauseDownload(String fileId) {
    final cancelToken = _cancelTokens[fileId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Загрузка приостановлена пользователем');
    }
  }

  /// Отменить загрузку
  Future<void> cancelDownload(String fileId) async {
    pauseDownload(fileId);
    
    final info = _partialFiles[fileId];
    if (info != null) {
      final file = File(info.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      _removePartialFileInfo(fileId);
    }
  }

  /// Очистить кеш прогрессивных загрузок
  Future<void> clearCache() async {
    try {
      // Отменяем все активные загрузки
      for (final fileId in _cancelTokens.keys.toList()) {
        pauseDownload(fileId);
      }

      // Удаляем файлы
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/progressive_cache');
      
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }

      // Очищаем информацию
      _partialFiles.clear();
      await _savePartialFilesInfo();
      
      // Закрываем контроллеры
      for (final controller in _progressControllers.values) {
        if (!controller.isClosed) {
          controller.close();
        }
      }
      _progressControllers.clear();
      
    } catch (e) {
      print('Ошибка очистки кеша прогрессивной загрузки: $e');
    }
  }

  /// Инициализация отслеживания скорости
  void _initSpeedTracking(String fileId, int initialBytes) {
    _lastDownloadedBytes[fileId] = initialBytes;
    _lastSpeedUpdate[fileId] = DateTime.now();
    
    _speedCalculationTimers[fileId] = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _updateSpeedCalculation(fileId),
    );
  }

  /// Обновление расчета скорости
  void _updateSpeedCalculation(String fileId) {
    final lastBytes = _lastDownloadedBytes[fileId] ?? 0;
    final lastUpdate = _lastSpeedUpdate[fileId] ?? DateTime.now();
    
    _lastDownloadedBytes[fileId] = lastBytes;
    _lastSpeedUpdate[fileId] = DateTime.now();
  }

  /// Расчет скорости загрузки
  int _calculateSpeed(String fileId, int currentBytes) {
    final lastBytes = _lastDownloadedBytes[fileId] ?? currentBytes;
    final lastUpdate = _lastSpeedUpdate[fileId] ?? DateTime.now();
    final now = DateTime.now();
    
    final timeDiff = now.difference(lastUpdate).inMilliseconds;
    if (timeDiff > 0) {
      final bytesDiff = currentBytes - lastBytes;
      final speed = (bytesDiff * 1000) ~/ timeDiff; // bytes per second
      
      _lastDownloadedBytes[fileId] = currentBytes;
      _lastSpeedUpdate[fileId] = now;
      
      return speed > 0 ? speed : 0;
    }
    
    return 0;
  }

  /// Расчет оставшегося времени
  Duration _calculateETA(String fileId, int downloadedBytes, int totalBytes) {
    final speed = _calculateSpeed(fileId, downloadedBytes);
    if (speed <= 0) return Duration.zero;
    
    final remainingBytes = totalBytes - downloadedBytes;
    final etaSeconds = remainingBytes ~/ speed;
    
    return Duration(seconds: etaSeconds);
  }

  /// Очистка отслеживания скорости
  void _cleanupSpeedTracking(String fileId) {
    _speedCalculationTimers[fileId]?.cancel();
    _speedCalculationTimers.remove(fileId);
    _lastDownloadedBytes.remove(fileId);
    _lastSpeedUpdate.remove(fileId);
    _cancelTokens.remove(fileId);
  }

  /// Отправка прогресса
  void _emitProgress(String fileId, DownloadProgress progress) {
    final controller = _progressControllers[fileId];
    if (controller != null && !controller.isClosed) {
      controller.add(progress);
    }
  }

  /// Обновление информации о частично загруженном файле
  void _updatePartialFileInfo(String fileId, String filePath, int downloadedBytes, int totalBytes) {
    _partialFiles[fileId] = PartialFileInfo(
      fileId: fileId,
      filePath: filePath,
      downloadedBytes: downloadedBytes,
      totalSize: totalBytes,
      lastModified: DateTime.now(),
    );
    _savePartialFilesInfo();
  }

  /// Удаление информации о частично загруженном файле
  void _removePartialFileInfo(String fileId) {
    _partialFiles.remove(fileId);
    _savePartialFilesInfo();
  }

  /// Сохранение информации о частично загруженных файлах
  Future<void> _savePartialFilesInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _partialFiles.map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString(_partialFilesKey, json.encode(data));
    } catch (e) {
      print('Ошибка сохранения информации о частичных файлах: $e');
    }
  }

  /// Загрузка информации о частично загруженных файлах
  Future<void> _loadPartialFilesInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataString = prefs.getString(_partialFilesKey);
      
      if (dataString != null) {
        final Map<String, dynamic> data = json.decode(dataString);
        _partialFiles.clear();
        
        for (final entry in data.entries) {
          try {
            final info = PartialFileInfo.fromJson(entry.value);
            // Проверяем, что файл еще существует
            if (await File(info.filePath).exists()) {
              _partialFiles[entry.key] = info;
            }
          } catch (e) {
            print('Ошибка загрузки информации о файле ${entry.key}: $e');
          }
        }
        
        // Сохраняем обновленную информацию
        await _savePartialFilesInfo();
      }
    } catch (e) {
      print('Ошибка загрузки информации о частичных файлах: $e');
    }
  }

  /// Получить список частично загруженных файлов
  List<PartialFileInfo> getPartialFiles() {
    return _partialFiles.values.toList();
  }

  /// Освобождение ресурсов
  void dispose() {
    for (final timer in _speedCalculationTimers.values) {
      timer.cancel();
    }
    _speedCalculationTimers.clear();
    
    for (final controller in _progressControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _progressControllers.clear();
    
    for (final cancelToken in _cancelTokens.values) {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel();
      }
    }
    _cancelTokens.clear();
  }
}

/// Информация о частично загруженном файле
class PartialFileInfo {
  final String fileId;
  final String filePath;
  final int downloadedBytes;
  final int totalSize;
  final DateTime lastModified;

  PartialFileInfo({
    required this.fileId,
    required this.filePath,
    required this.downloadedBytes,
    required this.totalSize,
    required this.lastModified,
  });

  double get percentage => downloadedBytes / totalSize;
  bool get isPlayable => percentage >= 0.15;
  bool get isCompleted => downloadedBytes >= totalSize;

  factory PartialFileInfo.fromJson(Map<String, dynamic> json) {
    return PartialFileInfo(
      fileId: json['fileId'] as String,
      filePath: json['filePath'] as String,
      downloadedBytes: json['downloadedBytes'] as int,
      totalSize: json['totalSize'] as int,
      lastModified: DateTime.parse(json['lastModified'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileId': fileId,
      'filePath': filePath,
      'downloadedBytes': downloadedBytes,
      'totalSize': totalSize,
      'lastModified': lastModified.toIso8601String(),
    };
  }
}