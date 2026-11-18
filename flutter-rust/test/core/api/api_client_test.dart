import 'dart:io';
import 'dart:typed_data';

import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient _client(
  MockClientHandler handler, {
  String? token = 'test-token',
}) => ApiClient(
  baseUrl: 'https://api.test',
  tokenProvider: () async => token,
  httpClient: MockClient(handler),
);

void main() {
  test('sends the bearer token, JSON body and returns the response', () async {
    late http.Request seen;
    final client = _client((request) async {
      seen = request;
      return http.Response('{"ok":true}', 201);
    });

    final body = await client.postJson('/v1/feedback', '{"a":1}');

    expect(body, '{"ok":true}');
    expect(seen.method, 'POST');
    expect(seen.url.toString(), 'https://api.test/v1/feedback');
    expect(seen.headers['Authorization'], 'Bearer test-token');
    expect(seen.headers['Content-Type'], startsWith('application/json'));
    expect(seen.body, '{"a":1}');
  });

  test('get / put / delete use the right HTTP method', () async {
    final methods = <String>[];
    final client = _client((request) async {
      methods.add(request.method);
      return http.Response('{}', request.method == 'DELETE' ? 204 : 200);
    });

    await client.getJson('/v1/profile');
    await client.putJson('/v1/profile', '{}');
    await client.delete('/v1/account');

    expect(methods, ['GET', 'PUT', 'DELETE']);
  });

  test('no signed-in user: throws before any request is made', () async {
    var requests = 0;
    final client = _client((request) async {
      requests++;
      return http.Response('', 200);
    }, token: null);

    await expectLater(
      client.getJson('/v1/profile'),
      throwsA(isA<ApiUnauthenticatedException>()),
    );
    expect(requests, 0);
  });

  test('error envelope becomes code + message', () async {
    final client = _client(
      (request) async => http.Response(
        '{"error":{"code":"validation_failed","message":"Name can\'t be empty."}}',
        422,
      ),
    );

    await expectLater(
      client.putJson('/v1/profile', '{}'),
      throwsA(
        isA<ApiResponseException>()
            .having((e) => e.statusCode, 'statusCode', 422)
            .having((e) => e.isValidation, 'isValidation', true)
            .having((e) => e.message, 'message', "Name can't be empty."),
      ),
    );
  });

  test('a non-envelope error body never crashes parsing', () async {
    for (final body in ['<html>502 Bad Gateway</html>', '', '{"oops":1}']) {
      final client = _client((request) async => http.Response(body, 502));
      await expectLater(
        client.getJson('/v1/feedback'),
        throwsA(
          isA<ApiResponseException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having((e) => e.code, 'code', ApiResponseException.codeUnknown),
        ),
        reason: 'body: $body',
      );
    }
  });

  test('connection failure becomes ApiNetworkException', () async {
    final client = _client(
      (request) async => throw const SocketException('offline'),
    );

    await expectLater(
      client.getJson('/v1/feedback'),
      throwsA(isA<ApiNetworkException>()),
    );
  });

  test(
    'isReachable is false, not an exception, when the API is down',
    () async {
      final client = _client(
        (request) async => throw const SocketException('offline'),
      );
      expect(await client.isReachable(), isFalse);
    },
  );

  test('postBytes sends raw bytes with the given content type', () async {
    late http.Request seen;
    final client = _client((request) async {
      seen = request;
      return http.Response('{"id":"x"}', 201);
    });

    final body = await client.postBytes(
      '/v1/files?name=a.png',
      Uint8List.fromList([1, 2, 3]),
      contentType: 'image/png',
    );

    expect(body, '{"id":"x"}');
    expect(seen.method, 'POST');
    expect(seen.bodyBytes, [1, 2, 3]);
    expect(seen.headers['Content-Type'], startsWith('image/png'));
    expect(seen.headers['Authorization'], 'Bearer test-token');
  });

  test('getBytes returns the body bytes untouched', () async {
    final client = _client(
      (request) async => http.Response.bytes([0, 255, 128, 7], 200),
    );
    expect(await client.getBytes('/v1/files/x'), [0, 255, 128, 7]);
  });

  test('getBytes maps a 404 to a typed exception', () async {
    final client = _client(
      (request) async => http.Response(
        '{"error":{"code":"not_found","message":"Not found."}}',
        404,
      ),
    );
    await expectLater(
      client.getBytes('/v1/files/x'),
      throwsA(
        isA<ApiResponseException>().having(
          (e) => e.isNotFound,
          'isNotFound',
          true,
        ),
      ),
    );
  });

  test('deleteJson sends DELETE with a JSON body', () async {
    late http.Request seen;
    final client = _client((request) async {
      seen = request;
      return http.Response('', 204);
    });
    await client.deleteJson('/v1/push/token', '{"token":"t"}');
    expect(seen.method, 'DELETE');
    expect(seen.body, '{"token":"t"}');
    expect(seen.headers['Content-Type'], startsWith('application/json'));
  });
}
