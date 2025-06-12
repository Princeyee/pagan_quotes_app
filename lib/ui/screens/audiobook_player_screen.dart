import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
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

    // Инициализируем контроллер анимации в правильном состоянии
    if (_isPlaying) {
      _playPauseController.value = 1.0;
    } else {
      _playPauseController.value = 0.0;
    }

    _initializeAudio();
    _setupAudioListeners();
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
      body: Stack(
        children: [
          // Blurred background from cover image
          Positioned.fill(
            child: Hero(
              tag: 'audiobook_cover_${widget.audiobook.id}',
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
                    color: Colors.black.withOpacity(0.7),
                  ),
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

                // Chapter List (if visible)
                if (_showChapterList)
                  Expanded(
                    flex: 2,
                    child: _buildChapterList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
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
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _showChapterList ? Icons.list : Icons.menu_book,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _showChapterList = !_showChapterList),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: _handleMenuAction,
            color: Colors.black.withOpacity(0.8),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoverSection(AudiobookChapter currentChapter) {
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
                    color: Colors.black.withOpacity(0.5),
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
                  child: widget.audiobook.coverPath.startsWith('http')
                      ? Image.network(
                          widget.audiobook.coverPath,
                          width: 300,
                          height: 300,
                          fit: BoxFit.cover,
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
                          fit: BoxFit.cover,
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
        ],
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
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.4),
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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Главы',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _showChapterList = false),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.audiobook.chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = widget.audiobook.chapters[index];
                    final isCurrentChapter = index == _currentChapterIndex;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isCurrentChapter 
                            ? Theme.of(context).primaryColor.withOpacity(0.3)
                            : Colors.transparent,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrentChapter
                              ? Theme.of(context).primaryColor
                              : Colors.white.withOpacity(0.2),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isCurrentChapter ? Colors.white : Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          chapter.title,
                          style: TextStyle(
                            fontWeight: isCurrentChapter ? FontWeight.bold : FontWeight.normal,
                            color: isCurrentChapter ? Colors.white : Colors.white.withOpacity(0.9),
                          ),
                        ),
                        subtitle: Text(
                          _formatDuration(chapter.duration),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        onTap: () => _changeChapter(index),
                        trailing: isCurrentChapter
                            ? AnimatedBuilder(
                                animation: _waveController,
                                builder: (context, child) {
                                  return Icon(
                                    Icons.graphic_eq,
                                    color: Colors.white,
                                  );
                                },
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
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
    }
  }

  void _showSpeedDialog() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
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
          backgroundColor: Colors.black.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
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
    super.dispose();
  }
}