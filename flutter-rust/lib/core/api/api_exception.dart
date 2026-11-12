/// Typed errors thrown by [ApiClient].
///
/// The client never returns `null` to signal failure — it throws one of
/// these. Providers let them propagate into `AsyncValue.error`. UI renders
/// the error state. No silent swallowing.
library;

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

/// The Worker answered with a non-2xx status. For 422 the [body] is the
/// user-facing validation message produced by the shared Rust rules.
class ApiResponseException extends ApiException {
  const ApiResponseException(super.path, this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiResponseException($path, $statusCode): $body';
}
