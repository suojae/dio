import 'collection.dart';
import 'image_result.dart';
import 'models.dart';
import 'search_response.dart';
import 'tag.dart';
import 'user.dart';

class ImageDetails extends ImageResult {

  ImageDetails({
    required super.id,
    required super.description,
    required super.altDescription,
    required super.urls,
    required super.user,
    required super.likes,
    required super.createdAt,
    super.tags,
    this.location,
    this.exif,
    this.statistics,
    this.topics,
    this.relatedCollections,
  });

  factory ImageDetails.fromJson(Map<String, dynamic> json) {
    return ImageDetails(
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
      location: json['location'] != null ? json['location']['name'] as String? : null,
      exif: json['exif'] as Map<String, dynamic>?,
      statistics: json['statistics'] != null
          ? ImageStats.fromJson(json['statistics'])
          : null,
      topics: json['topics'] != null
          ? (json['topics'] as List).map((topic) => topic['title'] as String).toList()
          : null,
      relatedCollections: json['related_collections'] != null
          ? (json['related_collections']['results'] as List)
          .map((collection) => Collection.fromJson(collection))
          .toList()
          : null,
    );
  }
  final String? location;
  final Map<String, dynamic>? exif;
  final ImageStats? statistics;
  final List<String>? topics;
  final List<Collection>? relatedCollections;
}
