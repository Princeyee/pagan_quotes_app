import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/audiobook.dart';
import '../../services/audiobook_service.dart';
import '../../services/google_drive_service.dart';
import '../../services/debug_audiobook_service.dart';
import '../../ui/widgets/audiobook_card.dart';
import '../widgets/glass_background.dart';
import 'audiobook_player_screen.dart';
import 'dart:convert';

class AudiobookLibraryScreen extends StatefulWidget {
  @override
  _AudiobookLibraryScreenState createState() => _AudiobookLibraryScreenState();
}

class _AudiobookLibraryScreenState extends State<AudiobookLibraryScreen> {
  final AudiobookService _audiobookService = AudiobookService();
  final GoogleDriveService _googleDriveService = GoogleDriveService();
  final DebugAudiobookService _debugService = DebugAudiobookService();
  List<Audiobook> _audiobooks = [];
  bool _isLoading = true;
  bool _isGoogleDriveConnected = false;
  bool _useDebugMode = false; // Флаг для режима отладки

  @override
  void initState() {
    super.initState();
    _loadAudiobooks();
    _checkGoogleDriveStatus();
  }
  
  Future<void> _checkGoogleDriveStatus() async {
    try {
      final isInitialized = await _googleDriveService.initialize();
      setState(() {
        _isGoogleDriveConnected = isInitialized;
      });
    } catch (e) {
      print('Ошибка при проверке статуса Google Drive: $e');
    }
  }

  Future<void> _loadAudiobooks() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      List<Audiobook> audiobooks;
      
      if (_useDebugMode) {
        // Режим отладки - только локальные файлы
        print('🔧 Режим отладки: загружаем только локальные аудиокниги');
        audiobooks = await _debugService.getLocalAudiobooks();
      } else {
        // Обычный режим - пытаемся загрузить из Google Drive
        audiobooks = await _audiobookService.getAudiobooks();
      }
      
      if (mounted) {
        setState(() {
          _audiobooks = audiobooks;
          _isLoading = false;
        });
        
        // Проверяем статус Google Drive после загрузки книг (только в обычном режиме)
        if (!_useDebugMode) {
          _checkGoogleDriveStatus();
        }
      }
    } catch (e) {
      print('Ошибка при загрузке аудиокниг: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки аудиок��иг: $e')),
        );
      }
    }
  }
  
  Future<void> _connectToGoogleDrive() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final isInitialized = await _googleDriveService.initialize();
      
      if (mounted) {
        setState(() {
          _isGoogleDriveConnected = isInitialized;
          _isLoading = false;
        });
        
        if (isInitialized) {
          // Если успешно подключились, перезагружаем книги
          _loadAudiobooks();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Успешное подключение к Google Drive')),
          );
        } else {
          final lastError = _googleDriveService.getLastError();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не удалось подключиться к Google Drive: $lastError'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('Ошибка при подключении к Google Drive: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка подключения к Google Drive: $e'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  // Метод для отображения диагностической информации
  Future<void> _showDiagnosticInfo() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final diagnosticInfo = await _googleDriveService.getDiagnosticInfo();
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        // Подготовка полного текста диагностики для копирования
        final String fullDiagnosticText = '''
ДИАГНОСТИКА GOOGLE DRIVE:
Статус инициализации: ${diagnosticInfo['isInitialized'] ? 'Да' : 'Нет'}
Пользователь: ${diagnosticInfo['userEmail'] ?? 'Нет'}
Онлайн: ${diagnosticInfo['isOnline'] ? 'Да' : 'Нет'}
ID папки: ${diagnosticInfo['targetFolderId']}
Кеш: ${diagnosticInfo['cacheStatus'] ?? 'Не определен'}
Файлов в кеше: ${diagnosticInfo['cachedFilesCount'] ?? '0'}
Последнее обновление кеша: ${diagnosticInfo['cacheLastUpdated'] ?? 'Никогда'}
Последняя ошибка: ${diagnosticInfo['lastError'] ?? 'Нет'}

ПОЛНАЯ ИНФОРМАЦИЯ:
${const JsonEncoder.withIndent('  ').convert(diagnosticInfo)}
''';

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Диагностика Google Drive'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Статус инициализации: ${diagnosticInfo['isInitialized'] ? 'Да' : 'Нет'}'),
                  SizedBox(height: 8),
                  Text('Пользователь: ${diagnosticInfo['userEmail'] ?? 'Нет'}'),
                  SizedBox(height: 8),
                  Text('Онлайн: ${diagnosticInfo['isOnline'] ? 'Да' : 'Нет'}'),
                  SizedBox(height: 8),
                  Text('ID папки: ${diagnosticInfo['targetFolderId']}'),
                  SizedBox(height: 8),
                  // Новые поля
                  Text('Статус кеша: ${diagnosticInfo['cacheStatus'] ?? 'Не определен'}'),
                  SizedBox(height: 8),
                  Text('Файлов в кеше: ${diagnosticInfo['cachedFilesCount'] ?? '0'}'),
                  SizedBox(height: 8),
                  Text('Последнее обновление кеша: ${
                    diagnosticInfo['cacheLastUpdated'] != null
                      ? DateTime.parse(diagnosticInfo['cacheLastUpdated']).toLocal().toString()
                      : 'Никогда'
                  }'),
                  SizedBox(height: 8),
                  // Конец новых полей
                  Text('Последняя ошибка: ${diagnosticInfo['lastError'] ?? 'Нет'}'),
                  SizedBox(height: 16),
                  Text('Полная информация:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      const JsonEncoder.withIndent('  ').convert(diagnosticInfo),
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Кнопка для копирования всей информации
                  ElevatedButton.icon(
                    icon: Icon(Icons.copy),
                    label: Text('Копировать всю информацию'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      minimumSize: Size(double.infinity, 48),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: fullDiagnosticText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Диагностическая информация скопирована в буфер обмена'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                  // Кнопка для очистки кеша
                  SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: Icon(Icons.delete),
                    label: Text('Очистить кеш'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 48),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _googleDriveService.clearCache();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Кеш успешно очищен'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      // Показываем диагностику снова
                      _showDiagnosticInfo();
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Закрыть'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _connectToGoogleDrive();
                },
                child: Text('Переподключиться'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка получения диагностической информации: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Аудиокниги',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          // Кнопка переключения режима отладки
          IconButton(
            icon: Icon(
              _useDebugMode ? Icons.bug_report : Icons.cloud,
              color: _useDebugMode ? Colors.orange : Colors.blue,
            ),
            onPressed: _isLoading ? null : () {
              setState(() {
                _useDebugMode = !_useDebugMode;
              });
              _loadAudiobooks();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_useDebugMode 
                    ? '🔧 Режим отладки: только локальные файлы' 
                    : '☁️ Обычный режим: Google Drive + локальные файлы'
                  ),
                  backgroundColor: _useDebugMode ? Colors.orange : Colors.blue,
                ),
              );
            },
            tooltip: _useDebugMode 
                ? 'Режим отладки (только локальные файлы)'
                : 'Обычный режим (Google Drive + локальные)',
          ),
          // Кнопка для подключения к Google Drive (только в обычном режиме)
          if (!_useDebugMode) IconButton(
            icon: Icon(
              _isGoogleDriveConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isGoogleDriveConnected ? Colors.green : Colors.grey,
            ),
            onPressed: _isLoading ? null : _connectToGoogleDrive,
            tooltip: _isGoogleDriveConnected
                ? 'Подключено к Google Drive'
                : 'Подключиться к Google Drive',
          ),
          // Кнопка для обновления файлов Drive (только в обычном режиме)
          if (!_useDebugMode) IconButton(
            icon: Icon(Icons.cloud_sync),
            onPressed: _isLoading ? null : () async {
              setState(() { _isLoading = true; });
              try {
                // Принудительно обновляем файлы
                await _googleDriveService.refreshFiles();
                // Затем перезагружаем аудиокниги
                await _loadAudiobooks();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Список файлов Drive обновлен'))
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка обновления: $e'))
                );
              } finally {
                if (mounted) setState(() { _isLoading = false; });
              }
            },
            tooltip: 'Обновить файл�� Drive',
          ),
          // Кнопка для диагностики (только в обычном режиме)
          if (!_useDebugMode) IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _isLoading ? null : _showDiagnosticInfo,
            tooltip: 'Диагностика Google Drive',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAudiobooks,
            tooltip: 'Обновить библиотеку',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Размытый фон с изображением из главного экрана
          Image.asset(
            'assets/images/backgrounds/main_bg.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          // Стеклянный контейнер с использованием GlassBackground
          SafeArea(
            child: GlassBackground(
              borderRadius: BorderRadius.circular(20),
              child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  )
                : _audiobooks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _useDebugMode ? Icons.bug_report : Icons.audiotrack,
                              size: 80,
                              color: _useDebugMode ? Colors.orange[600] : Colors.grey[600],
                            ),
                            SizedBox(height: 20),
                            Text(
                              _useDebugMode 
                                ? 'Нет локальных аудиокниг'
                                : 'Нет доступных аудиокниг',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              _useDebugMode
                                ? 'Добавьте аудиофайлы в папку assets/audiobooks/\nили переключитесь в обычный режим'
                                : 'Добавьте аудиофайлы в папку Google Drive\nили переключитесь в режим отладки',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_useDebugMode) ...[
                              SizedBox(height: 20),
                              ElevatedButton.icon(
                                icon: Icon(Icons.cloud),
                                label: Text('Переключиться в обычный режим'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _useDebugMode = false;
                                  });
                                  _loadAudiobooks();
                                },
              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAudiobooks,
                        child: GridView.builder(
                          padding: EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _audiobooks.length,
                          itemBuilder: (context, index) {
                            final audiobook = _audiobooks[index];
                            return AudiobookCard(
                              audiobook: audiobook,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AudiobookPlayerScreen(
                                      audiobook: audiobook,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
