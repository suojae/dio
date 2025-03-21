
import 'image_result.dart';
import 'profile_image.dart';
import 'tag.dart';

class Urls {

  Urls({
    required this.raw,
    required this.full,
    required this.regular,
    required this.small,
    required this.thumb,
  });

  factory Urls.fromJson(Map<String, dynamic> json) {
    return Urls(
      raw: json['raw'] as String,
      full: json['full'] as String,
      regular: json['regular'] as String,
      small: json['small'] as String,
      thumb: json['thumb'] as String,
    );
  }
  final String raw;
  final String full;
  final String regular;
  final String small;
  final String thumb;
}







