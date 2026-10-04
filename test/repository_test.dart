import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sweissa_municipality/core/models.dart';
import 'package:sweissa_municipality/core/repository.dart';

class SignedInRepository extends MunicipalityRepository {
  SignedInRepository(super.client);
  @override
  String? get userId => '10000000-0000-0000-0000-000000000001';
}

void main() {
  const owner = '10000000-0000-0000-0000-000000000001',
      id = '20000000-0000-0000-0000-000000000001';
  RequestDraft draft() => RequestDraft(id: id, ownerId: owner, service: false)
    ..category = 'مياه'
    ..description = 'A water pipe is leaking';
  test('retry after a committed insert does not insert again', () async {
    var inserts = 0;
    final client = SupabaseClient(
      'https://example.test',
      'key',
      httpClient: MockClient((request) async {
        if (request.method == 'POST') inserts++;
        return http.Response(
          jsonEncode([
            {'id': id, 'submission_fingerprint': draftFingerprint(draft())},
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await SignedInRepository(client).submit(draft());
    expect(inserts, 0);
    await client.dispose();
  });
  test('failed database insert is propagated to the form', () async {
    final client = SupabaseClient(
      'https://example.test',
      'key',
      httpClient: MockClient(
        (request) async => request.method == 'GET'
            ? http.Response(
                '[]',
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              )
            : http.Response(
                '{"code":"42501","message":"Denied"}',
                403,
                headers: {'content-type': 'application/json'},
                request: request,
              ),
      ),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await expectLater(
      SignedInRepository(client).submit(draft()),
      throwsA(isA<PostgrestException>()),
    );
    await client.dispose();
  });
  test('draft cannot be submitted under a different account', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://example.test',
      'key',
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('[]', 200);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await expectLater(
      SignedInRepository(client).submit(
        RequestDraft(id: id, ownerId: 'another-account', service: false),
      ),
      throwsA(isA<AuthException>()),
    );
    expect(calls, 0);
    await client.dispose();
  });

  test(
    'changed content under a committed ID is rejected instead of claiming success',
    () async {
      final client = SupabaseClient(
        'https://example.test',
        'key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode([
              {'id': id, 'submission_fingerprint': 'old-fingerprint'},
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await expectLater(
        SignedInRepository(client).submit(draft()),
        throwsA(isA<SubmittedDraftChanged>()),
      );
      await client.dispose();
    },
  );
  test('failed photo upload prevents database insertion', () async {
    var inserts = 0;
    final client = SupabaseClient(
      'https://example.test',
      'key',
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/storage/')) {
          return http.Response(
            '{"statusCode":"403","error":"Forbidden","message":"Denied"}',
            403,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST') inserts++;
        return http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final withPhoto = draft()
      ..photo = Uint8List.fromList([0xff, 0xd8, 0xff, 0])
      ..photoExtension = 'jpg';
    await expectLater(
      SignedInRepository(client).submit(withPhoto),
      throwsA(isA<StorageException>()),
    );
    expect(inserts, 0);
    await client.dispose();
  });
}
