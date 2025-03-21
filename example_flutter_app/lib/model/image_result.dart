import 'models.dart';
import 'tag.dart';
import 'user.dart';

class ImageResult {

  ImageResult({
    required this.id,
    required this.description,
    required this.altDescription,
    required this.urls,
    required this.user,
    required this.likes,
    required this.createdAt,
    this.tags,
  });

  factory ImageResult.fromJson(Map<String, dynamic> json) {
    return ImageResult(
      id: json['id'] as String,
      description: json['description'] as String? ?? '',
      altDescription: json['alt_description'] as String? ?? '',
      urls: Urls.fromJson(json['urls']),
      user: User.fromJson(json['user']),
      likes: json['likes'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      tags: json['tags'] != null
          ? (json['tags'] as List).map((tag) => Tag.fromJson(tag)).toList()
          : null,
    );
  }
  final String id;
  final String description;
  final String altDescription;
  final Urls urls;
  final User user;
  final int likes;
  final DateTime createdAt;
  final List<Tag>? tags;
}
