import 'image_result.dart';
import 'user.dart';

class Collection {

  Collection({
    required this.id,
    required this.title,
    required this.description,
    required this.user,
    required this.totalPhotos,
    this.previewPhotos,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      user: User.fromJson(json['user']),
      totalPhotos: json['total_photos'] as int,
      previewPhotos: json['preview_photos'] != null
          ? (json['preview_photos'] as List)
          .map((photo) => ImageResult.fromJson(photo))
          .toList()
          : null,
    );
  }
  final String id;
  final String title;
  final String description;
  final User user;
  final int totalPhotos;
  final List<ImageResult>? previewPhotos;
}
