
import 'package:flutter/material.dart';
import '../../models/audiobook.dart';
import '../../services/audiobook_service.dart';
import '../../ui/widgets/audiobook_card.dart';
import 'audiobook_player_screen.dart';

class AudiobookLibraryScreen extends StatefulWidget {
  @override
  _AudiobookLibraryScreenState createState() => _AudiobookLibraryScreenState();
}

class _AudiobookLibraryScreenState extends State<AudiobookLibraryScreen> {
  final AudiobookService _audiobookService = AudiobookService();
  List<Audiobook> _audiobooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAudiobooks();
  }

  Future<void> _loadAudiobooks() async {
    try {
      final audiobooks = await _audiobookService.getAudiobooks();
      setState(() {
        _audiobooks = audiobooks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки аудиокниг: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1a1a1a),
      appBar: AppBar(
        title: Text(
          'Аудиокниги',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF1a1a1a),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
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
    );
  }
}
