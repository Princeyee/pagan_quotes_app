import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../models/audiobook.dart';
import '../../services/enhanced_audiobook_service.dart';
import '../../services/public_google_drive_service.dart';
import '../../services/progressive_download_service.dart';

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
  final PublicGoogleDriveService _driveService = PublicGoogleDriveService();

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
  
  // Background playback
  bool _playInBackground = true;

  DownloadProgress? _downloadProgress;
  StreamSubscription<DownloadProgress>? _progressSub;

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.initialChapter ?? 0;

    _initializeAnimations();
    _initializeAudio();
    _setupAudioListeners();
    _extractColorsFromCover();
    _audiobookService.initialize();
    _subscribeToDownloadProgress();
    _initAudioSession();
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
        await session.setActive(false);
        print('Фоновое воспроизведение выключено');
      }
    } catch (e) {
      print('Ошибка при настройке фонового воспроизведения: $e');
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

  // Извлечение цветов из обложки книги
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

  void _subscribeToDownloadProgress() {
    _progressSub?.cancel();
    final chapter = widget.audiobook.chapters[_currentChapterIndex];
    if (chapter.driveFileId != null) {
      // Устанавливаем начальное состояние заг��узки
      setState(() {
        _downloadProgress = DownloadProgress(
          fileId: chapter.driveFileId!,
          downloadedBytes: 0,
          totalBytes: 0,
          percentage: 0.0,
          status: ProgressiveDownloadStatus.downloading,
        );
      });
      
      _progressSub = _driveService.getDownloadProgressStream(chapter.driveFileId!).listen((progress) {
        setState(() {
          _downloadProgress = progress;
        });
        
        // Автостарт, если достигнут playable threshold
        if (!_isPlaying && progress.isPlayable && _isLoading) {
          setState(() {
            _isLoading = false;
          });
          _audioPlayer.play();
        }
        
        // Убираем состояние загрузки когда файл готов
        if (progress.status == ProgressiveDownloadStatus.completed && _isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  void _initializeAudio() async {
    setState(() => _isLoading = true);
    _downloadProgress = null;
    _subscribeToDownloadProgress();
    
    try {
      final chapter = widget.audiobook.chapters[_currentChapterIndex];
      
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
      
      // НЕ убираем _isLoading здесь - это сделает подписка на прогресс
      // когда файл станет playable или полностью загружен
      
      // Если файл уже готов (из кеша), убираем з��грузку
      if (playableUrl.startsWith('file://') || !playableUrl.startsWith('http')) {
        setState(() => _isLoading = false);
        await _audioPlayer.play();
      }
    } catch (e) {
      _showError('Ошибка загрузки аудиофайла: $e');
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
        _downloadProgress = null;
      });
      _subscribeToDownloadProgress();
      
      try {
        final chapter = widget.audiobook.chapters[index];
        
        final playableUrl = await _audiobookService.getPlayableUrl(chapter);
        
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
        
        // Если файл уже готов (из кеша), убираем загрузку
        if (playableUrl.startsWith('file://') || !playableUrl.startsWith('http')) {
          setState(() => _isLoading = false);
          await _audioPlayer.play();
        }
        
        // Предзагружаем следующие главы
        _audiobookService.preloadNextChapters(widget.audiobook, index);
        
      } catch (e) {
        _showError('Ошибка загрузки главы: $e');
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
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // Свайп вверх для показа списка глав
          if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
            setState(() => _showChapterList = true);
            _chapterListController.forward();
          }
          // Свайп вниз для скрытия списка глав
          else if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            setState(() => _showChapterList = false);
            _chapterListController.reverse();
          }
        },
        child: Container(
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: _handleMenuAction,
            color: _dominantColor.withOpacity(0.9),
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

  void _showSleepTimerDialog() {
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
    // Улучшенная логика определения состояния буферизации
    final isBuffering = _isLoading || 
                       (_downloadProgress == null && _isLoading) ||
                       (_downloadProgress != null && 
                        _downloadProgress!.status == ProgressiveDownloadStatus.downloading && 
                        !_downloadProgress!.isPlayable);
    final isDownloading = _downloadProgress != null && _downloadProgress!.status == ProgressiveDownloadStatus.downloading;
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Красивая анимация загрузки
          if (isBuffering) ...[
            _buildLoadingAnimation(),
            const SizedBox(height: 24),
          ] else ...[
            // Прогресс воспроизведения (показывается только когда файл готов)
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
          ],

          // Кнопки управления
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Предыдущая глава
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                iconSize: 32,
                onPressed: (_currentChapterIndex > 0 && !isBuffering) ? _previousChapter : null,
              ),

              // Перемотка назад
              IconButton(
                icon: const Icon(Icons.replay_30, color: Colors.white),
                iconSize: 28,
                onPressed: !isBuffering ? () {
                  final newPosition = _currentPosition - const Duration(seconds: 30);
                  _seek(newPosition < Duration.zero ? Duration.zero : newPosition);
                } : null,
              ),

              // Play/Pause
              _buildPlayPauseButton(),

              // Перемотка вперед
              IconButton(
                icon: const Icon(Icons.forward_30, color: Colors.white),
                iconSize: 28,
                onPressed: !isBuffering ? () {
                  final newPosition = _currentPosition + const Duration(seconds: 30);
                  _seek(newPosition > _totalDuration ? _totalDuration : newPosition);
                } : null,
              ),

              // Следующая глава
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                iconSize: 32,
                onPressed: (_currentChapterIndex < widget.audiobook.chapters.length - 1 && !isBuffering)
                    ? _nextChapter
                    : null,
              ),
            ],
          ),

          if (!isBuffering) ...[
            const SizedBox(height: 16),
            // Скорость воспроизведения (показывается только когда файл готов)
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
        ],
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    final isBuffering = _isLoading || 
                       (_downloadProgress == null && _isLoading) ||
                       (_downloadProgress != null && 
                        _downloadProgress!.status == ProgressiveDownloadStatus.downloading && 
                        !_downloadProgress!.isPlayable);
    return Container(
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
          onTap: isBuffering ? null : _playPause,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: isBuffering
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          value: _downloadProgress?.percentage ?? null,
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          backgroundColor: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      Icon(Icons.music_note, color: Colors.white.withOpacity(0.7), size: 28),
                    ],
                  )
                : AnimatedIcon(
                    icon: AnimatedIcons.play_pause,
                    progress: _playPauseController,
                    color: Colors.white,
                    size: 48,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingAnimation() {
    final downloadProgress = _downloadProgress;
    final progressPercentage = downloadProgress?.percentage ?? 0.0;
    final downloadSpeed = downloadProgress?.downloadSpeed ?? 0;
    final isDownloading = downloadProgress?.status == ProgressiveDownloadStatus.downloading;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Анимированная иконка загрузки
          Stack(
            alignment: Alignment.center,
            children: [
              // Внешний круг с анимацией
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3 + 0.3 * _waveController.value),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
              
              // Прогресс загрузки
              if (isDownloading)
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    value: progressPercentage,
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                )
              else
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                ),
              
              // Иконка в центре
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + 0.1 * _waveController.value,
                    child: Icon(
                      Icons.audiotrack,
                      color: Colors.white,
                      size: 32,
                    ),
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Текст загрузки
          Text(
            'Загрузка аудиокниги...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Детали загрузки
          if (isDownloading) ...[
            Text(
              '${(progressPercentage * 100).toInt()}% загружено',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            
            if (downloadSpeed > 0) ...[
              const SizedBox(height: 4),
              Text(
                _formatSpeed(downloadSpeed),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ] else ...[
            Text(
              'Подготовка к воспроизведению...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Прогресс бар
          if (isDownloading)
            Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progressPercentage,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.white.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1 + 2 * _waveController.value, 0),
                        end: Alignment(-0.5 + 2 * _waveController.value, 0),
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond} Б/с';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} КБ/с';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} МБ/с';
    }
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
    _progressSub?.cancel();
    _audioPlayer.dispose();
    _playPauseController.dispose();
    _waveController.dispose();
    _chapterListController.dispose();
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