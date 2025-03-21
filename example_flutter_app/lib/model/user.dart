import 'profile_image.dart';

class User {

  User({
    required this.id,
    required this.username,
    required this.name,
    this.bio,
    this.location,
    required this.profileImage,
    required this.totalPhotos,
    required this.totalLikes,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      name: json['name'] as String,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      profileImage: ProfileImage.fromJson(json['profile_image']),
      totalPhotos: json['total_photos'] as int? ?? 0,
      totalLikes: json['total_likes'] as int? ?? 0,
    );
  }
  final String id;
  final String username;
  final String name;
  final String? bio;
  final String? location;
  final ProfileImage profileImage;
  final int totalPhotos;
  final int totalLikes;
}
