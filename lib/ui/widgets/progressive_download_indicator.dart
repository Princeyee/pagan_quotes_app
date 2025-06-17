import 'package:flutter/material.dart';
import '../../services/progressive_download_service.dart';
import '../../services/local_audio_server.dart';

/// Виджет для отображения прогресса прогрессивной загрузки
class ProgressiveDownloadIndicator extends StatefulWidget {
  final String fileId;
  final Stream<DownloadProgress> progressStream;
  final VoidCallback? onCancel;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  const ProgressiveDownloadIndicator({
    Key? key,
    required this.fileId,
    required this.progressStream,
    this.onCancel,
    this.onPause,
    this.onResume,
  }) : super(key: key);

  @override
  State<ProgressiveDownloadIndicator> createState() => _ProgressiveDownloadIndicatorState();
}

class _ProgressiveDownloadIndicatorState extends State<ProgressiveDownloadIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  DownloadProgress? _currentProgress;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DownloadProgress>(
      stream: widget.progressStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        _currentProgress = snapshot.data!;
        final progress = _currentProgress!;

        // Обновляем анимацию прогресса
        _progressController.animateTo(progress.percentage);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(progress),
              const SizedBox(height: 12),
              _buildProgressBar(progress),
              const SizedBox(height: 8),
              _buildProgressInfo(progress),
              if (progress.status == ProgressiveDownloadStatus.downloading)
                _buildControls(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(DownloadProgress progress) {
    IconData icon;
    Color iconColor;
    String statusText;

    switch (progress.status) {
      case ProgressiveDownloadStatus.downloading:
        icon = Icons.download;
        iconColor = Colors.blue;
        statusText = progress.isPlayable ? 'Загрузка (можно воспроизводить)' : 'Загрузка...';
        break;
      case ProgressiveDownloadStatus.completed:
        icon = Icons.check_circle;
        iconColor = Colors.green;
        statusText = 'Загрузка завершена';
        break;
      case ProgressiveDownloadStatus.paused:
        icon = Icons.pause_circle;
        iconColor = Colors.orange;
        statusText = 'Загрузка приостановлена';
        break;
      case ProgressiveDownloadStatus.error:
        icon = Icons.error;
        iconColor = Colors.red;
        statusText = 'Ошибка загрузки';
        break;
      case ProgressiveDownloadStatus.cancelled:
        icon = Icons.cancel;
        iconColor = Colors.grey;
        statusText = 'Загрузка отменена';
        break;
      default:
        icon = Icons.download;
        iconColor = Colors.grey;
        statusText = 'Ожидание...';
    }

    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Icon(
              icon,
              color: progress.status == ProgressiveDownloadStatus.downloading
                  ? iconColor.withOpacity(0.5 + 0.5 * _pulseController.value)
                  : iconColor,
              size: 24,
            );
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (progress.isPlayable && progress.status == ProgressiveDownloadStatus.downloading)
                Text(
                  '🎵 Готов к воспроизведению',
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(DownloadProgress progress) {
    return Column(
      children: [
        // Основной прогресс-бар
        AnimatedBuilder(
          animation: _progressController,
          builder: (context, child) {
            return LinearProgressIndicator(
              value: _progressController.value,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress.isPlayable ? Colors.green : Colors.blue,
              ),
              minHeight: 6,
            );
          },
        ),
        
        const SizedBox(height: 4),
        
        // Индикатор готовности к воспроизведению
        Stack(
          children: [
            Container(
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            FractionallySizedBox(
              widthFactor: 0.15, // 15% для готовности к воспроизведению
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: progress.percentage >= 0.15 ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressInfo(DownloadProgress progress) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${(progress.percentage * 100).toInt()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '${AudioFileUtils.formatFileSize(progress.downloadedBytes)} / ${AudioFileUtils.formatFileSize(progress.totalBytes)}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedInfo(DownloadProgress progress) {
    if (progress.downloadSpeed <= 0) return const SizedBox.shrink();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AudioFileUtils.formatSpeed(progress.downloadSpeed),
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        if (progress.estimatedTimeRemaining.inSeconds > 0)
          Text(
            'Осталось: ${AudioFileUtils.formatDuration(progress.estimatedTimeRemaining)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (widget.onPause != null)
            IconButton(
              icon: const Icon(Icons.pause, color: Colors.white),
              onPressed: widget.onPause,
              tooltip: 'Приостановить',
            ),
          if (widget.onResume != null)
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              onPressed: widget.onResume,
              tooltip: 'Возобновить',
            ),
          if (widget.onCancel != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: widget.onCancel,
              tooltip: 'От��енить',
            ),
        ],
      ),
    );
  }
}

/// Компактный индикатор прогресса для встраивания в другие виджеты
class CompactProgressIndicator extends StatelessWidget {
  final DownloadProgress progress;
  final double size;

  const CompactProgressIndicator({
    Key? key,
    required this.progress,
    this.size = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CircularProgressIndicator(
            value: progress.percentage,
            strokeWidth: 2,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress.isPlayable ? Colors.green : Colors.blue,
            ),
          ),
          Center(
            child: Icon(
              progress.isPlayable ? Icons.play_arrow : Icons.download,
              size: size * 0.6,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Виджет для отображения статуса буферизации
class BufferingIndicator extends StatefulWidget {
  final bool isBuffering;
  final double? bufferPercentage;

  const BufferingIndicator({
    Key? key,
    required this.isBuffering,
    this.bufferPercentage,
  }) : super(key: key);

  @override
  State<BufferingIndicator> createState() => _BufferingIndicatorState();
}

class _BufferingIndicatorState extends State<BufferingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    if (widget.isBuffering) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(BufferingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBuffering != oldWidget.isBuffering) {
      if (widget.isBuffering) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isBuffering) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationController.value * 2 * 3.14159,
                child: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: 16,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            widget.bufferPercentage != null
                ? 'Буферизация ${(widget.bufferPercentage! * 100).toInt()}%'
                : 'Буферизация...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}