// lib/interceptors/app_interceptors.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// Logging interceptor for debugging
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('┌─────────────────────────────────────────────────────────────────────────');
      print('│ 🌐 REQUEST[${options.method}] => PATH: ${options.path}');
      print('│ Headers: ${options.headers}');
      print('│ QueryParameters: ${options.queryParameters}');
      if (options.data != null) {
        print('│ Body: ${_truncateIfNeeded(options.data)}');
      }
      print('└─────────────────────────────────────────────────────────────────────────');
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print('┌─────────────────────────────────────────────────────────────────────────');
      print('│ ✅ RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
      if (response.data != null) {
        print('│ Response: ${_truncateIfNeeded(response.data)}');
      }
      print('└─────────────────────────────────────────────────────────────────────────');
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      print('┌─────────────────────────────────────────────────────────────────────────');
      print('│ ❌ ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}');
      print('│ ${err.message}');
      if (err.response?.data != null) {
        print('│ Error Response: ${_truncateIfNeeded(err.response!.data)}');
      }
      print('└─────────────────────────────────────────────────────────────────────────');
    }
    super.onError(err, handler);
  }

  String _truncateIfNeeded(dynamic data) {
    try {
      final String stringData = data is String
          ? data
          : jsonEncode(data);

      if (stringData.length > 1000) {
        return '${stringData.substring(0, 1000)}... (truncated)';
      }
      return stringData;
    } catch (e) {
      return data.toString();
    }
  }
}

// Cache interceptor for storing and retrieving responses
class CacheInterceptor extends Interceptor {
  final Dio dio;
  final Map<String, CacheEntry> _cache = {};

  CacheInterceptor(this.dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final shouldCache = options.extra['cache'] == true;

    if (!shouldCache) {
      return handler.next(options);
    }

    final cacheKey = options.extra['cache-key'] as String? ??
        '${options.uri}${jsonEncode(options.queryParameters)}';

    final cachedResponse = _cache[cacheKey];

    if (cachedResponse != null && !cachedResponse.isExpired) {
      if (kDebugMode) {
        print('📦 Returning cached response for: $cacheKey');
      }

      // Return cached response
      final headers = Headers();
      cachedResponse.headers.forEach((key, values) {
        headers.set(key, values);
      });

      return handler.resolve(
        Response(
          data: cachedResponse.data,
          statusCode: 200,
          requestOptions: options,
          headers: headers,
        ),
      );
    }

    // No valid cache, proceed with request
    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Only cache successful responses
    if (response.statusCode != 200 && response.statusCode != 201) {
      return handler.next(response);
    }

    final shouldCache = response.requestOptions.extra['cache'] == true;

    if (shouldCache) {
      final cacheKey = response.requestOptions.extra['cache-key'] as String? ??
          '${response.requestOptions.uri}${jsonEncode(response.requestOptions.queryParameters)}';

      final ttl = response.requestOptions.extra['cache-ttl'] as Duration? ??
          const Duration(minutes: 10);

      if (kDebugMode) {
        print('💾 Caching response for: $cacheKey');
      }

      // Store response in cache
      _cache[cacheKey] = CacheEntry(
        data: response.data,
        headers: response.headers.map,
        expiry: DateTime.now().add(ttl),
      );
    }

    return handler.next(response);
  }

  // Clear specific cache entry
  void invalidateCache(String key) {
    _cache.remove(key);
  }

  // Clear all cache
  void clearCache() {
    _cache.clear();
  }
}

// Cache entry model
class CacheEntry {
  final dynamic data;
  final Map<String, List<String>> headers;
  final DateTime expiry;

  CacheEntry({
    required this.data,
    required this.headers,
    required this.expiry,
  });

  bool get isExpired => DateTime.now().isAfter(expiry);
}

// Error handling interceptor
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 429) {
      // Rate limiting - special handling
      // Could implement backoff strategy here
      if (kDebugMode) {
        print('⚠️ Rate limit hit! Implementing backoff...');
      }

      // If there's a Retry-After header, respect it
      final retryAfter = err.response?.headers['retry-after']?.first;
      if (retryAfter != null) {
        final seconds = int.tryParse(retryAfter) ?? 5;
        if (kDebugMode) {
          print('⏱️ Retrying after $seconds seconds');
        }
      }
    }

    // Add additional error information to help with debugging
    if (err.response != null) {
      err = DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: err.error,
        message: _buildDetailedErrorMessage(err),
      );
    }

    handler.next(err);
  }

  String _buildDetailedErrorMessage(DioException err) {
    final parts = <String>[];

    parts.add('Status: ${err.response?.statusCode}');
    parts.add('URL: ${err.requestOptions.uri}');
    parts.add('Method: ${err.requestOptions.method}');

    if (err.response?.data is Map) {
      try {
        final errorMap = err.response!.data as Map<String, dynamic>;
        if (errorMap.containsKey('errors')) {
          parts.add('Errors: ${errorMap['errors']}');
        } else if (errorMap.containsKey('error')) {
          parts.add('Error: ${errorMap['error']}');
        }
      } catch (_) {}
    }

    return parts.join(' | ');
  }
}

// Retry interceptor for transient failures
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int retries;
  final List<Duration> retryDelays;

  RetryInterceptor({
    required this.dio,
    this.retries = 3,
    this.retryDelays = const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ],
  });

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    // Check if we should retry based on extra options
    if (err.requestOptions.extra['retry'] != true) {
      return handler.next(err);
    }

    // Get current retry attempt
    var extra = err.requestOptions.extra;
    var currentRetry = extra['currentRetry'] as int? ?? 0;

    // Check if we can retry
    if (_shouldRetry(err) && currentRetry < retries) {
      // Update retry count
      extra['currentRetry'] = currentRetry + 1;

      // Calculate delay
      final delay = retryDelays.length > currentRetry
          ? retryDelays[currentRetry]
          : retryDelays.last;

      if (kDebugMode) {
        print('🔄 Retrying request (attempt ${currentRetry + 1}/$retries) after $delay');
      }

      // Wait before retrying
      await Future.delayed(delay);

      // Create options for retry
      final options = Options(
        method: err.requestOptions.method,
        headers: err.requestOptions.headers,
        extra: extra,
        contentType: err.requestOptions.contentType,
        responseType: err.requestOptions.responseType,
        validateStatus: err.requestOptions.validateStatus,
        receiveTimeout: err.requestOptions.receiveTimeout,
        sendTimeout: err.requestOptions.sendTimeout,
      );

      try {
        // Retry the request
        final response = await dio.request<dynamic>(
          err.requestOptions.path,
          data: err.requestOptions.data,
          queryParameters: err.requestOptions.queryParameters,
          options: options,
          cancelToken: err.requestOptions.cancelToken,
          onSendProgress: err.requestOptions.onSendProgress,
          onReceiveProgress: err.requestOptions.onReceiveProgress,
        );

        // Return successful response
        return handler.resolve(response);
      } catch (e) {
        // If retry fails, forward the error
        return handler.next(e is DioException ? e : err);
      }
    }

    // If we shouldn't retry, forward the error
    return handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    // Retry on timeouts and 5xx errors
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode != null && err.response!.statusCode! >= 500 && err.response!.statusCode! < 600);
  }
}