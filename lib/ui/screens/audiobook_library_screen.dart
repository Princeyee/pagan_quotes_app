import 'package:flutter/material.dart';
import '../../models/audiobook.dart';
import '../../services/enhanced_audiobook_service.dart';
import '../../ui/widgets/audiobook_card.dart';
import '../widgets/glass_background.dart';
import 'enhanced_audiobook_player.dart';
import 'dart:ui' as ui;

class AudiobookLibraryScreen extends StatefulWidget {
  @override
  _AudiobookLibraryScreenState createState() => _AudiobookLibraryScreenState();
}

class _AudiobookLibraryScreenState extends State<AudiobookLibraryScreen> {
  final EnhancedAudiobookService _audiobookService = EnhancedAudiobookService();
  List<Audiobook> _audiobooks = [];
  bool _isLoading = true;
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _loadAudiobooks();
  }

  Future<void> _loadAudiobooks() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Начинаем загрузку аудиокниг...';
    });
    
    try {
      print('🔍 Начинаем загрузку аудиокниг...');
      
      // Инициализируем сервис
      await _audiobookService.initialize();
      
      setState(() {
        _debugInfo = 'Сервис инициализирован, загружаем аудиокниги...';
      });
      
      // Загружаем аудиокниги
      final audiobooks = await _audiobookService.getAudiobooks();
      
      print('📚 Загружено аудиокниг: ${audiobooks.length}');
      
      if (mounted) {
        setState(() {
          _audiobooks = audiobooks;
          _isLoading = false;
          _debugInfo = 'Загружено ${audiobooks.length} аудиокниг';
        });
      }
    } catch (e) {
      print('❌ Ошибка при загрузке аудиокниг: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _debugInfo = 'Ошибка: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки аудиокниг: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/backgrounds/main_bg.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: GlassBackground(
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
                                    'Добавьте аудиофайлы в папку Google Drive',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 20),
                                  // Отладочная информация
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    margin: EdgeInsets.symmetric(horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[600]!),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Отладочная информация:',
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          _debugInfo,
                                          style: TextStyle(
                                            color: Colors.grey[300],
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        SizedBox(height: 10),
                                        ElevatedButton(
                                          onPressed: _loadAudiobooks,
                                          child: Text('Повторить загрузку'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber,
                                            foregroundColor: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
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
                                          builder: (context) => EnhancedAudiobookPlayer(
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
                Positioned(
                  top: 16,
                  left: 16,
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Material(
                        color: Colors.black.withOpacity(0.25),
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                          onPressed: () => Navigator.of(context).maybePop(),
                          tooltip: 'Назад',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}