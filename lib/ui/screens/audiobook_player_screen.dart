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

    _initializeAudio();
    _setupAudioListeners();
  }

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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.primaryColor.withOpacity(0.1),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
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
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.audiobook.author,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_showChapterList ? Icons.list : Icons.menu_book),
            onPressed: () => setState(() => _showChapterList = !_showChapterList),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'speed', child: Text('Скорость')),
              const PopupMenuItem(value: 'timer', child: Text('Таймер сна')),
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
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: widget.audiobook.coverPath.startsWith('http')
                      ? Image.network(
                          widget.audiobook.coverPath,
                          width: 250,
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 250,
                              height: 250,
                              color: Colors.grey[800],
                              child: Icon(
                                Icons.audiotrack,
                                color: Colors.white,
                                size: 80,
                              ),
                            );
                          },
                        )
                      : Image.asset(
                          widget.audiobook.coverPath,
                          width: 250,
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 250,
                              height: 250,
                              color: Colors.grey[800],
                              child: Icon(
                                Icons.audiotrack,
                                color: Colors.white,
                                size: 80,
                              ),
                            );
                          },
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
                ),
                child: IconButton(
                  icon: AnimatedIcon(
                    icon: AnimatedIcons.play_pause,
                    progress: _playPauseController,
                    color: Colors.white,
                  ),
                  iconSize: 48,
                  onPressed: _isLoading ? null : _playPause,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Главы',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
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

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrentChapter
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isCurrentChapter ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    chapter.title,
                    style: TextStyle(
                      fontWeight: isCurrentChapter ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentChapter ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                  subtitle: Text(_formatDuration(chapter.duration)),
                  onTap: () => _changeChapter(index),
                  trailing: isCurrentChapter
                      ? AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, child) {
                            return Icon(
                              Icons.graphic_eq,
                              color: Theme.of(context).primaryColor,
                            );
                          },
                        )
                      : null,
                );
              },
            ),
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
    }
  }

  void _showSpeedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Скорость воспроизведения'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
            return RadioListTile<double>(
              title: Text('${speed}x'),
              value: speed,
              groupValue: _playbackSpeed,
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
    );
  }

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Таймер сна'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_sleepTimer != null)
              ListTile(
                title: const Text('Отключить таймер'),
                leading: const Icon(Icons.timer_off),
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
                title: Text('$minutes минут'),
                leading: const Icon(Icons.timer),
                onTap: () {
                  _setSleepTimer(Duration(minutes: minutes));
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
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