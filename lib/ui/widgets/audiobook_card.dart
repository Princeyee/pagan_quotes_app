
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/audiobook.dart';
import '../../utils/custom_cache.dart';

class AudiobookCard extends StatelessWidget {
  final Audiobook audiobook;
  final VoidCallback onTap;

  const AudiobookCard({
    Key? key,
    required this.audiobook,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.4 * 255).round()),
              blurRadius: 15,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Фоновое изображение обложки
              _buildCoverImage(),
              
              // Размытый оверлей
              _buildBlurredOverlay(),
              
              // Контент карточки
              _buildCardContent(context),
              
              // Индикатор воспроизведения
              _buildPlayIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    return audiobook.coverPath.startsWith('http')
        ? CachedNetworkImage(
            imageUrl: audiobook.coverPath,
            cacheManager: CustomCache.instance,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: Colors.grey[900],
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.amber,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => _buildDefaultCover(),
          )
        : Image.asset(
            audiobook.coverPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDefaultCover(),
          );
  }

  Widget _buildDefaultCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.withAlpha((0.6 * 255).round()),
            Colors.indigo.withAlpha((0.8 * 255).round()),
            Colors.black,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.audiotrack,
          color: Colors.white54,
          size: 60,
        ),
      ),
    );
  }

  Widget _buildBlurredOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withAlpha((0.3 * 255).round()),
              Colors.black.withAlpha((0.8 * 255).round()),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Верхняя часть - иконка аудио
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha((0.5 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withAlpha((0.2 * 255).round()),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.headphones,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              // Количество глав
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha((0.9 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${audiobook.chapters.length} глав',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // Нижняя часть - информация �� книге
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                audiobook.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 4),
              
              Text(
                audiobook.author,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withAlpha((0.9 * 255).round()),
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              // Длительность
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.white.withAlpha((0.8 * 255).round()),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(audiobook.totalDuration),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha((0.8 * 255).round()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayIndicator() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.amber,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withAlpha((0.4 * 255).round()),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.play_arrow,
          color: Colors.black,
          size: 28,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));

    if (duration.inHours > 0) {
      return '${hours}ч ${minutes}м';
    } else {
      return '${minutes}м';
    }
  }
}