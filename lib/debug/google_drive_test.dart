import 'package:flutter/material.dart';
import '../services/google_drive_service_fixed.dart';

class GoogleDriveTestPage extends StatefulWidget {
  const GoogleDriveTestPage({Key? key}) : super(key: key);

  @override
  State<GoogleDriveTestPage> createState() => _GoogleDriveTestPageState();
}

class _GoogleDriveTestPageState extends State<GoogleDriveTestPage> {
  final GoogleDriveServiceFixed _driveService = GoogleDriveServiceFixed();
  String _status = 'Готов к тестированию';
  String _details = '';
  bool _isLoading = false;
  Map<String, dynamic>? _diagnostics;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Тест Google Drive'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Статус
            Card(
              color: _getStatusColor(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📊 Статус',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Кнопки тестирования
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testInitialization,
                    icon: const Icon(Icons.login),
                    label: const Text('Тест входа'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testFilesList,
                    icon: const Icon(Icons.folder),
                    label: const Text('Тест файлов'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _getDiagnostics,
                    icon: const Icon(Icons.info),
                    label: const Text('Диагностика'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _forceReauth,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Переавторизация'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Детали
            if (_details.isNotEmpty)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📝 Детали',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _details,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Индикатор загрузки
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (_status.contains('✅')) return Colors.green;
    if (_status.contains('❌')) return Colors.red;
    if (_status.contains('⚠️')) return Colors.orange;
    return Colors.blue;
  }

  Future<void> _testInitialization() async {
    setState(() {
      _isLoading = true;
      _status = '🔄 Тестируем инициализацию...';
      _details = '';
    });

    try {
      final success = await _driveService.initialize();
      
      setState(() {
        if (success) {
          _status = '✅ Инициализация успешна';
          _details = 'Пользователь: ${_driveService.getCurrentUserEmail()}\n';
          _details += 'Сервис инициализирован: ${_driveService.isServiceInitialized()}';
        } else {
          _status = '❌ Ошибка инициализации';
          _details = _driveService.getLastError();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '💥 Критическая ошибка';
        _details = 'Исключение: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testFilesList() async {
    setState(() {
      _isLoading = true;
      _status = '🔄 Получаем список файлов...';
      _details = '';
    });

    try {
      final files = await _driveService.getAudiobookFiles();
      
      setState(() {
        _status = '📁 Найдено файлов: ${files.length}';
        _details = 'Список файлов:\n\n';
        
        if (files.isEmpty) {
          _details += 'Файлы не найдены.\n';
          _details += 'Возможные причины:\n';
          _details += '- Папка пуста\n';
          _details += '- Нет доступа к папке\n';
          _details += '- Проблемы с авт��ризацией\n';
        } else {
          for (int i = 0; i < files.length && i < 10; i++) {
            final file = files[i];
            _details += '${i + 1}. ${file.name}\n';
            _details += '   ID: ${file.id}\n';
            _details += '   Тип: ${file.mimeType}\n\n';
          }
          
          if (files.length > 10) {
            _details += '... и еще ${files.length - 10} файлов';
          }
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Ошибка получения файлов';
        _details = 'Исключение: $e\n\n';
        _details += 'Последняя ошибка сервиса: ${_driveService.getLastError()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _getDiagnostics() async {
    setState(() {
      _isLoading = true;
      _status = '🔍 Собираем диагностическую информацию...';
      _details = '';
    });

    try {
      final diagnostics = await _driveService.getDiagnosticInfo();
      _diagnostics = diagnostics;
      
      setState(() {
        _status = '📊 Диагностика завершена';
        _details = _formatDiagnostics(diagnostics);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Ошибка диагностики';
        _details = 'Исключение: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _forceReauth() async {
    setState(() {
      _isLoading = true;
      _status = '🔄 Принудительная переавторизация...';
      _details = '';
    });

    try {
      final success = await _driveService.forceReauth();
      
      setState(() {
        if (success) {
          _status = '✅ Переавторизация успешна';
          _details = 'Новый пользователь: ${_driveService.getCurrentUserEmail()}';
        } else {
          _status = '❌ Ошибка переавторизации';
          _details = _driveService.getLastError();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '💥 Критическая ошибка переавторизации';
        _details = 'Исключение: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDiagnostics(Map<String, dynamic> diagnostics) {
    final buffer = StringBuffer();
    
    buffer.writeln('🕐 Время: ${diagnostics['timestamp']}');
    buffer.writeln('🔧 Инициализирован: ${diagnostics['isInitialized']}');
    buffer.writeln('👤 Пользователь: ${diagnostics['userEmail']}');
    buffer.writeln('🌐 Онлайн: ${diagnostics['isOnline']}');
    buffer.writeln('📁 ID папки: ${diagnostics['targetFolderId']}');
    buffer.writeln('💾 Статус кеша: ${diagnostics['cacheStatus']}');
    buffer.writeln('📄 Файлов в кеше: ${diagnostics['cachedFilesCount']}');
    buffer.writeln('⏰ Последнее обновление: ${diagnostics['cacheLastUpdated'] ?? 'Никогда'}');
    buffer.writeln('🔍 Режим отладки: ${diagnostics['debugMode']}');
    buffer.writeln('🔑 Scopes: ${diagnostics['scopes']}');
    
    if (diagnostics['lastError'] != null && diagnostics['lastError'].toString().isNotEmpty) {
      buffer.writeln('\n❌ Последняя ошибка:');
      buffer.writeln(diagnostics['lastError']);
    }
    
    if (diagnostics['googleSignInCurrentUser'] != null) {
      buffer.writeln('\n👤 Google Sign-In:');
      buffer.writeln('Текущий пользователь: ${diagnostics['googleSignInCurrentUser']}');
      buffer.writeln('Авторизован: ${diagnostics['googleSignInIsSignedIn']}');
    }
    
    if (diagnostics['driveApiInitialized'] != null) {
      buffer.writeln('\n🔧 Drive API:');
      buffer.writeln('Инициализирован: ${diagnostics['driveApiInitialized']}');
      buffer.writeln('Статус: ${diagnostics['driveApiStatus'] ?? 'Неизвестно'}');
    }
    
    if (diagnostics['connectivityType'] != null) {
      buffer.writeln('\n🌐 Подключение: ${diagnostics['connectivityType']}');
    }
    
    return buffer.toString();
  }
}