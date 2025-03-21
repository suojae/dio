class Tag {
  Tag({
    required this.title,
    this.type,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      title: json['title'] as String,
      type: json['type'] as String?,
    );
  }
  final String title;
  final String? type;
}
