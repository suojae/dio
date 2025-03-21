import 'image_result.dart';

class SearchResponse {

  SearchResponse({
    required this.total,
    required this.totalPages,
    required this.results,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      total: json['total'] as int,
      totalPages: json['total_pages'] as int,
      results: (json['results'] as List)
          .map((result) => ImageResult.fromJson(result))
          .toList(),
    );
  }
  final int total;
  final int totalPages;
  final List<ImageResult> results;
}

class ImageStats {

  ImageStats({
    required this.downloads,
    required this.views,
    required this.likes,
  });

  factory ImageStats.fromJson(Map<String, dynamic> json) {
    return ImageStats(
      downloads: json['downloads'] as int,
      views: json['views'] as int,
      likes: json['likes'] as int,
    );
  }
  final int downloads;
  final int views;
  final int likes;
}

