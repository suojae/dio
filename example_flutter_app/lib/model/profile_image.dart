class ProfileImage {

  ProfileImage({
    required this.small,
    required this.medium,
    required this.large,
  });

  factory ProfileImage.fromJson(Map<String, dynamic> json) {
    return ProfileImage(
      small: json['small'] as String,
      medium: json['medium'] as String,
      large: json['large'] as String,
    );
  }
  final String small;
  final String medium;
  final String large;
}