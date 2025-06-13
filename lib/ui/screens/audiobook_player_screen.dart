import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../../models/audiobook.dart';
import '../../services/audiobook_service.dart';

class AudiobookPlayerScreen extends StatefulWidget {
  final Audiobook audiobook;
  final int? initialChapter;

  const AudiobookPlayerScreen({
    Key? key,
    required this.audiobook,
    this.initialChapter,
  }) : super(key: key);

  @override
  State<AudiobookPlayerScreen> createState() => _AudiobookPlayerScreenState();
}

class _AudiobookPlayerScreenState extends State<AudiobookPlayerScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudiobookService _audiobookService = AudiobookService();

  late AnimationController _playPauseController;
  late AnimationController _waveController;

  int _currentChapterIndex = 0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _showChapterList = false;
  double _playbackSpeed = 1.0;

  // Sleep timer
  Duration? _sleepTimer;
  DateTime? _sleepEndTime;
  
  // Background playback
  bool _playInBackground = true;



  void _initializeAudio() async {
    setState(() => _isLoading = true);

    try {
      final chapterPath = widget.audiobook.chapters[_currentChapterIndex].filePath;
      await _audioPlayer.setAsset(chapterPath);

      // Восстановить позицию из сохраненного прогресса
      final progress = await _audiobookService.getProgress(widget.audiobook.id);
      if (progress != null && progress.chapterIndex == _currentChapterIndex) {
        await _audioPlayer.seek(progress.position);
      }
    } catch (e) {
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

      // Автопереход к следующей главе
      if (processingState == ProcessingState.completed) {
        _nextChapter();
      }
    });
  }
  
  // Контроллер анимации для списка глав
  late AnimationController _chapterListAnimationController;
  
  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.initialChapter ?? 0;

    _playPauseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    
    // Контроллер анимации для списка глав
    _chapterListAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Инициализируем контроллер анимации в правильном состоянии
    if (_isPlaying) {
      _playPauseController.value = 1.0;
    } else {
      _playPauseController.value = 0.0;
    }

    // Инициализируем аудио сессию и настраиваем фоновое воспроизведение
    _initAudioSession();
    
    _initializeAudio();
    _setupAudioListeners();
  }
  
  // Инициализация аудио сессии
  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.music());
      // По умолчанию включаем фоновое воспроизведение
      _setupBackgroundPlayback();
    } catch (e) {
      print('Ошибка инициализации аудио сессии: $e');
    }
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
        final chapterPath = widget.audiobook.chapters[index].filePath;
        await _audioPlayer.setAsset(chapterPath);

        // Проверить сохраненный прогресс для новой главы
        final progress = await _audiobookService.getProgress(widget.audiobook.id);
        if (progress != null && progress.chapterIndex == index) {
          await _audioPlayer.seek(progress.position);
        }
      } catch (e) {
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

  void _setSleepTimer(Duration duration) {
    setState(() {
      _sleepTimer = duration;
      _sleepEndTime = DateTime.now().add(duration);
    });

    Future.delayed(duration, () {
      if (mounted && _isPlaying) {
        _audioPlayer.pause();
        setState(() {
          _sleepTimer = null;
          _sleepEndTime = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Таймер сна сработал')),
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
    final theme = Theme.of(context);
    final currentChapter = widget.audiobook.chapters[_currentChapterIndex];

    return Scaffold(
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // Свайп вверх для показа списка глав
          if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
            setState(() => _showChapterList = true);
          }
          // Свайп вниз для скрытия списка глав
          else if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            setState(() => _showChapterList = false);
          }
        },
        child: Stack(
          children: [
            // Blurred background from cover image
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
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: Colors.black.withAlpha((0.7 * 255).round()),
                  ),
                ),
              ),
            ),
            
            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(context),
  
                  // Cover Art & Chapter Info
                  Expanded(
                    flex: 3,
                    child: _buildCoverSection(currentChapter),
                  ),
  
                  // Progress & Controls
                  Expanded(
                    flex: 2,
                    child: _buildControlsSection(theme),
                  ),
                ],
              ),
            ),
            
            // Chapter List (показывается при свайпе с анимацией)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.6, // Занимает 60% экрана
              child: _buildChapterList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((0.3 * 255).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.all(8.0),
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
                    color: Colors.white.withAlpha((0.7 * 255).round()),
                  ),
                ),
              ],
            ),
          ),
          // Индикатор свайпа для списка глав
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _showChapterList ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _showChapterList ? "Скрыть главы" : "Показать главы",
                  style: TextStyle(
                    color: Colors.white.withAlpha((0.9 * 255).round()),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: _handleMenuAction,
            color: Colors.black.withAlpha((0.8 * 255).round()),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'speed', 
                child: Row(
                  children: [
                    const Icon(Icons.speed, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text('Скорость', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'timer', 
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text('Таймер сна', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'background', 
                child: Row(
                  children: [
                    Icon(
                      _playInBackground ? Icons.music_note : Icons.music_off,
                      color: Colors.white,
                      size: 20
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _playInBackground ? 'Фоновое воспроизведение: Вкл' : 'Фоновое воспроизведение: Выкл',
                      style: const TextStyle(color: Colors.white)
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoverSection(AudiobookChapter currentChapter) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Cover Art
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.5 * 255).round()),
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
                  child: Container(
                    width: 300,
                    height: 300,
                    color: Colors.black, // Черный фон для контейнера
                    child: widget.audiobook.coverPath.startsWith('http')
                      ? Image.network(
                          widget.audiobook.coverPath,
                          width: 300,
                          height: 300,
                          fit: BoxFit.contain, // Используем contain для сохранения пропорций
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 300,
                              height: 300,
                              color: Colors.grey[800],
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
                          width: 300,
                          height: 300,
                          fit: BoxFit.contain, // Используем contain для сохранения пропорций
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 300,
                              height: 300,
                              color: Colors.grey[800],
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

          // Chapter Title
          Text(
            currentChapter.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // Chapter Progress
          Text(
            'Глава ${_currentChapterIndex + 1} из ${widget.audiobook.chapters.length}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Кнопки быстрого доступа (таймер сна и список глав)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Кнопка таймера сна
              _buildQuickActionButton(
                icon: Icons.nightlight_round,
                label: _sleepTimer != null 
                    ? _formatDuration(_sleepEndTime!.difference(DateTime.now()))
                    : 'Таймер сна',
                onTap: _showSleepTimerDialog,
                isActive: _sleepTimer != null,
                color: theme.primaryColor,
              ),
              
              const SizedBox(width: 12),
              
              // Кнопка списка глав
              _buildQuickActionButton(
                icon: Icons.menu_book,
                label: 'Главы',
                onTap: () => setState(() => _showChapterList = !_showChapterList),
                isActive: _showChapterList,
                color: theme.primaryColor,
              ),
              
              const SizedBox(width: 12),
              
              // Кнопка скорости воспроизведения
              _buildQuickActionButton(
                icon: Icons.speed,
                label: '${_playbackSpeed}x',
                onTap: _showSpeedDialog,
                isActive: _playbackSpeed != 1.0,
                color: theme.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Виджет для кнопок быстрого доступа
  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isActive
                  ? [color.withAlpha((0.3 * 255).round()), color.withAlpha((0.1 * 255).round())]
                  : [Colors.white.withAlpha((0.1 * 255).round()), Colors.white.withAlpha((0.05 * 255).round())],
            ),
            border: Border.all(
              color: isActive ? color.withAlpha((0.5 * 255).round()) : Colors.white.withAlpha((0.1 * 255).round()),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? color : Colors.white.withAlpha((0.8 * 255).round()),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? color : Colors.white.withAlpha((0.8 * 255).round()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Progress Bar
          Column(
            children: [
              Row(
                children: [
                  Text(
                    _formatDuration(_currentPosition),
                    style: const TextStyle(fontSize: 12),
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
                      activeColor: theme.primaryColor,
                    ),
                  ),
                  Text(
                    _formatDuration(_totalDuration),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),

              // Sleep Timer Info
              if (_sleepTimer != null)
                Text(
                  'Таймер: ${_formatDuration(_sleepEndTime!.difference(DateTime.now()))}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.primaryColor,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Playback Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Previous Chapter
              IconButton(
                icon: const Icon(Icons.skip_previous),
                iconSize: 32,
                onPressed: _currentChapterIndex > 0 ? _previousChapter : null,
              ),

              // Rewind 30s
              IconButton(
                icon: const Icon(Icons.replay_30),
                iconSize: 28,
                onPressed: () {
                  final newPosition = _currentPosition - const Duration(seconds: 30);
                  _seek(newPosition < Duration.zero ? Duration.zero : newPosition);
                },
              ),

              // Play/Pause
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.7 * 255).round()), // Меняем цвет с белого на темный
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withAlpha((0.4 * 255).round()),
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
                        color: theme.primaryColor, // Меняем цвет иконки с белого на цвет темы
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),

              // Forward 30s
              IconButton(
                icon: const Icon(Icons.forward_30),
                iconSize: 28,
                onPressed: () {
                  final newPosition = _currentPosition + const Duration(seconds: 30);
                  _seek(newPosition > _totalDuration ? _totalDuration : newPosition);
                },
              ),

              // Next Chapter
              IconButton(
                icon: const Icon(Icons.skip_next),
                iconSize: 32,
                onPressed: _currentChapterIndex < widget.audiobook.chapters.length - 1
                    ? _nextChapter
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Speed Control
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Скорость: '),
              Text(
                '${_playbackSpeed}x',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChapterList() {
    final theme = Theme.of(context);
    
    return AnimatedSlide(
      offset: _showChapterList ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuart,
      child: AnimatedOpacity(
        opacity: _showChapterList ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha((0.75 * 255).round()),
                    Colors.black.withAlpha((0.85 * 255).round()),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: Colors.white.withAlpha((0.15 * 255).round()),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.6 * 255).round()),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
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
                        color: Colors.white.withAlpha((0.3 * 255).round()),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  
                  // Заголовок списка глав
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.primaryColor.withAlpha((0.2 * 255).round()),
                          Colors.black.withAlpha((0.5 * 255).round()),
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withAlpha((0.15 * 255).round()),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book,
                          color: theme.primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Главы аудиокниги',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withAlpha((0.5 * 255).round()),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.1 * 255).round()),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => setState(() => _showChapterList = false),
                            tooltip: 'Закрыть список глав',
                          ),
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
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: isCurrentChapter
                                ? LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      theme.primaryColor.withAlpha((0.2 * 255).round()),
                                      theme.primaryColor.withAlpha((0.1 * 255).round()),
                                    ],
                                  )
                                : null,
                            boxShadow: isCurrentChapter
                                ? [
                                    BoxShadow(
                                      color: theme.primaryColor.withAlpha((0.2 * 255).round()),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _changeChapter(index),
                              splashColor: theme.primaryColor.withAlpha((0.1 * 255).round()),
                              highlightColor: theme.primaryColor.withAlpha((0.05 * 255).round()),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                child: Row(
                                  children: [
                                    // Номер главы (улучшенный дизайн)
                                    Container(
                                      width: 40,
                                      height: 40,
                                      margin: const EdgeInsets.only(right: 16),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: isCurrentChapter
                                              ? [
                                                  theme.primaryColor,
                                                  theme.primaryColor.withAlpha((0.6 * 255).round()),
                                                ]
                                              : [
                                                  Colors.grey.withAlpha((0.3 * 255).round()),
                                                  Colors.grey.withAlpha((0.1 * 255).round()),
                                                ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isCurrentChapter
                                                ? theme.primaryColor.withAlpha((0.5 * 255).round())
                                                : Colors.black.withAlpha((0.3 * 255).round()),
                                            blurRadius: isCurrentChapter ? 10 : 5,
                                            spreadRadius: isCurrentChapter ? 1 : 0,
                                          ),
                                        ],
                                        border: Border.all(
                                          color: isCurrentChapter
                                              ? theme.primaryColor.withAlpha((0.7 * 255).round())
                                              : Colors.white.withAlpha((0.1 * 255).round()),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: isCurrentChapter
                                                ? Colors.white
                                                : Colors.white.withAlpha((0.9 * 255).round()),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            shadows: isCurrentChapter
                                                ? [
                                                    Shadow(
                                                      color: Colors.black.withAlpha((0.5 * 255).round()),
                                                      blurRadius: 3,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
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
                                              color: isCurrentChapter
                                                  ? Colors.white
                                                  : Colors.white.withAlpha((0.9 * 255).round()),
                                              letterSpacing: 0.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: isCurrentChapter
                                                    ? theme.primaryColor
                                                    : Colors.white.withAlpha((0.5 * 255).round()),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatDuration(chapter.duration),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: isCurrentChapter
                                                      ? theme.primaryColor
                                                      : Colors.white.withAlpha((0.5 * 255).round()),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Индикатор текущей главы
                                    if (isCurrentChapter)
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black.withAlpha((0.3 * 255).round()),
                                        ),
                                        child: AnimatedBuilder(
                                          animation: _waveController,
                                          builder: (context, child) {
                                            return Icon(
                                              _isPlaying ? Icons.graphic_eq : Icons.play_arrow,
                                              color: theme.primaryColor,
                                              size: 24,
                                            );
                                          },
                                        ),
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
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'speed':
        _showSpeedDialog();
        break;
      case 'timer':
        _showSleepTimerDialog();
        break;
      case 'background':
        _toggleBackgroundPlayback();
        break;
    }
  }
  
  void _toggleBackgroundPlayback() {
    setState(() {
      _playInBackground = !_playInBackground;
    });
    
    // Настраиваем фоновое воспроизведение
    _setupBackgroundPlayback();
    
    // Показываем уведомление пользователю
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _playInBackground 
              ? 'Фоновое воспроизведение включено' 
              : 'Фоновое воспроизведение выключено'
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _setupBackgroundPlayback() async {
    try {
      // Получаем экземпляр AudioSession
      final session = await AudioSession.instance;
      
      if (_playInBackground) {
        // Настраиваем сессию для фонового воспроизведения музыки
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ));
        
        // Активируем сессию
        await session.setActive(true);
        print('Фоновое воспроизведение включено');
      } else {
        // При отключении фонового воспроизведения можно деактивировать сессию
        // или оставить её активной, но с другими настройками
        await session.setActive(false);
        print('Фоновое воспроизведение выключено');
      }
    } catch (e) {
      print('Ошибка при настройке фонового воспроизведения: $e');
    }
  }

  void _showSpeedDialog() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.black.withAlpha((0.8 * 255).round()),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withAlpha((0.1 * 255).round()), width: 1),
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
                    color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                value: speed,
                groupValue: _playbackSpeed,
                activeColor: Theme.of(context).primaryColor,
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

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.black.withAlpha((0.8 * 255).round()),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withAlpha((0.1 * 255).round()), width: 1),
          ),
          title: const Text(
            'Таймер сна',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_sleepTimer != null)
                ListTile(
                  title: const Text(
                    'Отключить таймер',
                    style: TextStyle(color: Colors.white),
                  ),
                  leading: const Icon(Icons.timer_off, color: Colors.red),
                  onTap: () {
                    setState(() {
                      _sleepTimer = null;
                      _sleepEndTime = null;
                    });
                    Navigator.pop(context);
                  },
                ),
              ...[5, 10, 15, 30, 60].map((minutes) {
                return ListTile(
                  title: Text(
                    '$minutes минут',
                    style: const TextStyle(color: Colors.white),
                  ),
                  leading: const Icon(Icons.timer, color: Colors.white),
                  onTap: () {
                    _setSleepTimer(Duration(minutes: minutes));
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
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
    _chapterListAnimationController.dispose();
    // Освобождаем аудио ресурсы
    _releaseAudioResources();
    super.dispose();
  }
  
  // Метод для освобождения аудио ресурсов
  Future<void> _releaseAudioResources() async {
    try {
      // Деактивируем аудио сессию при закрытии плеера
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      print('Ошибка при освобождении аудио ресурсов: $e');
    }
  }
}