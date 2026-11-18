/// Typed errors thrown by [ApiClient].
///
/// The client never returns `null` to signal failure — it throws one of
/// these. Providers let them propagate into `AsyncValue.error`. UI renders
/// the error state. No silent swallowing.
library;

import 'dart:convert';

import 'package:app/core/api/api_client.dart' show ApiClient;

sealed class ApiException implements Exception {
  const ApiException(this.path);

  final String path;
}

/// No signed-in user. Route to sign-in instead of showing an error banner.
class ApiUnauthenticatedException extends ApiException {
  const ApiUnauthenticatedException(super.path);

  @override
  String toString() => 'ApiUnauthenticatedException($path)';
}

/// The request never got a response (offline, timeout, DNS, TLS).
/// Render the offline state and offer retry.
class ApiNetworkException extends ApiException {
  const ApiNetworkException(super.path, this.cause, this.stack);

  final Object cause;
  final StackTrace stack;

  @override
  String toString() => 'ApiNetworkException($path): $cause';
}

/// The Worker answered with a non-2xx status.
///
/// Every error body is `{"error": {"code", "message"}}` (see
/// `rust/shared/src/api.rs`). Branch on [code] — it is stable. [message] is
/// written for the user and safe to show for `validation_failed`; for other
/// codes prefer your own wording.
class ApiResponseException extends ApiException {
  const ApiResponseException(
    super.path,
    this.statusCode, {
    required this.code,
    required this.message,
  });

  /// Builds the exception from a raw response body. A body that is not the
  /// documented envelope (a proxy error page, an empty body) becomes code
  /// `unknown` with a generic message — never a parse crash.
  factory ApiResponseException.fromBody(
    String path,
    int statusCode,
    String body,
  ) {
    try {
      final decoded = jsonDecode(body);
      if (decoded case {
        'error': {'code': final String code, 'message': final String message},
      }) {
        return ApiResponseException(
          path,
          statusCode,
          code: code,
          message: message,
        );
      }
    } on FormatException {
      // fall through
    }
    return ApiResponseException(
      path,
      statusCode,
      code: codeUnknown,
      message: 'Something went wrong. Try again.',
    );
  }

  static const codeUnknown = 'unknown';
  static const codeValidationFailed = 'validation_failed';
  static const codeNotFound = 'not_found';
  static const codeUnauthenticated = 'unauthenticated';

  final int statusCode;
  final String code;
  final String message;

  bool get isValidation => code == codeValidationFailed;
  bool get isNotFound => code == codeNotFound;

  @override
  String toString() =>
      'ApiResponseException($path, $statusCode, $code): $message';
}
