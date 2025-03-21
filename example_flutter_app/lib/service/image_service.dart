import 'package:dio/dio.dart';
import '../model/api_error.dart';
import '../model/image_detail.dart';
import '../model/image_result.dart';
import '../model/search_response.dart';
import 'dio_interceptor.dart';

class ImageService {
  static const String _baseUrl = 'https://api.unsplash.com';
  static const String _apiKey = 'Lq6vQ6mgauclu2L4I_lX9WpyuNs6JW7I7Re-axIB8DM'; // demo api key


  late final Dio _dio;

  // Singleton pattern
  static final ImageService _instance = ImageService._internal();

  factory ImageService() => _instance;

  ImageService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Authorization': 'Client-ID $_apiKey',
        'Accept-Version': 'v1',
      },
    ),);

    // Add interceptors
    _dio.interceptors.add(LoggingInterceptor());
    _dio.interceptors.add(CacheInterceptor(_dio));
    _dio.interceptors.add(ErrorInterceptor());
    _dio.interceptors.add(RetryInterceptor(
      dio: _dio,
      retries: 3,
      retryDelays: const [
        Duration(milliseconds: 500),
        Duration(seconds: 1),
        Duration(seconds: 2),
      ],
    ),);
  }

  // Search for images
  Future<SearchResponse> searchImages({
    required String query,
    int page = 1,
    int perPage = 20,
    String? orderBy,
    String? color,
    String? orientation,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '/search/photos',
        queryParameters: {
          'query': query,
          'page': page,
          'per_page': perPage,
          if (orderBy != null) 'order_by': orderBy,
          if (color != null) 'color': color,
          if (orientation != null) 'orientation': orientation,
        },
        cancelToken: cancelToken,
        options: Options(
          extra: {
            'cache': true,
            'cache-key': 'search-$query-$page-$perPage-$orderBy-$color-$orientation',
            'cache-ttl': const Duration(hours: 1),
          },
        ),
      );

      return SearchResponse.fromJson(response.data);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      throw ApiError.fromException(e);
    }
  }

  // Get trending images
  Future<List<ImageResult>> getTrendingImages({
    int page = 1,
    int perPage = 20,
    String orderBy = 'popular',
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '/photos',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          'order_by': orderBy,
        },
        cancelToken: cancelToken,
        options: Options(
          extra: {
            'cache': true,
            'cache-key': 'trending-$page-$perPage-$orderBy',
            'cache-ttl': const Duration(minutes: 30),
          },
        ),
      );

      return (response.data as List)
          .map((json) => ImageResult.fromJson(json))
          .toList();
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      throw ApiError.fromException(e);
    }
  }

  // Get image details by ID
  Future<ImageDetails> getImageDetails({
    required String id,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '/photos/$id',
        queryParameters: {
          'statistics': 'true',
        },
        cancelToken: cancelToken,
        options: Options(
          extra: {
            'cache': true,
            'cache-key': 'image-details-$id',
            'cache-ttl': const Duration(hours: 2),
          },
        ),
      );

      return ImageDetails.fromJson(response.data);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      throw ApiError.fromException(e);
    }
  }

  // Get related images
  Future<List<ImageResult>> getRelatedImages({
    required String id,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '/photos/$id/related',
        cancelToken: cancelToken,
        options: Options(
          extra: {
            'cache': true,
            'cache-key': 'related-images-$id',
            'cache-ttl': const Duration(hours: 2),
          },
        ),
      );

      return (response.data['results'] as List)
          .map((json) => ImageResult.fromJson(json))
          .toList();
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      throw ApiError.fromException(e);
    }
  }

  // Get images by collection
  Future<List<ImageResult>> getCollectionImages({
    required String collectionId,
    int page = 1,
    int perPage = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '/collections/$collectionId/photos',
        queryParameters: {
          'page': page,
          'per_page': perPage,
        },
        cancelToken: cancelToken,
        options: Options(
          extra: {
            'cache': true,
            'cache-key': 'collection-$collectionId-$page-$perPage',
            'cache-ttl': const Duration(hours: 1),
          },
        ),
      );

      return (response.data as List)
          .map((json) => ImageResult.fromJson(json))
          .toList();
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      throw ApiError.fromException(e);
    }
  }

  // Download image
  Future<String> trackDownload({
    required String id,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '/photos/$id/download',
        cancelToken: cancelToken,
        options: Options(
          extra: {
            'retry': true,
          },
        ),
      );

      return response.data['url'] as String;
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      throw ApiError.fromException(e);
    }
  }

  // Handle DioExceptions and convert to ApiError
  dynamic _handleDioError(DioException e) {
    if (CancelToken.isCancel(e)) {
      throw ApiError(message: 'Request was cancelled');
    }

    if (e.response != null) {
      // Server responded with error
      final statusCode = e.response?.statusCode;

      if (statusCode == 401) {
        throw ApiError(
          message: 'Unauthorized: Invalid API key',
          statusCode: statusCode,
          errorType: 'auth',
        );
      } else if (statusCode == 403) {
        throw ApiError(
          message: 'Rate limit exceeded. Please try again later.',
          statusCode: statusCode,
          errorType: 'rate_limit',
        );
      } else if (statusCode == 404) {
        throw ApiError(
          message: 'Resource not found',
          statusCode: statusCode,
          errorType: 'not_found',
        );
      } else if (e.response?.data is Map) {
        // Try to parse error from response
        try {
          return ApiError.fromJson(e.response!.data);
        } catch (_) {
          throw ApiError(
            message: 'Server error: ${e.response?.statusMessage ?? 'Unknown error'}',
            statusCode: statusCode,
          );
        }
      } else {
        throw ApiError(
          message: 'Server error: ${e.response?.statusMessage ?? 'Unknown error'}',
          statusCode: statusCode,
        );
      }
    } else if (e.type == DioExceptionType.connectionTimeout) {
      throw ApiError(
        message: 'Connection timeout. Please check your internet connection.',
        errorType: 'timeout',
      );
    } else if (e.type == DioExceptionType.receiveTimeout) {
      throw ApiError(
        message: 'Receive timeout. The server is taking too long to respond.',
        errorType: 'timeout',
      );
    } else if (e.type == DioExceptionType.sendTimeout) {
      throw ApiError(
        message: 'Send timeout. The server is taking too long to respond.',
        errorType: 'timeout',
      );
    } else {
      throw ApiError(
        message: 'Network error: ${e.message}',
        errorType: 'network',
      );
    }
  }

  // Clear all caches
  void clearCache() {
    final cacheInterceptor = _dio.interceptors.firstWhere(
          (interceptor) => interceptor is CacheInterceptor,
      orElse: () => throw Exception('CacheInterceptor not found'),
    ) as CacheInterceptor;

    cacheInterceptor.clearCache();
  }

  // Set/Update API key (useful for runtime changes)
  void updateApiKey(String apiKey) {
    _dio.options.headers['Authorization'] = 'Client-ID $apiKey';
  }
}