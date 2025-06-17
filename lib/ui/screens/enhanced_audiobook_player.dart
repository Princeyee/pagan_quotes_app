import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../models/audiobook.dart';
import '../../services/enhanced_audiobook_service.dart';

class EnhancedAudiobookPlayer extends StatefulWidget {
  final Audiobook audiobook;
  final int? initialChapter;

  const EnhancedAudiobookPlayer({
    Key? key,
    required this.audiobook,
    this.initialChapter,
  }) : super(key: key);

  @override
  State<EnhancedAudiobookPlayer> createState() => _EnhancedAudiobookPlayerState();
}

class _EnhancedAudiobookPlayerState extends State<EnhancedAudiobookPlayer>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final EnhancedAudiobookService _audiobookService = EnhancedAudiobookService();

  late AnimationController _playPauseController;
  late AnimationController _waveController;
  late AnimationController _chapterListController;

  int _currentChapterIndex = 0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _showChapterList = false;
  double _playbackSpeed = 1.0;

  // Цветовая палитра из обложки
  Color _dominantColor = Colors.deepPurple;
  Color _accentColor = Colors.purple;
  List<Color> _gradientColors = [Colors.deepPurple, Colors.purple];

  // Sleep timer
  Duration? _sleepTimer;
  DateTime? _sleepEndTime;

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.initialChapter ?? 0;

    _initializeAnimations();
    _initializeAudio();
    _setupAudioListeners();
    _extractColorsFromCover();
    _audiobookService.initialize();
  }

  void _initializeAnimations() {
    _playPauseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    _chapterListController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  // Извлечение ц��етов из обложки книги
  Future<void> _extractColorsFromCover() async {
    try {
      ImageProvider imageProvider;
      
      if (widget.audiobook.coverPath.startsWith('http')) {
        imageProvider = NetworkImage(widget.audiobook.coverPath);
      } else {
        imageProvider = AssetImage(widget.audiobook.coverPath);
      }

      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 10,
      );

      setState(() {
        _dominantColor = paletteGenerator.dominantColor?.color ?? Colors.deepPurple;
        _accentColor = paletteGenerator.vibrantColor?.color ?? 
                      paletteGenerator.lightVibrantColor?.color ?? 
                      Colors.purple;
        
        _gradientColors = [
          _dominantColor,
          _accentColor,
          _dominantColor.withOpacity(0.8),
        ];
      });
    } catch (e) {
      print('Ошибка извлечения цветов: $e');
      // Используем цвета по умолчанию
      setState(() {
        _dominantColor = Colors.deepPurple;
        _accentColor = Colors.purple;
        _gradientColors = [Colors.deepPurple, Colors.purple];
      });
    }
  }

  void _initializeAudio() async {
    setState(() => _isLoading = true);

    try {
      final chapter = widget.audiobook.chapters[_currentChapterIndex];
      
      // Показываем прогресс загрузки
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Подготовка аудио...'),
            ],
          ),
          duration: Duration(seconds: 30),
          backgroundColor: _dominantColor.withOpacity(0.9),
        ),
      );
      
      final playableUrl = await _audiobookService.getPlayableUrl(chapter);
      
      if (playableUrl == null) {
        throw Exception('Не удалось получить URL для воспроизведения');
      }
      
      // Устанавливаем источник аудио
      if (playableUrl.startsWith('http')) {
        await _audioPlayer.setUrl(playableUrl);
      } else {
        await _audioPlayer.setFilePath(playableUrl);
      }

      // Восстановить позицию из сохраненного прогресса
      final progress = await _audiobookService.getProgress(widget.audiobook.id);
      if (progress != null && progress.chapterIndex == _currentChapterIndex) {
        await _audioPlayer.seek(progress.position);
      }
      
      // Предзагружаем следующие главы
      _audiobookService.preloadNextChapters(widget.audiobook, _currentChapterIndex);
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showError('Ошибка загрузки аудиофайла: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setupAudioListeners() {
    _audioPlayer.positionStream.listen((position) {
      setState(() => _currentPosition = position);
      _saveProgress();
    });

    _audioPlayer.durationStream.listen((duration) {
      setState(() => _totalDuration = duration ?? Duration.zero);
    });

    _audioPlayer.playerStateStream.listen((state) {
      final isPlaying = state.playing;
      final processingState = state.processingState;

      setState(() => _isPlaying = isPlaying);

      if (isPlaying) {
        _playPauseController.forward();
        _waveController.repeat();
      } else {
        _playPauseController.reverse();
        _waveController.stop();
      }

      if (processingState == ProcessingState.completed) {
        _nextChapter();
      }
    });
  }

  void _saveProgress() async {
    await _audiobookService.saveProgress(
      widget.audiobook.id,
      _currentChapterIndex,
      _currentPosition,
    );
  }

  void _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_audioPlayer.processingState == ProcessingState.idle ||
          _audioPlayer.processingState == ProcessingState.loading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 16),
                Text('Загрузка аудио...'),
              ],
            ),
            duration: Duration(seconds: 10),
            backgroundColor: _dominantColor.withOpacity(0.9),
          ),
        );
      }
      
      await _audioPlayer.play();
    }
  }

  void _seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void _changeChapter(int index) async {
    if (index >= 0 && index < widget.audiobook.chapters.length) {
      setState(() {
        _currentChapterIndex = index;
        _isLoading = true;
      });

      try {
        final chapter = widget.audiobook.chapters[index];
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 16),
                Text('Загрузка главы...'),
              ],
            ),
            duration: Duration(seconds: 10),
            backgroundColor: _dominantColor.withOpacity(0.9),
          ),
        );
        
        final playableUrl = await _audiobookService.getPlayableUrl(chapter);
        
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        if (playableUrl == null) {
          throw Exception('Не удалось получить URL для воспроизведения');
        }
        
        if (playableUrl.startsWith('http')) {
          await _audioPlayer.setUrl(playableUrl);
        } else {
          await _audioPlayer.setFilePath(playableUrl);
        }

        final progress = await _audiobookService.getProgress(widget.audiobook.id);
        if (progress != null && progress.chapterIndex == index) {
          await _audioPlayer.seek(progress.position);
        }
        
        await _audioPlayer.play();
        
        // Предзагружаем следующие главы
        _audiobookService.preloadNextChapters(widget.audiobook, index);
        
      } catch (e) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showError('Ошибка загрузки главы: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _nextChapter() {
    if (_currentChapterIndex < widget.audiobook.chapters.length - 1) {
      _changeChapter(_currentChapterIndex + 1);
    }
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      _changeChapter(_currentChapterIndex - 1);
    }
  }

  void _changeSpeed(double speed) async {
    setState(() => _playbackSpeed = speed);
    await _audioPlayer.setSpeed(speed);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradientColors,
          ),
        ),
        child: Stack(
          children: [
            // Фоновое изображение с блюром
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: widget.audiobook.coverPath.startsWith('http')
                        ? NetworkImage(widget.audiobook.coverPath) as ImageProvider
                        : AssetImage(widget.audiobook.coverPath),
                    fit: BoxFit.cover,
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _dominantColor.withOpacity(0.7),
                          _accentColor.withOpacity(0.8),
                          _dominantColor.withOpacity(0.9),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Основной контент
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    flex: 3,
                    child: _buildCoverSection(),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildControlsSection(),
                  ),
                ],
              ),
            ),
            
            // Список глав с glass effect
            _buildChapterList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.audiobook.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.audiobook.author,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _showChapterList ? Icons.keyboard_arrow_down : Icons.list,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() => _showChapterList = !_showChapterList);
              if (_showChapterList) {
                _chapterListController.forward();
              } else {
                _chapterListController.reverse();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCoverSection() {
    final currentChapter = widget.audiobook.chapters[_currentChapterIndex];
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Обложка без черных полос
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Hero(
                tag: 'audiobook_cover_${widget.audiobook.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 1.0, // Квадратная обложка
                    child: widget.audiobook.coverPath.startsWith('http')
                      ? Image.network(
                          widget.audiobook.coverPath,
                          fit: BoxFit.cover, // Заполняем весь контейнер
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: _dominantColor,
                              child: const Icon(
                                Icons.audiotrack,
                                color: Colors.white,
                                size: 100,
                              ),
                            );
                          },
                        )
                      : Image.asset(
                          widget.audiobook.coverPath,
                          fit: BoxFit.cover, // Заполняем весь контейнер
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: _dominantColor,
                              child: const Icon(
                                Icons.audiotrack,
                                color: Colors.white,
                                size: 100,
                              ),
                            );
                          },
                        ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Название главы
          Text(
            currentChapter.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // Прогресс главы
          Text(
            'Глава ${_currentChapterIndex + 1} из ${widget.audiobook.chapters.length}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Прогресс бар
          Column(
            children: [
              Row(
                children: [
                  Text(
                    _formatDuration(_currentPosition),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  Expanded(
                    child: Slider(
                      value: _totalDuration.inMilliseconds > 0
                          ? _currentPosition.inMilliseconds.toDouble()
                          : 0.0,
                      max: _totalDuration.inMilliseconds.toDouble(),
                      onChanged: (value) {
                        _seek(Duration(milliseconds: value.toInt()));
                      },
                      activeColor: Colors.white,
                      inactiveColor: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  Text(
                    _formatDuration(_totalDuration),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Кнопки управления
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Предыдущая глава
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                iconSize: 32,
                onPressed: _currentChapterIndex > 0 ? _previousChapter : null,
              ),

              // Перемотка назад
              IconButton(
                icon: const Icon(Icons.replay_30, color: Colors.white),
                iconSize: 28,
                onPressed: () {
                  final newPosition = _currentPosition - const Duration(seconds: 30);
                  _seek(newPosition < Duration.zero ? Duration.zero : newPosition);
                },
              ),

              // Play/Pause
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: _isLoading ? null : _playPause,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: AnimatedIcon(
                        icon: AnimatedIcons.play_pause,
                        progress: _playPauseController,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),

              // Перемотка вперед
              IconButton(
                icon: const Icon(Icons.forward_30, color: Colors.white),
                iconSize: 28,
                onPressed: () {
                  final newPosition = _currentPosition + const Duration(seconds: 30);
                  _seek(newPosition > _totalDuration ? _totalDuration : newPosition);
                },
              ),

              // Следующая глава
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                iconSize: 32,
                onPressed: _currentChapterIndex < widget.audiobook.chapters.length - 1
                    ? _nextChapter
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Скорость воспроизведения
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Скорость: ', style: TextStyle(color: Colors.white)),
              GestureDetector(
                onTap: _showSpeedDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChapterList() {
    return AnimatedSlide(
      offset: _showChapterList ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuart,
      child: AnimatedOpacity(
        opacity: _showChapterList ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.6,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _dominantColor.withOpacity(0.9),
                      _accentColor.withOpacity(0.95),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Индикатор свайпа
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    
                    // Заголовок
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(
                            Icons.menu_book,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Главы аудиокниги',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              setState(() => _showChapterList = false);
                              _chapterListController.reverse();
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Список глав
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        physics: const BouncingScrollPhysics(),
                        itemCount: widget.audiobook.chapters.length,
                        itemBuilder: (context, index) {
                          final chapter = widget.audiobook.chapters[index];
                          final isCurrentChapter = index == _currentChapterIndex;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: isCurrentChapter
                                  ? LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.3),
                                        Colors.white.withOpacity(0.1),
                                      ],
                                    )
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _changeChapter(index),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Номер главы
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: isCurrentChapter
                                                ? [Colors.white, Colors.white.withOpacity(0.8)]
                                                : [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)],
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: isCurrentChapter ? _dominantColor : Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      const SizedBox(width: 16),
                                      
                                      // Информация о главе
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              chapter.title,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: isCurrentChapter
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: Colors.white,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatDuration(chapter.duration),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white.withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Индикатор воспроизведения
                                      if (isCurrentChapter)
                                        AnimatedBuilder(
                                          animation: _waveController,
                                          builder: (context, child) {
                                            return Icon(
                                              _isPlaying ? Icons.graphic_eq : Icons.play_arrow,
                                              color: Colors.white,
                                              size: 24,
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSpeedDialog() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: _dominantColor.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Скорость воспроизведения',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
              final isSelected = speed == _playbackSpeed;
              return RadioListTile<double>(
                title: Text(
                  '${speed}x',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                value: speed,
                groupValue: _playbackSpeed,
                activeColor: Colors.white,
                onChanged: (value) {
                  if (value != null) {
                    _changeSpeed(value);
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _playPauseController.dispose();
    _waveController.dispose();
    _chapterListController.dispose();
    super.dispose();
  }
}