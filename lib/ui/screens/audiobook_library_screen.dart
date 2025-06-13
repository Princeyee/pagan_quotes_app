import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/audiobook.dart';
import '../../services/audiobook_service.dart';
import '../../services/google_drive_service.dart';
import '../../ui/widgets/audiobook_card.dart';
import 'audiobook_player_screen.dart';
import 'dart:convert';

class AudiobookLibraryScreen extends StatefulWidget {
  @override
  _AudiobookLibraryScreenState createState() => _AudiobookLibraryScreenState();
}

class _AudiobookLibraryScreenState extends State<AudiobookLibraryScreen> {
  final AudiobookService _audiobookService = AudiobookService();
  final GoogleDriveService _googleDriveService = GoogleDriveService();
  List<Audiobook> _audiobooks = [];
  bool _isLoading = true;
  bool _isGoogleDriveConnected = false;

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
      final audiobooks = await _audiobookService.getAudiobooks();
      
      if (mounted) {
        setState(() {
          _audiobooks = audiobooks;
          _isLoading = false;
        });
        
        // Проверяем статус Google Drive после загрузки книг
        _checkGoogleDriveStatus();
      }
    } catch (e) {
      print('Ошибка при загрузке аудиокниг: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки аудиокниг: $e')),
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
          // Кнопка для подключения к Google Drive
          IconButton(
            icon: Icon(
              _isGoogleDriveConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isGoogleDriveConnected ? Colors.green : Colors.grey,
            ),
            onPressed: _isLoading ? null : _connectToGoogleDrive,
            tooltip: _isGoogleDriveConnected 
                ? 'Подключено к Google Drive' 
                : 'Подключиться к Google Drive',
          ),
          // Кнопка для диагностики
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _isLoading ? null : _showDiagnosticInfo,
            tooltip: 'Диагностика Google Drive',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAudiobooks,
            tooltip: 'Обновить',
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
          
          // Стеклянный контейнер
          SafeArea(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.3 * 255).round()),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withAlpha((0.1 * 255).round()),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.2 * 255).round()),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
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
                                  Icons.audiotrack,
                                  size: 80,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(height: 20),
                                Text(
                                  'Нет доступных аудиокниг',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Добавьте аудиофайлы в папку assets/audiobooks/',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
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
            ),
          ),
        ],
      ),
    );
  }
}