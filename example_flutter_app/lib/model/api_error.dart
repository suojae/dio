class ApiError {

  ApiError({
    required this.message,
    this.statusCode,
    this.errorType,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      message: json['errors'] is List
          ? (json['errors'] as List).first.toString()
          : json['error'] as String? ?? 'Unknown error',
      statusCode: json['statusCode'] as int?,
      errorType: json['errorType'] as String?,
    );
  }

  factory ApiError.fromException(dynamic exception) {
    return ApiError(
      message: exception.toString(),
    );
  }
  final String message;
  final int? statusCode;
  final String? errorType;
}