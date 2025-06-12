
class Audiobook {
  final String id;
  final String title;
  final String author;
  final String coverPath;
  final List<AudiobookChapter> chapters;
  final Duration totalDuration;
  final String? description;

  Audiobook({
    required this.id,
    required this.title,
    required this.author,
    required this.coverPath,
    required this.chapters,
    required this.totalDuration,
    this.description,
  });

  factory Audiobook.fromJson(Map<String, dynamic> json) {
    final chaptersJson = json['chapters'] as List<dynamic>;
    final chapters = chaptersJson
        .map((chapterJson) => AudiobookChapter.fromJson(chapterJson))
        .toList();

    final totalDurationMs = json['totalDurationMs'] as int? ?? 0;
    
    return Audiobook(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      coverPath: json['coverPath'] as String,
      chapters: chapters,
      totalDuration: Duration(milliseconds: totalDurationMs),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'coverPath': coverPath,
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
      'totalDurationMs': totalDuration.inMilliseconds,
      'description': description,
    };
  }
}

class AudiobookChapter {
  final String title;
  final String filePath;
  final Duration duration;
  final int chapterNumber;

  AudiobookChapter({
    required this.title,
    required this.filePath,
    required this.duration,
    required this.chapterNumber,
  });

  factory AudiobookChapter.fromJson(Map<String, dynamic> json) {
    final durationMs = json['durationMs'] as int? ?? 0;
    
    return AudiobookChapter(
      title: json['title'] as String,
      filePath: json['filePath'] as String,
      duration: Duration(milliseconds: durationMs),
      chapterNumber: json['chapterNumber'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'filePath': filePath,
      'durationMs': duration.inMilliseconds,
      'chapterNumber': chapterNumber,
    };
  }
}

class AudiobookProgress {
  final String audiobookId;
  final int chapterIndex;
  final Duration position;
  final DateTime lastPlayed;

  AudiobookProgress({
    required this.audiobookId,
    required this.chapterIndex,
    required this.position,
    required this.lastPlayed,
  });

  factory AudiobookProgress.fromJson(Map<String, dynamic> json) {
    return AudiobookProgress(
      audiobookId: json['audiobookId'] as String,
      chapterIndex: json['chapterIndex'] as int,
      position: Duration(milliseconds: json['positionMs'] as int),
      lastPlayed: DateTime.parse(json['lastPlayed'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'audiobookId': audiobookId,
      'chapterIndex': chapterIndex,
      'positionMs': position.inMilliseconds,
      'lastPlayed': lastPlayed.toIso8601String(),
    };
  }
}
