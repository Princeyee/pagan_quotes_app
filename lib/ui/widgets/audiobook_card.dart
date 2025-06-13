import 'package:flutter/material.dart';
import '../../models/audiobook.dart';
import '../screens/audiobook_player_screen.dart';

class AudiobookCard extends StatelessWidget {
  final Audiobook audiobook;
  final VoidCallback? onTap;

  const AudiobookCard({
    Key? key,
    required this.audiobook,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          elevation: 8,
          color: Colors.black.withOpacity(0.8),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap ?? () => _navigateToPlayer(context),
            child: Container(
              height: 140,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Cover Art
                  Hero(
                    tag: 'audiobook_cover_${audiobook.id}',
                    child: Container(
                      width: 100,
                      height: 100, // Делаем контейнер квадратным
                      decoration: BoxDecoration(
                        color: Colors.black, // Черный фон для контейнера
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: audiobook.coverPath.startsWith('http')
                        ? Image.network(
                            audiobook.coverPath,
                            fit: BoxFit.cover, // Используем cover вместо fill
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.audiotrack,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              );
                            },
                          )
                        : Image.asset(
                            audiobook.coverPath,
                            fit: BoxFit.cover, // Используем cover вместо fill
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.audiotrack,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              );
                            },
                          ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Book Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          audiobook.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        Text(
                          audiobook.author,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Icon(
                              Icons.menu_book,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${audiobook.chapters.length} глав',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTotalDuration(audiobook.totalDuration),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Убираем кнопку Play
                ],
              ),
            ),
          ),
        ),
        // Добавляем название аудиокниги под карточкой
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            audiobook.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _navigateToPlayer(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AudiobookPlayerScreen(audiobook: audiobook),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  String _formatTotalDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}ч ${minutes}м';
    } else {
      return '${minutes}м';
    }
  }
}